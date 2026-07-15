import Foundation

/// Decides the final text for one utterance: run the optional AI `Enhancer` when it's
/// enabled and available, but fall back to deterministic `TextProcessor` cleanup on any
/// failure, timeout, empty, or over-expanded output. The enhancer is a quality layer,
/// never a gate — the user always gets insertable text.
///
/// Kept separate from `AppDelegate` so this decision logic is unit-testable with a fake
/// enhancer (no Apple Intelligence hardware required).
struct EnhancementPipeline {
    let enhancer: Enhancer?
    let aiEnhanceEnabled: Bool
    let removeFillers: Bool
    let dictionary: [DictionaryEntry]
    // Warm on-device responses were observed up to ~3.5 s; this bounds pathological
    // cases without falsely timing out normal calls (then falls back to deterministic).
    var timeout: Duration = .seconds(8)

    func run(_ raw: String) async -> String {
        if aiEnhanceEnabled, let enhancer, enhancer.isAvailable {
            if let enhanced = await enhanceWithTimeout(raw, enhancer) {
                let trimmed = enhanced.trimmingCharacters(in: .whitespacesAndNewlines)
                if isAcceptable(trimmed, raw: raw) {
                    // Apply custom spellings to the model's output as a guarantee.
                    return TextProcessor.applyDictionary(trimmed, dictionary)
                }
            }
        }
        return deterministic(raw)
    }

    private func deterministic(_ raw: String) -> String {
        TextProcessor(removeFillers: removeFillers, dictionary: dictionary).process(raw)
    }

    /// Race the enhancer against `timeout`; returns nil on throw or timeout so the caller
    /// falls back. (A cancellation-honoring enhancer also returns early on timeout.)
    private func enhanceWithTimeout(_ raw: String, _ enhancer: Enhancer) async -> String? {
        await withTaskGroup(of: String?.self) { group in
            group.addTask { try? await enhancer.enhance(raw, vocabulary: dictionary) }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    /// Reject empty output, and over-expansion that signals the model rewrote/expanded
    /// instead of cleaning. The `+ 20` floor keeps very short utterances from being
    /// falsely rejected when light punctuation/capitalization is added.
    private func isAcceptable(_ trimmed: String, raw: String) -> Bool {
        !trimmed.isEmpty && trimmed.count <= raw.count * 2 + 20
    }
}
