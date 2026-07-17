import SwiftUI

/// The permission-free celebration card shown briefly when a milestone is reached. Rendered in a
/// borderless, non-activating window by `AppDelegate` — no `UNUserNotification`, so it never
/// triggers a notification-permission prompt.
struct AchievementToastView: View {
    let achievement: Achievement

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: achievement.symbol)
                .font(.system(size: 26))
                .foregroundStyle(.yellow)
                .frame(width: 52, height: 52)
                .background(Circle().fill(Color(.windowBackgroundColor)))

            VStack(alignment: .leading, spacing: 3) {
                Text("Achievement Unlocked")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(achievement.title).font(.headline)
                Text(achievement.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(width: 330)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.quaternary))
        .shadow(radius: 14, y: 4)
        .padding(10)
    }
}
