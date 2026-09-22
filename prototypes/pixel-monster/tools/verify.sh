#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
engine="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
if [[ ! -x "$engine" ]]; then
  engine="$(command -v godot || command -v godot4)"
fi

run_godot() {
  local log_path="$1"
  shift
  "$engine" --headless --path "$project_dir" --log-file "$log_path" "$@"
  # Godot can return zero after a script fails to load. Check its diagnostics
  # as well as the process status so a broken suite cannot appear green in CI.
  python3 - "$log_path" <<'PY'
import pathlib
import re
import sys

log = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
if re.search(r"SCRIPT ERROR:|Parse Error:|Failed to load script|Error loading resource", log):
    raise SystemExit("Godot script/resource error: " + sys.argv[1])
PY
}

# A fresh clone has no .godot import cache (fonts, icons, script class index).
run_godot /tmp/pixel-monster-import.log --editor --quit
for suite in care steps_save battle; do
  run_godot "/tmp/pixel-monster-${suite}.log" --script "res://tests/test_${suite}.gd"
done
run_godot /tmp/pixel-monster-flow.log --script res://tests/test_flow.gd \
  -- --save-path=/tmp/pixel-monster-test-flow.json
run_godot /tmp/pixel-monster-release-flow.log --script res://tests/test_flow.gd \
  -- --release-simulation \
  --save-path=/tmp/pixel-monster-test-release.json
