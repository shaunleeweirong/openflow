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
              cleanup — rules + optional on-device AI (macOS 26)
                                  │
                                  ▼
                paste/type into the focused app at your cursor
```

- **ASR:** [NVIDIA Parakeet-TDT 0.6B](https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v3-coreml)
  via [FluidAudio](https://github.com/FluidInference/FluidAudio) (CoreML on the
  Apple Neural Engine). v3 = 25 European languages; v2 = English-only.
- **Cleanup:** deterministic rules — filler-word removal ("um", "uh"),
  accidental-repeat collapse, and a custom dictionary for names/jargon.
- **AI cleanup (optional, macOS 26 + Apple Intelligence):** an on-device pass via
  Apple Foundation Models fixes grammar, punctuation, and fillers while preserving
  your wording, names, and numbers — nothing leaves your Mac. Always falls back to
  the deterministic rules on any failure or timeout, so you still get instant text.
  Toggle in Settings; hidden when unavailable.
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
2. Launch it — the app is **Developer-ID signed and notarized by Apple**, so it
   opens with no Gatekeeper warning.
3. Grant **Microphone** and **Accessibility** when prompted; the speech model
   (~1 GB) downloads once on first launch (needs internet), then runs offline.

## Build & run

```bash
scripts/build_app.sh
open build/OpenFlow.app
```

First launch walks you through granting **Microphone** and **Accessibility**
permissions and downloads the speech model (~1 GB, one time).

> Dev note: `build_app.sh` signs with the first code-signing identity it finds
> (e.g. your "Apple Development" cert), so macOS keeps your Accessibility grant
> across rebuilds. With no identity it falls back to ad-hoc, which resets the
> grant on every rebuild.

## Cutting a release (maintainers)

`scripts/release.sh` builds a **Developer-ID signed, notarized, stapled** DMG, so
recipients download and double-click with no Gatekeeper warning:

```bash
scripts/release.sh                                     # → build/OpenFlow-0.1.0.dmg
gh release create v0.1.0 build/OpenFlow-0.1.0.dmg \
  --title "OpenFlow 0.1.0" --notes "See install steps in the README."
```

One-time setup (needs a paid Apple Developer account):

1. Create a **Developer ID Application** certificate (Xcode → Settings → Accounts →
   Manage Certificates → **+** → Developer ID Application).
2. Store notarization credentials as a keychain profile named `openflow-notary`:
   ```bash
   xcrun notarytool store-credentials "openflow-notary" \
     --apple-id you@example.com --team-id YOURTEAMID
   ```
   (prompts for an [app-specific password](https://support.apple.com/102654)).

`scripts/make_dmg.sh` still exists for a quick **unsigned** local DMG (recipients
would have to bypass Gatekeeper manually).

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
- AI cleanup (on-device) on/off — macOS 26 + Apple Intelligence
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
