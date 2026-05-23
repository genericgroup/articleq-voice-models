# Publishing voices

Step-by-step procedure for publishing a new voice (or a new version
of an existing voice) to the ArticleQ premium voice catalog.

## Prerequisites

- `gh` CLI authenticated with `repo` scope (run `gh auth status` to
  verify — should show `repo` in the token scopes)
- Write access to the `genericgroup/articleq-voice-models` repo
- A built voice file (typically `<voice-id>-v<version>.bin` for a
  per-voice file or `<base-id>-v<version>.tar.zst` for a shared base)

## Procedure for a new voice (per-voice file only)

Use this when the shared base for this engine version has already
been published and you're just adding another voice that references it.

```bash
# From the repo root.
./scripts/publish-voice.sh kokoro-en-bf-emma 1.0 ~/Downloads/emma.bin
```

The script will:

1. Compute the file's SHA-256 hash and byte size
2. Create a GitHub Release tagged `voice-emma-v1.0`
3. Upload the file as a release asset
4. Print the three values you need to paste into `manifests/manifest-v1.json`:
   - `cdnURL`
   - `sha256`
   - `downloadSizeBytes`

Then:

5. Open `manifests/manifest-v1.json`
6. Find the voice's `VoiceDescriptor` entry (or add a new one if it's
   a fresh voice — copy the structure from `docs/example-manifest-when-populated.json`)
7. Paste the three values
8. Bump `manifestVersion` to today's date (e.g. `"2026.05.22-1"`)
9. Commit + push:
   ```bash
   git add manifests/manifest-v1.json
   git commit -m "Publish Emma voice v1.0"
   git push
   ```

Within ~24 hours all premium ArticleQ users see "Update available" on
their next manifest refresh (or `Download` for fresh voices).

## Procedure for a new shared base

The shared base contains the architecture weights, tokens, and
espeak-ng data — the ~95 MB resource pack every voice using this
engine version shares.

```bash
./scripts/publish-base.sh kokoro-en-base 1.0 ~/work/kokoro-en-base.tar.zst
```

Then edit `manifests/manifest-v1.json` and paste the values into the
matching `SharedBaseDescriptor` entry under `sharedBases[]`.

A new shared base typically lands together with the first voice that
uses it — publish the base first, then publish the voice, then update
the manifest with both fragments in the same commit.

## Procedure for updating an existing voice

When a voice is retrained or otherwise updated:

1. **Bump the version** in the filename and the manifest's
   `engineVersion` field. v1.0 → v1.1, etc. Never reuse a version
   number — once a file is published with a given version it's
   immutable.
2. Run `publish-voice.sh` with the new version. This creates a new
   Release tag (e.g. `voice-emma-v1.1`) without affecting the v1.0
   Release.
3. Update the matching `VoiceDescriptor`'s `engineVersion`, `cdnURL`,
   `sha256`, and `downloadSizeBytes` in the manifest.
4. Bump `manifestVersion`.
5. Commit + push.

The ArticleQ app's `VoiceInstallManager` detects the version change
on next manifest refresh and surfaces "Update available" to users.
Their currently-installed v1.0 file stays usable until the v1.1
update is verified-and-moved, so a partial update never breaks
playback.

## First-time bootstrap

The repository starts with an **empty manifest** and
`featureFlags.premiumTTSEnabled: false`. This is intentional — until
real voice files exist, we don't want the ArticleQ app to surface
the feature.

To bring the feature online for the first time:

1. Build / obtain the Kokoro shared base archive (model.onnx + tokens
   + espeak-ng-data, tar-zstd-compressed)
2. Publish the shared base: `./scripts/publish-base.sh kokoro-en-base 1.0 <path>`
3. Build / obtain the first voice file (Emma)
4. Publish Emma: `./scripts/publish-voice.sh kokoro-en-bf-emma 1.0 <path>`
5. Edit `manifests/manifest-v1.json`:
   - Flip `featureFlags.premiumTTSEnabled` to `true`
   - Add the SharedBaseDescriptor + VoiceDescriptor from the printed fragments
   - Bump `manifestVersion`
6. Commit + push

At this point premium ArticleQ users see Emma as a downloadable voice.

## Manifest schema reference

See `docs/example-manifest-when-populated.json` for a fully-populated
sample. Key invariants the ArticleQ app's `VoiceCatalogManager`
enforces:

- `schemaVersion` MUST be ≤ the app's `VoiceCatalog.maxSupportedSchemaVersion`
  (currently `1`). Higher schema versions are ignored by older app
  builds — they fall back to the bundled catalog.
- `manifestVersion` is opaque; the app uses it for "is this newer
  than what I last refreshed?" comparison.
- `featureFlags.premiumTTSEnabled` — master kill switch. False means
  the app falls back to the system V2 voice with a toast even when
  the user has a premium voice selected.
- `voices[].engineVersion` — bumped when the voice file's binary
  format changes such that an older app build can't load it.
- `voices[].availabilityFloor` — optional `Int`. If set, the voice
  only appears in clients whose app `CFBundleVersion` is ≥ this
  number. Use this to ship a voice that requires a newer sherpa-onnx
  framework without breaking older clients.

## Staging vs production

`manifests/manifest-v1-staging.json` is an OPTIONAL parallel manifest
that DEBUG builds (or TestFlight) can read instead of the production
manifest. Use it when you want to QA a new voice on internal builds
before exposing it to production users.

To activate the staging manifest in the ArticleQ app, edit
`AppConstants.voiceCatalogManifestURL` to point at the `-staging`
file, build a DEBUG variant, and test. Don't ship the staging URL
to production.

## Archive

Old manifests can be moved to `manifests/archive/` for auditability
when significant changes ship — historical record of what was live at
what time. Not required, but useful when investigating "what voice did
user X have access to on 2026-Q3?"
