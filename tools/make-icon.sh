#!/bin/bash
# Regenerates Resources/AppIcon.icns from the app's own lamp drawing code.
set -euo pipefail
cd "$(dirname "$0")/.."

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

sources=()
for file in Sources/ClaudeTmuxLights/*.swift; do
  [[ $file == */main.swift ]] || sources+=("$file")
done
swiftc -O "${sources[@]}" tools/icon/main.swift -o "$work/make-icon"
"$work/make-icon" "$work/icon-1024.png"

iconset="$work/AppIcon.iconset"
mkdir "$iconset"
for size in 16 32 128 256 512; do
  sips -z $size $size "$work/icon-1024.png" --out "$iconset/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) "$work/icon-1024.png" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o Resources/AppIcon.icns
echo "Wrote Resources/AppIcon.icns"
