#!/usr/bin/env python3
"""Build the offline HTML sprite viewer and an actual Godot Web export.
Writes only kit/build/showcase and kit/build/vfx-showcase.zip; no publication.
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile

KIT=Path(__file__).resolve().parents[2]
VFX=KIT/'addons/proto_kit/vfx'
OUT=KIT/'build/showcase'

def run(args, env, log):
    result=subprocess.run(args,env=env,capture_output=True,text=True,timeout=180)
    text=result.stdout+result.stderr
    log.write_text(text)
    # Editor sandbox TCP errors are separate; parser/shader/export errors fail the build.
    bad=any(x in text for x in ['SCRIPT ERROR','SHADER ERROR','Parse Error','Failed to export','Error exporting'])
    if result.returncode or bad:
        raise RuntimeError(f'Command failed; inspect {log}')

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    (KIT/'build/.gdignore').touch()
    for name in ['index.html','styles.css','player.js','app.js','serve.py']:
        shutil.copy2(KIT/'showcase'/name,OUT/name)
    data=json.loads((VFX/'assets/scenario/index.json').read_text())
    assets=OUT/'assets';assets.mkdir(exist_ok=True)
    for entry in data:
        source=VFX/'assets/scenario'/entry['id']
        atlas=json.loads((source/(entry['id']+'.json')).read_text())
        entry['rects']=[frame['frame'] for frame in atlas['frames']]
        for ext in ['.png','.recipe.json']:
            shutil.copy2(source/(entry['id']+ext),assets/(entry['id']+ext))
    (OUT/'data.js').write_text('window.VFX_DATA = '+json.dumps(data,ensure_ascii=False)+';\n')
    godot=os.environ.get('GODOT_BIN','godot')
    version=subprocess.check_output([godot,'--version'],text=True).strip().split('.official')[0]
    templates=Path(os.environ.get('XDG_DATA_HOME',str(Path.home()/'.local/share')))/'godot/export_templates'/version
    template=templates/'web_nothreads_release.zip'
    if not template.is_file():
        raise FileNotFoundError(f'Matching Godot Web template missing: {template}')
    with tempfile.TemporaryDirectory(prefix='vfx-showcase-') as temporary:
        stage=Path(temporary);addon=stage/'addons/proto_kit';addon.mkdir(parents=True)
        shutil.copytree(VFX,addon/'vfx',ignore=shutil.ignore_patterns('*.import'))
        for path in (KIT/'addons/proto_kit').glob('pixel_vfx*'):
            if path.is_file():shutil.copy2(path,addon/path.name)
        (stage/'project.godot').write_text('''config_version=5
[application]
config/name="Godogen VFX Showcase"
run/main_scene="res://addons/proto_kit/vfx/showcase.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")
[display]
window/size/viewport_width=1100
window/size/viewport_height=650
window/stretch/mode="canvas_items"
[rendering]
renderer/rendering_method="gl_compatibility"
textures/default_filters/use_nearest_mipmap_filter=false
''')
        (stage/'export_presets.cfg').write_text('''[preset.0]
name="Web"
platform="Web"
runnable=true
export_filter="all_resources"
include_filter="*.json,*.txt"
exclude_filter=""
script_export_mode=2
[preset.0.options]
custom_template/release="'''+str(template)+'''"
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=true
html/export_icon=false
html/canvas_resize_policy=2
html/focus_canvas_on_start=false
progressive_web_app/enabled=false
''')
        env=dict(os.environ,XDG_DATA_HOME=str(stage/'userdata'),XDG_CONFIG_HOME=str(stage/'config'))
        isolated_templates=stage/'userdata/godot/export_templates'/version
        isolated_templates.mkdir(parents=True)
        shutil.copy2(template,isolated_templates/template.name)
        run([godot,'--headless','--path',str(stage),'--editor','--quit'],env,KIT/'build/showcase-import.log')
        engine=OUT/'godot';engine.mkdir(exist_ok=True)
        run([godot,'--headless','--path',str(stage),'--export-pack','Web',str(engine/'index.pck')],env,KIT/'build/showcase-export.log')
        # Use the exact-version official release runtime. export-pack requires no debug template.
        with zipfile.ZipFile(template) as runtime:
            print('Runtime members:', runtime.namelist())
            for member, output in [('godot.js','index.js'),('godot.wasm','index.wasm'),('godot.audio.worklet.js','index.audio.worklet.js'),('godot.audio.position.worklet.js','index.audio.position.worklet.js')]:
                (engine/output).write_bytes(runtime.read(member))
        (engine/'index.html').write_text('''<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Godot VFX preview</title><style>html,body{margin:0;width:100%;height:100%;background:#171d1b;color:#dce7dd;font:14px system-ui}canvas{display:block;width:100%;height:100%}#status{position:absolute;inset:0;display:grid;place-content:center;text-align:center;pointer-events:none}</style></head><body><canvas id="canvas" aria-label="Godot effect preview"></canvas><div id="status">Starting Godot…</div><script src="index.js"></script><script>
const status=document.getElementById('status');
const engine=new Engine({executable:'index',mainPack:'index.pck',canvasResizePolicy:2,focusCanvas:false,gdextensionLibs:[],args:[]});
engine.startGame({canvas:document.getElementById('canvas'),onProgress:(loaded,total)=>{status.textContent=total?'Loading Godot '+Math.round(loaded/total*100)+'%':'Loading Godot…'}}).then(()=>{status.remove()},error=>{status.textContent='Godot could not start: '+error.message;console.error(error)});
</script></body></html>''')
        for required in ['index.html','index.js','index.wasm','index.pck']:
            assert (engine/required).stat().st_size>0,required
    # Preserve license notices in the portable website package, outside the PCK too.
    shutil.copytree(VFX/'licenses',OUT/'licenses',dirs_exist_ok=True)
    license_text=(VFX/'assets/scenario/cinder-explosion/README.txt').read_text()
    (OUT/'licenses/Scenario-export-README.txt').write_text(license_text)
    package=KIT/'build/vfx-showcase.zip'
    with zipfile.ZipFile(package,'w',zipfile.ZIP_DEFLATED) as archive:
        for file in sorted(OUT.rglob('*')):
            if file.is_file():archive.write(file,file.relative_to(OUT))
    print(f'{len(data)} sprites + native Godot Web export: {OUT}')
    print(f'ZIP: {package} ({package.stat().st_size:,} bytes)')
    print('SHA256:',hashlib.sha256(package.read_bytes()).hexdigest())

if __name__=='__main__':main()
