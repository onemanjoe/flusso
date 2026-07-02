import Foundation

enum SelfTest {
    /// Returns true when a selftest ran; the caller must exit afterwards.
    static func runIfRequested() async -> Bool {
        let args = CommandLine.arguments
        if args.contains("--selftest-audio") {
            await audioTest()
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
}
