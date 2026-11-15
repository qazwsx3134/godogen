"""Import the exported Boss in an isolated Godot project and test its clips."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

here=Path(__file__).resolve().parent
with tempfile.TemporaryDirectory(prefix='boss-animated-check-') as temporary:
    root=Path(temporary)
    for name in ('boss_animated.glb','validate_animation.gd'):
        shutil.copy2(here/name,root/name)
    (root/'project.godot').write_text(
        'config_version=5\n[application]\nconfig/name="Animated Boss validation"\n'
        '[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
    env=dict(os.environ,XDG_DATA_HOME=str(root/'data'),XDG_CONFIG_HOME=str(root/'config'))
    subprocess.run(['godot','--headless','--path',temporary,'--editor','--quit'],env=env,check=True)
    subprocess.run(['godot','--headless','--path',temporary,'--script','res://validate_animation.gd'],
                   env=env,check=True)
