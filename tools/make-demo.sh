#!/bin/bash
# Regenerates docs/demo.gif by rendering the app's own panel view (not a screen recording).
# Uses ffmpeg for a smoother GIF when it is installed, and falls back to the built-in encoder.
set -euo pipefail
cd "$(dirname "$0")/.."

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

sources=()
for file in Sources/ClaudeTmuxLights/*.swift; do
  [[ $file == */main.swift ]] || sources+=("$file")
done
swiftc -O "${sources[@]}" tools/demo/main.swift -o "$work/make-demo"
mkdir -p docs "$work/frames"
"$work/make-demo" docs "$work/frames"

if command -v ffmpeg >/dev/null; then
  ffmpeg -v error -y -framerate 15 -i "$work/frames/frame-%03d.png" \
    -vf "split[a][b];[a]palettegen=max_colors=256:stats_mode=full[p];[b][p]paletteuse=dither=sierra2_4a" \
    -loop 0 docs/demo.gif
fi
ls -lh docs/demo.gif
