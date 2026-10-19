from pathlib import Path
from concurrent.futures import ThreadPoolExecutor,as_completed
import json,re,subprocess,sys
ROOT=Path('/Users/peter/repo/godot/godogen/prototypes/madara-survivor/art_src/round2')
PYTHON='/Users/peter/repo/agent-sprite-forge/.venv/bin/python'
MASTER='/Users/peter/repo/agent-sprite-forge/skills/generate2dsprite/scripts/master_still.py'
REFERENCE='/Users/peter/repo/godot/godogen/prototypes/madara-survivor/art_src/round1/madara/candidate-03.png'
POSES={
'idle':'calm standing idle, war fan held loosely at his side, slight lean back, arrogant',
'run-a':'running toward the lower-right, left leg forward, hair streaming behind, fan held back',
'run-b':'running toward the lower-right, right leg forward, the opposite stride of run-a',
'punch':'a fast straight punch with the left fist toward the lower-right, right hand holding the fan back',
'kick':'a powerful high flying side kick toward the lower-right (combo finisher), body horizontal, hair flaring',
'fan-swing':'a wide horizontal sweep of the war fan with both hands toward the lower-right, motion arc implied by the pose, no motion lines',
'seal':'both hands forming the tiger hand seal in front of his chest, fan tucked under his arm, eyes intense'}
ROOT.joinpath('inputs').mkdir(exist_ok=True)
art=Path('/Users/peter/repo/godot/godogen/prototypes/madara-survivor/docs/art-spec.md').read_text()
COMMON=re.findall(r'```text\n(.*?)\n```',art,re.S)[0]
IDENTITY='The exact same Uchiha Madara as the FIRST attached identity reference: the same pale sharp face, visible red Sharingan eye, waist-length wild spiky black hair with the same long fringe covering his right eye; identical segmented crimson-red armour including chest plates, large shoulder guards and skirt panels, identical dark navy high-collared clothes and trousers, white shin bandages and black ninja sandals. The exact same cream-white war fan with a single red circle, black rim and wooden handle. Preserve the anime cel-shaded treatment, thick dark outlines, palette, costume construction and anatomical proportions. Only the requested pose and the physically necessary positions of limbs, hair, armour panels and fan change; do not copy the standing idle pose.'
(ROOT/'inputs/identity.txt').write_text(IDENTITY+'\n')
(ROOT/'inputs/poses.json').write_text(json.dumps(POSES,indent=2)+'\n')

def generate(name):
 if(ROOT/name).exists():return {'name':name,'status':'blocked','error':'output exists'}
 extra=COMMON+'\n\nUse the FIRST attached image for identity, palette, linework and standing-equivalent anatomical scale only; the required pose overrides its old pose. Show exactly one isolated character, including every hand, foot, hair tip and the entire war fan, with safe padding on every side. No motion streaks, no detached attack effects, no afterimages, no cast shadow. Preserve the 42 degree elevated view and lower-right body direction; do not turn toward the upper-right or make a flat side-profile camera.'
 if name=='run-a':extra+=' Anatomical LEFT leg reaches forward toward the lower-right; the RIGHT leg trails. Make this stride unambiguous.'
 if name=='run-b':extra+=' Anatomical RIGHT leg reaches forward toward the lower-right; the LEFT leg trails, the exact opposite stride of run-a. Hair streams behind; hold the fan back.'
 if name=='kick':extra+=' This pose is airborne, overriding the common standing/grounded wording: torso approximately horizontal, one leg fully extended in a strong side kick to the lower-right, the other leg bent. Retain the war fan securely in the trailing hand and keep all extremities inside the canvas. No ground contact or floor.'
 if name=='seal':extra+=' The right hand must be free to join the left in the tiger seal: hold the fan under the arm, not in either hand. Both index and middle fingers extend together with the other fingers interlocked.'
 cmd=[PYTHON,MASTER,'generate','--name','madara-'+name,'--subject','Uchiha Madara, a single full-body character','--identity-file',str(ROOT/'inputs/identity.txt'),'--identity-ref',REFERENCE,'--identity-ref-what','the user-selected Madara identity master still, not a pose template','--identity-copy','the exact face, waist-length spiky hair and right-eye fringe, segmented crimson armour, navy clothes, white shin wraps, sandals, cream-white red-circle fan, cel shading, thick ink outlines and body proportions; change only the pose', '--recap','Uchiha Madara in crimson segmented armour with long spiky black hair and a white-and-red war fan','--pose',POSES[name],'--extra',extra,'--finish','hd','--facing','right','--view','elevated three-quarter overhead view about 42 degrees, body turned diagonally toward the lower-right','--class','hero','--key','green','--takes','2','--route','codex-cli','--output-dir',str(ROOT/name)]
 (ROOT/'inputs'/f'{name}-command.json').write_text(json.dumps(cmd,indent=2)+'\n')
 print('START '+name,flush=True)
 with(ROOT/'inputs'/f'{name}-generation.log').open('w')as log:p=subprocess.run(cmd,cwd='/Users/peter/repo/agent-sprite-forge',stdout=log,stderr=subprocess.STDOUT)
 record={'name':name,'exit_code':p.returncode};run=ROOT/name/'run.json'
 if run.exists():
  d=json.loads(run.read_text());record.update(status=d.get('status'),takes=[t.get('status')for t in d.get('takes',[])])
 print('FINISH '+json.dumps(record),flush=True);return record
if __name__=='__main__':
 results=[]
 with ThreadPoolExecutor(max_workers=3)as pool:
  for f in as_completed([pool.submit(generate,n)for n in POSES]):results.append(f.result())
 (ROOT/'inputs/generation-results.json').write_text(json.dumps(results,indent=2)+'\n')
 sys.exit(0 if all(r.get('status')=='ok'for r in results)else 1)
