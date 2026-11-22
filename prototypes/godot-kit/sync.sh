#!/usr/bin/env bash
# Copies addons/proto_kit into Godot prototypes. Edit the kit here, never a copy.
#
#   ./sync.sh                 refresh every prototype that already has addons/proto_kit
#   ./sync.sh <name>...       add or refresh prototypes/<name>/addons/proto_kit
#   ./sync.sh --check         exit 1 if any copy differs from the kit
#   ./sync.sh [--check] --addon <id> <name>...  install or verify a third-party addon
#   ./sync.sh --conductor <name>...          copy the optional Conductor addon
#   ./sync.sh --check --conductor <name>...  compare the optional addon
#
# Copies, not symlinks: this repo is checked out on Windows/WSL where git turns symlinks
# into plain text files, and Godot exports need real files under res://.
set -euo pipefail

kit_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source="$kit_dir/addons/proto_kit"
cd "$kit_dir/.."

check=0
addon=
targets=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) check=1 ;;
    --conductor) addon=conductor ;;
    --addon)
      if [[ $# -lt 2 || "$2" == -* ]]; then
        echo 'usage: ./sync.sh [--check] --addon <id> <target>...' >&2
        exit 2
      fi
      addon="$2"
      shift ;;
    --*) echo "unknown option: $1" >&2; exit 2 ;;
    *) targets+=("${1%/}") ;;
  esac
  shift
done
case "$addon" in
  "") ;;
  conductor) addon_dir=conductor ;;
  phantom-camera) addon_dir=phantom_camera ;;
  debug-draw-3d) addon_dir=debug_draw_3d ;;
  raytraced-audio) addon_dir=raytraced_audio ;;
  ambientcg|ambientcg-material-downloader) addon_dir=ambientcg ;;
  sunshine-clouds-2) addon_dir=SunshineClouds2 ;;
  *) echo "unknown addon: $addon" >&2; exit 2 ;;
esac
if [[ ${#targets[@]} -eq 0 ]]; then
  if [[ -n "$addon" ]]; then
    echo 'usage: ./sync.sh [--check] --addon <id> <target>...' >&2
    exit 2
  fi
  for copy in */addons/proto_kit; do
    [[ -d "$copy" && "$copy" != godot-kit/* ]] && targets+=("${copy%/addons/proto_kit}")
  done
fi

status=0
for target in "${targets[@]}"; do
  if [[ ! -f "$target/project.godot" ]]; then
    echo "skip: $target is not a Godot project" >&2; status=1; continue
  fi
  if [[ -n "$addon" ]]; then
    addon_source="$kit_dir/third_party/$addon"
    destination="$target/addons/$addon_dir"
    if [[ $check -eq 1 ]]; then
      diff -qr --exclude='*.import' -- "$addon_source" "$destination" || status=1
    else
      if [[ "$addon_dir" == ambientcg && -f "$destination/plugin.cfg" ]] &&
        [[ "$(sed -n 's/^name=//p' "$destination/plugin.cfg")" != "$(sed -n 's/^name=//p' "$addon_source/plugin.cfg")" ]]; then
        echo "skip: $target already has a different AmbientCG variant in $destination" >&2
        status=1
        continue
      fi
      mkdir -p "$destination"
      rsync -a --exclude='*.import' -- "$addon_source/" "$destination/"
      echo "synced $addon: $target"
    fi
  elif [[ $check -eq 1 ]]; then
    python3 "$kit_dir/tools/audit_copies.py" --check "$target" || status=1
  else
    mkdir -p "$target/addons/proto_kit"
    rsync -a --delete "$source/" "$target/addons/proto_kit/"
    echo "synced: $target"
  fi
done
exit $status
