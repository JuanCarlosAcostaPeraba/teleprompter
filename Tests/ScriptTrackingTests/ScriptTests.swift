import ScriptTracking
import XCTest

final class ScriptTests: XCTestCase {
    func testSpanishAccentsAndStageDirections() {
        let script = Script("¡Buenos días! [Mira a cámara]\n¿Qué tal?")
        XCTAssertEqual(script.words, ["buenos", "dias", "que", "tal"])
        XCTAssertEqual(script.tokens.map(\.text).joined(), "¡Buenos días! [Mira a cámara]\n¿Qué tal?")
        XCTAssertEqual(script.nextPosition(after: 0, transcript: "Buenos dias", previous: ""), 2)
    }

    func testPausesAndRepeatedWords() {
        let script = Script("very very good morning today")
        XCTAssertEqual(script.nextPosition(after: 0, transcript: "very", previous: ""), 1)
        XCTAssertEqual(script.nextPosition(after: 1, transcript: "very", previous: "very"), 1)
        XCTAssertEqual(script.nextPosition(after: 1, transcript: "very very", previous: "very"), 2)
        XCTAssertEqual(script.nextPosition(after: 2, transcript: "very very actually", previous: "very very"), 2)
    }

    func testDistinctivePhraseCanJumpBothDirections() {
        let script = Script("we are ready to begin the session let me show this final example")
        XCTAssertEqual(script.nextPosition(after: 1, transcript: "this final example", previous: ""), 13)
        XCTAssertEqual(script.nextPosition(after: 13, transcript: "ready to begin", previous: ""), 5)
    }

    func testAmbiguousDistantPhraseStaysPut() {
        let script = Script("one two three four five six seven eight what comes next then what comes next")
        XCTAssertEqual(script.nextPosition(after: 0, transcript: "what comes next", previous: ""), 0)
    }
    func testSpanishEndingAfterOmissionInsertionOrSubstitution() {
        let script = Script("El texto espera y continúa cuando vuelvo a hablar")
        let prior = "El texto espera y continúa cuando"
        for transcript in [
            "El texto espera y continúa cuando a hablar",
            "El texto espera y continúa cuando vuelvo eh a hablar",
            "El texto espera y continúa cuando vuelvo de hablar",
        ] {
            XCTAssertEqual(script.nextPosition(after: 6, transcript: transcript, previous: prior), 9)
        }
    }

    func testDoesNotFinishWithoutFinalWord() {
        let script = Script("El texto espera y continúa cuando vuelvo a hablar")
        XCTAssertLessThan(script.nextPosition(after: 6, transcript: "continúa cuando vuelvo a", previous: ""), 9)
    }

    func testSpanishEndingCanRecoverAfterRecognitionResets() {
        let script = Script("Buenos días. Hoy vamos a comprobar que el lector sigue cada palabra. Cuando hago una pausa, el texto espera y continúa cuando vuelvo a hablar.")
        XCTAssertEqual(script.nextPosition(after: 21, transcript: "a hablar", previous: ""), 25)
        XCTAssertEqual(script.nextPosition(after: 21, transcript: "a hablar", previous: "a hablar"), 21)

        let repeated = Script("Vamos a hablar. Pero después vuelvo a hablar.")
        XCTAssertEqual(repeated.nextPosition(after: 4, transcript: "a hablar", previous: ""), 4)
    }
    func testJapaneseSegmentationPreservesOriginalTextAndTracksSpeech() {
        let text = "今日はいい天気です。[間を置く] 明日も晴れです。"
        let script = Script(text, locale: "ja-JP")
        XCTAssertEqual(script.tokens.map(\.text).joined(), text)
        XCTAssertGreaterThan(script.words.count, 4)
        let transcript = "今日はいい天気です。明日も晴れです。"
        XCTAssertEqual(script.nextPosition(after: 0, transcript: transcript, previous: ""), script.words.count)
    }
}
