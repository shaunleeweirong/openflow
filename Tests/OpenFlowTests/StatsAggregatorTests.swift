import XCTest
@testable import OpenFlow

final class StatsAggregatorTests: XCTestCase {
    private let cal = StatsTestSupport.calendar()   // UTC

    func testEmptyHistoryIsSafeZeroState() {
        let snap = StatsAggregator.snapshot(
            days: [:], totals: .empty,
            now: StatsTestSupport.date(2026, 7, 17, 12, 0, calendar: cal),
            calendar: cal, unlockedIDs: []
        )
        XCTAssertEqual(snap.totalWords, 0)
        XCTAssertEqual(snap.averageWPM, 0)
        XCTAssertEqual(snap.topPercent, 99, accuracy: 0.0001)
        XCTAssertEqual(snap.currentDailyStreak, 0)
        XCTAssertTrue(snap.perApp.isEmpty)
        XCTAssertTrue(snap.unlockedAchievements.isEmpty)
    }

    func testComposesTotalsStreakPercentileAndPerApp() {
        let day = DailyStat(
            day: "2026-07-17",
            wordCount: 40, dictationCount: 3, spokenSeconds: 20,
            appWords: ["A": 30, "B": 10]
        )
        let days = ["2026-07-17": day]
        let totals = LifetimeTotals.recompute(from: days)

        let snap = StatsAggregator.snapshot(
            days: days, totals: totals,
            now: StatsTestSupport.date(2026, 7, 17, 12, 0, calendar: cal),
            calendar: cal,
            unlockedIDs: ["first_dictation"],
            appNames: ["A": "Alpha"]
        )

        XCTAssertEqual(snap.totalWords, 40)
        XCTAssertEqual(snap.totalDictations, 3)
        // 40 words / (20s = 1/3 min) = 120 WPM → Top 4%.
        XCTAssertEqual(snap.averageWPM, 120, accuracy: 0.0001)
        XCTAssertEqual(snap.topPercent, 4.0, accuracy: 0.0001)
        XCTAssertEqual(snap.topPercentText, "Top 4%")
        XCTAssertEqual(snap.currentDailyStreak, 1)

        // Per-app sorted by words descending, with friendly name where known.
        XCTAssertEqual(snap.perApp.count, 2)
        XCTAssertEqual(snap.perApp.first?.bundleID, "A")
        XCTAssertEqual(snap.perApp.first?.displayName, "Alpha")
        XCTAssertEqual(snap.perApp.first?.words, 30)
        XCTAssertEqual(snap.perApp.last?.displayName, "B")  // unknown → bundleID fallback

        XCTAssertEqual(snap.unlockedAchievements.map(\.id), ["first_dictation"])
    }
}
