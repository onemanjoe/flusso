import Foundation

/// Pure audio-level maths, shared by the recorder (which emits a live level for
/// the notch waveform) and by the checks. Lives in FlussoCore because the
/// FlussoChecks target links only FlussoCore.
public enum AudioLevel {
    /// Root mean square of a PCM float frame. Zero for an empty buffer.
    public static func rms(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        var sum = 0.0
        for s in samples { sum += Double(s) * Double(s) }
        return Float((sum / Double(samples.count)).squareRoot())
    }

    /// Maps a raw RMS (speech is typically ~0.01...0.2) to a 0...1 bar height,
    /// with gain so ordinary speech fills most of the range, clamped to 0...1.
    public static func normalized(rms: Float, gain: Float = 8) -> Float {
        let v = rms * gain
        if v.isNaN || v < 0 { return 0 }
        return min(v, 1)
    }
}
