#!/bin/bash
# Renders the themes in turn on a patch of macOS wallpaper, drawn by the app's own views.
# Usage: tools/make-showcase.sh [wallpaper image] [--no-captions] [--4k | --readme]
#   build/showcase.mp4      1920x1080 video (the default)
#   build/showcase-4k.mp4   3840x2160 video, with --4k
#   docs/demo.gif           the 1038x300 strip at the top of the README, with --readme (needs ffmpeg)
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

mode=video
for flag in ${flags[@]+"${flags[@]}"}; do
  case $flag in
    --4k) mode=4k ;;
    --readme) mode=readme ;;
  esac
done
if [[ $mode == readme ]] && ! command -v ffmpeg >/dev/null; then
  echo "--readme needs ffmpeg to make the GIF: brew install ffmpeg" >&2
  exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

sources=()
for file in Sources/ClaudeTmuxLights/*.swift; do
  [[ $file == */main.swift ]] || sources+=("$file")
done
swiftc -O "${sources[@]}" tools/showcase/main.swift -o "$work/make-showcase"

case $mode in
  video) output=build/showcase.mp4 ;;
  4k) output=build/showcase-4k.mp4 ;;
  readme) output=$work/strip.mp4 ;;
esac
mkdir -p build
"$work/make-showcase" "$wallpaper" "$output" ${flags[@]+"${flags[@]}"} | grep -v '^frame'

if [[ $mode == readme ]]; then
  # Ordered dithering keeps the wallpaper's gradients smooth and the file far smaller than error diffusion.
  ffmpeg -v error -y -i "$output" \
    -vf "split[a][b];[a]palettegen=max_colors=256:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" \
    -loop 0 docs/demo.gif
  output=docs/demo.gif
fi
ls -lh "$output"
