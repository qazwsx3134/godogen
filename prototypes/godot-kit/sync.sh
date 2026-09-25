#!/usr/bin/env bash
# Copies addons/proto_kit into Godot prototypes. Edit the kit here, never a copy.
#
#   ./sync.sh                 refresh every prototype that already has addons/proto_kit
#   ./sync.sh <name>...       add or refresh prototypes/<name>/addons/proto_kit
#   ./sync.sh --check         exit 1 if any copy differs from the kit
#
# Copies, not symlinks: this repo is checked out on Windows/WSL where git turns symlinks
# into plain text files, and Godot exports need real files under res://.
set -euo pipefail

kit_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source="$kit_dir/addons/proto_kit"
cd "$kit_dir/.."

check=0
targets=()
for arg in "$@"; do
  if [[ "$arg" == --check ]]; then check=1; else targets+=("${arg%/}"); fi
done
if [[ ${#targets[@]} -eq 0 ]]; then
  for copy in */addons/proto_kit; do
    [[ -d "$copy" && "$copy" != godot-kit/* ]] && targets+=("${copy%/addons/proto_kit}")
  done
fi

status=0
for target in "${targets[@]}"; do
  if [[ ! -f "$target/project.godot" ]]; then
    echo "skip: $target is not a Godot project" >&2; status=1; continue
  fi
  if [[ $check -eq 1 ]]; then
    diff -r "$source" "$target/addons/proto_kit" >/dev/null || { echo "drift: $target (run godot-kit/sync.sh)"; status=1; }
  else
    mkdir -p "$target/addons/proto_kit"
    rsync -a --delete "$source/" "$target/addons/proto_kit/"
    echo "synced: $target"
  fi
done
exit $status
