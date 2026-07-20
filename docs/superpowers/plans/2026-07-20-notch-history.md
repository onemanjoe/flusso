# Notch waveform + history-on-hover Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a live voice waveform to the notch Listening state, and a hover-to-open list of the last 5 dictations with click-to-copy, reachable by tapping Fn (no menu-bar History needed).

**Architecture:** Pure maths (RMS level, snippet/relative-time) live in `FlussoCore` so the `FlussoChecks` target can unit-test them. `AudioRecorder` emits a throttled level from its existing tap. `RecordingIndicator` gains a waveform, a peek hint, and an expanded history list, and forwards DynamicNotchKit's `isHovering` to `AppState`. `AppState` wires level, snapshots history, cancels the pending recording on hover, and copies the chosen entry to the clipboard.

**Tech Stack:** Swift 6 tools / language mode v5, SwiftUI, AppKit, DynamicNotchKit 1.1.0, FluidAudio 0.15.4, macOS 15+.

## Global Constraints

- Build the app with `swift build --product Flusso` (plain `swift build` hangs in FluidAudioCLI). Full Xcode must be selected (`xcode-select -p` → `/Applications/Xcode.app/...`) because DynamicNotchKit uses `@Entry`/`#Preview` macros.
- Checks run with `swift run FlussoChecks` (no `swift test` on this Mac). `FlussoChecks` links **only** `FlussoCore` — any code to be unit-tested must live in `Sources/FlussoCore`.
- No em or en dashes anywhere (code, strings, comments): use commas or hyphens. Ellipsis "..." is fine.
- Permissive dependencies only. No new dependency is added by this plan.
- Do not add latency to a normal dictation (hold + speak + release) path.
- Work stays on branch `feature/notch-history`; commit after each task.

---

### Task 1: AudioLevel maths (FlussoCore) + checks

**Files:**
- Create: `Sources/FlussoCore/AudioLevel.swift`
- Create: `Tests/FlussoChecks/AudioLevelChecks.swift`
- Modify: `Tests/FlussoChecks/Checks.swift` (register `await audioLevelChecks()`)

**Interfaces:**
- Produces: `enum AudioLevel { static func rms(_ samples: [Float]) -> Float; static func normalized(rms: Float, gain: Float = 8) -> Float }`

- [ ] **Step 1: Write the failing checks**

Create `Tests/FlussoChecks/AudioLevelChecks.swift`:

```swift
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
```

- [ ] **Step 2: Register and run to verify it fails**

In `Tests/FlussoChecks/Checks.swift`, add `await audioLevelChecks()` right after `await appSettingsChecks()`.

Run: `swift run FlussoChecks 2>&1 | tail -5`
Expected: compile error "cannot find 'AudioLevel' in scope" (checks reference a type that does not exist yet).

- [ ] **Step 3: Write minimal implementation**

Create `Sources/FlussoCore/AudioLevel.swift`:

```swift
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
```

- [ ] **Step 4: Run checks to verify they pass**

Run: `swift run FlussoChecks 2>&1 | tail -6`
Expected: the four new `PASS` lines and `N passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add Sources/FlussoCore/AudioLevel.swift Tests/FlussoChecks/AudioLevelChecks.swift Tests/FlussoChecks/Checks.swift
git commit -m "Add AudioLevel RMS maths for the notch waveform"
```

---

### Task 2: HistoryDisplay maths (FlussoCore) + checks

**Files:**
- Create: `Sources/FlussoCore/HistoryDisplay.swift`
- Create: `Tests/FlussoChecks/HistoryDisplayChecks.swift`
- Modify: `Tests/FlussoChecks/Checks.swift` (register `await historyDisplayChecks()`)

**Interfaces:**
- Produces: `enum HistoryDisplay { static func text(cleaned: String, raw: String) -> String; static func snippet(cleaned: String, raw: String, max: Int = 48) -> String; static func relativeTime(from: Date, to: Date) -> String }`

- [ ] **Step 1: Write the failing checks**

Create `Tests/FlussoChecks/HistoryDisplayChecks.swift`:

