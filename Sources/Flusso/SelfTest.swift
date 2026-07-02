import AVFoundation
import Foundation

enum SelfTest {
    /// Returns true when a selftest ran; the caller must exit afterwards.
    static func runIfRequested() async -> Bool {
        let args = CommandLine.arguments
        if args.contains("--selftest-audio") {
            await audioTest()
            return true
        }
        if let i = args.firstIndex(of: "--selftest-asr"), args.count > i + 1 {
            await asrTest(wavPath: args[i + 1])
            return true
        }
        return false
    }

    private static func audioTest() async {
        print("Recording 2 seconds, speak now...")
        let recorder = AudioRecorder()
        do {
            try recorder.start()
            try await Task.sleep(nanoseconds: 2_000_000_000)
            let samples = recorder.stop()
            let expected = Int(AudioRecorder.targetSampleRate * 2)
            let peak = samples.map(abs).max() ?? 0
            print("samples: \(samples.count) (expected ~\(expected)), peak: \(peak)")
            let out = FileManager.default.temporaryDirectory.appendingPathComponent("flusso-selftest.wav")
            try WavWriter.write(samples: samples, to: out)
            print("wav written: \(out.path)")
        } catch {
            print("audio selftest failed: \(error)")
        }
    }

    private static func asrTest(wavPath: String) async {
        do {
            let url = URL(fileURLWithPath: wavPath)
            let file = try AVAudioFile(forReading: url)
            let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                       sampleRate: file.fileFormat.sampleRate,
                                       channels: 1, interleaved: false)!
            let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                          frameCapacity: AVAudioFrameCount(file.length))!
            try file.read(into: buffer)
            var samples = [Float](repeating: 0, count: Int(buffer.frameLength))
            samples.withUnsafeMutableBufferPointer {
                $0.baseAddress!.update(from: buffer.floatChannelData![0], count: Int(buffer.frameLength))
            }
            print("loaded \(samples.count) samples, preparing engine (first run downloads ~600 MB)...")
            let engine = ParakeetEngine()
            try await engine.prepare()
            let start = Date()
            let text = try await engine.transcribe(samples)
            print("transcript (\(String(format: "%.2f", Date().timeIntervalSince(start))) s): \(text)")
        } catch {
            print("asr selftest failed: \(error)")
        }
    }
}
