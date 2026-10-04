#!/usr/bin/env bash
# One command for an itch.io Web build of any Godot prototype:
#   godot-kit/tools/web/build_web.sh <project dir> [--zip-name <name>]      (zip defaults to <project folder name>-web)
#   godot-kit/tools/web/build_web.sh --self-test
#
# import -> export the "Web" preset of <project>/export_presets.cfg -> patch the vanished-file bug in index.js
# (patch_idbfs.py, fails loudly if the engine's glue code changed) -> what the .pck is made of (pck_size.py) -> <name>.zip.
# build/web is what `butler push` takes; the zip is for drag-and-drop upload (index.html sits at its top level).
# The project needs a Web preset named "Web" exporting to build/web/index.html (copy sugarcane-tanks/export_presets.cfg).
# The web template is fetched on first use (fetch_web_templates.py, about 13 MB instead of the 1.28 GB .tpz); pass
# FETCH_ARGS to change what it fetches, e.g. FETCH_ARGS="--want web_release.zip,web_debug.zip" with Thread Support on.
# Environment: GODOT_BIN (default `godot`), FETCH_ARGS.
set -euo pipefail
tools="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
godot="${GODOT_BIN:-godot}"

if [ "${1:-}" = "--self-test" ]; then
	scratch="$(mktemp -d)"
	trap 'rm -rf "${scratch:?}"' EXIT
	fail=0
	expect() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
	empty="$scratch/not_a_project"; mkdir -p "$empty"
	out="$("$0" "$empty" 2>&1)" && rc=0 || rc=$?
	expect "a folder without project.godot is refused" '[ "$rc" -ne 0 ] && echo "$out" | grep -q "project.godot"'
	noexp="$scratch/no_preset"; mkdir -p "$noexp"; printf '[application]\nconfig/name="x"\n' > "$noexp/project.godot"
	out="$("$0" "$noexp" 2>&1)" && rc=0 || rc=$?
	expect "a project without export_presets.cfg is refused" '[ "$rc" -ne 0 ] && echo "$out" | grep -q "export_presets.cfg"'
	out="$("$0" 2>&1)" && rc=0 || rc=$?
	expect "no arguments prints the usage and fails" '[ "$rc" -ne 0 ] && echo "$out" | grep -q "usage"'
	python3 "$tools/patch_idbfs.py" --self-test >/dev/null && echo "ok   patch_idbfs.py self-test passes" || { echo "FAIL patch_idbfs.py self-test"; fail=1; }
	python3 "$tools/pck_size.py" --self-test >/dev/null && echo "ok   pck_size.py self-test passes" || { echo "FAIL pck_size.py self-test"; fail=1; }
	python3 "$tools/fetch_web_templates.py" --self-test >/dev/null && echo "ok   fetch_web_templates.py self-test passes" || { echo "FAIL fetch_web_templates.py self-test"; fail=1; }
	echo "build_web self-test $([ $fail -eq 0 ] && echo PASSED || echo FAILED)"
	exit $fail
fi

[ $# -ge 1 ] || { echo "usage: build_web.sh <project dir> [--zip-name <name>]" >&2; exit 2; }
project="$(cd "$1" && pwd)"
shift
zip_name="$(basename "$project")-web"
if [ "${1:-}" = "--zip-name" ]; then zip_name="${2:?--zip-name needs a name}"; fi
[ -f "$project/project.godot" ] || { echo "$project has no project.godot" >&2; exit 2; }
[ -f "$project/export_presets.cfg" ] || { echo "$project has no export_presets.cfg with a preset named \"Web\" (copy godot-kit's sugarcane-tanks/export_presets.cfg)" >&2; exit 2; }

# The export needs the template that matches the engine; fetch it once.
version="$("$godot" --version | sed -E 's/^([0-9]+\.[0-9]+).*/\1/')"
# shellcheck disable=SC2086
python3 "$tools/fetch_web_templates.py" --version "$version" --check ${FETCH_ARGS:-} >/dev/null 2>&1 || python3 "$tools/fetch_web_templates.py" --version "$version" ${FETCH_ARGS:-}

mkdir -p "$project/build/web"
touch "$project/build/.gdignore"     # Godot must not import its own output
"$godot" --headless --path "$project" --editor --quit >/dev/null 2>&1
rm -f "$project/build/web/index.html"
"$godot" --headless --path "$project" --export-release Web "$project/build/web/index.html" 2>&1 | grep -E 'ERROR|error|DONE' || true
[ -f "$project/build/web/index.html" ] || { echo "export failed: no build/web/index.html (is the Web preset named \"Web\" and the template installed?)" >&2; exit 1; }
python3 "$tools/patch_idbfs.py" "$project/build/web/index.js"
python3 "$tools/pck_size.py" "$project/build/web/index.pck" | sed -n 1,6p
rm -f "$project/build/$zip_name.zip"
(cd "$project/build/web" && python3 -m zipfile -c "../$zip_name.zip" $(ls))
ls -l "$project/build/web" | awk 'NR>1 && $5>20000 {printf "  %9d  %s\n", $5, $9}'
echo "zip: $project/build/$zip_name.zip ($(du -h "$project/build/$zip_name.zip" | cut -f1))"
echo "folder for butler: $project/build/web"