```swift
import Foundation
import FlussoCore

func historyDisplayChecks() async {
    await Harness.check("text prefers cleaned, falls back to raw when cleaned empty") {
        try Harness.expect(HistoryDisplay.text(cleaned: "Ciao.", raw: "ehm ciao") == "Ciao.", "cleaned not preferred")
        try Harness.expect(HistoryDisplay.text(cleaned: "   ", raw: "ciao grezzo") == "ciao grezzo", "raw fallback failed")
    }
    await Harness.check("snippet collapses whitespace and newlines to one line") {
        let s = HistoryDisplay.snippet(cleaned: "riga uno\n  riga\tdue", raw: "", max: 48)
        try Harness.expect(s == "riga uno riga due", "got '\(s)'")
    }
    await Harness.check("snippet truncates with ellipsis at max") {
        let s = HistoryDisplay.snippet(cleaned: String(repeating: "a", count: 60), raw: "", max: 10)
        try Harness.expect(s.count == 10, "wrong length \(s.count): '\(s)'")
        try Harness.expect(s.hasSuffix("..."), "no ellipsis: '\(s)'")
    }
    await Harness.check("relativeTime buckets seconds/minutes/hours/days") {
        let now = Date(timeIntervalSince1970: 1_000_000)
        try Harness.expect(HistoryDisplay.relativeTime(from: now.addingTimeInterval(-10), to: now) == "ora", "sec")
        try Harness.expect(HistoryDisplay.relativeTime(from: now.addingTimeInterval(-65), to: now) == "1 min", "min")
        try Harness.expect(HistoryDisplay.relativeTime(from: now.addingTimeInterval(-7200), to: now) == "2 h", "hour")
        try Harness.expect(HistoryDisplay.relativeTime(from: now.addingTimeInterval(-172800), to: now) == "2 g", "day")
    }
}
```

- [ ] **Step 2: Register and run to verify it fails**

In `Tests/FlussoChecks/Checks.swift`, add `await historyDisplayChecks()` after `await audioLevelChecks()`.

Run: `swift run FlussoChecks 2>&1 | tail -5`
Expected: compile error "cannot find 'HistoryDisplay' in scope".

- [ ] **Step 3: Write minimal implementation**

Create `Sources/FlussoCore/HistoryDisplay.swift`:

```swift
import Foundation

/// Pure presentation helpers for showing recent dictations in the notch.
/// In FlussoCore so FlussoChecks can test them.
public enum HistoryDisplay {
    /// Text to show/copy for a record: prefer cleaned, fall back to raw when empty.
    public static func text(cleaned: String, raw: String) -> String {
        let c = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return c.isEmpty ? raw.trimmingCharacters(in: .whitespacesAndNewlines) : c
    }

    /// One-line snippet: collapse whitespace/newlines, truncate to `max` with "...".
    public static func snippet(cleaned: String, raw: String, max: Int = 48) -> String {
        let full = text(cleaned: cleaned, raw: raw)
        let collapsed = full.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .joined(separator: " ")
        if collapsed.count <= max { return collapsed }
        return String(collapsed.prefix(Swift.max(0, max - 3))) + "..."
    }

    /// Short relative time: "ora", "N min", "N h", "N g".
    public static func relativeTime(from date: Date, to now: Date) -> String {
        let s = Swift.max(0, now.timeIntervalSince(date))
        switch s {
        case ..<60: return "ora"
        case ..<3600: return "\(Int(s / 60)) min"
        case ..<86_400: return "\(Int(s / 3600)) h"
        default: return "\(Int(s / 86_400)) g"
        }
    }
}
```

- [ ] **Step 4: Run checks to verify they pass**

Run: `swift run FlussoChecks 2>&1 | tail -6`
Expected: the four new `PASS` lines and `N passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add Sources/FlussoCore/HistoryDisplay.swift Tests/FlussoChecks/HistoryDisplayChecks.swift Tests/FlussoChecks/Checks.swift
git commit -m "Add HistoryDisplay snippet/relative-time helpers"
```

---

### Task 3: AudioRecorder emits a throttled level

**Files:**
- Modify: `Sources/Flusso/AudioRecorder.swift`

**Interfaces:**
- Consumes: `AudioLevel.rms`, `AudioLevel.normalized` (Task 1).
- Produces: `AudioRecorder.onLevel: ((Float) -> Void)?` (a 0...1 level, ~20 Hz, called from the audio thread).

No unit test (AudioRecorder is in the app target, which FlussoChecks does not link). Verified by build.

