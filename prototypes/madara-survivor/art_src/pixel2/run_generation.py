from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, wait, FIRST_COMPLETED
import json, subprocess
ROOT=Path('/Users/peter/repo/godot/godogen/prototypes/madara-survivor/art_src/pixel2')
P=ROOT/'inputs'
def run(name):
 print('START '+name,flush=True)
 cmd=json.loads((P/f'{name}-command.json').read_text())
 with (P/f'{name}-generation.log').open('w') as log:
  proc=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT)
 d=ROOT/name
 result=json.loads((d/'run.json').read_text()) if (d/'run.json').exists() else {}
 good=sum(t.get('status')=='ok' for t in result.get('takes',[]))
 record={'pose':name,'exit':proc.returncode,'status':result.get('status'),'successful_takes':good,'command':'edit'}
 (P/f'{name}-result.json').write_text(json.dumps(record,indent=2)+'\n')
 print('FINISH '+json.dumps(record),flush=True)
 return proc.returncode==0 and good==1
names=iter(['idle','run_a','run_b','punch','kick','fan','seal'])
ok=True
with ThreadPoolExecutor(max_workers=2) as pool:
 pending={pool.submit(run,next(names)) for _ in range(2)}
 while pending:
  done,pending=wait(pending,return_when=FIRST_COMPLETED)
  for f in done:
   if not f.result():ok=False
  if ok:
   for _ in done:
    name=next(names,None)
    if name:pending.add(pool.submit(run,name))
raise SystemExit(0 if ok else 1)
