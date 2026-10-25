#!/bin/sh
# Renders social-preview.html to social-preview.png (1280 × 640) with headless
# Google Chrome, then writes a 506 × 253 thumbnail (roughly an X/Twitter large
# card) to a temporary directory for checking legibility. Requires macOS and
# Google Chrome; set CHROME to use another Chromium binary.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
chrome=${CHROME:-"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"}
out="$here/social-preview.png"
tmp=${TMPDIR:-/tmp}
scratch=$(mktemp -d "${tmp%/}/lassotext-social-preview-XXXXXX")
trap 'rm -rf "$scratch/profile"' EXIT

if ! "$chrome" --headless=new --disable-gpu --hide-scrollbars \
  --user-data-dir="$scratch/profile" --no-first-run --no-default-browser-check \
  --allow-file-access-from-files \
  --force-device-scale-factor=1 --window-size=1280,640 \
  --default-background-color=03181eff \
  --screenshot="$out" \
  "file://$here/social-preview.html" 2>"$scratch/chrome.log"; then
  cat "$scratch/chrome.log" >&2
  exit 1
fi

thumbnail="$scratch/thumbnail-506x253.png"
sips -Z 506 "$out" --out "$thumbnail" >/dev/null

for f in "$out" "$thumbnail"; do
  printf '%s\n' "$f"
  sips -g pixelWidth -g pixelHeight "$f" | tail -n +2
  printf '  bytes: %s\n' "$(stat -f %z "$f")"
done
