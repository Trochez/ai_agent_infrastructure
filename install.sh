#!/usr/bin/env bash
set -Eeuo pipefail
PAYLOAD_SHA256="629547aee16d83688fe80d774c955945ed63918754d4c71feb6774e7adda2884"
PART_COUNT=6
RAW_BASE="https://raw.githubusercontent.com/Trochez/ai_agent_infrastructure/main/payload.parts"
SELF_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || pwd)"
TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT INT TERM
: > "$TMP/payload.b64"
for i in $(seq 0 $((PART_COUNT-1))); do
  part="$(printf 'part%02d' "$i")"
  if [[ -f "$SELF_DIR/payload.parts/$part" ]]; then
    cat "$SELF_DIR/payload.parts/$part" >> "$TMP/payload.b64"
  else
    command -v curl >/dev/null || { echo "curl is required to download installer payload" >&2; exit 69; }
    curl -fsSL "$RAW_BASE/$part" >> "$TMP/payload.b64"
  fi
done
if command -v base64 >/dev/null 2>&1; then
  base64 -d "$TMP/payload.b64" > "$TMP/payload.tar.gz" 2>/dev/null || base64 -D "$TMP/payload.b64" > "$TMP/payload.tar.gz"
else
  echo "base64 command is required" >&2; exit 69
fi
if command -v sha256sum >/dev/null 2>&1; then ACTUAL="$(sha256sum "$TMP/payload.tar.gz" | awk '{print $1}')"
elif command -v shasum >/dev/null 2>&1; then ACTUAL="$(shasum -a 256 "$TMP/payload.tar.gz" | awk '{print $1}')"
else echo "sha256sum or shasum is required" >&2; exit 69; fi
[[ "$ACTUAL" == "$PAYLOAD_SHA256" ]] || { echo "payload checksum mismatch" >&2; exit 74; }
mkdir -p "$TMP/payload"
tar -xzf "$TMP/payload.tar.gz" -C "$TMP/payload"
bash "$TMP/payload/install.sh" "$@"
exit $?
