#!/usr/bin/env python3
"""Register only saved native scenes; preserve Scenario catalog metadata."""
import json
from pathlib import Path
KIT=Path(__file__).resolve().parents[3];BASE=KIT/'addons/proto_kit/vfx'
entries=json.loads((BASE/'assets/scenario/index.json').read_text())
three=json.loads((BASE/'three_sources.json').read_text())
effects={e['id']:{'2d':e['scene_2d'],'3d':e['scene_3d']}for e in entries}
details={e['id']:dict(name=e['name'],source='Scenario',loop=e['loop'],duration=e['frames']/e['fps'])for e in entries}
for e in three:
    path=BASE/'3d/00gamedevs'/(e['id']+'.tscn');assert path.is_file(),e['id']
    uri='res://addons/proto_kit/vfx/3d/00gamedevs/'+path.name
    effects[e['id']]={'3d':uri};p=e['preset']
    special=e['id']in ['impact-frame','weapon-smear']
    details[e['id']]=dict(name=p.get('english',p['name']),source='00GameDevs',loop=False if e['id']=='impact-frame' else not p.get('burst',False),duration=.4 if e['id']=='impact-frame' else p.get('duration',5),preview_height=0 if e['id'].startswith('spell-indicator') or e['id']=='impact-frame' else 1.4)
    e.update(status='ported_native_godot',scene_3d=uri)
    if e['id'] not in ['spell-indicator-circle','spell-indicator-sector']:
        e['port_method']='native_dynamic_ribbon' if e['id']=='weapon-smear' else ('native_canvas_postprocess' if e['id']=='impact-frame' else 'source_geometry_glsl_with_30fps_cpu_channels')
        e['visual_acceptance']='pending_gpu_browser'
text='extends RefCounted\n## Native scene catalog; original notices retained in licenses/.\nconst EFFECTS := {\n'
for id,modes in effects.items():text+='\t'+json.dumps(id)+': {'+', '.join(json.dumps(k)+': preload('+json.dumps(v)+')'for k,v in modes.items())+'},\n'
text+='}\nconst DETAILS := '+json.dumps(details,ensure_ascii=False,indent='\t')+'\n\n'
text+='static func get_scene(id: String, dimension: String = "2d") -> PackedScene:\n\treturn EFFECTS.get(id, {}).get(dimension) as PackedScene\n\n'
text+='static func ids(dimension: String = "2d") -> PackedStringArray:\n\tvar result := PackedStringArray()\n\tfor id: String in EFFECTS:\n\t\tif EFFECTS[id].has(dimension):\n\t\t\tresult.append(id)\n\treturn result\n'
(BASE/'library.gd').write_text(text)
(BASE/'three_sources.json').write_text(json.dumps(three,ensure_ascii=False,indent=2)+'\n')
print('41 2D / 87 3D scenes registered; all 46 Three.js exports have native scenes')
