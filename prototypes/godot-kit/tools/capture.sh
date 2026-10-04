#!/usr/bin/env bash
# Records a video of a Godot project:
#   godot-kit/tools/capture.sh <project dir> <output dir> [frames] [-- game args, e.g. --autoplay --room=5]
# It opens a window (it needs a display; macOS crashes on --headless with --write-movie, and without a window there is
# no renderer to record). Frames are written at the project's own viewport size whatever --resolution says, at a fixed
# 30 fps, as <output dir>/f*.png plus f.wav; with ffmpeg installed they are also made into video.mp4.
# On macOS a window covered by another window stops updating, hence --always-on-top. Environment: GODOT_BIN (default `godot`).
set -euo pipefail
GODOT_BIN=${GODOT_BIN:-godot}
[ $# -ge 2 ] || { echo "usage: capture.sh <project dir> <output dir> [frames] [-- game args...]" >&2; exit 2; }
project="$(cd "$1" && pwd)"
out="$2"
shift 2
frames=300
if [ $# -gt 0 ] && [ "$1" != "--" ]; then frames="$1"; shift; fi
[ "${1:-}" = "--" ] && shift

mkdir -p "$out"
rm -f "$out"/f*.png "$out"/f.wav
"$GODOT_BIN" --path "$project" --rendering-method gl_compatibility --resolution 540x960 --always-on-top \
	--write-movie "$out/f.png" --fixed-fps 30 --quit-after "$frames" -- "$@"

if command -v ffmpeg >/dev/null; then
	ffmpeg -y -v error -framerate 30 -pattern_type glob -i "$out/f*.png" \
		$( [ -f "$out/f.wav" ] && echo "-i $out/f.wav" ) \
		-c:v libx264 -pix_fmt yuv420p -movflags +faststart "$out/video.mp4"
	echo "==> $out/video.mp4"
fi
