import Foundation
import FlussoCore

func appSettingsChecks() async {
    await Harness.check("settings defaults when file missing") {
        let s = AppSettings.load(from: Harness.tempDir())
        try Harness.expect(s.ollamaModel == "qwen2.5:7b", "wrong default model")
        try Harness.expect(s.cleanupEnabled && s.storeAudio && !s.paused, "wrong defaults")
        try Harness.expect(s.ollamaEndpoint == "http://localhost:11434", "wrong endpoint")
    }
    await Harness.check("settings round-trip") {
        let dir = Harness.tempDir()
        var s = AppSettings()
        s.ollamaModel = "llama4:8b"
        s.paused = true
        try s.save(to: dir)
        let loaded = AppSettings.load(from: dir)
        try Harness.expect(loaded == s, "round-trip mismatch")
    }
    await Harness.check("settings corrupt file falls back to defaults") {
        let dir = Harness.tempDir()
        try "not json".write(to: dir.appendingPathComponent("settings.json"), atomically: true, encoding: .utf8)
        let s = AppSettings.load(from: dir)
        try Harness.expect(s == AppSettings(), "did not fall back")
    }
}
