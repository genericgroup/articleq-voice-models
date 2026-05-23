#!/usr/bin/env bash
#
# publish-base.sh — publish a shared-base archive to GitHub Releases.
#
# A "shared base" carries the resources every voice using a given
# engine needs: the model architecture weights, tokens file, and
# espeak-ng phoneme data. ~120 MB compressed for Kokoro v1.0.
#
# Archive format: AppleArchive .aar (LZFSE compressed). Chosen over
# .tar.zst because Apple's `Compression` framework can extract .aar
# natively (`AppleArchive` framework, iOS 14+ / macOS 11+) with no
# third-party Swift dependency. Produce one from a directory with:
#
#   aa archive -d <base-id>-v<version>/ -o <base-id>-v<version>.aar -a lzfse
#
# Usage:
#   ./scripts/publish-base.sh <base-id> <version> <path-to-archive>
#
# Example:
#   ./scripts/publish-base.sh kokoro-en-base 1.0 ~/work/kokoro-en-base-v1.0.aar
#
# What it does:
#   1. Computes SHA-256 + byte size of the archive
#   2. Creates a GitHub Release named base-<short-name>-v<version>
#   3. Uploads the archive as a release asset with the canonical name
#      <base-id>-v<version>.tar.zst
#   4. Prints the cdnURL / sha256 / downloadSizeBytes values for the
#      matching SharedBaseDescriptor in manifests/manifest-v1.json
#
# Requires: gh (authenticated), shasum, stat
#
set -euo pipefail

# --- Args -------------------------------------------------------------

if [[ $# -ne 3 ]]; then
    echo "Usage: $0 <base-id> <version> <path-to-archive>" >&2
    echo "" >&2
    echo "Example:" >&2
    echo "  $0 kokoro-en-base 1.0 ~/work/kokoro-en-base.tar.zst" >&2
    exit 2
fi

BASE_ID="$1"
VERSION="$2"
FILE="$3"

if [[ ! -f "$FILE" ]]; then
    echo "Error: file not found: $FILE" >&2
    exit 1
fi

if [[ ! "$BASE_ID" =~ ^kokoro-[a-z]+-base$ ]]; then
    echo "Error: base-id must match 'kokoro-<locale>-base' (e.g. kokoro-en-base)" >&2
    echo "       Got: $BASE_ID" >&2
    exit 1
fi

# Extract the locale segment for the short release tag.
LOCALE="${BASE_ID#kokoro-}"
LOCALE="${LOCALE%-base}"
TAG="base-${LOCALE}-v${VERSION}"
ASSET_NAME="${BASE_ID}-v${VERSION}.aar"

# --- Compute hash + size ----------------------------------------------

echo "→ Computing SHA-256 for $(basename "$FILE")…"
SHA=$(shasum -a 256 "$FILE" | awk '{print $1}')
SIZE=$(stat -f%z "$FILE" 2>/dev/null || stat -c%s "$FILE")
echo "  SHA-256: $SHA"
echo "  Bytes:   $SIZE"

# --- Stage with canonical name ----------------------------------------

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
        --title "Kokoro $(echo "$LOCALE" | tr '[:lower:]' '[:upper:]') shared base v${VERSION}" \
        --notes "Shared resource pack for the Kokoro TTS engine ($LOCALE locale).

This archive contains the model architecture weights, tokens file,
and espeak-ng phoneme data referenced by every voice with
\`sharedBaseId: \\\"$BASE_ID-v$VERSION\\\"\`.

Base ID: \`$BASE_ID\`
Version: $VERSION
SHA-256: \`$SHA\`
Size: $SIZE bytes

See [docs/PUBLISHING.md](../docs/PUBLISHING.md) for the publish workflow."
fi

CDN_URL="https://github.com/genericgroup/articleq-voice-models/releases/download/${TAG}/${ASSET_NAME}"

cat <<EOF

═══════════════════════════════════════════════════════════════════
✓ Published $BASE_ID v$VERSION

Manifest fragment — paste these three fields into the matching
SharedBaseDescriptor in manifests/manifest-v1.json:

  "cdnURL":           "$CDN_URL"
  "sha256":           "$SHA"
  "downloadSizeBytes": $SIZE

Don't forget to bump "manifestVersion" at the top of the manifest
to a fresh stamp (e.g. \$(date +%Y.%m.%d-1)).

═══════════════════════════════════════════════════════════════════
EOF
