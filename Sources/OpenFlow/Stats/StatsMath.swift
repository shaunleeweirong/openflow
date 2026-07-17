import Foundation

/// Pure derivations from lifetime totals. No IO, no state.
enum StatsMath {
    /// Baseline average typing speed (WPM) used to estimate time saved by dictating instead.
    /// Documented tunable constant; ~40 WPM is a widely-cited average keyboard speed.
    static let baselineTypingWPM: Double = 40

    /// Average words per minute of *speaking*. Returns 0 when no time has been recorded
    /// (avoids divide-by-zero on first run / empty state).
    static func averageWPM(totalWords: Int, totalSpokenSeconds: Double) -> Double {
        guard totalSpokenSeconds > 0 else { return 0 }
        return Double(totalWords) / (totalSpokenSeconds / 60)
    }

    /// Estimated seconds saved vs typing the same words at `typingWPM`, minus time spent
    /// speaking. Clamped at 0 — dictation is expected to be faster; never surface a negative.
    static func timeSaved(
        totalWords: Int,
        totalSpokenSeconds: Double,
        typingWPM: Double = baselineTypingWPM
    ) -> TimeInterval {
        guard typingWPM > 0 else { return 0 }
        let typingSeconds = Double(totalWords) / typingWPM * 60
        return max(0, typingSeconds - totalSpokenSeconds)
    }
}
