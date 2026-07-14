# Flusso WORKLOG

Read this first at every session start.

## 2026-07-02
- Spec written and approved (docs/superpowers/specs/2026-07-02-flusso-design.md). Additions at approval: model flexibility via Ollama, open-source model watch, personalization layers.
- Model research in docs/model-recommendations.md: try qwen3.5:9b later, Parakeet V3 stays for speech, mlx-tune for future voice fine-tune.
- Implementation plan: docs/superpowers/plans/2026-07-02-flusso-v1.md (14 tasks). Executing on branch feature/v1 via subagent-driven development. Progress ledger: .superpowers/sdd/progress.md (gitignored).
- Constraint discovered: no swift test on this Mac (CommandLineTools only), checks run via `swift run FlussoChecks`.
- Constraint discovered: plain `swift build` (debug) hangs on a type-check timeout inside FluidAudioCLI, a demo tool we never use. Debug builds of the app must use `swift build --product Flusso` (verified, 5 s). Release builds are unaffected, `scripts/bundle.sh` works as is.
- Task 1 complete and reviewed (scaffold, commit 4408941).

## 2026-07-03
- ALL 14 TASKS COMPLETE on feature/v1 (26 commits, HEAD 306eee5). Every task spec+quality reviewed; critical fixes applied and re-reviewed: StateObject init bug (Task 12), onboarding retry guard (Task 14), sync @main entry (async @main silently kills Swift Concurrency under AppKit), clipboard full-fidelity restore, corpus clobber guard.
- Final whole-branch review (most capable model): READY TO MERGE. Privacy audit pass (only localhost Ollama + one-time HF model download). Checks 27/27. Release bundle builds.
- ASR verified end to end on IT+EN fixtures (Parakeet V3, ~0.17 s per utterance after load).
- Follow-up tickets (non-blocking): paste-into-non-editable target loses clipboard text after 0.7 s (recovery: menu Copy Last Dictation), add-word-from-History button, hotkey picker (Fn hardcoded), AppSettings decodeIfPresent when adding fields.
- PENDING: Giuseppe's live acceptance run (README "First run checklist"): install via `scripts/bundle.sh --install`, grant 3 permissions, download model via Setup, dictate IT+EN, Wi-Fi-off test, Ollama-off fallback test, quit WiseMe first (Fn conflict), set the globe/Fn key to Do Nothing in System Settings Keyboard.
- PENDING: merge feature/v1 → main (awaiting Giuseppe's choice).

## 2026-07-03 (speed package, his explicit priority)
- Benchmarked cleanup models on real IT/EN dictations: qwen2.5:7b stays default (qwen3.5:4b paraphrases, gemma4:e4b misses self-corrections; both left installed for future comparison).
- Shipped: 24h keep_alive + temperature 0 (kills the ~5s idle reload, WiseMe's real disease), fast path for short marker-free dictations (~0.25s total, local dictionary spelling enforcement), per-dictation stage timings shown in History, --selftest-pipeline benchmark tool.
- Review caught punctuation gaps in the fast-path guard ("Um, send the file."); fixed with token-normalized matching, RED-GREEN verified.
- Measured warm pipeline: ~1.0-1.1s total for filler-heavy dictations (0.2s ASR + 0.8-0.9s cleanup); fast path ~0.25s.
- Suite now 35 checks. Branch feature/v1 at 4513d7f, 28 commits, tree clean, bundle builds.

## 2026-07-04 (MERGED + live)
- feature/v1 MERGED to main (merge commit 80f27f9, --no-ff), branch deleted, 35 checks green on main. v1 is now official.
- Installed to /Applications, all 3 permissions granted, dictation confirmed working by Giuseppe.
- Cleanup Ollama is SHARED with WiseMe (same localhost:11434 + qwen2.5:7b). Speech model (FluidAudio Parakeet V3) already on disk at ~/Library/Application Support/FluidAudio/, no re-download.
- Accessibility gotcha: bundle.sh --install re-signs ad-hoc, breaking the grant; reset with tccutil + re-grant, do not reinstall after granting.

## 2026-07-04 (icon + share package)
- Added app icon (waveform on blue-indigo gradient squircle): AppIcon.icns committed, bundle.sh copies it to Resources + Info.plist CFBundleIconFile. Source: scratchpad make_icon.py (Pillow) -> iconset -> iconutil.
- English share package on Desktop: Flusso-for-a-friend.zip (app + README.txt + PROMPT-FOR-CLAUDE.md that drives a fresh Claude Code to install Ollama+model and the app). Replaced the earlier Italian zip.
- Reinstalled Giuseppe's /Applications copy to get the icon; as expected the ad-hoc re-sign broke Accessibility again (TCC still auth=2 but cdhash mismatch); reset + re-grant in progress. Confirmed the empirical test: unload model -> reinstall -> if engines start they reload the model; they did not, proving accessibility was the blocker.

## 2026-07-04 (language bug fix)
- BUG (from his real corpus): LLM cleanup translated longer EN dictations to IT ("I hope I can see you soon" -> "Io spero di rivedervi presto"). Fast-path (short) phrases were fine, which masked it earlier. Root cause: generic "never translate" rule too weak for qwen2.5:7b.
- FIX: detect transcript language on-device (NaturalLanguage NLLanguageRecognizer), inject "reply MUST be in <language>" into the prompt. Verified via real Ollama on the failing sentences + pipeline selftest: EN stays EN, IT stays IT. 37 checks green.

## 2026-07-04 (stable-signing verified, GitHub published, friend package remade)
- Stable-signing persistence CONFIRMED (earlier "failure" was a false alarm). The proxy I used, "did Ollama reload the model after reinstall?", is invalid: the app loads the model only on the first dictation, not at launch. Real check: after grant + rebuild + reinstall, TCC.db still shows kTCCServiceAccessibility|2 and kTCCServiceListenEvent|2 for com.giuseppe.flusso, and hex(csreq) of the stored Accessibility rule contains the cert hash d3130ef4... So the grant is pinned to the "Flusso Local Signing" cert and survives every rebuild. Giuseppe no longer needs to re-grant on his Mac.
- GitHub: the remote onemanjoe/flusso already had a DIFFERENT, unrelated single-commit version (45bb56b, "Flusso: local-first macOS dictation app", authored today, no common ancestor with our history). With Giuseppe's OK, backed it up to branch backup-old-version, then force-pushed our complete history. origin/main == local d52d4fa. Repo now holds our v1.
- Friend package remade (the Desktop zip was gone): rebuilt the app (cert-signed, still opens on any Mac via right-click Open / quarantine removal), staged Flusso.app + English README.txt + English PROMPT-FOR-CLAUDE.md, zipped with ditto to ~/Desktop/Flusso-for-a-friend.zip. Verified the app inside the zip: valid on disk, satisfies its Designated Requirement.

## 2026-07-14 (notch indicator)
- New feature, his idea: recording indicator moved from a floating panel at the bottom of the screen to the notch (Dynamic-Island style). Isolated in a git worktree at `.worktrees/feature-notch-indicator`, branch `feature/notch-indicator` (commit 451ae97).
- Evaluated the free/open-source notch apps he'd found (Boring Notch, Atoll, jackson-storm/DynamicNotch): all are GPL-3.0 monolithic end-user apps, not reusable libraries, so unusable given the "permissive deps only" rule. MrKai77/DynamicNotchKit (MIT, SPM package purpose-built to add notch UI to a host app, actively maintained) was the right fit and is now a dependency.
- `Sources/Flusso/RecordingIndicator.swift` rewritten: one long-lived `DynamicNotch` instance wrapping an `ObservableObject` state (label/color), so Listening -> Thinking cross-fades in place instead of tearing down/rebuilding a panel. Public API (`show(_:color:)` / `hide()`) unchanged, so `AppState.swift` needed no changes. `style: .auto` falls back to a floating panel on non-notch screens automatically.
- Environment constraint changed: DynamicNotchKit's source uses SwiftUI's `@Entry`/`#Preview` macros, which only resolve against Xcode's bundled macro plugins, not the bare Command Line Tools SDK. Xcode 26.6 was already installed on disk but not selected; Giuseppe ran `sudo xcode-select -s /Applications/Xcode.app` from a real Terminal (the in-session `!` prefix can't satisfy sudo's password prompt, no TTY). The old "no swift test on this Mac, CommandLineTools only" constraint from 2026-07-02 no longer applies as stated, full Xcode is active now. Reversible with `sudo xcode-select -s /Library/Developer/CommandLineTools` if ever needed.
- 37/37 checks green after the change (none of them cover RecordingIndicator directly, it's UI-only). Built + installed via `scripts/bundle.sh --install`, same stable signing cert, permissions survived the reinstall as expected.
- Live-verified by Giuseppe on his real keyboard/notch: dictation still pastes correctly, indicator now shows from the notch. His words: "Sembra che tutto funzioni perfettamente bene", "Cazzo è veramente figo."
- PENDING: merge feature/notch-indicator -> main (awaiting Giuseppe's choice).
