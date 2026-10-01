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
"${godot_run[@]}" --headless --path "$project_dir" --editor --import
"${godot_run[@]}" --headless --path "$project_dir" --export-release Web "$project_dir/build/web/index.html"
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
