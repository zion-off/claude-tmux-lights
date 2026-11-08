#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
app=build/ClaudeTmuxLights.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/ClaudeTmuxLights" "$app/Contents/MacOS/"
cp Resources/Info.plist "$app/Contents/"
cp server/claude_traffic.py "$app/Contents/Resources/"
cp Resources/AppIcon.icns "$app/Contents/Resources/"
codesign --force --sign - "$app"
echo "$PWD/$app"
