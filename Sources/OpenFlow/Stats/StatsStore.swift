import Foundation

/// Orchestrates the stats layer: holds the in-memory day map + cached totals, records each
/// dictation, evaluates achievements, persists, and publishes a snapshot for the UI.
///
/// Main-thread only — constructed and called from `AppDelegate` on the main thread (the record
/// call happens inside `finishDictation`'s `MainActor.run` block), mirroring `SettingsStore`.
/// Only the file write is dispatched off-main by `StatsFileStore`.
final class StatsStore: ObservableObject {
    static let shared = StatsStore()

    @Published private(set) var snapshot: InsightsSnapshot = .empty

    /// Invoked (on the main thread) with the highest newly-unlocked achievement, so a single
    /// dictation that jumps several tiers fires one celebration, not a burst.
    var onAchievementUnlocked: ((Achievement) -> Void)?

    private let settings: SettingsStore
    private let fileStore: StatsFileStore
    private var log: DailyLog
    private var calendar: Calendar { Calendar.current }

    init(settings: SettingsStore = .shared, fileStore: StatsFileStore = StatsFileStore()) {
        self.settings = settings
        self.fileStore = fileStore
        self.log = DailyLog(days: fileStore.load())
        rebuildSnapshot()
    }

    private var unlockedIDs: Set<String> { Set(settings.unlockedAchievements.keys) }

    /// Fold a completed dictation into today's totals, persist, refresh the snapshot, and
    /// celebrate any newly-crossed milestone.
    func record(_ event: DictationEvent) {
        let dayKey = CalendarKeys.dayKey(event.date, calendar)
        let old = progress()

        log.record(event, calendar: calendar, includeApp: settings.perAppTracking)
        settings.lifetimeTotals = settings.lifetimeTotals.adding(event, dayKey: dayKey)

        if settings.perAppTracking, let id = event.appBundleID, !id.isEmpty, let name = event.appName {
            var names = settings.statsAppNames
            if names[id] != name { names[id] = name; settings.statsAppNames = names }
        }

        fileStore.save(log.days)
        rebuildSnapshot()

        // Diff achievements against the freshly-rebuilt streak/totals.
        let newly = AchievementEngine.newlyUnlocked(old: old, new: progress(), alreadyUnlocked: unlockedIDs)
        guard !newly.isEmpty else { return }

        var unlocked = settings.unlockedAchievements
        let now = Date()
        for a in newly where unlocked[a.id] == nil { unlocked[a.id] = now }
        settings.unlockedAchievements = unlocked
        rebuildSnapshot()

        if let top = AchievementEngine.highest(newly) {
            onAchievementUnlocked?(top)
        }
    }

    /// Wipe all stats (file, cached totals, achievements, app names). Publishes a zeroed
    /// snapshot so any open Insights window updates live.
    func reset() {
        log = DailyLog()
        fileStore.delete()
        settings.lifetimeTotals = .empty
        settings.unlockedAchievements = [:]
        settings.statsAppNames = [:]
        rebuildSnapshot()
    }

    /// A short line for the menu bar, e.g. "🔥 5-day streak · 12,480 words".
    var menuSummary: String { Self.summaryText(for: snapshot) }

    /// Pure formatter so the menu can update straight from a published snapshot value.
    static func summaryText(for snap: InsightsSnapshot) -> String {
        let words = grouped(snap.totalWords)
        if snap.currentDailyStreak > 0 {
            return "🔥 \(snap.currentDailyStreak)-day streak · \(words) words"
        }
        return snap.totalWords > 0 ? "\(words) words dictated" : "No dictations yet"
    }

    // MARK: - Private

    private func progress() -> ProgressSnapshot {
        ProgressSnapshot(
            totalWords: settings.lifetimeTotals.totalWords,
            totalDictations: settings.lifetimeTotals.totalDictations,
            currentDailyStreak: snapshot.currentDailyStreak
        )
    }

    private func rebuildSnapshot() {
        snapshot = StatsAggregator.snapshot(
            days: log.days,
            totals: settings.lifetimeTotals,
            now: Date(),
            calendar: calendar,
            unlockedIDs: unlockedIDs,
            appNames: settings.statsAppNames
        )
    }

    private static func grouped(_ n: Int) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}
