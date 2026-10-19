from pathlib import Path
import json,subprocess,sys,time
from concurrent.futures import ThreadPoolExecutor,as_completed
ROOT=Path('/Users/peter/repo/godot/godogen/prototypes/madara-survivor/art_src/round1')
PYTHON='/Users/peter/repo/agent-sprite-forge/.venv/bin/python'
MASTER='/Users/peter/repo/agent-sprite-forge/skills/generate2dsprite/scripts/master_still.py'

def generate(name):
 spec=json.loads((ROOT/'inputs'/f'{name}.json').read_text())
 if (ROOT/name).exists():return {'name':name,'error':'output already exists'}
 cmd=[PYTHON,MASTER,'generate','--name',name,'--subject',spec['recap']+', full body','--identity-file',str(ROOT/'inputs'/f'{name}.txt'),'--recap',spec['recap'],'--extra',spec['extra'],'--finish','hd','--facing','right','--takes','3','--view','elevated three-quarter overhead view about 42 degrees, body turned diagonally toward the lower-right','--class',spec['class'],'--key',spec['key'],'--route','codex-cli','--output-dir',str(ROOT/name)]
 if name in ['caster-water','caster-earth']:
  cmd += ['--identity-ref',str(ROOT/'inputs/caster-body-reference.png'),'--identity-ref-what','the fire caster candidate, a body-build and costume-cut reference for this elemental variant','--identity-copy',
          'the face, hair, body build, limb proportions, pose and sleeveless-coat shape; use the coat colour and hand-chakra element specified in the written identity instead of the reference fire palette']
 print('START '+name,flush=True)
 with (ROOT/'inputs'/f'{name}-generation.log').open('w')as log:
  p=subprocess.run(cmd,cwd='/Users/peter/repo/agent-sprite-forge',stdout=log,stderr=subprocess.STDOUT)
 record={'name':name,'exit_code':p.returncode}
 run=ROOT/name/'run.json'
 if run.exists():
  d=json.loads(run.read_text());record['status']=d.get('status');record['takes']=[v.get('status')for v in d.get('takes',[])]
 print('FINISH '+json.dumps(record),flush=True)
 return record

if __name__=='__main__':
 names=sys.argv[1:];results=[]
 with ThreadPoolExecutor(max_workers=2)as pool:
  futures={pool.submit(generate,name):name for name in names}
  for fut in as_completed(futures):
   r=fut.result();results.append(r)
   if r.get('status')in ['no-route','fail']:
    for f in futures:f.cancel()
 (ROOT/'inputs'/('generation-results-'+str(int(time.time()))+'.json')).write_text(json.dumps(results,indent=2)+'\n')
 sys.exit(0 if all(r.get('status')=='ok'for r in results)else 1)
