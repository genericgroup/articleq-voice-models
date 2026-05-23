#!/usr/bin/env bash
#
# publish-voice.sh — publish a per-voice file to GitHub Releases and
# print the manifest fragment to paste into manifests/manifest-v1.json.
#
# Usage:
#   ./scripts/publish-voice.sh <voice-id> <version> <path-to-file>
#
# Example:
#   ./scripts/publish-voice.sh kokoro-en-bf-emma 1.0 ~/Downloads/emma.bin
#
# What it does:
#   1. Computes SHA-256 + byte size of the file
#   2. Creates a GitHub Release named voice-<short-name>-v<version>
#   3. Uploads the file as a release asset with the canonical name
#      <voice-id>-v<version>.bin
#   4. Prints the cdnURL / sha256 / downloadSizeBytes values that go
#      into the matching VoiceDescriptor in manifests/manifest-v1.json
#
# Requires: gh (authenticated), shasum, stat
#
set -euo pipefail

# --- Args -------------------------------------------------------------

if [[ $# -ne 3 ]]; then
    echo "Usage: $0 <voice-id> <version> <path-to-file>" >&2
    echo "" >&2
    echo "Example:" >&2
    echo "  $0 kokoro-en-bf-emma 1.0 ~/Downloads/emma.bin" >&2
    exit 2
fi

VOICE_ID="$1"
VERSION="$2"
FILE="$3"

if [[ ! -f "$FILE" ]]; then
    echo "Error: file not found: $FILE" >&2
    exit 1
fi

# --- Validate voice-id format -----------------------------------------
# Convention: engine-locale-gendercode-name, e.g. kokoro-en-bf-emma.
# We extract a short-name tag for the GitHub Release (last hyphen
# segment) — e.g. "emma" from "kokoro-en-bf-emma".

if [[ ! "$VOICE_ID" =~ ^kokoro-[a-z]+-[a-z]+-[a-z]+$ ]]; then
    echo "Error: voice-id must match 'kokoro-<locale>-<gendercode>-<name>'" >&2
    echo "       Got: $VOICE_ID" >&2
    exit 1
fi

SHORT_NAME="${VOICE_ID##*-}"
TAG="voice-${SHORT_NAME}-v${VERSION}"
ASSET_NAME="${VOICE_ID}-v${VERSION}.bin"

# --- Compute hash + size ----------------------------------------------

echo "→ Computing SHA-256 for $(basename "$FILE")…"
SHA=$(shasum -a 256 "$FILE" | awk '{print $1}')
SIZE=$(stat -f%z "$FILE" 2>/dev/null || stat -c%s "$FILE")  # macOS / Linux
echo "  SHA-256: $SHA"
echo "  Bytes:   $SIZE"

# --- Stage file under its canonical asset name ------------------------
# `gh release upload` uses the local filename as the asset name, so
# we copy the file to a temp location with the canonical name first.

TMPDIR=$(mktemp -d)
trap "rm -rf '$TMPDIR'" EXIT
STAGED="$TMPDIR/$ASSET_NAME"
cp "$FILE" "$STAGED"

# --- Create GitHub Release --------------------------------------------

if gh release view "$TAG" >/dev/null 2>&1; then
    echo "→ Release $TAG already exists — uploading additional asset"
    gh release upload "$TAG" "$STAGED" --clobber
else
    echo "→ Creating GitHub Release $TAG…"
    gh release create "$TAG" "$STAGED" \
        --title "$(echo "${SHORT_NAME:0:1}" | tr '[:lower:]' '[:upper:]')${SHORT_NAME:1} voice v${VERSION}" \
        --notes "Voice file for ArticleQ Premium TTS.

Voice ID: \`$VOICE_ID\`
Version: $VERSION
SHA-256: \`$SHA\`
Size: $SIZE bytes

See [docs/PUBLISHING.md](../docs/PUBLISHING.md) for the publish workflow."
fi

CDN_URL="https://github.com/genericgroup/articleq-voice-models/releases/download/${TAG}/${ASSET_NAME}"

# --- Print the manifest fragment --------------------------------------

cat <<EOF

═══════════════════════════════════════════════════════════════════
✓ Published $VOICE_ID v$VERSION

Manifest fragment — paste these three fields into the matching
VoiceDescriptor in manifests/manifest-v1.json:

  "cdnURL":           "$CDN_URL"
  "sha256":           "$SHA"
  "downloadSizeBytes": $SIZE

Don't forget to bump "manifestVersion" at the top of the manifest
to a fresh stamp (e.g. \$(date +%Y.%m.%d-1)).

═══════════════════════════════════════════════════════════════════
EOF
