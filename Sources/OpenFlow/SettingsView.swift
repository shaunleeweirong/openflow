import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore

    @State private var entries: [DictionaryEntry] = []
    @State private var newSpoken = ""
    @State private var newWritten = ""
    @State private var showResetConfirm = false

    var body: some View {
        Form {
            Section("Hotkey") {
                KeyboardShortcuts.Recorder("Push-to-talk (hold):", name: .pushToTalk)
                Text("Hold to record, release to transcribe.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Cleanup") {
                Toggle("Remove filler words (um, uh…)", isOn: bind(\.removeFillers))
                Toggle("Play start/stop sounds", isOn: bind(\.playSounds))
            }

            Section("AI cleanup") {
                Toggle("Enhance with on-device AI", isOn: bind(\.aiEnhance))
                    .disabled(!EnhancerSupport.isAvailable)
                if EnhancerSupport.isAvailable {
                    Text("Fixes grammar, fillers, and punctuation on-device via Apple Intelligence — nothing leaves your Mac. Adds about a second per dictation; off by default (the rule-based cleanup is instant).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Requires macOS 26 with Apple Intelligence enabled. Using rule-based cleanup for now.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Text insertion") {
                Picker("Insert text by", selection: bind(\.injectionMode)) {
                    Text("Pasting (recommended)").tag(TextInjector.Mode.paste)
                    Text("Typing it out").tag(TextInjector.Mode.type)
                }
                Toggle("Restore clipboard after pasting", isOn: bind(\.restoreClipboard))
            }

            Section("Model") {
                Picker("Parakeet model", selection: bind(\.modelVersion)) {
                    Text("v3 — 25 European languages").tag("v3")
                    Text("v2 — English only, best recall").tag("v2")
                }
                Text("Changing the model takes effect after relaunching OpenFlow (new model downloads on next launch).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Custom dictionary") {
                Text("Fix words the model gets wrong: names, jargon, acronyms.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(entries) { entry in
                    HStack {
                        Text(entry.spoken)
                        Image(systemName: "arrow.right").foregroundStyle(.secondary)
                        Text(entry.written).fontWeight(.medium)
                        Spacer()
                        Button(role: .destructive) {
                            entries.removeAll { $0.id == entry.id }
                            settings.dictionaryEntries = entries
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }

                HStack {
                    TextField("Heard as (e.g. super base)", text: $newSpoken)
                    Image(systemName: "arrow.right").foregroundStyle(.secondary)
                    TextField("Replace with (e.g. Supabase)", text: $newWritten)
                    Button("Add") {
                        let entry = DictionaryEntry(
                            spoken: newSpoken.trimmingCharacters(in: .whitespaces),
                            written: newWritten.trimmingCharacters(in: .whitespaces)
                        )
                        guard !entry.spoken.isEmpty, !entry.written.isEmpty else { return }
                        entries.append(entry)
                        settings.dictionaryEntries = entries
                        newSpoken = ""
                        newWritten = ""
                    }
                    .disabled(newSpoken.trimmingCharacters(in: .whitespaces).isEmpty
                        || newWritten.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Section("Insights") {
                Toggle("Track dictation stats", isOn: bind(\.statsEnabled))
                Toggle("Break down by app", isOn: bind(\.perAppTracking))
                    .disabled(!settings.statsEnabled)
                Text("Stats live only on this Mac and are never uploaded. The per-app breakdown records which app you dictated into — off by default.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Reset stats…", role: .destructive) { showResetConfirm = true }
                    .confirmationDialog("Reset all stats?", isPresented: $showResetConfirm) {
                        Button("Reset stats", role: .destructive) { StatsStore.shared.reset() }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This permanently deletes your word counts, streaks, and achievements.")
                    }
            }

            Section("General") {
                Toggle("Launch at login", isOn: bind(\.launchAtLogin))
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 520)
        .onAppear { entries = settings.dictionaryEntries }
    }

    /// Bridge SettingsStore's plain properties into SwiftUI bindings.
    private func bind<T>(_ keyPath: ReferenceWritableKeyPath<SettingsStore, T>) -> Binding<T> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { settings[keyPath: keyPath] = $0 }
        )
    }
}
