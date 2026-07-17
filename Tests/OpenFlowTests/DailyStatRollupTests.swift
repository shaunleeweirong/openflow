import XCTest
@testable import OpenFlow

final class DailyStatRollupTests: XCTestCase {
    private let cal = StatsTestSupport.calendar()   // UTC

    func testSameDayEventsSumAndMergeApps() {
        var log = DailyLog()
        let d = StatsTestSupport.date(2026, 7, 17, 9, 0, calendar: cal)
        let d2 = StatsTestSupport.date(2026, 7, 17, 15, 0, calendar: cal)
        log.record(StatsTestSupport.event(d, words: 10, seconds: 5, app: "com.apple.Notes"), calendar: cal, includeApp: true)
        log.record(StatsTestSupport.event(d2, words: 20, seconds: 10, app: "com.apple.Notes"), calendar: cal, includeApp: true)

        let stat = log.days["2026-07-17"]
        XCTAssertEqual(stat?.wordCount, 30)
        XCTAssertEqual(stat?.dictationCount, 2)
        XCTAssertEqual(stat?.spokenSeconds, 15)
        XCTAssertEqual(stat?.appWords["com.apple.Notes"], 30)
    }

    func testDifferentDaysDistinctKeys() {
        var log = DailyLog()
        log.record(StatsTestSupport.event(StatsTestSupport.date(2026, 7, 17, 9, 0, calendar: cal)), calendar: cal, includeApp: false)
        log.record(StatsTestSupport.event(StatsTestSupport.date(2026, 7, 18, 9, 0, calendar: cal)), calendar: cal, includeApp: false)
        XCTAssertEqual(Set(log.days.keys), ["2026-07-17", "2026-07-18"])
    }

    func testPerAppOffLeavesAppWordsEmpty() {
        var log = DailyLog()
        let d = StatsTestSupport.date(2026, 7, 17, 9, 0, calendar: cal)
        log.record(StatsTestSupport.event(d, app: "com.apple.Notes"), calendar: cal, includeApp: false)
        XCTAssertTrue(log.days["2026-07-17"]?.appWords.isEmpty ?? false)
    }

    func testActiveDaysOnlyIncludesDaysWithDictations() {
        var log = DailyLog()
        log.record(StatsTestSupport.event(StatsTestSupport.date(2026, 7, 17, 9, 0, calendar: cal)), calendar: cal, includeApp: false)
        XCTAssertEqual(log.activeDays, ["2026-07-17"])
    }

    func testIncrementalTotalsEqualFullRecompute() {
        var log = DailyLog()
        var incremental = LifetimeTotals.empty
        let events = [
            StatsTestSupport.event(StatsTestSupport.date(2026, 7, 15, 9, 0, calendar: cal), words: 12, seconds: 6, app: "A"),
            StatsTestSupport.event(StatsTestSupport.date(2026, 7, 15, 18, 0, calendar: cal), words: 8, seconds: 4, app: "B"),
            StatsTestSupport.event(StatsTestSupport.date(2026, 7, 17, 9, 0, calendar: cal), words: 30, seconds: 11, app: "A"),
        ]
        for e in events {
            let key = CalendarKeys.dayKey(e.date, cal)
            log.record(e, calendar: cal, includeApp: true)
            incremental = incremental.adding(e, dayKey: key)
        }
        XCTAssertEqual(incremental, LifetimeTotals.recompute(from: log.days))
        XCTAssertEqual(incremental.totalWords, 50)
        XCTAssertEqual(incremental.totalDictations, 3)
        XCTAssertEqual(incremental.firstDay, "2026-07-15")
        XCTAssertEqual(incremental.lastDay, "2026-07-17")
    }
}
