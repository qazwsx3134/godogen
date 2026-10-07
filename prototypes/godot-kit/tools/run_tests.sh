#!/usr/bin/env bash
# Runs a Godot project's headless test suites with a strict check of the log.
#   godot-kit/tools/run_tests.sh <project dir> [suite[:fps] ...]      no suites = every tests/test_*.gd
#   godot-kit/tools/run_tests.sh --self-test
#
# A suite is tests/test_<name>.gd, a SceneTree script (see addons/proto_kit/test_kit.gd) that prints
# "<NAME> TESTS PASSED". `play:60` runs the suite with --fixed-fps 60: needed when its timers must run on game time.
# Godot exits 0 even after a SCRIPT ERROR, so the log is checked as well. A suite passes only when
#   - its process exits 0,
#   - the log has no `SCRIPT ERROR`, `Parse Error` or `Failed to load script`, and no line that starts with `FAIL`,
#   - the log says PASSED.
# The project is imported first (`--editor --quit`) so files added since the last run are known.
# Environment: GODOT_BIN (default `godot`), TEST_TIMEOUT (seconds per suite, default 600).
# Logs go to a new folder under $TMPDIR; its path is printed. Exit code 1 if any suite failed.
set -u
godot="${GODOT_BIN:-godot}"
limit="${TEST_TIMEOUT:-600}"

run_suites() {
	local project="$1" logs failed=0 suite name fps extra log rc
	shift
	logs="$(mktemp -d "${TMPDIR:-/tmp}/godot-tests.XXXXXX")"
	"$godot" --headless --path "$project" --editor --quit >"$logs/import.log" 2>&1
	local suites=("$@")
	if [ ${#suites[@]} -eq 0 ]; then
		for file in "$project"/tests/test_*.gd; do
			[ -e "$file" ] || continue
			name="$(basename "$file" .gd)"
			suites+=("${name#test_}")
		done
	fi
	if [ ${#suites[@]} -eq 0 ]; then
		echo "no tests/test_*.gd in $project" >&2
		return 2
	fi
	for suite in "${suites[@]}"; do
		name="${suite%%:*}"
		fps=""
		[ "$suite" != "$name" ] && fps="${suite#*:}"
		extra=()
		[ -n "$fps" ] && extra=(--fixed-fps "$fps")
		log="$logs/$name.log"
		timeout "$limit" "$godot" --headless --path "$project" ${extra[@]+"${extra[@]}"} --script "res://tests/test_$name.gd" >"$log" 2>&1
		rc=$?
		if [ $rc -ne 0 ] || grep -qE 'SCRIPT ERROR|Parse Error|Failed to load script|^FAIL' "$log" || ! grep -q 'PASSED' "$log"; then
			echo "FAIL $name (exit $rc) - $log"
			failed=1
		else
			echo "PASS $name"
		fi
	done
	echo "logs: $logs"
	return $failed
}

if [ "${1:-}" = "--self-test" ]; then
	scratch="$(mktemp -d)"
	trap 'rm -rf "${scratch:?}"' EXIT
	mkdir -p "$scratch/tests"
	printf '[application]\nconfig/name="run_tests_self_test"\n' > "$scratch/project.godot"
	printf 'extends SceneTree\nfunc _init() -> void:\n\tprint("GOOD TESTS PASSED")\n\tquit()\n' > "$scratch/tests/test_good.gd"
	printf 'extends SceneTree\nfunc _init() -> void:\n\tprint("FAIL: something is wrong")\n\tprint("BAD TESTS PASSED")\n\tquit()\n' > "$scratch/tests/test_failing.gd"
	printf 'extends SceneTree\nfunc _init() -> void:\n\tundefined_function()\n\tprint("BROKEN TESTS PASSED")\n\tquit()\n' > "$scratch/tests/test_broken.gd"
	printf 'extends SceneTree\nfunc _init() -> void:\n\tprint("nothing to say")\n\tquit()\n' > "$scratch/tests/test_silent.gd"
	printf 'extends SceneTree\nfunc _init() -> void:\n\tcall_deferred("_boom")\n\tcall_deferred("_done")\nfunc _boom() -> void:\n\tvar nothing = null\n\tnothing.fly()\nfunc _done() -> void:\n\tprint("RUNTIME TESTS PASSED")\n\tquit()\n' > "$scratch/tests/test_runtime.gd"
	printf 'extends SceneTree\nfunc _init() -> void:\n\tprint("TIMED TESTS PASSED %%s" %% Engine.max_fps)\n\tquit()\n' > "$scratch/tests/test_timed.gd"
	fail=0
	expect() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
	out="$(run_suites "$scratch" good timed:60 2>&1)" && rc=0 || rc=$?
	expect "passing suites exit 0 and are reported PASS (a :fps suffix is accepted)" '[ "$rc" -eq 0 ] && echo "$out" | grep -q "^PASS good" && echo "$out" | grep -q "^PASS timed"'
	out="$(run_suites "$scratch" failing 2>&1)" && rc=0 || rc=$?
	expect "a log line starting with FAIL fails the suite even though Godot exits 0" '[ "$rc" -eq 1 ] && echo "$out" | grep -q "^FAIL failing"'
	out="$(run_suites "$scratch" broken 2>&1)" && rc=0 || rc=$?
	expect "a script that does not even load fails the suite" '[ "$rc" -eq 1 ] && echo "$out" | grep -q "^FAIL broken"'
	out="$(run_suites "$scratch" silent 2>&1)" && rc=0 || rc=$?
	expect "a suite that never says PASSED fails" '[ "$rc" -eq 1 ] && echo "$out" | grep -q "^FAIL silent"'
	out="$(run_suites "$scratch" runtime 2>&1)" && rc=0 || rc=$?
	expect "a suite that prints PASSED and exits 0 after a SCRIPT ERROR still fails" '[ "$rc" -eq 1 ] && echo "$out" | grep -q "^FAIL runtime"'
	out="$(run_suites "$scratch" 2>&1)" && rc=0 || rc=$?
	expect "with no suite names every tests/test_*.gd runs, and one failure fails the run" '[ "$rc" -eq 1 ] && echo "$out" | grep -q "^PASS good" && echo "$out" | grep -q "^FAIL failing" && echo "$out" | grep -q "^FAIL broken" && echo "$out" | grep -q "^FAIL silent" && echo "$out" | grep -q "^FAIL runtime"'
	empty="$(mktemp -d)"
	out="$(run_suites "$empty" 2>&1)" && rc=0 || rc=$?
	expect "a project without tests is reported, not passed" '[ "$rc" -eq 2 ] && echo "$out" | grep -q "no tests"'
	rm -rf "${empty:?}"
	echo "run_tests self-test $([ $fail -eq 0 ] && echo PASSED || echo FAILED)"
	exit $fail
fi

[ $# -ge 1 ] || { echo "usage: run_tests.sh <project dir> [suite[:fps] ...]" >&2; exit 2; }
[ -f "$1/project.godot" ] || { echo "$1 has no project.godot" >&2; exit 2; }
project="$(cd "$1" && pwd)"
shift
run_suites "$project" "$@"
