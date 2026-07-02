# Model recommendations, mid-2026

Research date: 2026-07-02. Target hardware: MacBook Pro M1 Max, 64 GB. Pipeline: local ASR, then local LLM cleanup via Ollama (Italian and English), latency-sensitive.

## 1. LLM for dictation cleanup (replacing qwen2.5:7b)

qwen2.5:7b (Sep 2024) is now two generations behind. The Qwen3.5 small series shipped March 2, 2026 on Ollama with 0.8b, 2b, 4b and 9b sizes (https://ollama.com/library/qwen3.5), and Google released Gemma 4 on March 31, 2026 (https://ai.google.dev/gemma/docs/core/model_card_4). Llama 4 has no small dense variant, its smallest model (Scout) is a 109B MoE, so it is out of scope for this job (https://ollama.com/library/llama4). Qwen3.6 exists but only in 27b/35b coding-focused variants (https://ollama.com/library/qwen3.6).

Ranked picks:

1. **qwen3.5:9b** (6.6 GB, default tag). Clear upgrade over qwen2.5:7b: 201 languages vs 29, much stronger instruction following, 256K context, reported to match far larger models on benchmarks (https://ollama.com/library/qwen3.5, https://techie007.substack.com/p/qwen-35-the-complete-guide-benchmarks). Important for latency: it is a thinking model, run it with thinking disabled (`think: false` in the Ollama API) or cleanup calls will crawl. Expected on M1 Max: roughly 30 to 45 tok/s at Q4, small models on Apple Silicon generally land in the 40 to 80 tok/s band (https://llmcheck.net/benchmarks).
2. **gemma4:e4b** (default Gemma 4 tag, 8B total, 4.5B effective, MatFormer edge design). 140+ languages, strong European prose quality, text plus image plus audio input, 128K context. Around 40 to 60+ tok/s on Apple Silicon, so lower latency than the 9B Qwen at similar cleanup quality (https://ollama.com/library/gemma4, https://gemma4-ai.com/blog/gemma4-mac-performance). Best pick if you weight latency over peak quality.
3. **qwen3.5:4b** (3.4 GB). The pure speed option, roughly 60 to 80 tok/s expected. Being two generations ahead, it likely still beats qwen2.5:7b on Italian cleanup while cutting latency roughly in half. Good candidate for an A/B test against the 9b.
4. **ministral-3** 8b (Mistral 3 family, Dec 2025, Apache 2.0). Trained natively on 40+ languages with particular strength in European languages including Italian (https://mistral.ai/news/mistral-3/, https://ollama.com/library/ministral-3). Solid alternative if Qwen's Italian register feels off, comparable speed to qwen3.5:9b.

Optional quality tier on 64 GB: **gemma4:26b** (MoE, 25.2B total but only 3.8B active, 18 GB on disk) gives near-frontier quality at small-model decode speed, overkill for filler removal but viable given the RAM.

Practical notes: keep the model resident with `keep_alive`, disable thinking, and prefer the MLX-tagged variants Ollama now publishes for Apple Silicon.

## 2. ASR: does anything beat Parakeet-TDT 0.6B v3?

Short answer: Parakeet v3 remains the best latency-per-watt choice on a Mac, and a mid-2026 Dictato benchmark on 13,023 recordings found Parakeet is still the best engine specifically for disfluent speech with fillers and restarts, which is exactly dictation (https://dicta.to/blog/speech-to-text-engine-comparison-mac-2026/). NVIDIA has not shipped a multilingual Parakeet v4, its 2026 successors are Nemotron models (https://developer.nvidia.com/blog/nvidia-speech-ai-models-deliver-industry-leading-accuracy-and-performance/).

Contenders that run locally on Apple Silicon:

- **Qwen3-ASR 0.6B / 1.7B** (open weights, MLX ports available). The accuracy upgrade. On LibriSpeech test-clean the 1.7B scores 1.63% WER vs 1.93% for Parakeet-TDT 0.6B, with notably better noise robustness, 30 languages including Italian, language hints, and streaming support. RTF 0.27 (1.7B fp16) or 0.08 (0.6B) on M4 Pro, about 3.4 GB RAM for the 1.7B (https://github.com/moona3k/mlx-qwen3-asr, https://github.com/Blaizzy/mlx-audio). Worth benchmarking against Parakeet v3 on your own Italian audio.
- **Nemotron-3.5-ASR-Streaming-0.6B** (NVIDIA, 2026). The real Parakeet successor: 40 languages, native punctuation and capitalization, configurable latency from 80 ms chunks, already supported in mlx-audio and in the MacParakeet app (https://huggingface.co/nvidia/nemotron-3.5-asr-streaming-0.6b, https://github.com/Blaizzy/mlx-audio). Best candidate if you want true streaming dictation.
- **Voxtral-Mini-4B-Realtime-2602** (Mistral, Feb 2026, Apache 2.0). Realtime transcription under 500 ms delay, 13 languages, MLX support via mlx-audio and voxmlx, but 4B parameters makes it the heaviest option and llama.cpp does not support it yet (https://huggingface.co/mistralai/Voxtral-Mini-4B-Realtime-2602, https://github.com/awni/voxmlx).
- **Apple SpeechAnalyzer** (macOS built-in, not open source): scored 4.0% WER on Italian in the Dictato test, the best on-device Italian number published, worth a fallback path even if it is not open weights.
- Kyutai STT covers English and French only, not useful here. Whisper large-v3-turbo via WhisperKit remains relevant mainly for its vocabulary boosting of proper nouns.

Recommendation: keep Parakeet v3 as default, add Qwen3-ASR 1.7B as a selectable high-accuracy engine, and watch Nemotron-3.5 streaming in mlx-audio.

## 3. Personal voice adaptation (single-speaker fine-tuning)

- **Whisper plus LoRA is the mature recipe.** LoRA trains under 1.6% of parameters and works with modest data (https://aws.amazon.com/blogs/machine-learning/fine-tune-whisper-models-on-amazon-sagemaker-with-lora/). For non-standard or accented speech the gains are large and fast: studies show 30 minutes of speaker audio can take WER from unusable to usable (one dysarthric-speech line went 76.8% to 12.6% WER with 30 minutes, and 30-minute fine-tunes on accented speakers landed at 12 to 15% WER) (https://arxiv.org/html/2506.22810v1). For a mild accent where baseline WER is already under 10%, expect smaller gains, aim for 1 to 5 hours of your own corrected dictations.
- **Parakeet/NeMo fine-tuning is heavier.** NeMo guidance recommends on the order of 100 hours for robust fine-tuning and keeping the pretrained tokenizer below 50 hours, and it is designed around NVIDIA GPUs (https://docs.nvidia.com/nemo/speech/nightly/asr/fine_tuning.html). Not practical for one speaker on a Mac.
- **Closest to turnkey on a Mac: mlx-tune.** It fine-tunes STT models natively on Apple Silicon with LoRA, supporting Whisper, Parakeet TDT, Qwen3-ASR, Canary and Voxtral, 16 GB+ RAM recommended (https://github.com/ARahim3/mlx-tune). It is a Python workflow, not a one-click app, no true turnkey Mac product exists yet.
- **Cheapest wins first:** the app itself can log audio plus your final corrected text, which is the ideal training set over time. Before fine-tuning, try WhisperKit vocabulary boosting or Qwen3-ASR context hints for the personal dictionary, since the LLM cleanup layer already fixes most non-acoustic errors.
