#!/bin/bash
# dgist-6g: put our sources into an Aerial 25-3 SDK checkout. Idempotent.
#   scripts/apply_overlay.sh [SDK_DIR]      (default: AERIAL_SDK_DIR from .env, or /opt/nvidia/cuBB inside the container)
# 1. aerial/   = our own files at SDK-relative paths (cuPHY-CP/dapp_hook/...), copied over
# 2. patches/  = the changes to NVIDIA's files (Apache-2.0 sources: cuphycontroller, cuphydriver, l2 adapters, testMAC, RU emulator,
#                phase-4 scripts), applied with git or patch; a marker file records the applied patch checksum
set -eu
D=$(cd "$(dirname "$0")/.." && pwd)
SDK=${1:-${AERIAL_SDK_DIR:-}}
[ -z "$SDK" ] && [ -f "$D/.env" ] && SDK=$(grep -E '^AERIAL_SDK_DIR=' "$D/.env" | head -1 | cut -d= -f2 | awk '{print $1}')
[ -z "$SDK" ] && [ -d /opt/nvidia/cuBB ] && SDK=/opt/nvidia/cuBB
[ -d "$SDK/cuPHY-CP/cuphydriver" ] || { echo "not an Aerial SDK checkout: '$SDK'"; exit 1; }
PATCH=$D/patches/aerial-25-3-dgist.patch; SUM=$(sha256sum "$PATCH" | cut -c1-16); MARK=$SDK/.dgist-6g-overlay
echo "== dgist-6g overlay -> $SDK"
cp -a "$D/aerial/." "$SDK/"
echo "   sources copied (cuPHY-CP/dapp_hook)"
if [ -f "$MARK" ] && grep -q "$SUM" "$MARK"; then
  echo "   patch $SUM already applied"
else
  if git -C "$SDK" rev-parse --is-inside-work-tree > /dev/null 2>&1 && git -C "$SDK" apply --check "$PATCH" 2>/dev/null; then
    git -C "$SDK" apply "$PATCH"; echo "   patch applied with git apply"
  elif command -v patch > /dev/null && (cd "$SDK" && patch -p1 --dry-run -N -s < "$PATCH" > /dev/null 2>&1); then
    (cd "$SDK" && patch -p1 -N -s < "$PATCH"); echo "   patch applied with patch -p1"
  elif git -C "$SDK" apply --reverse --check "$PATCH" 2>/dev/null; then
    echo "   patch already present in the tree (reverse check passed)"
  else
    echo "!! the patch does not apply cleanly to $SDK (is it the Aerial 25-3 release tree, or already partially patched?)"; echo "   inspect with: git -C $SDK apply --check $D/patches/aerial-25-3-dgist.patch"; exit 1
  fi
  echo "aerial-25-3-dgist.patch $SUM $(date -u +%FT%TZ)" > "$MARK"
fi
echo "== done. Build with: docker compose --profile tools run --rm build"
