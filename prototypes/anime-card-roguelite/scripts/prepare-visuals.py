#!/usr/bin/env python3
"""Process the visual-v1 2x2 magenta sheets without creating artwork.

The wrapper deliberately delegates chroma-keying, frame extraction, alignment,
and QC to generate2dsprite.py. It only validates PNG dimensions, selects the
per-asset processor contract, and aggregates pipeline metadata into qc.json.
"""

from __future__ import annotations

import argparse
import json
import struct
import shutil
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
DEFAULT_INPUT_DIR = REPO_ROOT / "prototypes/anime-card-roguelite/assets/visual-v1/raw"
DEFAULT_OUTPUT_DIR = REPO_ROOT / "prototypes/anime-card-roguelite/assets/visual-v1/processed"
DEFAULT_QC = REPO_ROOT / "prototypes/anime-card-roguelite/assets/visual-v1/qc.json"
DEFAULT_TOOL = Path("/home/ronghao/.codex/skills/generate2dsprite/scripts/generate2dsprite.py")
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"

ASSETS = {
    "hero-shadow_ninja": {"kind": "character", "target": "player", "mode": "player_actions"},
    "hero-ki_fighter": {"kind": "character", "target": "player", "mode": "player_actions"},
    "hero-silver_ronin": {"kind": "character", "target": "player", "mode": "player_actions"},
    "cameo-shinpachi": {"kind": "character", "target": "npc", "mode": "npc_walk"},
    "enemy-raider": {"kind": "character", "target": "creature", "mode": "combat"},
    "enemy-boss": {"kind": "character", "target": "creature", "mode": "combat"},
    "fx-energy": {"kind": "fx", "target": "asset", "mode": "fx"},
    "fx-beam": {"kind": "fx", "target": "asset", "mode": "fx"},
}


def relative_path(path: Path) -> str:
    try:
        return path.resolve().relative_to(REPO_ROOT).as_posix()
    except ValueError:
        return str(path.resolve())


def png_size(path: Path) -> tuple[int, int]:
    """Read a PNG IHDR size with stdlib only; no image synthesis or Pillow."""
    with path.open("rb") as handle:
        header = handle.read(24)
    if len(header) < 24 or header[:8] != PNG_SIGNATURE or header[12:16] != b"IHDR":
        raise ValueError("不是有效 PNG 檔。")
    width, height = struct.unpack(">II", header[16:24])
    if not width or not height:
        raise ValueError("PNG 尺寸不可為零。")
    return width, height


def processor_contract(asset: dict[str, str], output_dir: Path, python_executable: str) -> list[str]:
    command = [
        python_executable,
        str(DEFAULT_TOOL),
        "process",
        "--target",
        asset["target"],
        "--mode",
        asset["mode"],
        "--output-dir",
        str(output_dir),
        "--rows",
        "2",
        "--cols",
        "2",
        "--cell-size",
        "256",
        "--label-prefix",
        asset["id"],
        "--duration",
        "125",
        "--threshold",
        "128",
        "--edge-threshold",
        "180",
        "--strict-qc",
        "--trim-border", "0",
    ]
    if asset["kind"] == "fx":
        command.extend(["--align", "center", "--scale-strategy", "fit", "--component-mode", "largest" if asset['id'] == 'fx-beam' else "all", "--fit-scale", "0.85", "--shared-scale"])
    else:
        command.extend(
            [
                "--align",
                "feet",
                "--scale-strategy",
                "fit",
                "--component-mode",
                "largest",
                "--shared-scale",
                "--fit-scale",
                "0.82",
                "--max-body-scale-cv",
                "0.08",
                "--max-anchor-y-std",
                "0.05",
            ]
        )
    return command


def dependency_status(python_executable: str) -> dict[str, str]:
    probe = "import importlib.util,json; print(json.dumps({'numpy': bool(importlib.util.find_spec('numpy')), 'Pillow': bool(importlib.util.find_spec('PIL'))}))"
    try:
        result = subprocess.run([python_executable, "-c", probe], capture_output=True, text=True, check=False)
        values = json.loads(result.stdout) if result.returncode == 0 else {}
    except (OSError, json.JSONDecodeError):
        values = {}
    return {name: "available" if values.get(name, False) else "missing" for name in ("numpy", "Pillow")}


