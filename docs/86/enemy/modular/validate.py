"""Import the assemblies and compare their animation to the originals in Godot."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

here = Path(__file__).resolve().parent
enemy = here.parent
with tempfile.TemporaryDirectory(prefix="enemy-modular-check-") as temp:
    root = Path(temp)
    for name in ("melee", "tank"):
        shutil.copy2(here / f"{name}_reassembled.glb", root / f"{name}.glb")
        shutil.copy2(enemy / name / f"{name}.glb", root / f"{name}_original.glb")
    shutil.copy2(enemy / "validate_models.gd", root / "validate_models.gd")
    shutil.copy2(here / "compare_animation.gd", root / "compare_animation.gd")
    (root / "project.godot").write_text(
        'config_version=5\n[application]\nconfig/name="Modular enemy validation"\n'
        '[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding="utf-8")
    env = dict(os.environ, XDG_DATA_HOME=str(root / "data"), XDG_CONFIG_HOME=str(root / "config"))
    subprocess.run(["godot", "--headless", "--path", temp, "--editor", "--quit"], env=env, check=True)
    for script in ("validate_models.gd", "compare_animation.gd"):
        subprocess.run(["godot", "--headless", "--path", temp, "--script", f"res://{script}"],
                       env=env, check=True)
