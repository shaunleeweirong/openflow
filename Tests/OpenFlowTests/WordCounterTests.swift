import XCTest
@testable import OpenFlow

final class WordCounterTests: XCTestCase {
    func testEmptyAndWhitespaceIsZero() {
        XCTAssertEqual(WordCounter.count(""), 0)
        XCTAssertEqual(WordCounter.count("   "), 0)
        XCTAssertEqual(WordCounter.count("\n\t  "), 0)
    }

    func testSingleWordIgnoresSurroundingWhitespace() {
        XCTAssertEqual(WordCounter.count("hello"), 1)
        XCTAssertEqual(WordCounter.count("  hello  "), 1)
    }

    func testCollapsesRunsOfWhitespace() {
        XCTAssertEqual(WordCounter.count("hello world"), 2)
        XCTAssertEqual(WordCounter.count("hello     world"), 2)
        XCTAssertEqual(WordCounter.count("one two three four five"), 5)
    }

    func testNewlinesAndTabsSeparateWords() {
        XCTAssertEqual(WordCounter.count("hello\nworld\tthere"), 3)
    }

    func testPunctuationAttachedCountsAsOneWord() {
        XCTAssertEqual(WordCounter.count("Hello, world."), 2)
        // Hyphenated tokens count as one word (pinned rule: split on whitespace only).
        XCTAssertEqual(WordCounter.count("well-being is good"), 3)
    }
}
