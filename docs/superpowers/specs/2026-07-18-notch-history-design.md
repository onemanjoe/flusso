# Notch: live waveform + history-on-hover — design

Date: 2026-07-18
Branch: `feature/notch-history`
Status: approved (design), pre-implementation

## Purpose

Two additions to the existing notch recording indicator, both requested by Giuseppe:

1. **Live waveform** while listening: replace the static red dot with bars that react to the
   user's voice level in real time, so it is obvious the mic is actually capturing.
2. **Recent-dictations on hover**: press Fn, hover the indicator with the mouse, and the notch
   opens the last 5 dictations; click one to copy its text to the clipboard. This lets the user
   grab a recent dictation without opening the menu-bar History window.

The driving gesture (Giuseppe's words): "premo Fn, non dico niente, passo sopra col mouse e scelgo
con un clic quale voglio copiare."

## Out of scope (this round)

- IT/EN language badge (deferred, cheap to add later).
- Live transcription preview (needs streaming ASR rework; deferred).
- Trimming the on-disk corpus (unbounded `corpus.jsonl` growth is a pre-existing follow-up, not
  introduced here).

## Interaction model

States, driven by Fn (push-to-talk) plus mouse hover over the indicator:

1. **Fn down** → phase `.recording`. Indicator shows **Listening** with the live waveform.
   At this moment AppState also snapshots `history.recent(5)` and hands it to the indicator, so the
   list is ready if the user hovers.
2. **User speaks, releases Fn** (no hover) → normal dictation, unchanged, with the waveform shown
   the whole time. Text is cleaned and pasted as today.
3. **User hovers the indicator** (mouse enters it) → the notch **pins open** (stays even if Fn is
   released) and shows the **history list**. The pending recording is **cancelled** (recorder
   stopped, samples discarded, phase back to `.idle`) so nothing gets pasted.
4. **User clicks a row** → that entry's text is copied to the clipboard; the notch briefly shows
   **Copiato**. The user pastes wherever with Cmd+V.
5. **Mouse leaves the indicator** → notch hides, back to idle.

### Tap to peek (so a tap works, not only a hold)

Fn is hold-to-talk, so a quick tap-and-release would normally hide the indicator before the mouse
arrives. Flusso already distinguishes a **quick tap** from a **hold** in `HotkeyMonitor` (covered by
the checks "quick tap cancels" and "hold and release processes"): a quick tap already **cancels** the
recording (no paste). We reuse that existing distinction instead of measuring audio silence:

- **Quick tap** → recording cancelled as today, but the indicator now **lingers** for a short grace
  window (~2 s) armed for hover, instead of hiding immediately. If the mouse enters in that window →
  browsing (step 3). If the window expires with no hover → hide. This is the "premo Fn, non dico
  niente, poi vado col mouse" path.
- **Hold + hover** → if the mouse enters the indicator while Fn is still held, we cancel + pin + show
  history immediately (step 3); releasing Fn afterwards does nothing.
- **Hold + speak + release** (no hover) → normal dictation, unchanged. **No delay is added to a
  normal dictation** (speed is a hard constraint for this app).

Exact wiring into `HotkeyMonitor`'s tap/cancel path and `handle(.cancelRecording)` is confirmed in
the implementation plan; the contract here is: a quick tap leaves the indicator hoverable for ~2 s.

## Architecture

Keep the existing decoupling: `RecordingIndicator` exposes a small API and knows nothing about
`AppState` internals; `AppState` owns the wiring. `AudioRecorder` stays the single audio choke point.

### AudioRecorder.swift

- In the existing tap closure (the one point every buffer already passes through), compute a
  smoothed RMS level normalised to roughly `0...1`.
- Expose the level to the UI. Chosen mechanism: an `onLevel: ((Float) -> Void)?` callback invoked
  from the tap (audio thread); AppState hops it to the MainActor, throttled to ~20-30 Hz. (A
  callback keeps `AudioRecorder` free of SwiftUI/ObservableObject concerns, matching its current
  plain-class style.)
- No peak/silence tracking is needed: the tap-vs-hold distinction already lives in `HotkeyMonitor`
  and drives the "tap to peek" behaviour, so the level is used only for the waveform.

### RecordingIndicator.swift

- **Compact view**: replace the single dot with a small **waveform** (a handful of vertical bars,
  e.g. 4-5) whose heights follow the current level. Level lives on the existing internal `State`
  object as a new `@Published var level: Float`, updated reactively (same pattern as label/color, so
  it still cross-fades and updates in place). Keep the "Thinking" state as-is (no waveform).
- **Expanded view**: a **history mode** rendering up to 5 rows. Each row = a Button showing a short
  snippet (first ~40 chars of `cleaned`, falling back to `raw` when `cleaned` is empty) plus a
  relative time. Tapping a row calls a copy closure. A transient **Copiato** confirmation replaces
  the row content or shows a check for ~1 s.
- **Hover**: enable hover so the notch expands, and use SwiftUI `.onHover` in the content to fire
  `onHoverChange(Bool)` back to AppState (this is the pin/cancel signal). Confirm behaviour on both
  the built-in notch (`.notch`) and the external-monitor floating pill (`.floating`).
- **API additions** (public surface stays small):
  - `show(_ label:color:level:)` or keep `show(_:color:)` and pump level separately via a setter.
  - `setLevel(_:)`, `setHistory(_ entries:onCopy:)`, `onHoverChange` callback, and a `pin()`/`unpin()`
    or a single `showHistory()` entry point. Exact shape decided in the plan; the contract is:
    AppState can (a) push the level, (b) push a 5-entry snapshot + copy closure, (c) learn when the
    mouse enters/leaves.

### AppState.swift

- Recorder wiring: set `recorder.onLevel` to forward level to the indicator (throttled, MainActor).
- Fn down (`.startRecording`): after starting the recorder, snapshot `history.recent(5)` and pass it
  to the indicator with a copy closure `{ entry in copy(entry) }`.
- Hover enter: `beginBrowsing()` — if phase `.recording`, stop+discard recorder, phase `.idle`, tell
  the indicator to stay pinned in history mode. Hover exit: `endBrowsing()` — `indicator.hide()`.
- Quick tap (existing cancel path): keep the indicator visible for a ~2 s grace timer armed for
  hover, instead of hiding immediately. Hold + release (no hover): process as today.
- `copy(_ entry:)`: write `entry.cleaned` (or `raw`) to `NSPasteboard` (same approach as the existing
  `copyLastDictation()`), then tell the indicator to show **Copiato**.

### DictationRecord

No change. Existing fields (`date`, `raw`, `cleaned`, …) are enough. `recent(5)` already exists.

## Data flow

```
mic buffer ─(tap)→ AudioRecorder: RMS level + peak
                        │ onLevel (throttled, MainActor)
                        ▼
                  RecordingIndicator.State.level ──▶ waveform bars (compact)

Fn down ─▶ AppState.startRecording ─▶ recorder.start(); indicator.show(Listening)
                                   └▶ history.recent(5) ─▶ indicator.setHistory(…, onCopy:)

mouse enter ─▶ indicator.onHoverChange(true) ─▶ AppState.beginBrowsing()
                                                   ├ cancel recorder, phase .idle
                                                   └ indicator stays: history list (expanded)

row click ─▶ onCopy(entry) ─▶ NSPasteboard = entry.cleaned ─▶ indicator shows "Copiato"

mouse leave ─▶ onHoverChange(false) ─▶ AppState.endBrowsing() ─▶ indicator.hide()

quick tap → cancel + indicator lingers ~2s (arm hover) ; hold+release (no hover) → stopAndProcess (paste)
```

## Error / edge handling

- **Empty history**: fewer than 5 (or zero) records → show what exists; zero → a quiet "Nessuna
  dettatura" row, still no crash.
- **Long text**: truncate the snippet for display; copy the full text.
- **External monitor (no notch)**: the indicator is a floating pill; hover + history must work there
  too. This is the screen where the earlier bug lived, so it is a required manual check.
- **Race on Fn up during grace**: if the user starts a new Fn press while a linger timer is pending,
  cancel the timer and treat it as a fresh recording.
- **Audio thread safety**: level callback fires off the audio thread; all UI updates hop to
  MainActor. Peak is read on Fn up (main) after `stop()`.
- **Clipboard**: copying only sets the pasteboard; no paste is simulated (safe, no Accessibility
  side effects).

## Testing / verification

Pure logic is covered by `FlussoChecks` (no `swift test` on this Mac; checks are the harness):

- RMS level is finite, non-negative, and monotonic with input amplitude on a synthetic buffer.
- Snapshot helper returns at most 5 entries, newest first.
- Copy writes the expected string to a pasteboard abstraction.

UI/hover behaviour is not unit-testable here; it is verified manually by Giuseppe on real hardware:

- Build + install via `scripts/bundle.sh --install` (stable signing cert, permissions survive).
- Fn + speak → waveform shows, normal paste, no added delay.
- Fn + silence + hover → history opens, click copies, Cmd+V pastes elsewhere.
- Same on the external LG monitor (floating pill).

## Follow-ups (not now)

- IT/EN badge (plumb detected language onto `DictationRecord`; also run detection on the fast path).
- Corpus trimming / cap on `corpus.jsonl`.
- Optional "Incollato ✓" confirmation after a normal dictation.
