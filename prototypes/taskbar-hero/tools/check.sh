#!/usr/bin/env bash
# Runs real scene/domain checks with isolated saves and rejects Godot script errors.
set -eu
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
check_dir="$(mktemp -d /tmp/taskbar-check.XXXXXX)"
failed=0
for suite in progression_v2 save_v2 save_recovery ui_v2 playable waves soak scene_persistence editor_contract; do
  log="$check_dir/$suite.log"
  if env XDG_DATA_HOME="$check_dir/$suite" timeout 60 godot --headless --path "$project_dir" --script "res://tests/test_$suite.gd" > "$log" 2>&1; then
    if rg -q '(^ERROR:|SCRIPT ERROR:|^FAIL:|FAILED)' "$log" || ! rg -q 'PASSED' "$log"; then
      printf 'FAIL %s — %s\n' "$suite" "$log"
      failed=1
    else
      printf 'PASS %s\n' "$suite"
    fi
  else
    printf 'FAIL %s — %s\n' "$suite" "$log"
    failed=1
  fi
done
printf 'Evidence: %s\n' "$check_dir"
exit "$failed"
