import XCTest
@testable import OpenFlow

final class PercentileTableTests: XCTestCase {
    func testMonotonicNonIncreasing() {
        var last = Double.greatestFiniteMagnitude
        for wpm in stride(from: 0.0, through: 300.0, by: 5.0) {
            let top = PercentileTable.topPercent(forWPM: wpm)
            XCTAssertLessThanOrEqual(top, last + 1e-9, "top% must not rise as WPM rises (at \(wpm))")
            last = top
        }
    }

    func testClamps() {
        XCTAssertEqual(PercentileTable.topPercent(forWPM: 0), 99, accuracy: 0.0001)
        XCTAssertEqual(PercentileTable.topPercent(forWPM: -10), 99, accuracy: 0.0001)
        XCTAssertEqual(PercentileTable.topPercent(forWPM: 240), 0.1, accuracy: 0.0001)
        XCTAssertEqual(PercentileTable.topPercent(forWPM: 1000), 0.1, accuracy: 0.0001)
    }

    func testEngagingRangeNotPinned() {
        // Typical dictation (90–160 WPM) should land in an engaging band, never pinned at 0.1
        // and never above ~8%.
        for wpm in stride(from: 90.0, through: 160.0, by: 5.0) {
            let top = PercentileTable.topPercent(forWPM: wpm)
            XCTAssertGreaterThan(top, 0.5, "not pinned at the floor at \(wpm)")
            XCTAssertLessThanOrEqual(top, 8.0, "stays impressive at \(wpm)")
        }
    }

    func testInterpolation() {
        // 120 sits halfway between 110→5% and 130→3% → 4%.
        XCTAssertEqual(PercentileTable.topPercent(forWPM: 120), 4.0, accuracy: 0.0001)
    }

    func testFormatting() {
        XCTAssertEqual(PercentileTable.formatted(4.0), "Top 4%")
        XCTAssertEqual(PercentileTable.formatted(50), "Top 50%")
        XCTAssertEqual(PercentileTable.formatted(0.7), "Top 0.7%")
        XCTAssertEqual(PercentileTable.formatted(0.1), "Top 0.1%")
    }
}