- [ ] **Step 1: Add the import and property**

At the top of `Sources/Flusso/AudioRecorder.swift`, change `import AVFoundation` to:

```swift
import AVFoundation
import FlussoCore
```

Inside `final class AudioRecorder`, add below `private let lock = NSLock()`:

```swift
    /// Emits a 0...1 voice level (~20 Hz) from the audio thread while recording,
    /// for the notch waveform. Consumers must hop to the main actor themselves.
    var onLevel: ((Float) -> Void)?
    private var lastLevelEmit: TimeInterval = 0
```

- [ ] **Step 2: Reset the throttle in start()**

In `start()`, right after `samples.removeAll()` (still under the lock/unlock pair is fine to place just after `lock.unlock()`):

```swift
        lastLevelEmit = 0
```

- [ ] **Step 3: Emit the level inside the tap**

In the tap closure, replace this block:

```swift
            guard let channel = out.floatChannelData?[0] else { return }
            self.lock.lock()
            if self.samples.count < Self.maxSamples {
                self.samples.append(contentsOf: UnsafeBufferPointer(start: channel,
                                                                    count: Int(out.frameLength)))
            }
            self.lock.unlock()
```

with:

```swift
            guard let channel = out.floatChannelData?[0] else { return }
            let frame = Int(out.frameLength)
            self.lock.lock()
            if self.samples.count < Self.maxSamples {
                self.samples.append(contentsOf: UnsafeBufferPointer(start: channel, count: frame))
            }
            self.lock.unlock()

            if let onLevel = self.onLevel, frame > 0 {
                let now = ProcessInfo.processInfo.systemUptime
                if now - self.lastLevelEmit >= 0.05 {
                    self.lastLevelEmit = now
                    let buf = Array(UnsafeBufferPointer(start: channel, count: frame))
                    onLevel(AudioLevel.normalized(rms: AudioLevel.rms(buf)))
                }
            }
```

- [ ] **Step 4: Build to verify it compiles**

Run: `swift build --product Flusso 2>&1 | tail -5`
Expected: `Build ... complete!` with no errors.

- [ ] **Step 5: Commit**

```bash
git add Sources/Flusso/AudioRecorder.swift
git commit -m "AudioRecorder: emit a throttled voice level for the waveform"
```

---

### Task 4: RecordingIndicator waveform + peek + history + hover

**Files:**
- Modify (full rewrite): `Sources/Flusso/RecordingIndicator.swift`

**Interfaces:**
- Consumes: DynamicNotchKit `DynamicNotch` (`isHovering` published, `hoverBehavior`, `compact(on:)`, `expand(on:)`, `hide()`).
- Produces (used by Task 5):
  - top-level `struct IndicatorRow: Identifiable { let id: UUID; let snippet: String; let time: String; init(snippet:time:) }`
  - `RecordingIndicator.onHoverChange: ((Bool) -> Void)?`
  - `func showListening()`, `func showThinking()`, `func showPeek()`, `func setLevel(_ level: Float)`, `func showHistory(_ rows: [IndicatorRow], onCopy: @escaping (Int) -> Void)`, `func flashCopied()`, `func hide()`

Verified by build; behaviour verified manually in Task 6.

- [ ] **Step 1: Replace the file contents**

Overwrite `Sources/Flusso/RecordingIndicator.swift` with:

