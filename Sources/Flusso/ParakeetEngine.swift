import FluidAudio
import Foundation

final class ParakeetEngine: TranscriptionEngine {
    let displayName = "Parakeet V3 (local, 25 languages)"
    private var manager: AsrManager?

    var isReady: Bool { manager != nil }

    func prepare() async throws {
        guard manager == nil else { return }
        let models = try await AsrModels.downloadAndLoad(version: .v3)
        let m = AsrManager(config: .default)
        try await m.loadModels(models)
        manager = m
    }

    func transcribe(_ samples: [Float]) async throws -> String {
        guard let manager else {
            throw NSError(domain: "Flusso", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "speech model not loaded"])
        }
        // Adaptation (see task-10-report.md): the checked-out FluidAudio 0.15.x
        // AsrManager has no zero-arg `transcribe(samples)` (that's a stale README
        // example). The real signature is
        // `transcribe(_:decoderState: inout TdtDecoderState, language:) async throws -> ASRResult`.
        // Each Flusso dictation is a one-shot utterance, not a continuous streaming
        // session, so a fresh decoder state per call is correct here, matching how
        // FluidAudioCLI creates one state per file transcription.
        var decoderState = TdtDecoderState.make()
        let result = try await manager.transcribe(samples, decoderState: &decoderState)
        return result.text
    }
}
