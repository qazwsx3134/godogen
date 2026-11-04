#!/usr/bin/env python3
"""Index a local model library without modifying or copying its source files."""

from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import csv
import io
import json
import os
from pathlib import Path
import re
import struct
from urllib.parse import quote, unquote, urlsplit


REPO = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = REPO.parent / "model-assets"
DEFAULT_OUTPUT = REPO / "docs" / "model-assets"
MODEL_EXTENSIONS = {".glb", ".gltf", ".fbx", ".obj", ".blend"}

# Categories and aliases describe names, not verified visual appearances.
CATEGORY_TERMS = {
    "建築": "building house home hut cabin wall roof tower window door floor stairs stair column structure arch gate battlement dock bridge overhang platform chimney brick bricks panel",
    "自然與地形": "tree plant grass rock rocks stone stones water bush flower foliage ground dirt terrain hill patch log",
    "街景與道具": "sign signpost fence barrel barrels box crate chest bucket banner flag pot cart well campfire tent post lantern",
    "家具與工具": "chair table shelf shelves ladder workbench hammer axe tool bed bedroll bench cabinet rack display",
    "食物與餐具": "food fruit vegetable apple bread cake cheese drink plate bowl cup bottle fish mushroom carrot pumpkin",
    "角色與裝備": "character figurine weapon sword shield bow arrow spear helmet armor",
    "冒險與戰鬥": "siege ballista trebuchet catapult ram trap coin key potion target",
    "現代設施": "industrial commercial urban road car truck shipping container solar streetlight freezer",
}
SEARCH_ALIASES = {
    "building": "房屋 建築 小屋", "wall": "牆 牆壁", "roof": "屋頂 瓦片",
    "window": "窗 窗戶", "door": "門 入口", "tower": "塔 塔樓",
    "floor": "地板 地面", "stairs": "樓梯 階梯", "column": "柱 柱子",
    "structure": "建築 結構 木架", "gate": "門 城門", "bridge": "橋 橋梁",
    "tree": "樹 樹木", "plant": "植物", "grass": "草 草地", "flower": "花",
    "rock": "石頭 岩石", "rocks": "石頭 岩石", "stone": "石頭 石材", "water": "水",
    "fence": "柵欄 圍欄", "sign": "路牌 指示牌", "signpost": "路牌 指示牌",
    "barrel": "木桶 桶子", "barrels": "木桶 桶子", "crate": "木箱 箱子", "box": "箱子 木箱",
    "chest": "寶箱 箱子", "bucket": "水桶 桶子", "pot": "罐子 鍋子",
    "table": "桌子", "chair": "椅子", "bench": "長椅 工作台", "workbench": "工作台",
    "shelf": "架子 貨架", "ladder": "梯子", "tool": "工具", "tent": "帳篷",
    "character": "角色 人物", "weapon": "武器", "food": "食物", "fish": "魚",
    "wood": "木頭 木材 木製", "planks": "木板 木材", "brick": "磚 磚塊", "bricks": "磚 磚塊",
    "house": "房屋 建築 小屋", "hut": "房屋 小屋", "cabin": "房屋 小屋", "panel": "板 牆板",
    "key": "鑰匙", "coin": "硬幣 金幣", "potion": "藥水", "campfire": "營火 篝火",
}
TOWN_PACKS = {"kenney_mini-forest_1.0", "kenney_survival-kit", "kenney_castle-kit", "kenney_retro-fantasy-kit", "kenney_mini-dungeon"}
TOWN_TERMS = set("building wall roof window door floor column structure arch gate bridge tree plant grass rock rocks stone stones fence sign signpost barrel barrels box crate chest bucket pot ladder workbench tent".split())


def tokens(name: str) -> set[str]:
    return set(filter(None, re.split(r"[^a-z0-9]+", name.lower())))


def classify(pack: str, name: str) -> tuple[list[str], list[str], bool]:
    words = tokens(name)
    categories = [label for label, terms in CATEGORY_TERMS.items() if words & set(terms.split())]
    if "food-kit" in pack and "食物與餐具" not in categories:
        categories.append("食物與餐具")
    if any(part in pack for part in ("city-kit", "retro-urban", "mini-shop")) and "現代設施" not in categories:
        categories.append("現代設施")
    if "prototype-kit" in pack:
        categories.append("原型積木")
    if not categories:
        categories = ["其他／待分類"]
    aliases = sorted({alias for word in words for alias in SEARCH_ALIASES.get(word, "").split()})
    return categories, aliases, pack in TOWN_PACKS and bool(words & TOWN_TERMS)


