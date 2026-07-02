import Foundation

enum ASRModelState: Equatable {
    case notLoaded
    case downloading
    case loading
    case ready
    case failed(String)

    var label: String {
        switch self {
        case .notLoaded: return "Not loaded"
        case .downloading: return "Downloading model (~1 GB, one-time)…"
        case .loading: return "Loading model…"
        case .ready: return "Ready"
        case .failed(let msg): return "Model error: \(msg)"
        }
    }
}

enum ASRError: LocalizedError {
    case notReady

    var errorDescription: String? {
        switch self {
        case .notReady: return "Speech model is not loaded yet."
        }
    }
}

/// Seam for swapping ASR engines (Parakeet now; WhisperKit / Apple SpeechAnalyzer later).
protocol ASREngine: AnyObject {
    var state: ASRModelState { get }
    var onStateChange: ((ASRModelState) -> Void)? { get set }

    /// Download (first run) and load the model. Safe to call more than once.
    func prepare() async throws

    /// Transcribe a complete utterance of 16 kHz mono Float32 samples.
    func transcribe(samples: [Float]) async throws -> String

    /// Transcribe an audio file (any format; converted internally).
    func transcribe(fileURL: URL) async throws -> String
}
