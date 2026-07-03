import Cocoa
import FlussoCore
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    enum Phase: Equatable {
        case starting, needsSetup(String), idle, recording, processing
    }

    @Published var phase: Phase = .starting
    @Published var lastWarning: String?
    @Published var settings: AppSettings {
        didSet { try? settings.save(to: dir) }
    }
    // Adaptation (task-13): marked @Published so DictionaryView's List refreshes
    // after add/remove. PersonalDictionary is a value type, so mutating it through
    // the binding (`state.dictionary.remove(term)`) triggers this property's
    // didSet/willSet exactly like a whole-value assignment would.
    @Published var dictionary: PersonalDictionary {
        didSet { try? dictionary.save(to: dir) }
    }

    let dir: URL
    let history: HistoryStore
    let engine: TranscriptionEngine = ParakeetEngine()
    private let recorder = AudioRecorder()
    private let hotkey = HotkeyMonitor()
    private let indicator = RecordingIndicator()
    private var lastCleaned: String?
    private var startInFlight = false

    init(directory: URL = Paths.appSupportDir()) {
        dir = directory
        settings = AppSettings.load(from: directory)
        dictionary = PersonalDictionary.load(from: directory)
        history = HistoryStore(directory: directory)
    }

    func startEngines() async {
        // Adaptation (task-12): guard reentry so calling this twice (once from
        // FlussoApp.init(), once from the .task on the menu content, since
        // MenuBarExtra's .task timing is unreliable, see FlussoApp.swift) never
        // creates a second CGEventTap in HotkeyMonitor, which has no idempotency
        // guard of its own and would otherwise leak a live, unstoppable tap and
        // double-fire every Fn press. A plain `phase == .starting` check is not
        // enough: `engine.prepare()` below is a real suspension point, so two
        // concurrently scheduled calls could both pass a phase-based guard
        // before either updates phase. Set this flag synchronously, before any
        // `await`, so MainActor serialization guarantees only the call that
        // starts running first ever proceeds.
        //
        // Post-review fix (C1): a one-shot flag that was never reset made a
        // failed automatic launch call (e.g. fresh install, permissions not
        // yet granted) permanently unrecoverable, since OnboardingView's
        // "Download and start" button calls this same method and it would be
        // a no-op forever after the first attempt. Replace the one-shot flag
        // with an in-flight flag (still set synchronously before any `await`,
        // so concurrent calls are still serialized) plus a phase gate: only
        // `.starting` (first automatic call) or `.needsSetup` (retry from
        // onboarding) are allowed to proceed. Once engines are actually
        // running (`.idle`/`.recording`/`.processing`), further calls return
        // immediately, so the hotkey tap can still never be double-started.
        guard !startInFlight else { return }
        switch phase {
        case .starting, .needsSetup: break
        default: return
        }
        startInFlight = true
        defer { startInFlight = false }
        guard Permissions.microphoneGranted, Permissions.accessibilityGranted,
              Permissions.inputMonitoringGranted else {
            phase = .needsSetup("Permissions missing. Open Setup from the menu.")
            return
        }
        do {
            try await engine.prepare()
        } catch {
            phase = .needsSetup("Speech model not ready: \(error.localizedDescription)")
            return
        }
        hotkey.onAction = { [weak self] action in self?.handle(action) }
        guard hotkey.start() else {
            phase = .needsSetup("Cannot listen for the Fn key. Check Input Monitoring permission.")
            return
        }
        phase = .idle
        prewarmCleanupModel()
    }

    /// First chat after idle pays ~5 s of model load, which would trip the cleanup
    /// timeout. A throwaway ping at startup loads the model while nobody waits.
    private func prewarmCleanupModel() {
        guard settings.cleanupEnabled, let url = URL(string: settings.ollamaEndpoint) else { return }
        let client = OllamaClient(endpoint: url)
        let model = settings.ollamaModel
        Task.detached {
            _ = try? await client.chat(model: model, system: "Reply with: ok",
                                       user: "ok", timeoutSeconds: 60)
        }
    }

    private func handle(_ action: FnAction) {
        guard !settings.paused else { return }
        switch action {
        case .startRecording:
            guard phase == .idle else { return }
            do {
                try recorder.start()
                phase = .recording
                indicator.show("Listening", color: .red)
            } catch {
                lastWarning = "Microphone failed: \(error.localizedDescription)"
            }
        case .cancelRecording:
            guard phase == .recording else { return }
            _ = recorder.stop()
            phase = .idle
            indicator.hide()
        case .stopAndProcess:
            guard phase == .recording else { return }
            let samples = recorder.stop()
            phase = .processing
            indicator.show("Thinking", color: .orange)
            Task { await process(samples) }
        case .none:
            break
        }
    }

    private func process(_ samples: [Float]) async {
        defer {
            indicator.hide()
            phase = .idle
        }
        guard Double(samples.count) >= AudioRecorder.targetSampleRate * 0.4 else { return }
        do {
            let transcribeStart = Date()
            let raw = try await engine.transcribe(samples)
            let transcribeMs = Int(Date().timeIntervalSince(transcribeStart) * 1000)
            guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

            let cleanStart = Date()
            var result = CleanResult(text: raw, usedFallback: false)
            // Post-review fix (I1): `settings.ollamaEndpoint` is user-editable text,
            // so force-unwrapping `URL(string:)` could crash on a malformed value.
            // Treat an invalid URL like cleanup disabled: skip cleanup, fall back to
            // the raw transcript, and surface a dedicated warning.
            if settings.cleanupEnabled, let url = URL(string: settings.ollamaEndpoint) {
                let client = OllamaClient(endpoint: url)
                let model = settings.ollamaModel
                let cleaner = Cleaner(chat: { system, user in
                    try await client.chat(model: model, system: system, user: user, timeoutSeconds: 5)
                })
                result = await cleaner.clean(raw: raw, dictionaryTerms: dictionary.terms)
                lastWarning = result.usedFallback
                    ? "AI cleanup unavailable, pasted the raw transcription." : nil
            } else if settings.cleanupEnabled {
                result = CleanResult(text: raw, usedFallback: true)
                lastWarning = "Ollama endpoint is not a valid URL, pasted the raw transcription."
            } else {
                lastWarning = nil
            }
            let cleanMs = Int(Date().timeIntervalSince(cleanStart) * 1000)

            Injector.paste(result.text)
            lastCleaned = result.text

            var audioFile: String?
            if settings.storeAudio {
                let name = "\(Int(Date().timeIntervalSince1970)).wav"
                try? WavWriter.write(samples: samples,
                                     to: history.audioDir.appendingPathComponent(name))
                audioFile = name
            }
            try? history.append(DictationRecord(date: Date(), raw: raw,
                                                cleaned: result.text, audioFile: audioFile,
                                                transcribeMs: transcribeMs, cleanMs: cleanMs))
        } catch {
            lastWarning = "Transcription failed: \(error.localizedDescription)"
        }
    }

    func copyLastDictation() {
        guard let lastCleaned else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lastCleaned, forType: .string)
    }

    func togglePaused() {
        // Post-review fix (M1): pausing while a recording is in flight used to
        // leave the recorder running and the indicator on screen, stranded,
        // since `handle(_:)` gates every action on `!settings.paused`. Stop the
        // recorder and reset to idle first so pausing mid-recording can't strand it.
        if phase == .recording {
            _ = recorder.stop()
            indicator.hide()
            phase = .idle
        }
        settings.paused.toggle()
    }
}
