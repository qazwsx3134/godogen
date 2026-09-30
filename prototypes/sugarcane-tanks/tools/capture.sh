#!/usr/bin/env bash
# 錄影：tools/capture.sh <輸出目錄> [影格數] [-- 遊戲參數，例如 --autoplay --room=5]
# macOS 上 --headless 搭配 --write-movie 會 crash，所以會開一個視窗錄（會短暫搶 focus）。
set -euo pipefail

GODOT_BIN=${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT=${1:?用法: capture.sh <輸出目錄> [影格數] [-- 遊戲參數...]}
FRAMES=${2:-300}
shift 2 || shift 1 || true
[ "${1:-}" = "--" ] && shift || true

mkdir -p "$OUT"
rm -f "$OUT"/f*.png "$OUT"/f.wav
"$GODOT_BIN" --path "$ROOT" --rendering-method gl_compatibility --resolution 540x960 --always-on-top \
	--write-movie "$OUT/f.png" --fixed-fps 30 --quit-after "$FRAMES" -- "$@"

if command -v ffmpeg >/dev/null; then
	ffmpeg -y -v error -framerate 30 -pattern_type glob -i "$OUT/f*.png" \
		$( [ -f "$OUT/f.wav" ] && echo "-i $OUT/f.wav" ) \
		-c:v libx264 -pix_fmt yuv420p -movflags +faststart "$OUT/video.mp4"
	echo "==> $OUT/video.mp4"
fi
