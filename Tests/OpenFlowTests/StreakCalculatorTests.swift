import XCTest
@testable import OpenFlow

final class StreakCalculatorTests: XCTestCase {
    private let cal = StatsTestSupport.calendar()   // UTC

    private func now(_ y: Int, _ m: Int, _ d: Int) -> Date {
        StatsTestSupport.date(y, m, d, 12, 0, calendar: cal)
    }

    func testEmptyHistory() {
        let r = StreakCalculator.compute(activeDays: [], now: now(2026, 7, 17), calendar: cal)
        XCTAssertEqual(r.currentDailyStreak, 0)
        XCTAssertEqual(r.longestDailyStreak, 0)
        XCTAssertEqual(r.currentWeeklyStreak, 0)
        XCTAssertFalse(r.isActiveToday)
    }

    func testActiveTodayOnly() {
        let r = StreakCalculator.compute(activeDays: ["2026-07-17"], now: now(2026, 7, 17), calendar: cal)
        XCTAssertEqual(r.currentDailyStreak, 1)
        XCTAssertEqual(r.longestDailyStreak, 1)
        XCTAssertTrue(r.isActiveToday)
    }

    func testActiveYesterdayNotTodayStillCounts() {
        // Not yet dictated today, but yesterday was active → streak alive, not broken.
        let r = StreakCalculator.compute(activeDays: ["2026-07-16"], now: now(2026, 7, 17), calendar: cal)
        XCTAssertEqual(r.currentDailyStreak, 1)
        XCTAssertFalse(r.isActiveToday)
    }

    func testTwoDayGapBreaksStreak() {
        let r = StreakCalculator.compute(activeDays: ["2026-07-15"], now: now(2026, 7, 17), calendar: cal)
        XCTAssertEqual(r.currentDailyStreak, 0)
    }

    func testFiveConsecutiveEndingToday() {
        let days: Set = ["2026-07-13", "2026-07-14", "2026-07-15", "2026-07-16", "2026-07-17"]
        let r = StreakCalculator.compute(activeDays: days, now: now(2026, 7, 17), calendar: cal)
        XCTAssertEqual(r.currentDailyStreak, 5)
        XCTAssertEqual(r.longestDailyStreak, 5)
    }

    func testFiveConsecutiveEndingYesterday() {
        let days: Set = ["2026-07-12", "2026-07-13", "2026-07-14", "2026-07-15", "2026-07-16"]
        let r = StreakCalculator.compute(activeDays: days, now: now(2026, 7, 17), calendar: cal)
        XCTAssertEqual(r.currentDailyStreak, 5)
        XCTAssertFalse(r.isActiveToday)
    }

    func testBrokenThenResumed() {
        // A run of 3 in early July, then a gap, then 2 up to today.
        let days: Set = ["2026-07-01", "2026-07-02", "2026-07-03", "2026-07-16", "2026-07-17"]
        let r = StreakCalculator.compute(activeDays: days, now: now(2026, 7, 17), calendar: cal)
        XCTAssertEqual(r.currentDailyStreak, 2)
        XCTAssertEqual(r.longestDailyStreak, 3)
    }

    func testYearBoundaryDailyStreak() {
        let days: Set = ["2025-12-31", "2026-01-01"]
        let r = StreakCalculator.compute(activeDays: days, now: now(2026, 1, 1), calendar: cal)
        XCTAssertEqual(r.currentDailyStreak, 2)
        XCTAssertEqual(r.longestDailyStreak, 2)
    }

    func testDSTSpringForwardStaysConsecutive() {
        // US spring-forward 2026 is Mar 8 (a 23-hour day). Stepping by calendar day, not by
        // 86 400 seconds, must keep the run consecutive across it.
        let ny = StatsTestSupport.calendar("America/New_York")
        let days: Set = ["2026-03-07", "2026-03-08", "2026-03-09"]
        let nowNY = StatsTestSupport.date(2026, 3, 9, 12, 0, calendar: ny)
        let r = StreakCalculator.compute(activeDays: days, now: nowNY, calendar: ny)
        XCTAssertEqual(r.currentDailyStreak, 3)
        XCTAssertEqual(r.longestDailyStreak, 3)
    }

