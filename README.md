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

## Install

Download the latest **`OpenFlow-*.dmg`** from the
[**Releases page**](https://github.com/shaunleeweirong/openflow/releases/latest) —
no source checkout or Xcode needed:

1. Open the `.dmg` and drag **OpenFlow** into **Applications**.
2. First open is blocked by Gatekeeper (the app is ad-hoc signed, not notarized).
   Bypass it once via **System Settings → Privacy & Security → Open Anyway**, or
   from Terminal:
   ```bash
   xattr -dr com.apple.quarantine /Applications/OpenFlow.app
   ```
3. Grant **Microphone** and **Accessibility** when prompted; the speech model
   (~1 GB) downloads once on first launch (needs internet), then runs offline.

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

## Cutting a release (maintainers)

Package the app into a disk image and publish it to GitHub Releases so people can
[install it](#install) without building from source:

```bash
scripts/make_dmg.sh                                    # → build/OpenFlow-0.1.0.dmg
gh release create v0.1.0 build/OpenFlow-0.1.0.dmg \
  --title "OpenFlow 0.1.0" --notes "See install steps in the README."
```

`make_dmg.sh` builds a fresh release app and wraps it in a drag-to-Applications
DMG using only the built-in `hdiutil` — no extra tooling.

> Note: the DMG is ad-hoc signed (not notarized), so each new release gets a new
> signature and users must re-grant Accessibility after updating. Developer-ID
> signing + notarization (paid Apple Developer account) removes both the
> Gatekeeper prompt and the re-grant.

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
