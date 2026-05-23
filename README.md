# ArticleQ — Premium Voice Models

This repository hosts the on-device text-to-speech voice models used
by the ArticleQ iOS / macOS app's premium TTS feature. Model files
are distributed as GitHub Release assets; the app fetches a manifest
from this repository at runtime to discover available voices.

**This repository contains no executable code.** All assets are
passive data files (neural network weights in ONNX format, phoneme
data, voice style embeddings) that the app loads into the
sherpa-onnx inference runtime at playback time. Synthesis happens
entirely on-device — no audio or article text is ever sent to a
remote server.

## How it fits together

```
┌──────────────────────────────────────────────────────────────┐
│  ArticleQ app (iOS / macOS)                                  │
│                                                              │
│  ┌────────────────────────┐    ┌───────────────────────────┐ │
│  │ Bundled VoiceCatalog   │    │ Sherpa-ONNX inference     │ │
│  │ (first launch fallback)│    │ runtime (statically linked│ │
│  └────────────────────────┘    │ in app binary)            │ │
│            │                   └───────────────────────────┘ │
│            ▼                            ▲                    │
│  ┌────────────────────────┐    ┌───────────────────────────┐ │
│  │ VoiceCatalogManager    │    │ PremiumTTSBackend         │ │
│  │ (fetches manifest)     │    │ (loads model + synthesizes│ │
│  └────────────────────────┘    └───────────────────────────┘ │
│            │                                                 │
└────────────┼─────────────────────────────────────────────────┘
             │ HTTPS GET manifest-v1.json + voice files
             ▼
┌──────────────────────────────────────────────────────────────┐
│  This repo (genericgroup/articleq-voice-models)              │
│                                                              │
│  manifests/manifest-v1.json    ← describes available voices  │
│  releases/                                                   │
│    base-en-v1.0/               ← Kokoro arch + tokens +      │
│                                  espeak-ng data (one per     │
│                                  engine version)             │
│    voice-emma-v1.0/            ← per-voice style file        │
│    voice-michael-v1.0/                                       │
│    ...                                                       │
└──────────────────────────────────────────────────────────────┘
```

The app falls back to a **bundled catalog** (compiled into the binary)
if the manifest fetch fails — first launch and offline launch both
resolve a usable catalog without a network round-trip.

The manifest URL the app reads is:

```
https://raw.githubusercontent.com/genericgroup/articleq-voice-models/main/manifests/manifest-v1.json
```

`raw.githubusercontent.com` is fronted by Fastly's CDN, so manifest
fetches are fast. Voice files are served from
`objects.githubusercontent.com` (also Fastly).

## Repository layout

```
manifests/
  manifest-v1.json           Live manifest the production app reads
  manifest-v1-staging.json   Optional staging manifest for QA builds
  archive/                   Historical manifests retained for audit
scripts/
  publish-voice.sh           Bundle a voice file → GH Release + hash
  publish-base.sh            Bundle a shared-base archive → release
docs/
  PUBLISHING.md              Step-by-step procedure for new voices
  ATTRIBUTION.md             Per-voice licensing + dataset attributions
LICENSE                      Apache 2.0
```

## Adding a new voice

See [docs/PUBLISHING.md](docs/PUBLISHING.md) for the full procedure.
Short version:

```bash
# 1. Bundle the voice file
./scripts/publish-voice.sh kokoro-en-bf-emma 1.0 ./kokoro-en-bf-emma-v1.0.bin

# 2. Copy the printed manifest fragment into manifests/manifest-v1.json

# 3. Commit + push
git add manifests/manifest-v1.json
git commit -m "Add Emma voice v1.0"
git push
```

Within ~24 hours every premium ArticleQ user fetches the updated
manifest and sees "Update available" or the new voice as a fresh
Download option — **no App Store release required**.

## Licensing

All voice files and the inference architecture are derived from open
models with permissive licenses:

| Component | License | Source |
|-----------|---------|--------|
| Kokoro architecture + voice weights | Apache 2.0 | https://huggingface.co/hexgrad/Kokoro-82M |
| eSpeak-NG phoneme data | GPL-3.0 (data only, not linked into app code) | https://github.com/espeak-ng/espeak-ng |
| sherpa-onnx inference runtime | Apache 2.0 (statically linked in the ArticleQ app binary, not in this repo) | https://github.com/k2-fsa/sherpa-onnx |

Per-voice attribution lives in [docs/ATTRIBUTION.md](docs/ATTRIBUTION.md).
The ArticleQ app reproduces these attributions in
Settings → About → Acknowledgments.

## Security

- Every voice file in the live manifest carries a SHA-256 hash. The
  ArticleQ app verifies the hash after download and refuses to use a
  file with a mismatch.
- Manifests are served over HTTPS via GitHub's infrastructure.
- The repository is public so the URL chain (manifest → release →
  asset) is fully auditable.

## Not for direct end-user consumption

This repository is meant to be consumed by the ArticleQ app, not
downloaded manually by end users. If you've landed here from a
search result and you want to use these voices: download the
ArticleQ app from the App Store, subscribe to premium, and select a
voice from Settings → TTS → Premium Voices.

If you're a developer interested in Kokoro for your own project,
go to the [original Kokoro repo](https://huggingface.co/hexgrad/Kokoro-82M)
— our files here are repackaged for the ArticleQ install flow and
may not be the format you want.
