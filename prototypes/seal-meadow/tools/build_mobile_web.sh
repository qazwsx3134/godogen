#!/usr/bin/env bash
# Build the ETC2-only mobile candidate. The regular Web preset remains available for desktop compatibility.
set -euo pipefail
project="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
kit="$project/../godot-kit/tools/web"
godot="${GODOT_BIN:-godot}"
out="$project/build/mobile-web"
mkdir -p "$out"
touch "$project/build/.gdignore"
"$godot" --headless --path "$project" --editor --quit
"$godot" --headless --path "$project" --export-release "Mobile Web" "$out/index.html"
python3 "$kit/patch_idbfs.py" "$out/index.js"
python3 "$kit/pck_size.py" "$out/index.pck" | sed -n '1,6p'
(cd "$out" && python3 -m zipfile -c ../seal-meadow-mobile-web.zip index.html index.js index.pck index.wasm index.png index.icon.png index.apple-touch-icon.png index.audio.worklet.js index.audio.position.worklet.js)
echo "Mobile candidate: $project/build/seal-meadow-mobile-web.zip"