def triangle_count(document: dict) -> int:
    """Count glTF triangles instantiated by nodes in its default scene."""
    accessors = document.get("accessors", [])
    meshes = document.get("meshes", [])
    nodes = document.get("nodes", [])
    scenes = document.get("scenes", [])

    def count_accessor(index: int) -> int:
        count = int(accessors[index]["count"])
        if count < 0:
            raise ValueError("negative accessor count")
        return count

    def visit(index: int, ancestors: frozenset[int]) -> int:
        if index in ancestors:
            raise ValueError("cyclic scene graph")
        node = nodes[index]
        instance_count = 1
        gpu = node.get("extensions", {}).get("EXT_mesh_gpu_instancing")
        if gpu is not None:
            counts = {count_accessor(i) for i in gpu.get("attributes", {}).values()}
            if len(counts) != 1:
                raise ValueError("invalid GPU instance counts")
            instance_count = counts.pop()
        result = 0
        if "mesh" in node:
            for primitive in meshes[node["mesh"]].get("primitives", []):
                mode = primitive.get("mode", 4)
                accessor = primitive.get("indices", primitive.get("attributes", {}).get("POSITION"))
                if accessor is None:
                    raise ValueError("primitive without an accessor")
                count = count_accessor(accessor)
                if mode == 4:
                    if count % 3:
                        raise ValueError("incomplete triangle")
                    result += (count // 3) * instance_count
                elif mode in (5, 6):
                    result += max(0, count - 2) * instance_count
                elif mode not in (0, 1, 2, 3):
                    raise ValueError("unsupported primitive mode")
        for child in node.get("children", []):
            result += visit(child, ancestors | {index})
        return result

    if scenes:
        roots = scenes[document.get("scene", 0)].get("nodes", [])
    else:
        children = {child for node in nodes for child in node.get("children", [])}
        roots = [i for i in range(len(nodes)) if i not in children]
    return sum(visit(i, frozenset()) for i in roots)


def inspect_glb(path: Path, source: Path) -> dict:
    result = {"triangles": None, "dependencies": [], "error": None}
    try:
        with path.open("rb") as stream:
            magic, version, total = struct.unpack("<4sII", stream.read(12))
            chunk_length, chunk_type = struct.unpack("<I4s", stream.read(8))
            if magic != b"glTF" or version != 2 or chunk_type != b"JSON" or chunk_length > total - 20:
                raise ValueError("invalid GLB header")
            document = json.loads(stream.read(chunk_length).decode("utf-8"))
        result["triangles"] = triangle_count(document)
        for item in document.get("images", []) + document.get("buffers", []):
            uri = item.get("uri")
            if not uri or uri.startswith("data:"):
                continue
            parsed = urlsplit(uri)
            if parsed.scheme or parsed.netloc:
                result["dependencies"].append({"uri": uri, "status": "external_url"})
                continue
            dependency = (path.parent / unquote(parsed.path)).resolve()
            try:
                relative = dependency.relative_to(source.resolve()).as_posix()
            except ValueError:
                result["dependencies"].append({"uri": uri, "status": "outside_library"})
                continue
            result["dependencies"].append({"uri": uri, "path": relative, "status": "ok" if dependency.is_file() else "missing"})
    except (OSError, UnicodeError, ValueError, KeyError, IndexError, TypeError, struct.error) as exc:
        result["error"] = f"{type(exc).__name__}: {exc}"
    return result


def inventory(source: Path) -> dict:
    packs = []
    models = []
    for pack in sorted(p for p in source.iterdir() if p.is_dir()):
        license_path = pack / "License.txt"
        license_text = license_path.read_text(encoding="utf-8-sig", errors="replace").lower() if license_path.is_file() else ""
        license_name = "CC0" if "cc0" in license_text or "creative commons zero" in license_text else "待確認"
        groups = defaultdict(lambda: defaultdict(list))
        previews = {}
        counts = Counter()
        for directory, dirs, files in os.walk(pack):
            dirs.sort()
            for filename in sorted(files):
                path = Path(directory) / filename
                extension = path.suffix.lower()
                counts[extension] += 1
                relative = path.relative_to(source).as_posix()
                if extension in MODEL_EXTENSIONS:
                    groups[path.stem][extension[1:]].append(relative)
                elif extension == ".png" and path.parent.name.lower() == "previews":
                    previews[path.stem] = relative
        for name, formats in sorted(groups.items(), key=lambda item: item[0].lower()):
            categories, aliases, town = classify(pack.name, name)
            model = {"pack": pack.name, "name": name, "categories": categories, "aliases": aliases,
                     "town_candidate": town, "formats": dict(formats), "preview": previews.get(name),
                     "triangles": None, "dependencies": [], "inspection_error": None}
            if formats.get("glb"):
                analysis = inspect_glb(source / formats["glb"][0], source)
                model.update(triangles=analysis["triangles"], dependencies=analysis["dependencies"], inspection_error=analysis["error"])
            models.append(model)
        kinds = []
        if groups:
            kinds.append("3D 模型")
        if counts[".png"] and not groups:
            kinds.append("2D 圖像／介面")
        if counts[".ttf"] or counts[".otf"]:
            kinds.append("字型")
        packs.append({"name": pack.name, "types": kinds or ["其他"], "license": license_name,
                      "license_path": license_path.relative_to(source).as_posix() if license_path.is_file() else None,
                      "models": len(groups), "files": sum(counts.values()),
                      "overview": (pack / "Overview.html").relative_to(source).as_posix() if (pack / "Overview.html").is_file() else None})
    return {"packs": packs, "models": models}


def render_tsv(data: dict) -> str:
    output = io.StringIO(newline="")
    writer = csv.writer(output, delimiter="\t", lineterminator="\n")
    writer.writerow(["套件", "模型", "分類", "原始三角面", "城鎮候選", "GLB 相對素材庫路徑", "外部相依檔", "錯誤"])
    for item in data["models"]:
        deps = "; ".join(d.get("path", d["uri"]) + (" [" + d["status"] + "]" if d["status"] != "ok" else "") for d in item["dependencies"])
        writer.writerow([item["pack"], item["name"], ", ".join(item["categories"]),
                         "" if item["triangles"] is None else item["triangles"],
                         "是" if item["town_candidate"] else "", item["formats"].get("glb", [""])[0], deps,
                         item["inspection_error"] or ""])
    return output.getvalue()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE, help="素材庫根目錄（唯讀）")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT, help="索引輸出目錄")
    parser.add_argument("--check", action="store_true", help="比較既有索引，不寫入檔案")
    args = parser.parse_args()
    source = args.source.resolve()
    output = args.output.resolve()
    if not source.is_dir():
        parser.error(f"素材庫不存在：{source}")
    if output == source or source in output.parents:
        parser.error("輸出目錄不可位於素材庫內")
    data = inventory(source)
    relative_root = Path(os.path.relpath(source, output)).as_posix()
    data["source_root_url"] = quote(relative_root, safe="/.")
    template = (REPO / "docs" / "model-assets" / "template.html").read_text(encoding="utf-8")
    encoded = json.dumps(data, ensure_ascii=False, separators=(",", ":")).replace("<", "\\u003c").replace("\u2028", "\\u2028").replace("\u2029", "\\u2029")
    if template.count("/*__CATALOG_DATA__*/") != 1:
        raise ValueError("catalog template must contain exactly one data placeholder")
    rendered = template.replace("/*__CATALOG_DATA__*/", encoded)
    outputs = {output / "index.html": rendered, output / "models.tsv": render_tsv(data)}
    if args.check:
        stale = [str(path) for path, content in outputs.items() if not path.is_file() or path.read_text(encoding="utf-8") != content]
        if stale:
            print("索引需要更新：" + ", ".join(stale))
            return 1
    else:
        output.mkdir(parents=True, exist_ok=True)
        for path, content in outputs.items():
            path.write_text(content, encoding="utf-8", newline="\n")
    bad = sum(bool(item["inspection_error"]) for item in data["models"])
    missing = sum(d["status"] != "ok" for item in data["models"] for d in item["dependencies"])
    print(f"{len(data['packs'])} 素材包，{len(data['models'])} 筆 3D 模型；GLB 解析問題 {bad}，相依檔異常 {missing}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
