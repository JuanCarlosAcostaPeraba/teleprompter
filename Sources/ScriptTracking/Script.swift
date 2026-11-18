import Foundation
import NaturalLanguage

public struct Script {
    public struct Token: Identifiable {
        public let id: Int
        public let text: String
        public let wordIndex: Int?
    }

    public let tokens: [Token]
    public let words: [String]
    private let positions: [String: [Int]]
    private let locale: String?

    public init(_ text: String, locale: String? = nil) {
        self.locale = locale
        var words: [String] = []
        var tokens: [Token] = []
        let language = locale.map { Locale(identifier: $0) }
        let code = language?.language.languageCode?.identifier
        let tokenizer: NLTokenizer?
        if let code, ["zh", "ja", "th", "lo", "km", "my"].contains(code) {
            let wordTokenizer = NLTokenizer(unit: .word)
            let script = language?.language.script?.identifier
            wordTokenizer.setLanguage(NLLanguage(rawValue: code == "zh" && script == "Hant" ? "zh-Hant" : code))
            tokenizer = wordTokenizer
        } else {
            tokenizer = nil
        }

        func append(_ value: String, word: Bool) {
            tokens.append(Token(id: tokens.count, text: value, wordIndex: word ? words.count : nil))
            if word { words.append(Self.normalize(value)) }
        }

        let pattern = #/\[[^\]]*\]|[\p{L}\p{M}\p{N}]+(?:[’'][\p{L}\p{M}\p{N}]+)*|[^\p{L}\p{M}\p{N}]/#
        for match in text.matches(of: pattern) {
            let value = String(match.output)
            let isWord = value.first.map { $0.isLetter || $0.isNumber } ?? false
            guard isWord, let tokenizer else {
                append(value, word: isWord)
                continue
            }
            tokenizer.string = value
            var index = value.startIndex
            tokenizer.enumerateTokens(in: value.startIndex..<value.endIndex) { range, _ in
                if index < range.lowerBound { append(String(value[index..<range.lowerBound]), word: true) }
                append(String(value[range]), word: true)
                index = range.upperBound
                return true
            }
            if index < value.endIndex { append(String(value[index...]), word: true) }
        }
        self.words = words
        self.tokens = tokens
        self.positions = Dictionary(grouping: words.indices, by: { words[$0] })
    }

    public func recognitionContext(near cursor: Int) -> [String] {
        let visibleWords = tokens.compactMap { token -> String? in
            guard let index = token.wordIndex, index >= cursor, index < cursor + 60 else { return nil }
            return token.text
        }
        return stride(from: 0, to: visibleWords.count, by: 4).compactMap { start in
            let phrase = visibleWords[start..<min(start + 6, visibleWords.count)]
            return phrase.count >= 2 ? phrase.joined(separator: " ") : nil
        }
    }

    private static func normalize(_ word: String) -> String {
        word.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "’", with: "'")
    }

    /// Uses the latest contiguous spoken phrase. A short match can advance
    /// locally; a jump needs a distinctive phrase and fresh spoken evidence.
    public func nextPosition(after cursor: Int, transcript: String, previous: String) -> Int {
        let heard = Array(Script(transcript, locale: locale).words.suffix(10))
        let old = Array(Script(previous, locale: locale).words.suffix(10))
        guard heard != old, let last = heard.last, let endings = positions[last] else { return cursor }

        var nearby: [(end: Int, length: Int)] = []
        var distant: [(end: Int, length: Int)] = []
        for end in endings {
            let length = zip(heard.reversed(), words[...end].reversed())
                .prefix { $0 == $1 }.count
            if end + 1 >= cursor && end + 1 <= cursor + 6 {
                let startsAtCursor = end + 1 - length <= cursor
                let isNextWord = end == cursor && (old.isEmpty || old.last != last || heard.count > old.count)
                if (length >= 2 && startsAtCursor) || isNextWord {
                    nearby.append((end, length))
                    continue
                }
            }
            if length >= 3 && (old.count < 3 || !old.suffix(3).elementsEqual(heard.suffix(3))) {
                distant.append((end, length))
            }
        }
        let local = nearby.max { lhs, rhs in
            lhs.length == rhs.length ? lhs.end > rhs.end : lhs.length < rhs.length
        }
        if let best = distant.max(by: { $0.length < $1.length }),
           best.length > (local?.length ?? 0),
           distant.filter({ $0.length == best.length }).count == 1 {
            return best.end + 1
        }
        let exactPosition = local.map { $0.end + 1 } ?? cursor
        guard exactPosition < words.count else { return exactPosition }

        // A recognizer may resume after a pause with just the last two
        // words. Require a fresh, unique ending within two skipped words.
        if (3...4).contains(words.count - cursor), heard.count >= 2,
           heard.suffix(2).elementsEqual(words.suffix(2)),
           !heard.suffix(2).elementsEqual(old.suffix(2)),
           endings.filter({ $0 > 0 && words[$0 - 1] == heard[heard.count - 2] }).count == 1 {
            return words.count
        }

        // Allow one dictation error close to the current position. An exact
        // final word and two additional matches are required to move forward.
        let candidates = endings.filter { end in
            let skipped = end - cursor
            guard end >= exactPosition, (1...4).contains(skipped) else { return false }
            return matchesWithOneEdit(heard: heard, endingAt: end, cursor: cursor)
        }
        return candidates.count == 1 ? candidates[0] + 1 : exactPosition
    }

    private func matchesWithOneEdit(heard: [String], endingAt end: Int, cursor: Int) -> Bool {
        let longest = min(7, end + 1)
        let shortest = max(3, end - cursor + 1)
        guard shortest <= longest else { return false }

        for length in shortest...longest {
            let expected = Array(words[(end + 1 - length)...end])
            for observedLength in (length - 1)...(length + 1) where observedLength <= heard.count {
                let observed = Array(heard.suffix(observedLength))
                let prefix = zip(expected, observed).prefix { $0 == $1 }.count
                let suffix = zip(expected.dropFirst(prefix).reversed(), observed.dropFirst(prefix).reversed())
                    .prefix { $0 == $1 }.count
                let shared = prefix + suffix
                if shared >= 3, max(expected.count, observed.count) - shared == 1 {
                    return true
                }
            }
        }
        return false
    }
}
