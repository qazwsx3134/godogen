#!/usr/bin/env python3
"""Generate numerical test oracles from original JS snapshots, not Godot output."""
import hashlib,json,sys
from pathlib import Path
kit=Path(__file__).resolve().parents[3];root=kit.parents[1]
source=Path(sys.argv[1]);packed=Path(sys.argv[2]);result=[]
for file in sorted(source.glob('*.json')):
 if file.name=='stats.json':continue
 d=json.loads(file.read_text());g=json.loads((packed/file.stem/'data.json').read_text())
 entry={k:d[k]for k in ['id','preset','lifecycle','fps']};entry['meshes']=[]
 entry['source_sha256']=hashlib.sha256((root/'vfx-example/three-effect'/f'{d["id"]}.js').read_bytes()).hexdigest()
 for m in d['meshes']:
  converted=g['meshes'][m['index']];i=m['indices'][0]if m['indices']else 0
  extra={}
  for name,a in m['attributes'].items():
   if name in ['position','normal','uv']:continue
   at=0 if a['instanced']else i*a['size'];extra[name]=a['array'][at:at+a['size']]
  entry['meshes'].append(dict(index=m['index'],name=m['name'],vertices=converted['vertex_count'],first_position=m['attributes']['position']['array'][i*3:i*3+3],layout=converted['layout'],extra=extra,first_triangle=[m['attributes']['position']['array'][j*3:j*3+3]for j in (m['indices'][:3]if m['indices']else range(3))],render_order=m['material'].get('renderOrder',0),blending=m['material']['blending'],always_opaque=all(not s[m['index']]['transparent']for s in d['samples'])))
 frames=sorted(set([0,min(3,len(d['samples'])-1),min(12,len(d['samples'])-1),min(30,len(d['samples'])-1),min(60,len(d['samples'])-1)]))
 entry['reference']=[{'time':f/d['fps'],'meshes':d['samples'][f]}for f in frames]
 if d['ending']:entry['ending_reference']=d['ending'][len(d['ending'])//2];entry['ending_time']=(len(d['ending'])//2)/d['fps']
 result.append(entry)
out=kit/'tests/fixtures/three_reference.json';out.parent.mkdir(exist_ok=True);out.write_text(json.dumps(result,separators=(',',':')))
print('Original JS reference:',len(result),'effects;',out.stat().st_size,'bytes')
