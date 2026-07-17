import Foundation

/// Owns the single stats file — `[dayKey: DailyStat]` as JSON in Application Support. The load
/// is a one-time, tiny read at launch; writes (after every dictation) go to a serial background
/// queue and are atomic. Nothing here throws into the caller: stats IO must never crash a
/// dictation, so failures are logged and swallowed.
final class StatsFileStore {
    private let fileURL: URL?
    private let queue = DispatchQueue(label: "com.shaunlee.OpenFlow.stats.io")

    init(filename: String = "daily.json") {
        self.fileURL = Self.makeFileURL(filename)
    }

    private static func makeFileURL(_ filename: String) -> URL? {
        guard let base = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: false
        ) else { return nil }
        let folder = base.appendingPathComponent(
            Bundle.main.bundleIdentifier ?? "com.shaunlee.OpenFlow", isDirectory: true
        )
        return folder.appendingPathComponent(filename)
    }

    /// Synchronous load of the day map (called once at launch; the file is only a few KB).
    /// Returns an empty map when the file is absent or unreadable — not an error.
    func load() -> [String: DailyStat] {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: DailyStat].self, from: data)) ?? [:]
    }

    /// Persist a snapshot of the day map atomically, off the main thread.
    func save(_ days: [String: DailyStat]) {
        queue.async { [fileURL] in
            guard let url = fileURL else { return }
            do {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(), withIntermediateDirectories: true
                )
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys]
                try encoder.encode(days).write(to: url, options: .atomic)
            } catch {
                NSLog("OpenFlow stats save failed: \(error)")
            }
        }
    }

    /// Remove the file (used by Reset).
    func delete() {
        queue.async { [fileURL] in
            guard let url = fileURL else { return }
            try? FileManager.default.removeItem(at: url)
        }
    }
}
