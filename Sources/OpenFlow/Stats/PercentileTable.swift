import Foundation

/// Maps average dictation WPM to a flattering "Top X%" figure — Wispr Flow's key flourish.
///
/// The comparison is against published *typing*-speed norms (~40 WPM average), NOT against
/// other users, so it needs no backend and works fully offline. The exact academic dataset
/// is an open question; `table` is a deliberately tunable constant calibrated so that typical
/// dictation speeds (~90–160 WPM) land in an engaging low-single-digit range with headroom to
/// improve (rather than everyone pinned at Top 0.1%).
enum PercentileTable {
    /// Sorted ascending by `wpm`, with monotonically non-increasing `top`.
    static let table: [(wpm: Double, top: Double)] = [
        (0,   99.0),
        (40,  50.0),   // ~average typist
        (60,  25.0),
        (75,  10.0),
        (90,   8.0),   // entry dictation speed — already impressive vs typists
        (110,  5.0),
        (130,  3.0),
        (150,  1.5),
        (170,  0.7),
        (200,  0.2),
        (240,  0.1),   // clamp floor
    ]

    /// Interpolated "Top X%" for a WPM, clamped to [0.1, 99].
    static func topPercent(forWPM wpm: Double) -> Double {
        guard let first = table.first, let last = table.last else { return 99 }
        if wpm <= first.wpm { return first.top }
        if wpm >= last.wpm { return last.top }
        for i in 1..<table.count where wpm <= table[i].wpm {
            let lo = table[i - 1], hi = table[i]
            let t = (wpm - lo.wpm) / (hi.wpm - lo.wpm)
            let p = lo.top + (hi.top - lo.top) * t
            return min(99, max(0.1, p))
        }
        return last.top
    }

    /// "Top 4%" for whole percents, "Top 0.7%" below 1%.
    static func formatted(_ percent: Double) -> String {
        if percent < 1 {
            return "Top \(String(format: "%.1f", percent))%"
        }
        return "Top \(Int(percent.rounded()))%"
    }
}
