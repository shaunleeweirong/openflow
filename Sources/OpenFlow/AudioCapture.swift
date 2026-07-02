import AVFoundation

enum CaptureError: LocalizedError {
    case noInputDevice
    case alreadyRecording

    var errorDescription: String? {
        switch self {
        case .noInputDevice: return "No microphone input device found."
        case .alreadyRecording: return "Already recording."
        }
    }
}

/// Captures microphone audio while push-to-talk is held.
/// Buffers are copied at hardware format in the tap (cheap), then converted
/// once to 16 kHz mono Float32 on stop — keeps AVAudioConverter off the
/// audio thread (known crash hazard) and avoids resampling seams.
final class AudioCapture {
    private let engine = AVAudioEngine()
    private var buffers: [AVAudioPCMBuffer] = []
    private let lock = NSLock()
    private(set) var isRecording = false

    static let targetSampleRate: Double = 16_000

    func start() throws {
        guard !isRecording else { throw CaptureError.alreadyRecording }
        lock.lock()
        buffers.removeAll()
        lock.unlock()

        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw CaptureError.noInputDevice
        }

        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            guard let self, let copy = buffer.deepCopy() else { return }
            self.lock.lock()
            self.buffers.append(copy)
            self.lock.unlock()
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw error
        }
        isRecording = true
    }

    /// Stops capture and returns the whole utterance as 16 kHz mono Float32.
    func stop() -> [Float] {
        guard isRecording else { return [] }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false

        lock.lock()
        let collected = buffers
        buffers.removeAll()
        lock.unlock()

        return Self.convertTo16kMono(collected)
    }

    static func convertTo16kMono(_ input: [AVAudioPCMBuffer]) -> [Float] {
        guard let first = input.first else { return [] }
        let inFormat = first.format
        guard
            let outFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: targetSampleRate,
                channels: 1,
                interleaved: false
            ),
            let converter = AVAudioConverter(from: inFormat, to: outFormat)
        else { return [] }

        var queue = input
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            if queue.isEmpty {
                outStatus.pointee = .endOfStream
                return nil
            }
            outStatus.pointee = .haveData
            return queue.removeFirst()
        }

        var samples: [Float] = []
        while true {
            guard let outBuf = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: 8192) else { break }
            var error: NSError?
            let status = converter.convert(to: outBuf, error: &error, withInputFrom: inputBlock)
            if outBuf.frameLength > 0, let channel = outBuf.floatChannelData {
                samples.append(contentsOf: UnsafeBufferPointer(start: channel[0], count: Int(outBuf.frameLength)))
            }
            if status == .endOfStream || status == .error { break }
        }
        return samples
    }
}

extension AVAudioPCMBuffer {
    /// The tap reuses its buffer; copy before stashing.
    func deepCopy() -> AVAudioPCMBuffer? {
        guard let copy = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameLength) else {
            return nil
        }
        copy.frameLength = frameLength
        let src = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: audioBufferList))
        let dst = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
        for (s, d) in zip(src, dst) {
            guard let sData = s.mData, let dData = d.mData else { continue }
            memcpy(dData, sData, Int(s.mDataByteSize))
        }
        return copy
    }
}
