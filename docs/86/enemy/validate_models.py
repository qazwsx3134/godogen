"""Import and test both shipped GLBs in an isolated Godot 4.7 project."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

here = Path(__file__).resolve().parent
with tempfile.TemporaryDirectory(prefix="enemy-model-check-") as temp:
    root = Path(temp)
    for name in ("melee", "tank"):
        shutil.copy2(here / name / f"{name}.glb", root / f"{name}.glb")
    shutil.copy2(here / "validate_models.gd", root / "validate_models.gd")
    if "--crowd" in sys.argv:
        shutil.copy2(here / "measure_crowd.gd", root / "measure_crowd.gd")
    (root / "project.godot").write_text(
        'config_version=5\n[application]\nconfig/name="Enemy model validation"\n'
        '[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding="utf-8")
    env = dict(os.environ, XDG_DATA_HOME=str(root / "data"), XDG_CONFIG_HOME=str(root / "config"))
    subprocess.run(["godot", "--headless", "--path", temp, "--editor", "--quit"], env=env, check=True)
    subprocess.run(["godot", "--headless", "--path", temp, "--script", "res://validate_models.gd"], env=env, check=True)
    if "--crowd" in sys.argv:
        command = ["godot", "--path", temp, "--resolution", "1280x720", "--disable-vsync",
                   "--script", "res://measure_crowd.gd"]
        if sys.platform.startswith("linux") and not env.get("DISPLAY"):
            if not shutil.which("xvfb-run"):
                raise RuntimeError("--crowd needs a display or xvfb-run")
            command = ["xvfb-run", "-a", *command]
        subprocess.run(command, env=env, check=True)
