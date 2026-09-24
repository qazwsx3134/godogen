#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ ! -f "$project_dir/build/web/index.html" ]]; then
  echo "Run bash tools/build_web.sh first." >&2
  exit 1
fi
exec python3 -m http.server "${1:-5193}" --bind 127.0.0.1 --directory "$project_dir/build/web"
