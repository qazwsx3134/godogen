#!/usr/bin/env bash
# 跑全部測試：tools/check.sh
# Godot 遇到 SCRIPT ERROR 仍可能 exit 0，所以同時檢查 log。
set -u
GODOT_BIN=${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}
project="$(cd "$(dirname "$0")/.." && pwd)"
logs="$(mktemp -d "${TMPDIR:-/tmp}/sugarcane-check.XXXXXX")"
failed=0

"$GODOT_BIN" --headless --path "$project" --editor --quit >"$logs/import.log" 2>&1

for suite in rules scenes play persistence; do
	log="$logs/$suite.log"
	extra=""
	[ "$suite" = play ] && extra="--fixed-fps 60"
	timeout 300 "$GODOT_BIN" --headless --path "$project" $extra --script "res://tests/test_$suite.gd" >"$log" 2>&1
	rc=$?
	if [ $rc -ne 0 ] || grep -qE 'SCRIPT ERROR|Parse Error|Failed to load script|^FAIL' "$log" || ! grep -q 'PASSED' "$log"; then
		echo "FAIL $suite — $log"
		failed=1
	else
		echo "PASS $suite"
	fi
done
echo "logs: $logs"
exit $failed
