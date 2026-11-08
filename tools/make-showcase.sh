#!/bin/bash
# Renders build/showcase.mp4: each theme in turn on a patch of macOS wallpaper, drawn by the app's own views.
# Usage: tools/make-showcase.sh [wallpaper.heic] [--no-captions] [--4k]
# Writes build/showcase.mp4 at 1080p, or build/showcase-4k.mp4 with --4k.
# Any image works; dynamic HEIC wallpapers use their dark image. Without one, it looks for Ventura Graphic,
# which macOS downloads the first time it is picked in Wallpaper settings.
set -euo pipefail
cd "$(dirname "$0")/.."

wallpaper=""
flags=()
for arg in "$@"; do
  if [[ $arg == --* ]]; then flags+=("$arg"); else wallpaper=$arg; fi
done
if [[ -z $wallpaper ]]; then
  wallpaper=$(find /System/Library/AssetsV2/com_apple_MobileAsset_DesktopPicture -name "Ventura Graphic.heic" 2>/dev/null | head -1)
  [[ -n $wallpaper ]] || { echo "Pass a wallpaper image, or pick Ventura Graphic once in System Settings > Wallpaper." >&2; exit 1; }
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

sources=()
for file in Sources/ClaudeTmuxLights/*.swift; do
  [[ $file == */main.swift ]] || sources+=("$file")
done
swiftc -O "${sources[@]}" tools/showcase/main.swift -o "$work/make-showcase"
output=build/showcase.mp4
for flag in ${flags[@]+"${flags[@]}"}; do [[ $flag == --4k ]] && output=build/showcase-4k.mp4; done
mkdir -p build
"$work/make-showcase" "$wallpaper" "$output" ${flags[@]+"${flags[@]}"}
ls -lh "$output"
