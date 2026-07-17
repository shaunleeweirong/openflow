import Foundation

struct StreakResult: Equatable {
    var currentDailyStreak: Int
    var longestDailyStreak: Int
    var currentWeeklyStreak: Int
    var isActiveToday: Bool
    var freezesAvailable: Int
}

/// Pure streak math over the set of active day keys. Inject `now` and a `Calendar` (which
/// carries the user's timezone) so results are deterministic and testable. All stepping is by
/// calendar day/week — never by subtracting 86 400 seconds — so DST days stay consecutive.
///
/// Daily streaks are freeze-aware ("streak forgiveness"): the user earns one freeze per
/// `freezeEarnEvery` consecutive active days (capped at `maxFreezes`), and a freeze is auto-spent
/// to bridge a missed day so a single slip doesn't nuke a long streak. Freezes are derived by a
/// deterministic forward simulation over the history — no stateful spend to persist.
enum StreakCalculator {
    static let freezeEarnEvery = 7
    static let maxFreezes = 2

    static func compute(activeDays: Set<String>, now: Date, calendar: Calendar) -> StreakResult {
        let today = CalendarKeys.dayKey(now, calendar)
        let sim = simulateDaily(activeDays: activeDays, now: now, calendar: calendar)
        return StreakResult(
            currentDailyStreak: sim.current,
            longestDailyStreak: sim.longest,
            currentWeeklyStreak: currentWeekly(activeDays: activeDays, now: now, calendar: calendar),
            isActiveToday: activeDays.contains(today),
            freezesAvailable: sim.freezes
        )
    }

    private struct DailySim { var current: Int; var longest: Int; var freezes: Int }

    /// Walk forward one calendar day at a time from the earliest active day through today,
    /// growing the streak on active days, earning freezes at each `freezeEarnEvery` boundary,
    /// and auto-spending a freeze to bridge a missed day (reset only when none remain). Today is
    /// never treated as a miss — the streak survives until the day actually ends.
    private static func simulateDaily(activeDays: Set<String>, now: Date, calendar: Calendar) -> DailySim {
        guard let firstKey = activeDays.min(),
              let firstDate = CalendarKeys.date(fromDayKey: firstKey, calendar)
        else { return DailySim(current: 0, longest: 0, freezes: 0) }

        let startOfToday = calendar.startOfDay(for: now)
        let todayKey = CalendarKeys.dayKey(now, calendar)

        var streak = 0, longest = 0, freezes = 0
        var cursor = calendar.startOfDay(for: firstDate)

        while cursor <= startOfToday {
            let key = CalendarKeys.dayKey(cursor, calendar)
            if activeDays.contains(key) {
                streak += 1
                if streak % freezeEarnEvery == 0 { freezes = min(maxFreezes, freezes + 1) }
                longest = max(longest, streak)
            } else if key != todayKey {
                // A missed day in the past: spend a freeze to bridge it, else the streak breaks.
                if freezes > 0 { freezes -= 1 } else { streak = 0 }
            }
            // else: today, not yet active — grace, leave the streak untouched.

            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return DailySim(current: streak, longest: longest, freezes: freezes)
    }

    /// Weekly streak: a week counts if it saw ≥1 active day. Anchor at this week if active,
    /// else last week, then step back a week at a time. (Not freeze-aware.)
    private static func currentWeekly(activeDays: Set<String>, now: Date, calendar: Calendar) -> Int {
        var activeWeeks = Set<String>()
        for dayKey in activeDays {
            if let d = CalendarKeys.date(fromDayKey: dayKey, calendar) {
                activeWeeks.insert(CalendarKeys.weekKey(d, calendar))
            }
        }
        guard !activeWeeks.isEmpty else { return 0 }

        let startOfToday = calendar.startOfDay(for: now)
        let thisWeek = CalendarKeys.weekKey(now, calendar)
        let lastWeekDate = calendar.date(byAdding: .day, value: -7, to: startOfToday)!
        let lastWeek = CalendarKeys.weekKey(lastWeekDate, calendar)

        var cursor: Date
        if activeWeeks.contains(thisWeek) {
            cursor = startOfToday
        } else if activeWeeks.contains(lastWeek) {
            cursor = lastWeekDate
        } else {
            return 0
        }

        var count = 0
        while activeWeeks.contains(CalendarKeys.weekKey(cursor, calendar)) {
            count += 1
            cursor = calendar.date(byAdding: .day, value: -7, to: cursor)!
        }
        return count
    }
}
