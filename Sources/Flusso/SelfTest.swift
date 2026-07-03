import AVFoundation
import FlussoCore
import Foundation

enum SelfTest {
    /// Synchronous pre-check so the entry point can decide, before doing any
    /// async work, whether to run a CLI selftest or launch the SwiftUI app.
    static var isRequested: Bool {
        let args = CommandLine.arguments
        if args.contains("--selftest-audio") { return true }
        if let i = args.firstIndex(of: "--selftest-asr"), args.count > i + 1 { return true }
        if args.contains("--selftest-paste") { return true }
        if let i = args.firstIndex(of: "--selftest-pipeline"), args.count > i + 1 { return true }
        return false
    }

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
        if args.contains("--selftest-paste") {
            print("Click into any text field, pasting in 4 seconds...")
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            await MainActor.run { Injector.paste("flusso paste test ok") }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            return true
        }
        if let i = args.firstIndex(of: "--selftest-pipeline"), args.count > i + 1 {
            await pipelineTest(wavPath: args[i + 1])
            return true
        }
        return false
    }

    /// Loads a wav file into a flat array of float samples via a drain loop.
    /// Shared by `--selftest-asr` and `--selftest-pipeline`.
    private static func loadSamples(wavPath: String) throws -> [Float] {
        let url = URL(fileURLWithPath: wavPath)
        let file = try AVAudioFile(forReading: url)
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                   sampleRate: file.fileFormat.sampleRate,
                                   channels: 1, interleaved: false)!
        var samples: [Float] = []
        samples.reserveCapacity(Int(file.length))
        let chunk = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16384)!
        while file.framePosition < file.length {
            chunk.frameLength = 0
            try file.read(into: chunk)
            if chunk.frameLength == 0 { break }
            samples.append(contentsOf: UnsafeBufferPointer(start: chunk.floatChannelData![0],
                                                           count: Int(chunk.frameLength)))
        }
        return samples
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
            let samples = try loadSamples(wavPath: wavPath)
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

    /// End-to-end pipeline timing: load wav, transcribe, clean, report stage
    /// timings. Uses the real AppSettings (endpoint/model) from disk so the
    /// numbers reflect what a live dictation would actually see, including
    /// whichever model the user has configured.
    private static func pipelineTest(wavPath: String) async {
        do {
            let samples = try loadSamples(wavPath: wavPath)
            print("loaded \(samples.count) samples, preparing engine (first run downloads ~600 MB)...")
            let engine = ParakeetEngine()
            try await engine.prepare()

            let transcribeStart = Date()
            let transcript = try await engine.transcribe(samples)
            let transcribeMs = Int(Date().timeIntervalSince(transcribeStart) * 1000)

            let settings = AppSettings.load(from: Paths.appSupportDir())
            guard let url = URL(string: settings.ollamaEndpoint) else {
                print("invalid Ollama endpoint: \(settings.ollamaEndpoint)")
                return
            }
            let client = OllamaClient(endpoint: url)
            let model = settings.ollamaModel
            let cleaner = Cleaner(chat: { system, user in
                try await client.chat(model: model, system: system, user: user, timeoutSeconds: 30)
            })

            let cleanStart = Date()
            let result = await cleaner.clean(raw: transcript, dictionaryTerms: [])
            let cleanMs = Int(Date().timeIntervalSince(cleanStart) * 1000)

            print("transcript: \(transcript)")
            print("cleaned: \(result.text)")
            print("used fallback: \(result.usedFallback)")
            print("transcribe ms: \(transcribeMs)")
            print("clean ms: \(cleanMs)")
            print("total ms: \(transcribeMs + cleanMs)")
        } catch {
            print("pipeline selftest failed: \(error)")
        }
    }
}