```swift
import Cocoa
import SwiftUI
import Combine
import DynamicNotchKit

/// One row in the notch history list.
struct IndicatorRow: Identifiable {
    let id = UUID()
    let snippet: String
    let time: String
    init(snippet: String, time: String) {
        self.snippet = snippet
        self.time = time
    }
}

@MainActor
final class RecordingIndicator {
    /// What the notch is currently showing.
    enum Kind { case listening, thinking, peek, history }

    private final class State: ObservableObject {
        @Published var kind: Kind = .listening
        @Published var label = ""
        @Published var color = Color.red
        @Published var level: Float = 0
        @Published var rows: [IndicatorRow] = []
        @Published var copied = false
        var onCopy: ((Int) -> Void)?
    }

    /// Five bars whose height follows the live level, hugging the notch or the pill.
    private struct Waveform: View {
        @ObservedObject var state: State
        private let mults: [CGFloat] = [0.45, 0.75, 1.0, 0.75, 0.45]
        var body: some View {
            HStack(spacing: 2) {
                ForEach(0..<mults.count, id: \.self) { i in
                    Capsule().fill(state.color)
                        .frame(width: 2.5, height: max(3, CGFloat(state.level) * 15 * mults[i]))
                }
            }
            .frame(height: 16)
            .animation(.easeOut(duration: 0.08), value: state.level)
        }
    }

    private struct CompactLeading: View {
        @ObservedObject var state: State
        var body: some View {
            switch state.kind {
            case .listening: Waveform(state: state)
            case .peek: Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            case .thinking, .history: Circle().fill(state.color).frame(width: 8, height: 8)
            }
        }
    }

    private struct CompactTrailing: View {
        @ObservedObject var state: State
        var body: some View {
            Text(state.kind == .peek ? "storico" : state.label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(state.kind == .peek ? .secondary : .primary)
                .fixedSize()
        }
    }

    private struct ExpandedContent: View {
        @ObservedObject var state: State
        var body: some View {
            switch state.kind {
            case .history:
                VStack(alignment: .leading, spacing: 2) {
                    if state.copied {
                        Label("Copiato", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.green)
                            .padding(.vertical, 8).padding(.horizontal, 12)
                    } else if state.rows.isEmpty {
                        Text("Nessuna dettatura")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                            .padding(.vertical, 10).padding(.horizontal, 12)
                    } else {
                        ForEach(Array(state.rows.enumerated()), id: \.element.id) { idx, row in
                            Button { state.onCopy?(idx) } label: {
                                HStack(spacing: 8) {
                                    Text(row.snippet).font(.system(size: 12)).lineLimit(1)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(row.time).font(.system(size: 10)).foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 5).padding(.horizontal, 12)
                        }
                    }
                }
                .frame(width: 340)
                .padding(.vertical, 6)
            default:
                HStack(spacing: 8) {
                    if state.kind == .listening {
                        Waveform(state: state)
                    } else {
                        Circle().fill(state.color).frame(width: 10, height: 10)
                    }
                    if !state.label.isEmpty {
                        Text(state.label).font(.system(size: 13, weight: .medium))
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
            }
        }
    }

    var onHoverChange: ((Bool) -> Void)?

    private let state = State()
    private var notch: DynamicNotch<ExpandedContent, CompactLeading, CompactTrailing>?
    private var hoverCancellable: AnyCancellable?

    private var screen: NSScreen { NSScreen.main ?? NSScreen.screens[0] }

    private func hasNotch(_ screen: NSScreen) -> Bool {
        screen.auxiliaryTopLeftArea?.width != nil && screen.auxiliaryTopRightArea?.width != nil
    }

    func showListening() { state.kind = .listening; state.label = "Listening"; state.color = .red; present() }
    func showThinking() { state.kind = .thinking; state.label = "Thinking"; state.color = .orange; present() }
    func showPeek() { state.kind = .peek; state.label = ""; state.level = 0; present() }
    func setLevel(_ level: Float) { state.level = level }
    func flashCopied() { state.copied = true }

    func showHistory(_ rows: [IndicatorRow], onCopy: @escaping (Int) -> Void) {
        state.kind = .history
        state.rows = rows
        state.onCopy = onCopy
        state.copied = false
        let screen = self.screen
        let notch = notch ?? makeNotch()
        self.notch = notch
        // History is a dropdown list: always expand, on notch and non-notch screens.
        Task { await notch.expand(on: screen) }
    }

    func hide() {
        state.copied = false
        guard let notch else { return }
        Task { await notch.hide() }
    }

    /// Compact on a notched screen (hug the notch); expand into a floating pill on
    /// any screen without a notch, where the compact renderer is parked off-screen.
    private func present() {
        let screen = self.screen
        let notch = notch ?? makeNotch()
        self.notch = notch
        Task {
            if hasNotch(screen) { await notch.compact(on: screen) }
            else { await notch.expand(on: screen) }
        }
    }

    private func makeNotch() -> DynamicNotch<ExpandedContent, CompactLeading, CompactTrailing> {
        let state = self.state
        let n = DynamicNotch(
            hoverBehavior: [.keepVisible, .increaseShadow],
            style: .auto,
            expanded: { ExpandedContent(state: state) },
            compactLeading: { CompactLeading(state: state) },
            compactTrailing: { CompactTrailing(state: state) }
        )
        // Forward the library's hover state so AppState can open the history and
        // cancel the pending recording. removeDuplicates avoids repeat callbacks.
        hoverCancellable = n.$isHovering
            .removeDuplicates()
            .sink { [weak self] hovering in self?.onHoverChange?(hovering) }
        return n
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `swift build --product Flusso 2>&1 | tail -8`
Expected: `Build ... complete!`. If the generic parameter order of `DynamicNotch<Expanded, CompactLeading, CompactTrailing>` errors, confirm against the installed `DynamicNotch.init(hoverBehavior:style:expanded:compactLeading:compactTrailing:)` signature and match the closure labels exactly (do not reorder).

- [ ] **Step 3: Commit**

```bash
git add Sources/Flusso/RecordingIndicator.swift
git commit -m "RecordingIndicator: waveform, peek hint, hover-driven history list"
```

---

### Task 5: AppState wiring (level, snapshot, hover, linger, copy)

**Files:**
- Modify: `Sources/Flusso/AppState.swift`

**Interfaces:**
- Consumes: `AudioRecorder.onLevel` (Task 3); `RecordingIndicator` new API + `IndicatorRow` (Task 4); `HistoryStore.recent` and `HistoryDisplay` (existing / Task 2).

Pure checks still pass (`swift run FlussoChecks`); behaviour verified manually in Task 6.

- [ ] **Step 1: Add state properties**

In `AppState`, below `private var startInFlight = false`, add:

```swift
    private var browsingRecords: [DictationRecord] = []
    private var lingerTask: Task<Void, Never>?
