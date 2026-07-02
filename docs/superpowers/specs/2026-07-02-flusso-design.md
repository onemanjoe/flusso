# Flusso, private local dictation for macOS — Design (v1)

Date: 2026-07-02
Status: APPROVED by Giuseppe 2026-07-02, with three additions folded in below: swappable models via Ollama (§4a), openness to better open-source models (§4a), personalization on his voice and wording (§4b)
Working name: Flusso (changeable at any time before first build)

## 1. Goal

A small, fully offline dictation app that Giuseppe owns outright. Hold a key, speak Italian or English, release, and clean, well-punctuated text appears in whatever app is focused. Functional equivalent of Wispr Flow's core experience, with zero cloud, zero account, zero subscription, zero telemetry.

This is an original, clean-room implementation. No code is taken from Wispr Flow (proprietary) or VoiceInk (GPL). Only permissively licensed libraries are used as dependencies.

## 2. Non-goals (deferred to v2 or never)

- Per-app tone matching (casual in WhatsApp, formal in Mail)
- Voice-command edits on selected text ("make this shorter")
- Whisper mode (very low speaking volume)
- Snippets, teams, sync, mobile, Windows/Linux
- App Store distribution (paste injection is not sandbox-compatible; this is a personal tool)

## 3. User experience

- Menu bar icon, always running, launches at login.
- **Hold Fn → speak → release Fn** → text pastes at the cursor. Previous clipboard content is restored afterward.
- A small floating indicator appears while recording (listening state) and while processing (thinking state), so it never feels dead.
- Esc while recording cancels, nothing is pasted.
- Menu bar menu: Pause/Resume Flusso, Copy Last Dictation, Recent Dictations (last 20, local only), Personal Dictionary, Settings, Quit.
- Settings: hotkey choice (Fn default, alternatives selectable), cleanup on/off, Ollama model name, launch at login.
- First-run onboarding: a simple checklist window that requests the three macOS permissions (Microphone, Accessibility, Input Monitoring) and downloads the speech model, with plain-language explanations.

Hotkey conflict note: WiseMe currently owns short-press Fn. At install time, either quit/disable WiseMe or move one of the two to a different key. Decision deferred to rollout, default plan is Flusso takes Fn and WiseMe login item is disabled.

## 4. Architecture

Native Swift/SwiftUI menu bar app (MenuBarExtra), macOS 15+ target, Apple Silicon only. Chosen over Tauri/Electron/Python for latency, RAM footprint, direct access to system APIs, and single-binary simplicity.

Components, each independently testable:

1. **HotkeyMonitor** — CGEventTap watching flagsChanged for the Fn key (keyCode 63), with debounce for spurious release events on Fn+key combos. Requires Input Monitoring permission. Emits recordStart/recordStop/cancel events.
2. **AudioRecorder** — AVAudioEngine capture to 16 kHz mono PCM buffer in memory. Requires Microphone permission. Hard cap 120 s per dictation.
3. **Transcriber** — Parakeet-TDT 0.6B v3 (multilingual, auto language detect, IT+EN mixed OK) running on the Neural Engine via the FluidAudio Swift library (CoreML). Model files (~600 MB) downloaded once on first run into Application Support. Verify FluidAudio license is permissive (believed Apache-2.0) before adding the dependency, this is a task in the plan.
4. **Cleaner** — HTTP call to local Ollama (`http://localhost:11434/api/chat`, model `qwen2.5:7b`, already installed and running at login). System prompt: remove fillers, fix punctuation and capitalization, resolve self-corrections keeping only final intent, apply the personal dictionary spellings, never add content, never answer the text, output only the cleaned transcript, keep the original language. 5 s timeout.
5. **Injector** — save current NSPasteboard contents, set cleaned text, post CGEvent Cmd+V, restore previous clipboard after a short delay. Requires Accessibility permission. If no editable field accepts the paste, the text stays on the clipboard and a notification says so.
6. **Dictionary** — a JSON file in Application Support with a list of terms (seed: Materik, Trovi Technologies, Klaviyo, PureCase, CrystalCase, Ripple, Halo, Rolando, Shenzhen). Editable from a simple list window in the app. Injected into the Cleaner prompt.
7. **History** — the menu window shows the last 20 dictations (raw + cleaned) with copy and "add word to dictionary" actions. Underneath it, the full corpus store (§4b layer 2) keeps all dictations, and optionally audio clips, in Application Support, with a delete-all button. Never leaves the machine.
8. **Settings** — JSON file in Application Support, loaded at start, written on change.

