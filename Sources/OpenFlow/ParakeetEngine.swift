import Foundation
import FluidAudio

/// NVIDIA Parakeet-TDT via FluidAudio (CoreML, runs on the Apple Neural Engine).
/// v3 = 25 European languages; v2 = English-only, slightly better recall.
final class ParakeetEngine: ASREngine {
    private(set) var state: ASRModelState = .notLoaded {
        didSet { onStateChange?(state) }
    }
    var onStateChange: ((ASRModelState) -> Void)?

    private var manager: AsrManager?
    private var prepareTask: Task<Void, Error>?

    func prepare() async throws {
        if manager != nil { return }
        // Coalesce concurrent prepare() calls into one download/load.
        if let task = prepareTask {
            try await task.value
            return
        }
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                self.state = .downloading
                let version: AsrModelVersion =
                    SettingsStore.shared.modelVersion == "v2" ? .v2 : .v3
                let models = try await AsrModels.downloadAndLoad(version: version)
                self.state = .loading
                let manager = AsrManager(config: .default)
                try await manager.loadModels(models)
                self.manager = manager
                self.state = .ready
            } catch {
                self.state = .failed(error.localizedDescription)
                self.prepareTask = nil
                throw error
            }
        }
        prepareTask = task
        try await task.value
    }

    func transcribe(samples: [Float]) async throws -> String {
        guard let manager else { throw ASRError.notReady }
        // Fresh decoder state per utterance — each dictation is independent.
        var decoderState = try TdtDecoderState()
        let result = try await manager.transcribe(samples, decoderState: &decoderState)
        return result.text
    }

    func transcribe(fileURL: URL) async throws -> String {
        guard let manager else { throw ASRError.notReady }
        var decoderState = try TdtDecoderState()
        let result = try await manager.transcribe(fileURL, decoderState: &decoderState)
        return result.text
    }
}
