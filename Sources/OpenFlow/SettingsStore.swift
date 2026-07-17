import Foundation
import ServiceManagement

/// UserDefaults-backed settings, shared between UI and pipeline code.
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private enum Keys {
        static let removeFillers = "removeFillers"
        static let injectionMode = "injectionMode"
        static let restoreClipboard = "restoreClipboard"
        static let playSounds = "playSounds"
        static let modelVersion = "modelVersion"
        static let dictionaryEntries = "dictionaryEntries"
        static let onboardingCompleted = "onboardingCompleted"
        static let aiEnhance = "aiEnhance"
        static let statsEnabled = "statsEnabled"
        static let perAppTracking = "perAppTracking"
        static let unlockedAchievements = "unlockedAchievements"
        static let lifetimeTotals = "lifetimeTotals"
        static let statsAppNames = "statsAppNames"
    }

    private let defaults = UserDefaults.standard

    private init() {
        defaults.register(defaults: [
            Keys.removeFillers: true,
            Keys.injectionMode: TextInjector.Mode.paste.rawValue,
            Keys.restoreClipboard: true,
            Keys.playSounds: true,
            Keys.modelVersion: "v3",
            Keys.onboardingCompleted: false,
            Keys.aiEnhance: false,
            Keys.statsEnabled: true,      // fully local; on by default so the feature is discovered
            Keys.perAppTracking: false,   // the one mildly-sensitive part — opt-in
        ])
    }

    var removeFillers: Bool {
        get { defaults.bool(forKey: Keys.removeFillers) }
        set { defaults.set(newValue, forKey: Keys.removeFillers); objectWillChange.send() }
    }

    var injectionMode: TextInjector.Mode {
        get { TextInjector.Mode(rawValue: defaults.string(forKey: Keys.injectionMode) ?? "") ?? .paste }
        set { defaults.set(newValue.rawValue, forKey: Keys.injectionMode); objectWillChange.send() }
    }

    var restoreClipboard: Bool {
        get { defaults.bool(forKey: Keys.restoreClipboard) }
        set { defaults.set(newValue, forKey: Keys.restoreClipboard); objectWillChange.send() }
    }

    var playSounds: Bool {
        get { defaults.bool(forKey: Keys.playSounds) }
        set { defaults.set(newValue, forKey: Keys.playSounds); objectWillChange.send() }
    }

    /// "v3" (25 European languages) or "v2" (English-only, best recall).
    var modelVersion: String {
        get { defaults.string(forKey: Keys.modelVersion) ?? "v3" }
        set { defaults.set(newValue, forKey: Keys.modelVersion); objectWillChange.send() }
    }

    var onboardingCompleted: Bool {
        get { defaults.bool(forKey: Keys.onboardingCompleted) }
        set { defaults.set(newValue, forKey: Keys.onboardingCompleted); objectWillChange.send() }
    }

    /// On-device AI cleanup pass (Apple Foundation Models). Falls back to rule-based
    /// cleanup when off or unavailable. Default OFF (opt-in): the LLM adds ~1s per
    /// dictation vs the instant rule-based path, so instant is the default.
    var aiEnhance: Bool {
        get { defaults.bool(forKey: Keys.aiEnhance) }
        set { defaults.set(newValue, forKey: Keys.aiEnhance); objectWillChange.send() }
    }

    var dictionaryEntries: [DictionaryEntry] {
        get {
            guard let data = defaults.data(forKey: Keys.dictionaryEntries),
                  let entries = try? JSONDecoder().decode([DictionaryEntry].self, from: data)
            else { return [] }
            return entries
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Keys.dictionaryEntries)
            }
            objectWillChange.send()
        }
    }

    // MARK: - Usage stats (all local; never uploaded)

    /// Record dictation usage for the Insights view. On by default.
    var statsEnabled: Bool {
        get { defaults.bool(forKey: Keys.statsEnabled) }
        set { defaults.set(newValue, forKey: Keys.statsEnabled); objectWillChange.send() }
    }

    /// Break stats down by which app you dictated into. Opt-in (off by default).
    var perAppTracking: Bool {
        get { defaults.bool(forKey: Keys.perAppTracking) }
        set { defaults.set(newValue, forKey: Keys.perAppTracking); objectWillChange.send() }
    }

    /// Unlocked achievement ids → the date they were earned.
    var unlockedAchievements: [String: Date] {
        get { decodeJSON([String: Date].self, Keys.unlockedAchievements) ?? [:] }
        set { encodeJSON(newValue, Keys.unlockedAchievements) }
    }

    /// Cached lifetime totals so the menu summary / achievement diff never block on the file.
    var lifetimeTotals: LifetimeTotals {
        get { decodeJSON(LifetimeTotals.self, Keys.lifetimeTotals) ?? .empty }
        set { encodeJSON(newValue, Keys.lifetimeTotals) }
    }

    /// bundleID → friendly app name, for the per-app breakdown labels.
    var statsAppNames: [String: String] {
        get { decodeJSON([String: String].self, Keys.statsAppNames) ?? [:] }
        set { encodeJSON(newValue, Keys.statsAppNames) }
    }

    private func decodeJSON<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func encodeJSON<T: Encodable>(_ value: T, _ key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
        objectWillChange.send()
    }

    // MARK: - Launch at login (only works from a bundled .app)

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("Launch-at-login change failed: \(error)")
            }
            objectWillChange.send()
        }
    }
}
