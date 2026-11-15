"""Validate boss_meshy_refined.glb in a temporary Godot project without touching the game."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

here = Path(__file__).resolve().parent
with tempfile.TemporaryDirectory(prefix='boss-v2-check-') as temp:
    root = Path(temp)
    for filename in ('boss_meshy_refined.glb', 'validate_refined.gd'):
        shutil.copy2(here / filename, root / filename)
    (root / 'project.godot').write_text(
        'config_version=5\n[application]\nconfig/name="Boss model validation"\n'
        '[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding='utf-8')
    env = dict(os.environ, XDG_DATA_HOME=str(root / 'data'), XDG_CONFIG_HOME=str(root / 'config'))
    subprocess.run(['godot', '--headless', '--path', temp, '--editor', '--quit'], env=env, check=True)
    subprocess.run(['godot', '--headless', '--path', temp, '--script', 'res://validate_refined.gd'],
                   env=env, check=True)
