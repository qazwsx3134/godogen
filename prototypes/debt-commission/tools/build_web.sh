#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
godot_bin="${GODOT_BIN:-godot}"
template_data="$project_dir/.cache/export-data"
godot_run=(env "XDG_CONFIG_HOME=$project_dir/.cache/config" "XDG_CACHE_HOME=$project_dir/.cache/cache" "$godot_bin")
if [[ -d "$template_data/godot/export_templates/4.7.stable" ]]; then
  godot_run=(env "XDG_DATA_HOME=$template_data" "XDG_CONFIG_HOME=$project_dir/.cache/config" "XDG_CACHE_HOME=$project_dir/.cache/cache" "$godot_bin")
fi
# Parley and Dialogue Manager are editor-only here and excluded from the export. Re-enabling
# either plugin in Project Settings adds a runtime autoload (saved as a path or a uid) that the
# exported game could not load. (The MCP toolkit's autoload is fine: it strips itself on export.)
autoloads=$(sed -n '/^\[autoload\]/,/^\[/p' "$project_dir/project.godot")
for script in addons/parley/parley_runtime.gd addons/dialogue_manager/dialogue_manager.gd; do
  for ref in "res://$script" "$(cat "$project_dir/$script.uid" 2>/dev/null)"; do
    if [[ -n "$ref" ]] && grep -qF "$ref" <<<"$autoloads"; then
      echo "project.godot autoloads $script, which the Web export excludes; remove that autoload (see README)." >&2
      exit 1
    fi
  done
done
mkdir -p "$project_dir/build/web"
touch "$project_dir/build/.gdignore"
# Slim the download (fonts subset, lossy textures, smaller splash/icon, re-encoded music) on a scratch copy in
# .cache/web-slim, so the project's own files never change. SLIM=0 exports the project as it is.
# Steps and numbers: godot-kit/tools/web/slim_web.py and production/release/web-slimming.md.
export_root="$project_dir"
if [[ "${SLIM:-1}" != 0 ]]; then
  export_root="$project_dir/.cache/web-slim"
  mkdir -p "$export_root"
  # .godot is copied only the first time: later builds reimport just what changed.
  [[ -d "$export_root/.godot" ]] || rsync -a "$project_dir/.godot" "$export_root/"
  rsync -a --delete --exclude=/.godot --exclude=/build --exclude=/.cache --exclude=/art_src --exclude=/test-results \
    --exclude=/addons/proto_kit/vfx "$project_dir/" "$export_root/"
  uv run -q --with fonttools --with pillow --with soundfile \
    python3 "$project_dir/../godot-kit/tools/web/slim_web.py" "$export_root"
fi
"${godot_run[@]}" --headless --path "$export_root" --editor --import
"${godot_run[@]}" --headless --path "$export_root" --export-release Web "$project_dir/build/web/index.html"
# Emscripten's IDBFS lists user:// first, then copies each listed file into IndexedDB once the
# database answers. A file deleted in between (restart deletes the save right after writing it)
# fails the copy with ENOENT (errno 44), logged as "Failed to save IDB file system: undefined".
# Skip such a file: the delete marks the filesystem dirty, so Godot's next sync removes it.
python3 - "$project_dir/build/web/index.js" <<'EOF'
import sys
path = sys.argv[1]
source = open(path, encoding="utf-8").read()
old = "IDBFS.loadLocalEntry(path,(err,entry)=>{if(err)return done(err);"
new = "IDBFS.loadLocalEntry(path,(err,entry)=>{if(err)return err.errno===44?undefined:done(err);"
if source.count(old) != 1:
    sys.exit("index.js: IDBFS.loadLocalEntry no longer matches; re-check the vanished-file patch in tools/build_web.sh")
open(path, "w", encoding="utf-8").write(source.replace(old, new))
EOF
echo "Web build: $project_dir/build/web/index.html"
