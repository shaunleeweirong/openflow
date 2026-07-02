import Foundation

/// Headless smoke test: transcribe an audio file and exit.
/// Lets us verify model download + ASR end-to-end from the terminal,
/// with no microphone or Accessibility permissions involved.
func runTranscribeCLI(path: String) {
    let url = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: url.path) else {
        FileHandle.standardError.write("ERROR: no such file: \(path)\n".data(using: .utf8)!)
        exit(1)
    }

    Task.detached {
        do {
            let engine = ParakeetEngine()
            engine.onStateChange = { state in
                print("[model] \(state.label)")
            }
            let t0 = Date()
            try await engine.prepare()
            print("[model] prepared in \(String(format: "%.1f", Date().timeIntervalSince(t0)))s")

            let t1 = Date()
            let raw = try await engine.transcribe(fileURL: url)
            let elapsed = Date().timeIntervalSince(t1)

            let processor = TextProcessor(
                removeFillers: SettingsStore.shared.removeFillers,
                dictionary: SettingsStore.shared.dictionaryEntries
            )
            let cleaned = processor.process(raw)

            print("RAW:       \(raw)")
            print("CLEANED:   \(cleaned)")
            print("ASR time:  \(String(format: "%.2f", elapsed))s")
            exit(0)
        } catch {
            FileHandle.standardError.write("ERROR: \(error)\n".data(using: .utf8)!)
            exit(1)
        }
    }

    dispatchMain()
}
