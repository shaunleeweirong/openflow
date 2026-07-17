import Foundation
@testable import OpenFlow

/// Shared builders for the stats test suites — a fixed calendar + deterministic date/event
/// construction so streak/rollup/aggregator tests never depend on the wall clock or local tz.
enum StatsTestSupport {
    static func calendar(_ tzID: String = "UTC") -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: tzID)!
        return c
    }

    static func date(
        _ year: Int, _ month: Int, _ day: Int,
        _ hour: Int = 12, _ minute: Int = 0,
        calendar: Calendar
    ) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day; c.hour = hour; c.minute = minute
        return calendar.date(from: c)!
    }

    static func event(
        _ date: Date, words: Int = 10, seconds: Double = 5, app: String? = nil
    ) -> DictationEvent {
        DictationEvent(date: date, wordCount: words, spokenSeconds: seconds, appBundleID: app, appName: app)
    }
}
