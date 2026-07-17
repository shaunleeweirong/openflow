import SwiftUI

/// The dedicated Insights window. Observes `StatsStore` and renders its published snapshot.
struct InsightsView: View {
    @ObservedObject var stats: StatsStore

    private var snap: InsightsSnapshot { stats.snapshot }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                heading
                if snap.totalDictations == 0 {
                    emptyState
                } else {
                    statGrid
                    streakCard
                    heatmapCard
                    if !snap.perApp.isEmpty { perAppCard }
                    achievementsCard
                }
            }
            .padding(20)
        }
        .frame(width: 460, height: 560)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Insights").font(.title2.bold())
            Text("Computed on this Mac — nothing is ever uploaded.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: - Top stat tiles

    private var statGrid: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                statTile(grouped(snap.totalWords), "words dictated", "text.alignleft")
                statTile("\(Int(snap.averageWPM.rounded()))", "avg words / min", "gauge.with.needle")
            }
            HStack(spacing: 12) {
                statTile(snap.topPercentText, "vs typing speed", "trophy.fill")
                statTile(timeSaved(snap.timeSavedSeconds), "time saved", "clock.arrow.circlepath")
            }
        }
    }

    private func statTile(_ value: String, _ label: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: symbol).foregroundStyle(Color.accentColor)
            Text(value).font(.title3.bold()).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.windowBackgroundColor)))
    }

    // MARK: - Streak

    private var streakCard: some View {
        card("Streak") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 22) {
                    streakStat("\(snap.currentDailyStreak)", "day streak", flame: true)
                    streakStat("\(snap.longestDailyStreak)", "longest", flame: false)
                    streakStat("\(snap.currentWeeklyStreak)", "weeks", flame: false)
                    Spacer()
                    VStack(spacing: 3) {
                        Image(systemName: snap.isActiveToday ? "checkmark.seal.fill" : "circle.dashed")
                            .font(.title3)
                            .foregroundStyle(snap.isActiveToday ? .green : .secondary)
                        Text(snap.isActiveToday ? "Active today" : "Not yet today")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Label(freezeText, systemImage: "snowflake")
                    .font(.caption2)
                    .foregroundStyle(snap.freezesAvailable > 0 ? Color.cyan : .secondary)
            }
        }
    }

    private var freezeText: String {
        if snap.freezesAvailable > 0 {
            let plural = snap.freezesAvailable == 1 ? "" : "s"
            return "\(snap.freezesAvailable) streak freeze\(plural) banked — a missed day won't break your streak"
        }
        return "Dictate 7 days in a row to earn a streak freeze"
    }

    private var heatmapCard: some View {
        card("Activity", subtitle: "last \(snap.heatmap.count) weeks") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 3) {
                    ForEach(Array(snap.heatmap.enumerated()), id: \.offset) { _, week in
                        VStack(spacing: 3) {
                            ForEach(week) { cell in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(cell.isFuture ? Color.clear : levelColor(cell.level))
                                    .frame(width: 11, height: 11)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 2)
                                            .strokeBorder(cell.isToday ? Color.primary.opacity(0.6) : .clear, lineWidth: 1)
                                    )
                            }
                        }
                    }
                }
                HStack(spacing: 4) {
                    Text("Less").font(.caption2).foregroundStyle(.secondary)
                    ForEach(0..<5, id: \.self) { lvl in
                        RoundedRectangle(cornerRadius: 2).fill(levelColor(lvl)).frame(width: 10, height: 10)
                    }
                    Text("More").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func levelColor(_ level: Int) -> Color {
        switch level {
        case 0: return Color.secondary.opacity(0.15)
        case 1: return Color.accentColor.opacity(0.3)
        case 2: return Color.accentColor.opacity(0.5)
        case 3: return Color.accentColor.opacity(0.75)
        default: return Color.accentColor
        }
    }

    private func streakStat(_ value: String, _ label: String, flame: Bool) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                if flame { Image(systemName: "flame.fill").foregroundStyle(.orange) }
                Text(value).font(.title2.bold())
            }
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: - Per-app breakdown

    private var perAppCard: some View {
        let maxWords = Double(snap.perApp.first?.words ?? 1)
        return card("By app") {
            VStack(spacing: 10) {
                ForEach(snap.perApp.prefix(8)) { app in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(app.displayName).lineLimit(1)
                            Spacer()
                            Text("\(grouped(app.words)) words").font(.caption).foregroundStyle(.secondary)
                        }
                        ProgressView(value: Double(app.words), total: max(maxWords, 1))
                            .tint(Color.accentColor)
                    }
                }
            }
        }
    }

    // MARK: - Achievements

    private var achievementsCard: some View {
        let unlockedIDs = Set(snap.unlockedAchievements.map(\.id))
        return card("Achievements", subtitle: "\(unlockedIDs.count) of \(AchievementCatalog.all.count)") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 12)], spacing: 14) {
                ForEach(AchievementCatalog.all) { a in
                    let unlocked = unlockedIDs.contains(a.id)
                    VStack(spacing: 6) {
                        Image(systemName: unlocked ? a.symbol : "lock.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(unlocked ? .yellow : .secondary)
                            .frame(height: 26)
                        Text(a.title)
                            .font(.caption2)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(unlocked ? .primary : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .opacity(unlocked ? 1 : 0.45)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar.xaxis").font(.system(size: 40)).foregroundStyle(.secondary)
            Text("No dictations yet").font(.headline)
            Text("Hold your hotkey and speak — your stats will appear here.")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 420)
    }

    // MARK: - Helpers

    private func card<Content: View>(
        _ title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.windowBackgroundColor)))
    }

    private func grouped(_ n: Int) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    private func timeSaved(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m" }
        return "\(s / 3600)h \((s % 3600) / 60)m"
    }
}
