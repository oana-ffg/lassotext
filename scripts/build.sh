#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${1:-release}"
case "$configuration" in debug|release) ;; *) echo "Usage: $0 [debug|release]" >&2; exit 2 ;; esac
swift build -c "$configuration"
bin_dir="$(swift build -c "$configuration" --show-bin-path)"
app="$PWD/dist/LassoText.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_dir/LassoText" "$app/Contents/MacOS/LassoText"
cp Resources/Info.plist "$app/Contents/Info.plist"
swift scripts/make-icon.swift Resources/LassoText.png "$app/Contents/Resources/AppIcon.icns"
# Sign locally by default; public distribution also needs a Developer ID and notarization.
codesign --force --sign "${CODE_SIGN_IDENTITY:--}" "$app"
codesign --verify --strict "$app"
echo "Built $app"
