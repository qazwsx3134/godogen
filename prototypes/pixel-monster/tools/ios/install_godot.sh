#!/usr/bin/env bash
set -euo pipefail

# Official Godot 4.7 stable editor and matching export templates.  The editor
# version is intentionally exact; do not silently use the newest 4.7.x patch.
godot_version="${GODOT_RELEASE_VERSION:-4.7-stable}"
godot_reported_version="${GODOT_REPORTED_VERSION:-4.7.stable.official.5b4e0cb0f}"
template_version="${GODOT_TEMPLATE_VERSION:-4.7.stable}"
install_root="${GODOT_INSTALL_DIR:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/godot-${godot_version}}"
base_url="${GODOT_DOWNLOAD_BASE_URL:-https://github.com/godotengine/godot/releases/download/${godot_version}}"
editor_archive="${install_root}/Godot_v4.7-stable_macos.universal.zip"
template_archive="${install_root}/Godot_v4.7-stable_export_templates.tpz"
editor_binary="${install_root}/Godot.app/Contents/MacOS/Godot"
template_root="${HOME}/Library/Application Support/Godot/export_templates/${template_version}"

if [[ "${IOS_DRY_RUN:-0}" == "1" ]]; then
  printf '%s\n' "[dry-run] would install ${godot_reported_version} at ${install_root}" \
    "[dry-run] would install matching templates at ${template_root}" \
    "[dry-run] editor URL: ${base_url}/Godot_v4.7-stable_macos.universal.zip" \
    "[dry-run] template URL: ${base_url}/Godot_v4.7-stable_export_templates.tpz"
  exit 0
fi

mkdir -p "${install_root}"
if [[ ! -x "${editor_binary}" ]]; then
  curl -fsSL --retry 3 "${base_url}/Godot_v4.7-stable_macos.universal.zip" -o "${editor_archive}"
  unzip -q -o "${editor_archive}" -d "${install_root}"
fi

if [[ ! -f "${template_root}/ios.zip" ]]; then
  mkdir -p "${template_root}"
  curl -fsSL --retry 3 "${base_url}/Godot_v4.7-stable_export_templates.tpz" -o "${template_archive}"
  template_tmp="$(mktemp -d "${TMPDIR:-/tmp}/godot-templates.XXXXXX")"
  cleanup() { rm -rf "${template_tmp}"; }
  trap cleanup EXIT
  unzip -q -o "${template_archive}" -d "${template_tmp}"
  if [[ -d "${template_tmp}/templates" ]]; then
    cp -R "${template_tmp}/templates/." "${template_root}/"
  else
    cp -R "${template_tmp}/." "${template_root}/"
  fi
fi

actual_version="$("${editor_binary}" --version | head -n 1)"
if [[ "${actual_version}" != "${godot_reported_version}" ]]; then
  printf 'Godot version mismatch: expected %s, got %s\n' "${godot_reported_version}" "${actual_version}" >&2
  exit 2
fi
if [[ ! -f "${template_root}/ios.zip" ]]; then
  printf 'Godot iOS template missing: %s\n' "${template_root}/ios.zip" >&2
  exit 2
fi

printf 'GODOT_BIN=%s\n' "${editor_binary}"
if [[ -n "${GITHUB_ENV:-}" ]]; then
  printf 'GODOT_BIN=%s\n' "${editor_binary}" >> "${GITHUB_ENV}"
fi
