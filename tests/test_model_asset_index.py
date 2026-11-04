import importlib.util
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]
SCRIPT = REPO / "scripts" / "index_model_assets.py"
spec = importlib.util.spec_from_file_location("model_asset_index", SCRIPT)
indexer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(indexer)


def write_glb(path, document):
    payload = json.dumps(document).encode("utf-8")
    payload += b" " * ((-len(payload)) % 4)
    path.write_bytes(struct.pack("<4sII", b"glTF", 2, 20 + len(payload)) + struct.pack("<I4s", len(payload), b"JSON") + payload)


class ModelAssetIndexTests(unittest.TestCase):
    def test_triangle_count_follows_default_scene_and_instances(self):
        document = {
            "accessors": [{"count": 6}, {"count": 5}, {"count": 2}],
            "meshes": [{"primitives": [{"indices": 0}, {"attributes": {"POSITION": 1}, "mode": 5}]}],
            "nodes": [
                {"mesh": 0, "children": [1]},
                {"mesh": 0, "extensions": {"EXT_mesh_gpu_instancing": {"attributes": {"TRANSLATION": 2}}}},
                {"mesh": 0},
            ],
            "scenes": [{"nodes": [2]}, {"nodes": [0]}],
            "scene": 1,
        }
        self.assertEqual(indexer.triangle_count(document), 15)

    def test_external_texture_status_and_format_grouping(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory)
            pack = source / "kenney_survival-kit"
            glb_dir = pack / "Models" / "GLB format"
            glb_dir.mkdir(parents=True)
            (pack / "Models" / "OBJ format").mkdir()
            (pack / "Previews").mkdir()
            (pack / "License.txt").write_text("Creative Commons Zero, CC0", encoding="utf-8")
            (pack / "Previews" / "signpost.png").write_bytes(b"image")
            (pack / "Models" / "OBJ format" / "signpost.obj").write_text("", encoding="utf-8")
            document = {"asset": {"version": "2.0"}, "accessors": [{"count": 9}],
                        "meshes": [{"primitives": [{"indices": 0}]}],
                        "nodes": [{"mesh": 0}], "scenes": [{"nodes": [0]}],
                        "images": [{"uri": "Textures/colormap.png"}]}
            write_glb(glb_dir / "signpost.glb", document)
            missing = indexer.inventory(source)
            self.assertEqual(len(missing["models"]), 1)
            item = missing["models"][0]
            self.assertEqual(item["triangles"], 3)
            self.assertEqual(item["dependencies"][0]["status"], "missing")
            self.assertEqual(set(item["formats"]), {"glb", "obj"})
            self.assertEqual(missing["packs"][0]["license"], "CC0")
            self.assertTrue(item["town_candidate"])
            (glb_dir / "Textures").mkdir()
            (glb_dir / "Textures" / "colormap.png").write_bytes(b"image")
            self.assertEqual(indexer.inventory(source)["models"][0]["dependencies"][0]["status"], "ok")

    def test_regeneration_check_detects_stale_catalog_without_writing_source(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "library"
            (source / "pack").mkdir(parents=True)
            (source / "pack" / "License.txt").write_text("CC0", encoding="utf-8")
            output = root / "catalog"
            command = [sys.executable, str(SCRIPT), "--source", str(source), "--output", str(output)]
            subprocess.run(command, check=True, capture_output=True, text=True)
            before = (output / "index.html").read_text(encoding="utf-8")
            self.assertEqual(subprocess.run(command + ["--check"], capture_output=True).returncode, 0)
            (output / "models.tsv").write_text("stale", encoding="utf-8")
            self.assertEqual(subprocess.run(command + ["--check"], capture_output=True).returncode, 1)
            self.assertEqual((output / "index.html").read_text(encoding="utf-8"), before)
            self.assertEqual(sorted(p.name for p in (source / "pack").iterdir()), ["License.txt"])


if __name__ == "__main__":
    unittest.main()