def process_asset(
    asset_id: str,
    asset: dict[str, str],
    input_dir: Path,
    output_dir: Path,
    tool: Path,
    dependencies: dict[str, str],
    report_only: bool,
    python_executable: str,
) -> dict[str, object]:
    raw = input_dir / f"{asset_id}.png"
    destination = output_dir / asset_id
    entry: dict[str, object] = {
        "id": asset_id,
        "kind": asset["kind"],
        "input": relative_path(raw),
        "output": relative_path(destination),
        "raw_present": raw.is_file(),
        "expected": {
            "grid": [2, 2],
            "cell_size": 256,
            "sheet_size": [512, 512],
            **({"target_subject_height_px": 210, "target_footline_px": 230} if asset["kind"] != "fx" else {}),
        },
        "processor": {
            "target": asset["target"],
            "mode": asset["mode"],
            "align": "center" if asset["kind"] == "fx" else "feet",
            "component_mode": "all" if asset_id == "fx-energy" else "largest",
            "scale_strategy": "fit",
            "shared_scale": True,
            "fit_scale": 0.85 if asset["kind"] == "fx" else 0.82,
            "chroma_key": {"threshold": 128, "edge_threshold": 180},
        },
    }
    if not raw.is_file():
        entry["status"] = "missing-raw"
        return entry
    try:
        width, height = png_size(raw)
        entry["raw_size"] = [width, height]
        if width != height or width % 2 or height % 2:
            entry["status"] = "invalid-raw-grid"
            entry["error"] = "raw 必須是可均分的正方形 2x2 sheet。"
            return entry
        entry["raw_cell_size"] = [width // 2, height // 2]
    except (OSError, ValueError) as error:
        entry["status"] = "invalid-raw"
        entry["error"] = str(error)
        return entry
    if report_only:
        entry["status"] = "ready"
        return entry
    missing = [name for name, state in dependencies.items() if state == "missing"]
    if missing:
        entry["status"] = "blocked-dependency"
        entry["error"] = f"generate2dsprite.py 需要缺少的依賴：{', '.join(missing)}；未安裝。"
        return entry
    command = processor_contract({**asset, "id": asset_id}, destination, python_executable)
    command[command.index("--output-dir") + 1] = str(destination)
    command[command.index("--target") + 1] = asset["target"]
    command[command.index("--mode") + 1] = asset["mode"]
    command.insert(command.index("--target"), "--input")
    command.insert(command.index("--input") + 1, str(raw))
    if tool != DEFAULT_TOOL:
        command[1] = str(tool)
    entry["command"] = command
    completed = subprocess.run(command, capture_output=True, text=True, check=False)
    if completed.returncode:
        entry["status"] = "processor-failed"
        entry["error"] = (completed.stderr or completed.stdout or "processor failed").strip()[-2000:]
        return entry
    metadata_path = destination / "pipeline-meta.json"
    sheet_path = destination / "sheet-transparent.png"
    entry["status"] = "processed"
    if metadata_path.is_file():
        try:
            metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
            entry["qc_summary"] = metadata.get("qc_summary", {})
            entry["edge_touch_frames"] = metadata.get("edge_touch_frames", [])
            entry["output_edge_touch_frames"] = metadata.get("output_edge_touch_frames", [])
            entry["paste_clamped_frames"] = metadata.get("paste_clamped_frames", [])
        except (OSError, json.JSONDecodeError) as error:
            entry["status"] = "invalid-qc"
            entry["error"] = f"無法讀取 pipeline-meta.json：{error}"
    if not sheet_path.is_file():
        entry["status"] = "invalid-output"
        entry["error"] = "processor 沒有輸出 sheet-transparent.png。"
    else:
        try:
            entry["output_size"] = list(png_size(sheet_path))
            if entry["output_size"] != [512, 512]:
                entry["status"] = "invalid-output"
                entry["error"] = "透明 sheet 必須是 512x512。"
        except (OSError, ValueError) as error:
            entry["status"] = "invalid-output"
            entry["error"] = str(error)
    if entry['status'] == 'processed':
        runtime_path = output_dir.parent / f'{asset_id}.png'
        shutil.copy2(sheet_path, runtime_path)
        entry['runtime_path'] = relative_path(runtime_path)
    return entry


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input-dir", type=Path, default=DEFAULT_INPUT_DIR)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--qc", type=Path, default=DEFAULT_QC)
    parser.add_argument("--tool", type=Path, default=DEFAULT_TOOL)
    parser.add_argument("--python", dest="python_executable", default=sys.executable, help="執行 processor 的 Python；需有 numpy 與 Pillow。")
    parser.add_argument("--asset", action="append", choices=sorted(ASSETS), help="只處理指定 asset，可重複。")
    parser.add_argument("--report-only", action="store_true", help="只檢查已落地 raw 尺寸並更新 qc，不執行 processor。")
    args = parser.parse_args()
    input_dir = args.input_dir.resolve()
    output_dir = args.output_dir.resolve()
    qc_path = args.qc.resolve()
    selected = args.asset or list(ASSETS)
    dependencies = dependency_status(args.python_executable)
    entries = [
        process_asset(asset_id, ASSETS[asset_id], input_dir, output_dir, args.tool.resolve(), dependencies, args.report_only, args.python_executable)
        for asset_id in selected
    ]
    if args.asset and qc_path.is_file():
        previous = json.loads(qc_path.read_text(encoding='utf-8'))
        merged = {item['id']: item for item in previous.get('assets', [])}
        merged.update({item['id']: item for item in entries})
        entries = list(merged.values())
    statuses = {str(entry["status"]) for entry in entries}
    if any(status in statuses for status in {"blocked-dependency", "processor-failed", "invalid-raw", "invalid-raw-grid", "invalid-output", "invalid-qc"}):
        status = "blocked" if "blocked-dependency" in statuses else "failed"
    elif "missing-raw" in statuses:
        status = "pending"
    elif args.report_only:
        status = "report-only"
    else:
        status = "passed"
    payload = {
        "schema": "anime-card-roguelite.visual-v1.qc",
        "status": status,
        "grid": {"rows": 2, "cols": 2, "output_cell_px": 256, "output_sheet_px": [512, 512]},
        "input_dir": relative_path(input_dir),
        "output_dir": relative_path(output_dir),
        "processor": relative_path(args.tool.resolve()),
        "python": args.python_executable,
        "dependencies": dependencies,
        "assets": entries,
        "usage": "python3 prototypes/anime-card-roguelite/scripts/prepare-visuals.py",
    }
    qc_path.parent.mkdir(parents=True, exist_ok=True)
    qc_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": status, "qc": str(qc_path), "assets": {entry["id"]: entry["status"] for entry in entries}}, ensure_ascii=False))
    return 0 if args.report_only or status == "passed" else 2


if __name__ == "__main__":
    raise SystemExit(main())
