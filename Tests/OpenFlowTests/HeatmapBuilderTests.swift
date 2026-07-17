import XCTest
@testable import OpenFlow

final class HeatmapBuilderTests: XCTestCase {
    private let cal = StatsTestSupport.calendar()   // UTC

    func testLevelThresholds() {
        XCTAssertEqual(HeatmapBuilder.level(for: 0), 0)
        XCTAssertEqual(HeatmapBuilder.level(for: 1), 1)
        XCTAssertEqual(HeatmapBuilder.level(for: 99), 1)
        XCTAssertEqual(HeatmapBuilder.level(for: 100), 2)
        XCTAssertEqual(HeatmapBuilder.level(for: 299), 2)
        XCTAssertEqual(HeatmapBuilder.level(for: 300), 3)
        XCTAssertEqual(HeatmapBuilder.level(for: 799), 3)
        XCTAssertEqual(HeatmapBuilder.level(for: 800), 4)
        XCTAssertEqual(HeatmapBuilder.level(for: 5000), 4)
    }

    func testGridDimensions() {
        let grid = HeatmapBuilder.grid(days: [:], now: date(2026, 7, 17), calendar: cal, weeks: 12)
        XCTAssertEqual(grid.count, 12)                       // 12 week-columns
        XCTAssertTrue(grid.allSatisfy { $0.count == 7 })     // 7 weekday rows each
    }

    func testTodayIsPresentInLastColumnWithItsLevel() {
        let days = ["2026-07-17": DailyStat(day: "2026-07-17", wordCount: 250, dictationCount: 3, spokenSeconds: 30)]
        let grid = HeatmapBuilder.grid(days: days, now: date(2026, 7, 17), calendar: cal, weeks: 8)

        let todayCell = grid.flatMap { $0 }.first { $0.isToday }
        XCTAssertNotNil(todayCell)
        XCTAssertEqual(todayCell?.dayKey, "2026-07-17")
        XCTAssertEqual(todayCell?.wordCount, 250)
        XCTAssertEqual(todayCell?.level, 2)                  // 100..<300
        // Today lives in the final column.
        XCTAssertTrue(grid.last?.contains { $0.isToday } ?? false)
    }

    func testFutureCellsAreBlankAndFlagged() {
        // Some weekday rows after today (in the final week) must be marked future with level 0.
        let grid = HeatmapBuilder.grid(days: [:], now: date(2026, 7, 15), calendar: cal, weeks: 4)
        let future = grid.flatMap { $0 }.filter { $0.isFuture }
        XCTAssertFalse(future.isEmpty)
        XCTAssertTrue(future.allSatisfy { $0.level == 0 })
    }

    func testDaysBeforeHistoryAreLevelZero() {
        let days = ["2026-07-17": DailyStat(day: "2026-07-17", wordCount: 900)]
        let grid = HeatmapBuilder.grid(days: days, now: date(2026, 7, 17), calendar: cal, weeks: 6)
        let active = grid.flatMap { $0 }.filter { $0.level > 0 }
        XCTAssertEqual(active.count, 1)                      // only the one day with words
        XCTAssertEqual(active.first?.dayKey, "2026-07-17")
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        StatsTestSupport.date(y, m, d, 12, 0, calendar: cal)
    }
}