```

- [ ] **Step 2: Wire level and hover in startEngines()**

In `startEngines()`, immediately after `hotkey.onAction = { [weak self] action in self?.handle(action) }`, add:

```swift
        recorder.onLevel = { [weak self] level in
            Task { @MainActor in self?.indicator.setLevel(level) }
        }
        indicator.onHoverChange = { [weak self] hovering in
            self?.handleIndicatorHover(hovering)
        }
```

- [ ] **Step 3: Update the three indicator calls in handle(_:)**

In `handle(_:)`, replace the `.startRecording` body's `indicator.show("Listening", color: .red)` line with:

```swift
                lingerTask?.cancel()
                browsingRecords = history.recent(5)
                indicator.showListening()
```

Replace the whole `.cancelRecording` case:

```swift
        case .cancelRecording:
            guard phase == .recording else { return }
            _ = recorder.stop()
            phase = .idle
            indicator.showPeek()
            startLinger()
```

Replace, in `.stopAndProcess`, the line `indicator.show("Thinking", color: .orange)` with:

```swift
            indicator.showThinking()
```

- [ ] **Step 4: Add the hover/linger/copy methods**

Add these methods inside `AppState` (for example just before `func copyLastDictation()`):

```swift
    /// After a quick tap (cancelRecording), keep a subtle peek hint up briefly so
    /// the user can reach it with the mouse; hide it if they do not hover in time.
    private func startLinger() {
        lingerTask?.cancel()
        lingerTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard let self, !Task.isCancelled else { return }
            if self.phase == .idle { self.indicator.hide() }
        }
    }

    /// Mouse entered/left the indicator. On enter: cancel any pending recording and
    /// open the last-5 history. On leave: hide.
    private func handleIndicatorHover(_ hovering: Bool) {
        guard hovering else { indicator.hide(); return }
        lingerTask?.cancel()
        if phase == .recording {
            _ = recorder.stop()
            phase = .idle
        }
        let records = browsingRecords.isEmpty ? history.recent(5) : browsingRecords
        browsingRecords = records
        let now = Date()
        let rows = records.map { rec in
            IndicatorRow(snippet: HistoryDisplay.snippet(cleaned: rec.cleaned, raw: rec.raw),
                         time: HistoryDisplay.relativeTime(from: rec.date, to: now))
        }
        indicator.showHistory(rows) { [weak self] idx in self?.copyHistoryEntry(idx) }
    }

    private func copyHistoryEntry(_ index: Int) {
        guard index >= 0, index < browsingRecords.count else { return }
        let rec = browsingRecords[index]
        let text = HistoryDisplay.text(cleaned: rec.cleaned, raw: rec.raw)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        indicator.flashCopied()
    }
