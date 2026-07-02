# OpenFlow

A fully local, on-device voice dictation app for macOS — a free alternative to
Wispr Flow. Hold a hotkey, speak, release: your words are transcribed on your
Mac's Neural Engine and typed into whatever app has focus. **No cloud, no
subscription, no audio ever leaves your machine.**

## How it works

```
hold ⌥Space ─▶ mic capture ─▶ Parakeet-TDT ASR (on-device, ANE)
 (release)                        │
                                  ▼
                   cleanup (fillers, custom dictionary)
                                  │
                                  ▼
                paste/type into the focused app at your cursor
```

- **ASR:** [NVIDIA Parakeet-TDT 0.6B](https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v3-coreml)
  via [FluidAudio](https://github.com/FluidInference/FluidAudio) (CoreML on the
  Apple Neural Engine). v3 = 25 European languages; v2 = English-only.
- **Cleanup:** deterministic rules — filler-word removal ("um", "uh"),
  accidental-repeat collapse, and a custom dictionary for names/jargon. No LLM,
  no hallucination.
- **Injection:** clipboard + synthesized ⌘V (with clipboard restore), or a
  type-it-out mode for paste-blocked fields.

## Requirements

- macOS 14+ on Apple Silicon
- ~1.5 GB disk for the speech model (downloaded once on first launch)

## Build & run

```bash
scripts/build_app.sh
open build/OpenFlow.app
```

First launch walks you through granting **Microphone** and **Accessibility**
permissions and downloads the speech model (~1 GB, one time).

> Dev note: ad-hoc-signed builds get a new code-signing identity each rebuild,
> so macOS will ask you to re-grant Accessibility after rebuilding. This
> stops once the app is Developer-ID signed.

### Headless ASR smoke test

```bash
swift build
.build/debug/OpenFlow --transcribe /path/to/audio.wav
```

### Tests

```bash
swift test
```

## Settings

- Push-to-talk hotkey (default: hold ⌥ Option+Space)
- Filler-word removal on/off
- Custom dictionary (e.g. "super base" → "Supabase")
- Paste vs type-out insertion, clipboard restore
- Parakeet v3 (multilingual) vs v2 (English-only)
- Launch at login

## License & attribution

MIT — see [LICENSE](LICENSE).

Speech recognition uses NVIDIA **Parakeet-TDT** model weights
([CC-BY-4.0](https://creativecommons.org/licenses/by/4.0/)), converted to
CoreML and served by [FluidAudio](https://github.com/FluidInference/FluidAudio)
(MIT). Global hotkey via
[KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) (MIT).
