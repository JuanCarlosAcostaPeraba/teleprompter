import Foundation

public struct Script {
    public struct Token: Identifiable {
        public let id: Int
        public let text: String
        public let wordIndex: Int?
    }

    public let tokens: [Token]
    public let words: [String]
    private let positions: [String: [Int]]

    public init(_ text: String) {
        var words: [String] = []
        var tokens: [Token] = []
        let pattern = #/\[[^\]]*\]|[\p{L}\p{M}\p{N}]+(?:[’'][\p{L}\p{M}\p{N}]+)*|[^\p{L}\p{M}\p{N}]/#
        for match in text.matches(of: pattern) {
            let value = String(match.output)
            let isWord = value.first.map { $0.isLetter || $0.isNumber } ?? false
            tokens.append(Token(id: tokens.count, text: value, wordIndex: isWord ? words.count : nil))
            if isWord { words.append(Self.normalize(value)) }
        }
        self.words = words
        self.tokens = tokens
        self.positions = Dictionary(grouping: words.indices, by: { words[$0] })
    }

    private static func normalize(_ word: String) -> String {
        word.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "’", with: "'")
    }

    /// Uses the latest contiguous spoken phrase. A short match can advance
    /// locally; a jump needs a distinctive phrase and fresh spoken evidence.
    public func nextPosition(after cursor: Int, transcript: String, previous: String) -> Int {
        let heard = Array(Script(transcript).words.suffix(10))
        let old = Array(Script(previous).words.suffix(10))
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
