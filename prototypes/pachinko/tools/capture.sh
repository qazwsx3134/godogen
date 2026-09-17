#!/usr/bin/env bash
# 影格擷取。用法：tools/capture.sh <輸出目錄> [影格數] [-- 傳給遊戲的參數...]
#
# macOS 上 `--headless` 加 `--write-movie` 會 crash（MoltenVK 的 SPIRV 轉換炸掉），
# 所以**一定要有視窗**。會搶 focus 幾秒，這是已知代價。
# renderer 固定用 gl_compatibility，因為那才是 M1 定下的效能地板。
set -euo pipefail

GODOT=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT=${1:?用法: capture.sh <輸出目錄> [影格數] [-- 遊戲參數...]}
FRAMES=${2:-165}
shift 2 || shift 1 || true
[ "${1:-}" = "--" ] && shift || true

mkdir -p "$OUT"
rm -f "$OUT"/f*.png "$OUT"/f.wav
"$GODOT" --path "$ROOT" --rendering-method gl_compatibility \
	--write-movie "$OUT/f.png" --fixed-fps 30 --quit-after "$FRAMES" -- "$@"

if command -v ffmpeg >/dev/null; then
	ffmpeg -y -v error -framerate 30 -pattern_type glob -i "$OUT/f*.png" \
		-c:v libx264 -pix_fmt yuv420p -movflags +faststart "$OUT/video.mp4"
	echo "==> $OUT/video.mp4"
fi
