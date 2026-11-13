"""Import the rebuilt Phido into an isolated Godot project and validate it."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

here = Path(__file__).resolve().parent
with tempfile.TemporaryDirectory(prefix="phido-lowpoly-check-") as temp:
    root = Path(temp)
    shutil.copy2(here / "phido_lowpoly.glb", root / "model.glb")
    shutil.copy2(here / "verify.gd", root / "verify.gd")
    (root / "project.godot").write_text(
        'config_version=5\n[application]\nconfig/name="Phido low-poly validation"\n'
        '[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding="utf-8")
    env = dict(os.environ, XDG_DATA_HOME=str(root / "data"), XDG_CONFIG_HOME=str(root / "config"))
    subprocess.run(["godot", "--headless", "--path", temp, "--editor", "--quit"], env=env, check=True)
    subprocess.run(["godot", "--headless", "--path", temp, "--script", "res://verify.gd"], env=env, check=True)
