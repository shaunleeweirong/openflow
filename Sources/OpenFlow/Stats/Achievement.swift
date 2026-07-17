import Foundation

enum AchievementKind: String, Codable, Equatable {
    case firstDictation
    case totalWords
    case dailyStreak
}

struct Achievement: Identifiable, Equatable {
    let id: String          // stable, e.g. "words_10000" — persisted once unlocked
    let title: String
    let subtitle: String
    let kind: AchievementKind
    let threshold: Int      // words for .totalWords, days for .dailyStreak, 1 for .firstDictation
    let symbol: String      // SF Symbol for the toast / list row
}

/// The v1 milestone set. Ordered for display by threshold within each kind.
enum AchievementCatalog {
    static let wordTiers = [1_000, 5_000, 10_000, 25_000, 50_000, 100_000, 250_000, 500_000, 1_000_000]
    static let streakTiers = [3, 7, 14, 30, 60, 100, 365]

    static let all: [Achievement] = {
        var list: [Achievement] = [
            Achievement(
                id: "first_dictation",
                title: "First Words",
                subtitle: "You made your first dictation",
                kind: .firstDictation,
                threshold: 1,
                symbol: "sparkles"
            )
        ]
        for w in wordTiers {
            list.append(Achievement(
                id: "words_\(w)",
                title: "\(compactNumber(w)) Words",
                subtitle: "Dictated \(groupedNumber(w)) words in total",
                kind: .totalWords,
                threshold: w,
                symbol: "trophy.fill"
            ))
        }
        for d in streakTiers {
            list.append(Achievement(
                id: "streak_\(d)",
                title: "\(d)-Day Streak",
                subtitle: "Dictated \(d) days in a row",
                kind: .dailyStreak,
                threshold: d,
                symbol: "flame.fill"
            ))
        }
        return list
    }()

    static func achievement(id: String) -> Achievement? {
        all.first { $0.id == id }
    }

    // "1,000" → "1K", "1,000,000" → "1M" for compact titles.
    private static func compactNumber(_ n: Int) -> String {
        if n >= 1_000_000 { return "\(n / 1_000_000)M" }
        if n >= 1_000 { return "\(n / 1_000)K" }
        return "\(n)"
    }

    private static func groupedNumber(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

/// The snapshot of progress the engine diffs against. Plain values → trivially testable.
struct ProgressSnapshot: Equatable {
    var totalWords: Int
    var totalDictations: Int
    var currentDailyStreak: Int
}

enum AchievementEngine {
    /// Pure: achievements crossed by moving `old` → `new` that aren't already unlocked.
    /// Returned sorted ascending by threshold. The caller persists ALL returned ids but should
    /// celebrate only `highest(...)` so a single big dictation that jumps several tiers fires
    /// one toast, not a burst.
    static func newlyUnlocked(
        old: ProgressSnapshot,
        new: ProgressSnapshot,
        alreadyUnlocked: Set<String>
    ) -> [Achievement] {
        var result: [Achievement] = []
        for a in AchievementCatalog.all where !alreadyUnlocked.contains(a.id) {
            let crossed: Bool
            switch a.kind {
            case .firstDictation:
                crossed = old.totalDictations == 0 && new.totalDictations >= 1
            case .totalWords:
                crossed = old.totalWords < a.threshold && new.totalWords >= a.threshold
            case .dailyStreak:
                crossed = old.currentDailyStreak < a.threshold && new.currentDailyStreak >= a.threshold
            }
            if crossed { result.append(a) }
        }
        return result.sorted { $0.threshold < $1.threshold }
    }

    /// The single achievement to celebrate from a batch (highest threshold).
    static func highest(_ achievements: [Achievement]) -> Achievement? {
        achievements.max { $0.threshold < $1.threshold }
    }
}
