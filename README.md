# Flusso

Flusso is a private dictation app for the Mac. Hold the Fn key, speak in Italian or English, release Fn, and your words are typed into whatever text field you were using, cleaned up (fillers removed, self-corrections resolved, names spelled the way you taught it).

Everything happens on this Mac. Nothing you say is sent to a server, Apple, or anyone else.

## Privacy, in plain terms

- Speech recognition runs locally, using the Parakeet V3 model, downloaded once and then kept on this Mac.
- The optional cleanup step (removing "um" and fixing self-corrections) runs through Ollama, a small AI server that also runs locally on this Mac. Flusso only ever talks to it at `localhost`, never over the internet.
- The only two things that ever touch the network are the one-time download of the speech model on first setup, and local traffic to Ollama on this same Mac (which never leaves the Mac).
- You can turn off Wi-Fi entirely and Flusso keeps working exactly the same.
- Your dictations are stored only in `~/Library/Application Support/Flusso/`, a folder on your own Mac. Nothing is uploaded anywhere.

## Getting started

1. Make sure Ollama is installed and running (it powers the optional cleanup step). If you do not have it, install it from ollama.com, then run `ollama pull qwen2.5:7b` once in Terminal.
2. Open Terminal, go to the Flusso folder, and run:
   ```
   scripts/bundle.sh --install
   ```
   This builds Flusso and installs it into your Applications folder, then opens it.
3. Flusso lives in the menu bar (top right of your screen) with a waveform icon. Click it and choose "Setup..." to grant the three permissions below and download the speech model.
4. Once setup is done, hold the Fn key anywhere, speak, and release Fn. The text appears where your cursor was.

If you ever reinstall or rebuild Flusso, macOS may ask you to re-grant permissions, since the app's signature changed. That is expected, just grant them again.

## The three permissions

Flusso asks for three permissions, all handled from the Setup window in the menu bar:

- **Microphone**, so it can hear you while you dictate.
- **Input Monitoring**, so it can notice when you hold the Fn key.
- **Accessibility**, so it can type the cleaned up text into whatever app you were using.

If a permission does not seem to take effect, quit Flusso and reopen it.

## Where your data lives

Everything Flusso stores lives in one folder on your Mac, `~/Library/Application Support/Flusso/`. That includes your settings, your personal dictionary (names and words you have taught it), and the log of past dictations. There is a setting in Flusso, under Settings, "Privacy", to also keep the audio recordings of your dictations in that same folder, building your own private voice dataset over time. You can turn that off if you prefer not to keep the audio.

## Changing the AI model

Flusso uses a local Ollama model to clean up your dictation (remove fillers, resolve self-corrections). To change which model it uses:

1. Pull the model you want with Ollama, for example `ollama pull qwen3.5:9b` in Terminal.
2. Open Flusso's menu bar icon, choose "Settings...", then click "Refresh model list" and pick the new model from the dropdown.

You can also turn cleanup off entirely in Settings, in which case Flusso types exactly what it heard, with no AI pass over it.

## Launch at login

In Settings, toggle "Start Flusso at login" to have it open automatically every time you start your Mac. This only works once Flusso is installed in Applications (via `scripts/bundle.sh --install`), not when running it directly from a Terminal build.

## First run checklist

This is the manual check to run once, after installing and granting permissions, to confirm everything works end to end.

1. Dictate into Notes, Mail compose, WhatsApp Desktop, and a browser text box, in both Italian and English. Fillers should be removed, and "Materik" should be spelled correctly.
2. Self-correction test: say "scrivi lunedì, anzi no, martedì alle tre" and confirm the output keeps only "martedì alle tre".
3. Clipboard test: copy a word, dictate something else, then press Cmd+V afterward and confirm it still pastes the word you originally copied (Flusso should not clobber your clipboard).
4. Turn Wi-Fi off, then dictate. It must work exactly the same, since both the speech model and Ollama run locally.
5. Stop Ollama (`brew services stop ollama` in Terminal), then dictate. The raw, uncleaned text should still be pasted, and the menu bar should show a fallback warning. Afterward, restart Ollama with `brew services start ollama`.
6. Quick tap Fn (press and release fast): nothing should be pasted. Hold Fn and press Esc while holding it: the dictation should be cancelled.
7. If WiseMe (or any other Fn based dictation tool) is also installed and running, both it and Flusso will trigger on the Fn key at the same time, which is a conflict. To resolve it, quit WiseMe and remove it from your login items, or remap one of the two tools to a different key if you would rather keep both.
8. Run `swift run FlussoChecks` from the Flusso folder in Terminal and confirm it ends with "N passed, 0 failed" (0 failed is what matters, the exact count can grow over time as more checks are added).
