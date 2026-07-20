import Foundation
import FlussoCore

func audioLevelChecks() async {
    await Harness.check("rms of empty is zero") {
        try Harness.expect(AudioLevel.rms([]) == 0, "empty not zero")
    }
    await Harness.check("rms of constant amplitude equals that amplitude") {
        let r = AudioLevel.rms([0.5, 0.5, 0.5, 0.5])
        try Harness.expect(abs(r - 0.5) < 1e-6, "got \(r)")
    }
    await Harness.check("rms grows with amplitude") {
        let quiet = AudioLevel.rms([0.05, -0.05, 0.05, -0.05])
        let loud = AudioLevel.rms([0.4, -0.4, 0.4, -0.4])
        try Harness.expect(loud > quiet, "loud \(loud) not > quiet \(quiet)")
    }
    await Harness.check("normalized clamps to 0...1 and maps zero to zero") {
        try Harness.expect(AudioLevel.normalized(rms: 0) == 0, "zero not zero")
        try Harness.expect(AudioLevel.normalized(rms: 1.0) == 1, "loud not clamped to 1")
        try Harness.expect(AudioLevel.normalized(rms: -1) == 0, "negative not floored")
        try Harness.expect(AudioLevel.normalized(rms: Float.nan) == 0, "nan not floored")
    }
}