```

- [ ] **Step 5: Cancel linger when pausing**

In `togglePaused()`, inside the `if phase == .recording {` block, add `lingerTask?.cancel()` as the first line (before `_ = recorder.stop()`).

- [ ] **Step 6: Build and run checks**

Run: `swift build --product Flusso 2>&1 | tail -5`
Expected: `Build ... complete!`

Run: `swift run FlussoChecks 2>&1 | tail -3`
Expected: `N passed, 0 failed` (N is 37 plus the 8 new checks = 45).

- [ ] **Step 7: Commit**

```bash
git add Sources/Flusso/AppState.swift
git commit -m "AppState: pump level, snapshot history, hover-to-browse, copy on click"
```

---

### Task 6: Install, verify on hardware, update WORKLOG

**Files:**
- Modify: `WORKLOG.md`

No code. Manual acceptance by Giuseppe (UI/hover cannot be unit-tested here).

- [ ] **Step 1: Build and install the app**

Run: `scripts/bundle.sh --install 2>&1 | tail -8`
Expected: builds and installs to `/Applications`, same stable signing cert, permissions preserved.

- [ ] **Step 2: Ask Giuseppe to verify (checklist)**

Give Giuseppe this checklist and wait for his result on each:
1. Hold Fn and speak: the notch shows the moving waveform, releases, and pastes normally with no added delay.
2. Quick-tap Fn and say nothing: a small "storico" hint stays a couple of seconds; move the mouse over it and the last 5 dictations open.
3. Click a row: it shows "Copiato"; Cmd+V pastes that text elsewhere.
4. Repeat 2-3 with the external LG monitor connected and focused (floating pill): hover, list, copy all work.
5. History empty edge (fresh corpus or after Delete All): hovering shows "Nessuna dettatura", no crash.

If hover flickers or the list closes too eagerly during the compact-to-expanded transition, add a short (about 150 ms) debounce before acting on a `hovering == false` from `onHoverChange`, then re-test. (Root cause first: confirm via console/behaviour that it is a transient false, not a real leave.)

- [ ] **Step 3: Update WORKLOG.md**

Add a dated section under the latest entry summarising: waveform in Listening, tap-to-peek + hover-to-open last-5 history with click-to-copy, files touched, checks count, and Giuseppe's acceptance words.

- [ ] **Step 4: Commit**

```bash
git add WORKLOG.md
git commit -m "Update WORKLOG with notch waveform + history-on-hover"
```

---

## Self-Review

**Spec coverage:**
- Waveform in Listening -> Tasks 1, 3, 4. ✓
- Recent-5 on hover + click-to-copy -> Tasks 2, 4, 5. ✓
- Tap-to-peek linger -> Task 5 (`startLinger`, `.cancelRecording`). ✓
- "Copiato" feedback -> Task 4 (`copied`/`flashCopied`), Task 5 (`copyHistoryEntry`). ✓
- Cancel pending recording on hover -> Task 5 (`handleIndicatorHover`). ✓
- Works on external monitor -> Task 4 (`showHistory` always expands), Task 6 step 2.4. ✓
- No delay on normal dictation -> hold+release path untouched (Task 5 step 3 leaves `.stopAndProcess` processing as-is). ✓
- Edge: empty history -> Task 4 ("Nessuna dettatura"), Task 6 step 2.5. ✓
- Out of scope (IT/EN badge, live preview, corpus trimming) -> not implemented. ✓

**Placeholder scan:** No TBD/TODO; every code step shows full code. ✓

**Type consistency:** `IndicatorRow(snippet:time:)`, `showListening/showThinking/showPeek/setLevel/showHistory/flashCopied/hide`, `onHoverChange`, `AudioLevel.rms/normalized`, `HistoryDisplay.text/snippet/relativeTime` are defined in Tasks 1/2/4 and consumed with matching names/signatures in Tasks 3/5. ✓

## Known risk

The hover mechanics (compact-to-expanded transition without a spurious hide, and reliable `isHovering` on a notched screen vs the floating pill) is the one part that cannot be unit-tested here and may need the 150 ms debounce noted in Task 6 step 2. Everything else is either checked (`FlussoChecks`) or a plain build.
