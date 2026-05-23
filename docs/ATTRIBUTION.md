# Attribution & Licensing

This document records the per-asset attribution required by the
upstream licenses governing the models and data hosted in this
repository. The ArticleQ app reproduces these attributions in
**Settings → About → Acknowledgments**.

## Kokoro architecture + voice weights

- **Source:** https://huggingface.co/hexgrad/Kokoro-82M
- **License:** Apache 2.0
- **Author:** hexgrad
- **What we use:** The 82M-parameter TTS architecture (`model.onnx`)
  and the official voice style files (`voices.bin` entries for
  `af_*`, `am_*`, `bf_*`, `bm_*` American/British male/female voices).
- **Attribution required:** Yes — Apache 2.0 §4(c) requires us to
  retain the original copyright notice. The ArticleQ
  Acknowledgments screen credits "Kokoro by hexgrad" with a link to
  the Hugging Face repo.

## eSpeak-NG phoneme data

- **Source:** https://github.com/espeak-ng/espeak-ng
- **License:** GPL-3.0
- **What we use:** The `espeak-ng-data/` directory tree — phoneme
  rules and language data tables loaded at runtime by Kokoro's
  G2P pipeline.
- **GPL interaction:** GPL-3.0 applies to derivative works of the
  code, not to data files used as runtime input. The eSpeak-NG data
  is loaded by the sherpa-onnx inference runtime as opaque input;
  the ArticleQ app's Swift / Objective-C source code is not a
  derivative work of eSpeak-NG and is not subject to GPL-3.0.
- **Attribution required:** Yes — the GPL-3.0 NOTICE and the
  eSpeak-NG attribution are reproduced in the Acknowledgments
  screen with a link to the upstream repo.

## sherpa-onnx inference runtime

- **Source:** https://github.com/k2-fsa/sherpa-onnx
- **License:** Apache 2.0
- **Note:** sherpa-onnx is statically linked into the ArticleQ app
  binary via SPM — it is NOT distributed through this voice-models
  repository. Listed here for completeness of the on-device TTS
  attribution chain.

## Voice training data

The Kokoro voices were trained on public datasets including:

- **LibriTTS** — https://www.openslr.org/60/ — license: CC BY 4.0
- **LJSpeech** — https://keithito.com/LJ-Speech-Dataset/ — public
  domain
- **HiFi-TTS** — https://www.openslr.org/109/ — license: CC BY 4.0

(See the upstream Kokoro README for the full data list.)

These dataset licenses do not require per-voice attribution in the
deploying app, but the ArticleQ Acknowledgments screen credits them
generically as "Kokoro voices trained on open speech datasets
including LibriTTS, LJSpeech, and HiFi-TTS."

## Compliance checklist

Before each App Store submission that touches the premium TTS
feature, confirm:

- [ ] Settings → About → Acknowledgments still lists Kokoro / eSpeak-NG
      / sherpa-onnx with valid URLs
- [ ] This repository's `LICENSE` file is present
- [ ] This repository's README.md links to the Kokoro Hugging Face
      page and to the upstream license texts
- [ ] No voice file added to a Release has a license incompatible
      with Apache 2.0 distribution (e.g. CC BY-NC, proprietary)
