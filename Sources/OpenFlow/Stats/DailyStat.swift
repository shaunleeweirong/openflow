import Foundation

/// Day/week key helpers. Keys are derived through the caller's `Calendar` (which carries the
/// local timezone), so they match however the day was recorded. Using `DateComponents` rather
/// than a `DateFormatter` keeps this deterministic and DST-safe.
enum CalendarKeys {
    /// "yyyy-MM-dd" in the calendar's timezone. Zero-padded so lexical order == chronological.
    static func dayKey(_ date: Date, _ calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// "yyyy-Www" ISO week key. Uses `yearForWeekOfYear` so the year boundary is handled.
    static func weekKey(_ date: Date, _ calendar: Calendar) -> String {
        let c = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return String(format: "%04d-W%02d", c.yearForWeekOfYear ?? 0, c.weekOfYear ?? 0)
    }

    /// Parse a day key back into a `Date` (start of that day) via the calendar.
    static func date(fromDayKey key: String, _ calendar: Calendar) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var c = DateComponents()
        c.year = parts[0]; c.month = parts[1]; c.day = parts[2]
        return calendar.date(from: c)
    }
}

/// Usage rolled up for one calendar day (local timezone). This is the persisted unit — one
/// record per active day keeps storage tiny and bounded while covering every v1 metric.
struct DailyStat: Codable, Equatable {
    var day: String                 // "yyyy-MM-dd" in local timezone
    var wordCount: Int
    var dictationCount: Int
    var spokenSeconds: Double
    var appWords: [String: Int]     // bundleID -> words; empty unless per-app tracking was on

    init(
        day: String,
        wordCount: Int = 0,
        dictationCount: Int = 0,
        spokenSeconds: Double = 0,
        appWords: [String: Int] = [:]
    ) {
        self.day = day
        self.wordCount = wordCount
        self.dictationCount = dictationCount
        self.spokenSeconds = spokenSeconds
        self.appWords = appWords
    }

    /// Returns a copy with `event` folded in. `includeApp` gates the per-app breakdown.
    func adding(_ event: DictationEvent, includeApp: Bool) -> DailyStat {
        var copy = self
        copy.wordCount += event.wordCount
        copy.dictationCount += 1
        copy.spokenSeconds += event.spokenSeconds
        if includeApp, let id = event.appBundleID, !id.isEmpty {
            copy.appWords[id, default: 0] += event.wordCount
        }
        return copy
    }
}

/// Lifetime rollup, cached so the menu summary and achievement diff never rescan the file.
struct LifetimeTotals: Codable, Equatable {
    var totalWords: Int
    var totalDictations: Int
    var totalSpokenSeconds: Double
    var firstDay: String?
    var lastDay: String?

    init(
        totalWords: Int = 0,
        totalDictations: Int = 0,
        totalSpokenSeconds: Double = 0,
        firstDay: String? = nil,
        lastDay: String? = nil
    ) {
        self.totalWords = totalWords
        self.totalDictations = totalDictations
        self.totalSpokenSeconds = totalSpokenSeconds
        self.firstDay = firstDay
        self.lastDay = lastDay
    }

    static let empty = LifetimeTotals()

    /// Full recompute from the day map — the source of truth on reset and for reconciliation.
    static func recompute(from days: [String: DailyStat]) -> LifetimeTotals {
        var t = LifetimeTotals()
        for stat in days.values {
            t.totalWords += stat.wordCount
            t.totalDictations += stat.dictationCount
            t.totalSpokenSeconds += stat.spokenSeconds
        }
        let activeKeys = days.values.filter { $0.dictationCount > 0 }.map { $0.day }.sorted()
        t.firstDay = activeKeys.first
        t.lastDay = activeKeys.last
        return t
    }

    /// Incremental add for the hot path. Invariant: folding every event through `adding`
    /// yields the same result as `recompute` over the resulting day map (see tests).
    func adding(_ event: DictationEvent, dayKey: String) -> LifetimeTotals {
        var t = self
        t.totalWords += event.wordCount
        t.totalDictations += 1
        t.totalSpokenSeconds += event.spokenSeconds
        if t.firstDay == nil || dayKey < t.firstDay! { t.firstDay = dayKey }
        if t.lastDay == nil || dayKey > t.lastDay! { t.lastDay = dayKey }
        return t
    }
}

/// The in-memory day map plus the pure rollup. Persisted as its `days` dictionary.
struct DailyLog: Equatable {
    private(set) var days: [String: DailyStat]

    init(days: [String: DailyStat] = [:]) { self.days = days }

    /// Fold one event into the appropriate day bucket (creating it if needed).
    mutating func record(_ event: DictationEvent, calendar: Calendar, includeApp: Bool) {
        let key = CalendarKeys.dayKey(event.date, calendar)
        let existing = days[key] ?? DailyStat(day: key)
        days[key] = existing.adding(event, includeApp: includeApp)
    }

    /// Day keys that saw at least one dictation — the input to streak calculation.
    var activeDays: Set<String> {
        Set(days.values.filter { $0.dictationCount > 0 }.map { $0.day })
    }

    var totals: LifetimeTotals { LifetimeTotals.recompute(from: days) }
}
