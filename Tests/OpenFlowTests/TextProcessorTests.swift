import XCTest
@testable import OpenFlow

final class TextProcessorTests: XCTestCase {
    private func processor(
        fillers: Bool = true,
        dictionary: [DictionaryEntry] = []
    ) -> TextProcessor {
        TextProcessor(removeFillers: fillers, dictionary: dictionary)
    }

    // MARK: - Filler removal

    func testRemovesCommonFillers() {
        XCTAssertEqual(
            processor().process("um so we should uh meet tomorrow"),
            "So we should meet tomorrow"
        )
    }

    func testRemovesFillersWithTrailingPunctuation() {
        XCTAssertEqual(
            processor().process("Um, let's start the meeting."),
            "Let's start the meeting."
        )
    }

    func testKeepsFillersWhenDisabled() {
        XCTAssertEqual(
            processor(fillers: false).process("um hello"),
            "Um hello"
        )
    }

    func testDoesNotEatWordsContainingFillerSubstrings() {
        // "umbrella" contains "um"; "uhuru" starts with "uh".
        XCTAssertEqual(
            processor().process("the umbrella is huge"),
            "The umbrella is huge"
        )
    }

    // MARK: - Repeat collapse

    func testCollapsesAccidentalRepeats() {
        XCTAssertEqual(
            processor().process("the the meeting is at three"),
            "The meeting is at three"
        )
    }

    func testKeepsLegitimateDoubles() {
        XCTAssertEqual(
            processor().process("he had had enough"),
            "He had had enough"
        )
    }

    func testCollapsesTripleRepeats() {
        XCTAssertEqual(
            processor().process("I I I think so"),
            "I think so"
        )
    }

    // MARK: - Custom dictionary

    func testSubstitutesDictionaryEntries() {
        let dict = [DictionaryEntry(spoken: "super base", written: "Supabase")]
        XCTAssertEqual(
            processor(dictionary: dict).process("deploy it to super base today"),
            "Deploy it to Supabase today"
        )
    }

    func testSubstitutionIsCaseInsensitiveAndWholeWord() {
        let dict = [DictionaryEntry(spoken: "shaun", written: "Shaun")]
        XCTAssertEqual(
            processor(dictionary: dict).process("tell shaun about shauna"),
            "Tell Shaun about shauna"
        )
    }

    // MARK: - Tidy

    func testCollapsesWhitespaceAndFixesPunctuationSpacing() {
        XCTAssertEqual(
            processor().process("hello ,  world .How are you"),
            "Hello, world. How are you"
        )
    }

    func testCapitalizesFirstLetter() {
        XCTAssertEqual(processor().process("hello there"), "Hello there")
    }

    func testEmptyAndFillerOnlyInput() {
        XCTAssertEqual(processor().process(""), "")
        XCTAssertEqual(processor().process("   "), "")
        XCTAssertEqual(processor().process("um uh umm"), "")
    }

    func testPipelineOrderFillersThenRepeatsThenDictionary() {
        let dict = [DictionaryEntry(spoken: "cursor", written: "Cursor")]
        XCTAssertEqual(
            processor(dictionary: dict).process("um open the the file in cursor uh now"),
            "Open the file in Cursor now"
        )
    }
}
