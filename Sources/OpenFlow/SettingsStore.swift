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
