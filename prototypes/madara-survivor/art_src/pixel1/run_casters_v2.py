from pathlib import Path
import json, subprocess
from concurrent.futures import ThreadPoolExecutor
ROOT=Path('/Users/peter/repo/godot/godogen/prototypes/madara-survivor/art_src/pixel1')
P=ROOT/'inputs'/'casters-v2'
def run(e):
 cmd=json.loads((P/f'{e}-command.json').read_text())
 print('START '+e,flush=True)
 with (P/f'{e}-generation.log').open('w') as log:
  proc=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT)
 d=ROOT/f'caster-{e}'
 record=json.loads((d/'run.json').read_text()) if (d/'run.json').exists() else {}
 good=sum(t.get('status')=='ok' for t in record.get('takes',[]))
 result={'element':e,'exit':proc.returncode,'status':record.get('status'),'successful_takes':good}
 (P/f'{e}-result.json').write_text(json.dumps(result,indent=2)+'\n')
 print('FINISH '+json.dumps(result),flush=True)
 return proc.returncode==0 and good==2
with ThreadPoolExecutor(max_workers=2) as pool:
 a=pool.submit(run,'fire'); b=pool.submit(run,'water')
 ok=a.result() and b.result()
 if ok:ok=run('earth')
raise SystemExit(0 if ok else 1)