    func testTimezoneChangeDoesNotCrash() {
        let ny = StatsTestSupport.calendar("America/New_York")
        let days: Set = ["2026-07-16", "2026-07-17"]
        let r = StreakCalculator.compute(activeDays: days, now: StatsTestSupport.date(2026, 7, 17, 1, 0, calendar: ny), calendar: ny)
        XCTAssertGreaterThanOrEqual(r.currentDailyStreak, 1)
    }

    func testWeeklyConsecutiveWeeks() {
        // 07-10 and 07-17 are one ISO week apart → weekly streak 2.
        let days: Set = ["2026-07-10", "2026-07-17"]
        let r = StreakCalculator.compute(activeDays: days, now: now(2026, 7, 17), calendar: cal)
        XCTAssertEqual(r.currentWeeklyStreak, 2)
    }

    func testWeeklySkipResets() {
        // 07-03 is two ISO weeks before 07-17 → the gap breaks the weekly streak at 1.
        let days: Set = ["2026-07-03", "2026-07-17"]
        let r = StreakCalculator.compute(activeDays: days, now: now(2026, 7, 17), calendar: cal)
        XCTAssertEqual(r.currentWeeklyStreak, 1)
    }

    // MARK: - Streak freeze (forgiveness)

    private func consecutiveDays(from start: (Int, Int, Int), count: Int) -> Set<String> {
        var out = Set<String>()
        var d = StatsTestSupport.date(start.0, start.1, start.2, 12, 0, calendar: cal)
        for _ in 0..<count {
            out.insert(CalendarKeys.dayKey(d, cal))
            d = cal.date(byAdding: .day, value: 1, to: d)!
        }
        return out
    }

    func testNoFreezeBeforeSevenDays() {
        let r = StreakCalculator.compute(activeDays: consecutiveDays(from: (2026, 7, 14), count: 4),
                                         now: now(2026, 7, 17), calendar: cal)
        XCTAssertEqual(r.currentDailyStreak, 4)
        XCTAssertEqual(r.freezesAvailable, 0)
    }

    func testEarnsOneFreezeAtSevenDays() {
        let r = StreakCalculator.compute(activeDays: consecutiveDays(from: (2026, 7, 11), count: 7),
                                         now: now(2026, 7, 17), calendar: cal)
        XCTAssertEqual(r.currentDailyStreak, 7)
        XCTAssertEqual(r.freezesAvailable, 1)
    }

    func testFreezeBridgesASingleMissedDay() {
        // 8 active days (earns 1 freeze at day 7), miss one day, then active again today.
        var days = consecutiveDays(from: (2026, 7, 1), count: 8)   // 07-01…07-08
        days.insert("2026-07-10")                                  // gap on 07-09
        let r = StreakCalculator.compute(activeDays: days, now: now(2026, 7, 10), calendar: cal)
        XCTAssertEqual(r.currentDailyStreak, 9)   // freeze bridged the gap
        XCTAssertEqual(r.freezesAvailable, 0)     // and was consumed
    }

    func testTwoMissedDaysWithOneFreezeBreaks() {
        var days = consecutiveDays(from: (2026, 7, 1), count: 8)   // earns 1 freeze
        days.insert("2026-07-12")                                  // 07-09 and 07-10 both missed
        let r = StreakCalculator.compute(activeDays: days, now: now(2026, 7, 12), calendar: cal)
        XCTAssertEqual(r.currentDailyStreak, 1)   // one freeze bridged 07-09, 07-10 broke it
    }

    func testFreezesCapAtTwo() {
        let r = StreakCalculator.compute(activeDays: consecutiveDays(from: (2026, 7, 1), count: 21),
                                         now: now(2026, 7, 21), calendar: cal)
        XCTAssertEqual(r.currentDailyStreak, 21)
        XCTAssertEqual(r.freezesAvailable, 2)     // earned at 7/14/21, capped at 2
    }
}
