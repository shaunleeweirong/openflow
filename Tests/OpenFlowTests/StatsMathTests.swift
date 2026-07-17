import XCTest
@testable import OpenFlow

final class StatsMathTests: XCTestCase {
    func testAverageWPMBasic() {
        XCTAssertEqual(StatsMath.averageWPM(totalWords: 150, totalSpokenSeconds: 60), 150, accuracy: 0.0001)
        XCTAssertEqual(StatsMath.averageWPM(totalWords: 90, totalSpokenSeconds: 60), 90, accuracy: 0.0001)
    }

    func testAverageWPMZeroSecondsGuard() {
        XCTAssertEqual(StatsMath.averageWPM(totalWords: 0, totalSpokenSeconds: 0), 0)
        XCTAssertEqual(StatsMath.averageWPM(totalWords: 100, totalSpokenSeconds: 0), 0)
    }

    func testTimeSavedPositive() {
        // 40 words typed at 40 WPM = 60s; spoken in 20s → 40s saved.
        XCTAssertEqual(
            StatsMath.timeSaved(totalWords: 40, totalSpokenSeconds: 20, typingWPM: 40),
            40, accuracy: 0.0001
        )
    }

    func testTimeSavedClampedAtZero() {
        // Slower than typing → never negative.
        XCTAssertEqual(StatsMath.timeSaved(totalWords: 10, totalSpokenSeconds: 100, typingWPM: 40), 0)
        XCTAssertEqual(StatsMath.timeSaved(totalWords: 0, totalSpokenSeconds: 0), 0)
    }

    func testTimeSavedTypingWPMGuard() {
        XCTAssertEqual(StatsMath.timeSaved(totalWords: 100, totalSpokenSeconds: 10, typingWPM: 0), 0)
    }
}
