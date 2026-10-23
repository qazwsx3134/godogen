from pathlib import Path
import json, re, subprocess, sys

ROOT=Path(__file__).resolve().parent
FORGE=Path('/Users/peter/repo/agent-sprite-forge')
PYTHON=str(FORGE/'.venv/bin/python')
MASTER=str(FORGE/'skills/generate2dsprite/scripts/master_still.py')
BLOCKS=re.findall(r'```text\n(.*?)\n```',(ROOT/'BRIEF.md').read_text(),re.S)
STYLE,FORM=BLOCKS
TEAMS={
 'melee':('green','bright crimson red cloth, emblem: a white crossed sword over a round shield',
          'a tall crimson war banner with a white crossed sword and shield emblem on a dark wooden pole'),
 'ranged':('magenta','bright azure blue cloth, emblem: a white drawn bow crossed with a mage staff',
           'a tall azure war banner with a white drawn bow crossed with a mage staff emblem on a dark wooden pole'),
 'support':('magenta',"warm golden yellow cloth, emblem: a white radiant sun ring (the same sun-ring shape as the healer's staff head)",
            'a tall golden-yellow war banner with a white radiant sun-ring emblem on a dark wooden pole'),
}
EXTRA=('For this prop, the shared style describes pixel shading, outlines, light direction and elevated camera only; '
       'do not draw a person or creature. This is a NEW, clean, bright friendly-army command banner, not an old tattered '
       'navy background decoration: saturated team colour, intact fabric, no weathering, no tears. '
       'The cloth hangs vertically from the short upper crossbar, with a clear TWO-POINTED SWALLOWTAIL hem, thin gold trim, '
       'and exactly one large bold WHITE team emblem centered on the cloth. Simplify the emblem to a few strong shapes, '
       'outlined in dark slate so it stays legible even white against golden-yellow cloth at only 96 pixels tall. '
       'Do not draw any words, letters or numbers. All parts completely contained with safe margins. '
       'The wooden pole is straight and vertical with one plain iron spike at the bottom, no stand or ground plate. '
       'For this first frame the lower cloth gently curves slightly RIGHT; leave clear empty margin to both sides for the other animation frame. '
       'The sun-ring motif, when requested, is an eight-rayed round ring with a small central round disc and alternating long and short pointed rays, '
       'matching the cleric staff motif but rendered as one simple WHITE cloth emblem, not a gold staff or human figure. '
       'No cast shadow or glow on the flat chroma-key backdrop.')
CHANGE=('the cloth flutters the other way in the breeze: its swallowtail end swings slightly to the left and the folds shift; '
        'the pole, finial, crossbar, emblem, colours and size stay exactly the same')
KEEP=('the exact same banner design, upright dark wooden pole, brass spear-tip finial, short crossbar, plain bottom iron spike, '
      'single white emblem and its exact shape, bright cloth colour, thin gold trim, two swallowtail tips, pixel-art style, '
      'warm upper-left light and cool shadows, elevated 45-degree camera, same dimensions and same pole position. '
      'Do not move or bend the pole; do not redesign, mirror or replace the emblem; only the cloth and its folds move')

def invoke(team,frame,attempt):
 key,colours,recap=TEAMS[team]
 mode='generate' if frame=='frame_a' else 'edit'
 out=ROOT/'inputs'/f'{team}-{frame}-{attempt}'
 if not (out/'run.json').exists():
  cmd=[PYTHON,MASTER,mode,'--name','flags-'+team+'-'+frame,'--subject',recap,
       '--identity',FORM+'\n\n'+STYLE+'\n\n'+colours,'--recap',recap,
       '--route','codex-cli','--finish','pixel','--class','prop','--facing','none',
       '--key',key,'--takes','1','--timeout','360','--view','elevated three-quarter view about 45 degrees above',
       '--allowed-text','one simple white team emblem only; absolutely no lettering',
       '--output-dir',str(out)]
  if mode=='generate':cmd+=['--extra',EXTRA]
  else:cmd+=['--still',str(ROOT/team/'frame_a/candidate-01.png'),'--change',CHANGE,'--keep',KEEP]
  (out.parent/(out.name+'-command.json')).write_text(json.dumps(cmd,indent=2)+'\n')
  print('START '+out.name,flush=True)
  with (out.parent/(out.name+'.log')).open('w') as log:
   subprocess.run(cmd,cwd=FORGE,stdout=log,stderr=subprocess.STDOUT)
 if not (out/'run.json').exists():
  return {'team':team,'frame':frame,'attempt':attempt,'status':'fail','error':'no run.json; see log'}
 data=json.loads((out/'run.json').read_text())
 result={'team':team,'frame':frame,'attempt':attempt,'mode':mode,'status':data['status'],
         'run':str(out.relative_to(ROOT)),'seconds':sum(t['seconds'] for t in data.get('takes',[])),
         'errors':[t.get('error') for t in data.get('takes',[]) if t['status']!='ok']}
 print(json.dumps(result),flush=True)
 return result

if __name__=='__main__':
 (ROOT/'inputs').mkdir(exist_ok=True)
 results=[];stopped=False
 def persist(): (ROOT/'inputs/results.json').write_text(json.dumps({'stopped':stopped,'results':results},indent=2)+'\n')
 for team in TEAMS:
  for frame in ['frame_a','frame_b']:
   for attempt in [1,2]:
    result=invoke(team,frame,attempt);results.append(result);persist()
    if result['status']=='ok':break
    if 'did not finish within' not in json.dumps(result):stopped=True;break
   if stopped:break
   if result['status']!='ok':break
   p=subprocess.run([PYTHON,str(ROOT/'prepare_delivery.py'),'--team',team],cwd=ROOT)
   if p.returncode!=0:stopped=True;break
  if stopped:break
 persist()
 print('BATCH FINISHED '+json.dumps({'stopped':stopped,'successful':sum(r['status']=='ok' for r in results)}),flush=True)
