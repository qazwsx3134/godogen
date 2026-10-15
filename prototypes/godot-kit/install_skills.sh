#!/usr/bin/env bash
# Copies godot-kit/skills/* into a Claude Code skills folder. Edit the skills here, never a copy.
#
#   ./install_skills.sh                  install or refresh every skill in ~/.claude/skills
#   ./install_skills.sh <name>...        only these skills
#   ./install_skills.sh --check          exit 1 if an installed copy is missing or differs
#   ./install_skills.sh --dest <dir>     another skills folder (e.g. a project's .claude/skills)
#
# Copies, not symlinks: a symlink in ~/.claude/skills points at one machine's clone, is not part of the repo
# (another account never gets it), and git on Windows/WSL turns symlinks into plain text files.
# Each installed copy holds a .godot-kit-skill marker; a folder of the same name without it (someone's own
# skill) is left alone. A symlink of the same name (the old setup) is replaced by a copy.
set -euo pipefail

kit_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source="$kit_dir/skills"
dest="$HOME/.claude/skills"
marker=".godot-kit-skill"

check=0
names=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) check=1 ;;
    --dest) dest="${2:?--dest needs a folder}"; shift ;;
    *) names+=("${1%/}") ;;
  esac
  shift
done
if [[ ${#names[@]} -eq 0 ]]; then
  for dir in "$source"/*/; do names+=("$(basename "$dir")"); done
fi

status=0
for name in "${names[@]}"; do
  from="$source/$name"
  to="$dest/$name"
  if [[ ! -f "$from/SKILL.md" ]]; then
    echo "skip: $name has no SKILL.md in $source" >&2; status=1; continue
  fi
  if [[ $check -eq 1 ]]; then
    if [[ -L "$to" || ! -f "$to/$marker" ]]; then
      echo "missing: $to (run ./install_skills.sh)"; status=1
    elif ! diff -rq --exclude="$marker" "$from" "$to" >/dev/null; then
      echo "outdated: $to"; status=1
    else
      echo "ok: $to"
    fi
    continue
  fi
  if [[ -d "$to" && ! -L "$to" && ! -f "$to/$marker" ]]; then
    echo "refuse: $to exists and was not installed by godot-kit; move it away first" >&2; status=1; continue
  fi
  mkdir -p "$dest"
  [[ -L "$to" ]] && rm "$to"   # the old symlink setup: remove the link only, never its target
  mkdir -p "$to"
  rsync -a --delete --exclude="$marker" "$from/" "$to/"
  echo "installed from godot-kit: $from" > "$to/$marker"
  echo "installed: $to"
done
exit $status
