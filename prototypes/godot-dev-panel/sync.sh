#!/usr/bin/env bash
set -euo pipefail

module_dir="$(cd "$(dirname "$0")" && pwd)"
addon="addons/godot_dev_panel"
mode="copy"
if [[ ${1:-} == --check ]]; then
	mode="check"
	shift
fi
if [[ $# != 1 || ! "$1" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]]; then
	printf 'Usage: bash prototypes/godot-dev-panel/sync.sh [--check] <prototype-directory-name>\n' >&2
	exit 2
fi
project="$module_dir/../$1"
if [[ ! -f "$project/project.godot" ]]; then
	printf 'Godot project not found: %s\n' "$project" >&2
	exit 2
fi
if [[ "$mode" == check ]]; then
	diff -ru "$module_dir/$addon" "$project/$addon"
else
	mkdir -p "$project/$addon"
	cp -p "$module_dir/$addon/"* "$project/$addon/"
fi
