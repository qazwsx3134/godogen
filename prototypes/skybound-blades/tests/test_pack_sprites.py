"""Native-alpha art must work without the legacy, machine-local matte tool."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

from PIL import Image

spec = importlib.util.spec_from_file_location(
    "pack_sprites", Path(__file__).resolve().parents[1] / "tools/pack_sprites.py"
)
packer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(packer)


class NativeAlphaTests(unittest.TestCase):
    def test_alpha_and_pink_material_survive(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "sprite.png"
            image = Image.new("RGBA", (3, 3), (0, 0, 0, 0))
            image.putpixel((1, 1), (255, 0, 255, 255))
            image.putpixel((1, 0), (200, 50, 70, 96))
            image.save(source)
            self.assertEqual(packer.keyed(source).tobytes(), image.tobytes())

    def test_fully_empty_frame_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "empty frame"):
            packer.bbox_crop(Image.new("RGBA", (3, 3)))


if __name__ == "__main__":
    unittest.main()
