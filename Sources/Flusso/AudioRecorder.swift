import AVFoundation

final class AudioRecorder {
    static let targetSampleRate = 16_000.0
    static let maxSamples = Int(targetSampleRate * 120) // 120 s cap

    private let engine = AVAudioEngine()
    private var samples: [Float] = []
    private let lock = NSLock()

    func start() throws {
        lock.lock()
        samples.removeAll()
        lock.unlock()
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                               sampleRate: Self.targetSampleRate,
                                               channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: inputFormat, to: targetFormat)
        else { throw NSError(domain: "Flusso", code: 1,
                             userInfo: [NSLocalizedDescriptionKey: "audio format unavailable"]) }

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            let ratio = Self.targetSampleRate / inputFormat.sampleRate
            let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 16
            guard let out = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity)
            else { return }
            var served = false
            converter.convert(to: out, error: nil) { _, status in
                if served { status.pointee = .noDataNow; return nil }
                served = true
                status.pointee = .haveData
                return buffer
            }
            guard let channel = out.floatChannelData?[0] else { return }
            self.lock.lock()
            if self.samples.count < Self.maxSamples {
                self.samples.append(contentsOf: UnsafeBufferPointer(start: channel,
                                                                    count: Int(out.frameLength)))
            }
            self.lock.unlock()
        }
        engine.prepare()
        try engine.start()
    }

    func stop() -> [Float] {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        lock.lock()
        defer { lock.unlock() }
        return samples
    }
}

enum WavWriter {
    static func write(samples: [Float], to url: URL) throws {
        guard !samples.isEmpty else { return }
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                   sampleRate: AudioRecorder.targetSampleRate,
                                   channels: 1, interleaved: false)!
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                      frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { src in
            buffer.floatChannelData![0].update(from: src.baseAddress!, count: samples.count)
        }
        try file.write(from: buffer)
    }
}
