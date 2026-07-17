import Foundation

struct StreakResult: Equatable {
    var currentDailyStreak: Int
    var longestDailyStreak: Int
    var currentWeeklyStreak: Int
    var isActiveToday: Bool
}

/// Pure streak math over the set of active day keys. Inject `now` and a `Calendar` (which
/// carries the user's timezone) so results are deterministic and testable. All stepping is
/// by calendar day/week — never by subtracting 86 400 seconds — so DST days stay consecutive.
enum StreakCalculator {
    static func compute(activeDays: Set<String>, now: Date, calendar: Calendar) -> StreakResult {
        let today = CalendarKeys.dayKey(now, calendar)
        return StreakResult(
            currentDailyStreak: currentDaily(activeDays: activeDays, now: now, calendar: calendar),
            longestDailyStreak: longestDaily(activeDays: activeDays, calendar: calendar),
            currentWeeklyStreak: currentWeekly(activeDays: activeDays, now: now, calendar: calendar),
            isActiveToday: activeDays.contains(today)
        )
    }

    /// Anchor at today if active, else yesterday if active (so a not-yet-dictated today does
    /// NOT break the streak until a full day has passed), then walk back over active days.
    private static func currentDaily(activeDays: Set<String>, now: Date, calendar: Calendar) -> Int {
        let startOfToday = calendar.startOfDay(for: now)
        let today = CalendarKeys.dayKey(now, calendar)
        let yesterdayDate = calendar.date(byAdding: .day, value: -1, to: startOfToday)!
        let yesterday = CalendarKeys.dayKey(yesterdayDate, calendar)

        var cursor: Date
        if activeDays.contains(today) {
            cursor = startOfToday
        } else if activeDays.contains(yesterday) {
            cursor = yesterdayDate
        } else {
            return 0
        }

        var count = 0
        while activeDays.contains(CalendarKeys.dayKey(cursor, calendar)) {
            count += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        return count
    }

    /// Longest run of consecutive calendar days anywhere in the history.
    private static func longestDaily(activeDays: Set<String>, calendar: Calendar) -> Int {
        guard !activeDays.isEmpty else { return 0 }
        let sorted = activeDays.sorted()   // lexical == chronological for zero-padded keys
        var longest = 1
        var run = 1
        for i in 1..<sorted.count {
            if let prev = CalendarKeys.date(fromDayKey: sorted[i - 1], calendar),
               let next = calendar.date(byAdding: .day, value: 1, to: prev),
               CalendarKeys.dayKey(next, calendar) == sorted[i] {
                run += 1
            } else {
                run = 1
            }
            longest = max(longest, run)
        }
        return longest
    }

    /// Weekly streak: a week counts if it saw ≥1 active day. Anchor at this week if active,
    /// else last week, then step back a week at a time.
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
