import Foundation

/// One cell in the activity heatmap (a single calendar day).
struct HeatCell: Equatable, Identifiable {
    var dayKey: String
    var wordCount: Int
    var level: Int      // 0 (none) … 4 (most), for shading
    var isToday: Bool
    var isFuture: Bool   // trailing days of the current week, past today — rendered blank
    var id: String { dayKey }
}

/// Builds a GitHub-style activity grid from the daily records. Pure and testable: the view just
/// renders the returned columns. Each column is one week (aligned to the calendar's `firstWeekday`)
/// of 7 weekday rows; the last column contains today.
enum HeatmapBuilder {
    static let defaultWeeks = 16

    /// Word-count → shade level. Documented tunable thresholds.
    static func level(for words: Int) -> Int {
        switch words {
        case ..<1:      return 0
        case 1..<100:   return 1
        case 100..<300: return 2
        case 300..<800: return 3
        default:        return 4
        }
    }

    /// `weeks` columns ending with the week containing `now`; each column is 7 `HeatCell`s.
    static func grid(
        days: [String: DailyStat], now: Date, calendar: Calendar, weeks: Int = defaultWeeks
    ) -> [[HeatCell]] {
        let startOfToday = calendar.startOfDay(for: now)
        let todayKey = CalendarKeys.dayKey(now, calendar)

        guard weeks > 0,
              let thisWeek = calendar.dateInterval(of: .weekOfYear, for: startOfToday)?.start,
              let firstWeekStart = calendar.date(byAdding: .weekOfYear, value: -(weeks - 1), to: thisWeek)
        else { return [] }

        var columns: [[HeatCell]] = []
        var weekCursor = firstWeekStart
        for _ in 0..<weeks {
            var column: [HeatCell] = []
            var dayCursor = weekCursor
            for _ in 0..<7 {
                let key = CalendarKeys.dayKey(dayCursor, calendar)
                let words = days[key]?.wordCount ?? 0
                let isFuture = dayCursor > startOfToday
                column.append(HeatCell(
                    dayKey: key,
                    wordCount: words,
                    level: isFuture ? 0 : level(for: words),
                    isToday: key == todayKey,
                    isFuture: isFuture
                ))
                dayCursor = calendar.date(byAdding: .day, value: 1, to: dayCursor)!
            }
            columns.append(column)
            weekCursor = calendar.date(byAdding: .weekOfYear, value: 1, to: weekCursor)!
        }
        return columns
    }
}
