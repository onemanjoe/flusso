# Flusso WORKLOG

Read this first at every session start.

## 2026-07-02
- Spec written and approved (docs/superpowers/specs/2026-07-02-flusso-design.md). Additions at approval: model flexibility via Ollama, open-source model watch, personalization layers.
- Model research in docs/model-recommendations.md: try qwen3.5:9b later, Parakeet V3 stays for speech, mlx-tune for future voice fine-tune.
- Implementation plan: docs/superpowers/plans/2026-07-02-flusso-v1.md (14 tasks). Executing on branch feature/v1 via subagent-driven development. Progress ledger: .superpowers/sdd/progress.md (gitignored).
- Constraint discovered: no swift test on this Mac (CommandLineTools only), checks run via `swift run FlussoChecks`.
- Constraint discovered: plain `swift build` (debug) hangs on a type-check timeout inside FluidAudioCLI, a demo tool we never use. Debug builds of the app must use `swift build --product Flusso` (verified, 5 s). Release builds are unaffected, `scripts/bundle.sh` works as is.
- Task 1 complete and reviewed (scaffold, commit 4408941).
