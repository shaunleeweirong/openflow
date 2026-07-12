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

/// Latency benchmark for the AI enhancer: prewarm, then time N enhance calls in one
/// process (mimics the app, where the model should stay warm between dictations).
///   OpenFlow --bench "some text to clean up" 6
@available(macOS 26, *)
func runEnhanceBenchCLI(text: String, iterations: Int, gapSeconds: Double) {
    Task.detached {
        let enhancer = AppleFoundationEnhancer()
        guard enhancer.isAvailable else {
            FileHandle.standardError.write("ERROR: Foundation model unavailable\n".data(using: .utf8)!)
            exit(1)
        }
        var times: [Double] = []
        for i in 1...iterations {
            if i > 1, gapSeconds > 0 {
                try? await Task.sleep(for: .seconds(gapSeconds)) // idle between dictations
            }
            enhancer.prewarm()                                   // key-down warms the model
            try? await Task.sleep(for: .seconds(2))              // ~time the user speaks
            let t0 = Date()
            _ = try? await enhancer.enhance(text, vocabulary: [])
            let dt = Date().timeIntervalSince(t0)
            times.append(dt)
            print(String(format: "iter %2d (gap %.0fs): %.2fs", i, i > 1 ? gapSeconds : 0, dt))
        }
        let warm = Array(times.dropFirst()).sorted()
        let median = warm.isEmpty ? (times.first ?? 0) : warm[warm.count / 2]
        print(String(format: "first(cold?)=%.2fs  warm-min=%.2fs  warm-median=%.2fs",
                     times.first ?? 0, warm.first ?? 0, median))
        exit(0)
    }
    dispatchMain()
}

/// Headless smoke test for the AI enhancer: clean up a line of text and exit.
///   OpenFlow --enhance "um so like the the meeting is at 3 p.m."
@available(macOS 26, *)
func runEnhanceCLI(text: String) {
    Task.detached {
        let enhancer = AppleFoundationEnhancer()
        guard enhancer.isAvailable else {
            FileHandle.standardError.write(
                "ERROR: Foundation model unavailable (Apple Intelligence off or model not ready)\n"
                    .data(using: .utf8)!)
            exit(1)
        }
        do {
            let t0 = Date()
            let out = try await enhancer.enhance(
                text, vocabulary: SettingsStore.shared.dictionaryEntries)
            let elapsed = Date().timeIntervalSince(t0)
            print("INPUT:    \(text)")
            print("ENHANCED: \(out)")
            print("time:     \(String(format: "%.2f", elapsed))s")
            exit(0)
        } catch {
            FileHandle.standardError.write("ERROR: \(error)\n".data(using: .utf8)!)
            exit(1)
        }
    }
    dispatchMain()
}
