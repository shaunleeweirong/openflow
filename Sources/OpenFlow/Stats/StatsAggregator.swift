import Foundation

/// One row of the per-app breakdown.
struct AppUsage: Equatable, Identifiable {
    var bundleID: String
    var displayName: String
    var words: Int
    var id: String { bundleID }
}

/// The fully-computed view model the menu summary + Insights window render. Pure value type.
struct InsightsSnapshot: Equatable {
    var totalWords: Int
    var totalDictations: Int
    var averageWPM: Double
    var topPercent: Double
    var topPercentText: String
    var timeSavedSeconds: TimeInterval
    var currentDailyStreak: Int
    var longestDailyStreak: Int
    var currentWeeklyStreak: Int
    var isActiveToday: Bool
    var perApp: [AppUsage]
    var unlockedAchievements: [Achievement]

    static let empty = InsightsSnapshot(
        totalWords: 0, totalDictations: 0, averageWPM: 0,
        topPercent: 99, topPercentText: PercentileTable.formatted(99),
        timeSavedSeconds: 0, currentDailyStreak: 0, longestDailyStreak: 0,
        currentWeeklyStreak: 0, isActiveToday: false, perApp: [], unlockedAchievements: []
    )
}

/// Composes the pure sub-calculations into a single snapshot. No IO, no state.
enum StatsAggregator {
    static func snapshot(
        days: [String: DailyStat],
        totals: LifetimeTotals,
        now: Date,
        calendar: Calendar,
        unlockedIDs: Set<String>,
        appNames: [String: String] = [:]
    ) -> InsightsSnapshot {
        let activeDays = Set(days.values.filter { $0.dictationCount > 0 }.map { $0.day })
        let streak = StreakCalculator.compute(activeDays: activeDays, now: now, calendar: calendar)
        let wpm = StatsMath.averageWPM(
            totalWords: totals.totalWords,
            totalSpokenSeconds: totals.totalSpokenSeconds
        )
        let top = PercentileTable.topPercent(forWPM: wpm)
        let saved = StatsMath.timeSaved(
            totalWords: totals.totalWords,
            totalSpokenSeconds: totals.totalSpokenSeconds
        )

        var appTotals: [String: Int] = [:]
        for stat in days.values {
            for (id, w) in stat.appWords { appTotals[id, default: 0] += w }
        }
        let perApp = appTotals
            .map { AppUsage(bundleID: $0.key, displayName: appNames[$0.key] ?? $0.key, words: $0.value) }
            .sorted { $0.words > $1.words }

        let unlocked = AchievementCatalog.all.filter { unlockedIDs.contains($0.id) }

        return InsightsSnapshot(
            totalWords: totals.totalWords,
            totalDictations: totals.totalDictations,
            averageWPM: wpm,
            topPercent: top,
            topPercentText: PercentileTable.formatted(top),
            timeSavedSeconds: saved,
            currentDailyStreak: streak.currentDailyStreak,
            longestDailyStreak: streak.longestDailyStreak,
            currentWeeklyStreak: streak.currentWeeklyStreak,
            isActiveToday: streak.isActiveToday,
            perApp: perApp,
            unlockedAchievements: unlocked
        )
    }
}