Data flow: HotkeyMonitor → AudioRecorder → Transcriber → Cleaner → Injector, with History recording the Transcriber and Cleaner outputs.

## 4a. Model flexibility (requested at approval)

Nothing is hardcoded to a specific model. Two abstraction points:

- **Cleaner is model-agnostic through Ollama.** Settings queries `localhost:11434/api/tags` and shows a dropdown of every model Giuseppe has installed in Ollama; he picks one, no code change needed. Installing a new LLM is just `ollama pull <name>` and reselecting. Default stays `qwen2.5:7b` until a better one is validated. A custom endpoint field also allows any other OpenAI-compatible local server (LM Studio, llama.cpp) later.
- **Transcriber is an engine protocol, not a single implementation.** v1 ships the Parakeet V3 engine; the protocol (audio buffer in, text out, language info out) leaves room to add whisper.cpp large-v3-turbo (accuracy fallback) and Apple SpeechAnalyzer (macOS 26 native) as selectable engines later without touching the rest of the app.

A background research pass on current best open-source models for this exact job (IT+EN cleanup at 7B-14B size, and ASR alternatives) runs in parallel with the build; recommendations land in `docs/model-recommendations.md`.

## 4b. Personalization: learns his voice, language, wordings (requested at approval)

Honest framing: truly re-training the speech model on Giuseppe's voice is a heavy offline job (GPU training pipeline), not an app feature. Flusso instead personalizes in three layers, each fully local:

1. **v1, dictionary:** personal terms enforced in cleanup (already in scope, §4 item 6). One-tap "add word" from the history window when something comes out misspelled.
2. **v1, corpus collection (foundation for everything else):** every dictation is stored locally as a pair (raw transcript, cleaned text), and optionally the audio clip (setting, default ON, easy to purge). This becomes a growing private dataset of his voice, accent, and phrasing.
3. **v1.x, style adaptation:** the Cleaner prompt automatically includes a few recent examples of his corrected dictations (few-shot), so output drifts toward how he actually writes. Later, if the corpus grows large enough and he wants it, the collected audio+text pairs are exactly what a proper fine-tune of the speech model needs (v2+, done as a separate offline job, e.g. LoRA on Whisper or Parakeet via NeMo).

## 5. Failure behavior (graceful degradation, never silent loss)

| Failure | Behavior |
|---|---|
| Ollama down or times out (>5 s) | Paste the raw Parakeet transcript, menu bar icon shows a subtle warning state |
| Speech model missing/corrupt | Onboarding window reopens with a re-download button |
| Paste target rejects input | Text remains on clipboard, user notification |
| Permission revoked | Menu item turns into "Fix permissions…" opening the checklist |
| Empty/too-short audio (<0.4 s) | Discard silently, no paste |

## 6. Privacy guarantee

The app makes no network connections except to `localhost:11434` (Ollama) and the one-time model download on first run (from Hugging Face, then never again). Acceptance test: with Wi-Fi off, full dictation flow works end to end.

## 7. Testing

- Unit tests: Cleaner prompt assembly (dictionary injection, language preservation), fallback logic (timeout → raw), dictionary and settings persistence, hotkey debounce state machine.
- Integration: scripted run of Transcriber on 4 fixture recordings (IT, EN, mixed, with fillers and a self-correction) asserting expected cleaned output shape.
- Manual E2E checklist before calling v1 done: dictate into Mail, WhatsApp Desktop, Notes, and a browser text box, in Italian and English, with Wi-Fi off, verifying clipboard restoration each time.

## 8. Repository

`~/Documents/Progetti Claude Code/flusso`, git-tracked. Xcode-free build via Swift Package Manager (`swift build`), Swift 6.3 toolchain verified present on this Mac.
