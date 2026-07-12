import Foundation

/// Post-transcription text enhancement (e.g. an on-device LLM cleanup pass).
///
/// Kept behind a protocol — mirroring the `ASREngine` seam — so the enhancement engine
/// is swappable (Apple Foundation Models now; a bundled model later) and the pipeline
/// that consumes it can be unit-tested with a fake.
protocol Enhancer: AnyObject {
    /// Whether enhancement can run right now (OS/hardware capable, model ready).
    var isAvailable: Bool { get }

    /// Clean up `text`, treating `vocabulary` as the spelling authority for proper nouns.
    ///
    /// Throws on failure; callers MUST fall back to deterministic cleanup so the user
    /// always gets insertable text. The enhancer is a quality layer, never a gate.
    func enhance(_ text: String, vocabulary: [DictionaryEntry]) async throws -> String

    /// Warm the engine so the first dictation isn't slowed by cold-start. Optional.
    func prewarm()
}

extension Enhancer {
    func prewarm() {}
}
