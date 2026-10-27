from pathlib import Path
import json, subprocess, sys

ROOT = Path(__file__).resolve().parent
FORGE = Path('/Users/peter/repo/agent-sprite-forge')
PYTHON = str(FORGE/'.venv/bin/python')
MASTER = str(FORGE/'skills/generate2dsprite/scripts/master_still.py')
CLASSES = ['shield','sword','spear','bow','mage','healer']
ACTIONS = {
    'run_a': 'running to the right, leaning forward, left leg forward and right leg pushing back, weapon carried',
    'run_b': 'running to the right, mid-stride with the legs swapped: right knee raised high, left leg back (clearly different legs from run_a)',
    'strike': 'the attack at full extension',
    'down': 'fallen: lying on the back on the ground, eyes closed, weapon dropped beside the body, body horizontal',
    'volley': 'all-out charge cry: weapon raised high overhead with both arms, chest out, mouth open shouting',
}
STRIKES = {
    'shield': 'bashing forward with the tower shield, sword raised behind it',
    'sword': 'a wide horizontal slash, longsword swept forward to the right',
    'spear': 'a full lunge, spear thrust straight forward to the right',
    'bow': 'bow fully drawn and aimed to the right, arrow nocked',
    'mage': 'staff thrust forward to the right, the crystal flaring bright',
    'healer': 'sun-ring staff raised forward, a soft golden glow around the ring',
}
KEEP = ('the EXACT SAME accepted human character identity as the FIRST image: same face, hairstyle, facial hair if any, '
        'accepted outfit and equipment, very light low-saturation cloth, weapon design, natural metal/leather/skin/hair colours, '
        'body proportions, standing-equivalent anatomical body scale and head size, detailed HD-2D pixel-art style, '
        'warm light from upper-left with cool shadows, elevated three-quarter camera about 45 degrees above; '
        'RIGHT-facing for every upright action. Preserve the actual accepted image including its headgear; do not redesign it')
CONTAIN = (' This is one single clear key pose for a character displayed only 40 pixels tall: exaggerate the action and use a bold readable silhouette. '
           'Change only the pose; keep the original head size and standing-equivalent body scale relative to the canvas, do not zoom the camera '
           'and do not shrink the character to fit long weapons. Keep the full body, hands, feet, clothing and every weapon tip inside the square '
           'canvas with generous safe margins, no clipping. Keep the lowest contacting foot near y=90% of canvas height, or the lowest BODY '
           'point at that same ground line for the fallen pose. No ground plate, floor, cast shadow, text, border, motion streaks, detached '
           'attack effects or dust cloud. Crystal or sun-ring glow must stay small and attached, with crisp opaque pixel clusters. '
           'Outside the complete subject use only the specified flat chroma-key colour.')

def generate(cls, action, mode='edit', attempt=1):
    reference = ROOT.parent/'hd2'/cls/'candidate-01.png'
    spec_path = ROOT/'inputs'/f'{cls}-spec.json'
    if not spec_path.exists():
        spec = json.loads((ROOT.parent/'hd2/inputs'/f'{cls}-generate-1/spec.json').read_text())
        for field in ['identity_ref','style_ref','extra']: spec[field] = None
        spec['name'] = 'hd2b-'+cls
        spec['subject'] = 'the exact accepted '+cls+' human hero from the FIRST image'
        spec['recap'] = spec['subject']
        spec['identity'] = KEEP
        spec_path.write_text(json.dumps(spec,indent=2)+'\n')
    change = ACTIONS[action]
    if action=='strike': change += ': '+STRIKES[cls]
    if action=='run_a': change += '; clearly extend the LEFT lead leg in front and the RIGHT leg behind, keep the feet visibly separated'
    if action=='run_b': change += '; clearly lift the RIGHT knee to the chest and kick the LEFT leg behind, use an unmistakably opposite leg phase from run_a'
    out = ROOT/'inputs'/f'{cls}-{action}-{mode}-{attempt}'
    if not (out/'run.json').exists():
        cmd = [PYTHON,MASTER,mode,'--spec',str(spec_path),'--name','hd2b-'+cls+'-'+action,
               '--route','codex-cli','--finish','pixel','--class','hero','--facing','right',
               '--key','green' if cls in ['sword','mage'] else 'magenta','--takes','1','--timeout','360',
               '--output-dir',str(out)]
        if mode=='edit': cmd += ['--still',str(reference),'--change',change+CONTAIN,'--keep',KEEP]
        else: cmd += ['--identity-ref',str(reference),'--identity-ref-what','the approved exact human hero identity and scale reference',
                      '--identity-copy',KEEP,'--pose',change,'--extra',CONTAIN]
        (out.parent/(out.name+'-command.json')).write_text(json.dumps(cmd,indent=2)+'\n')
        print('START '+out.name,flush=True)
        with (out.parent/(out.name+'.log')).open('w') as log:
            subprocess.run(cmd,cwd=FORGE,stdout=log,stderr=subprocess.STDOUT)
    if not (out/'run.json').exists():
        return {'class':cls,'action':action,'mode':mode,'attempt':attempt,'status':'fail','error':'no run.json; see log','run':str(out.relative_to(ROOT))}
    data = json.loads((out/'run.json').read_text())
    result = {'class':cls,'action':action,'mode':mode,'attempt':attempt,'status':data['status'],'run':str(out.relative_to(ROOT)),
              'seconds':sum(t['seconds'] for t in data.get('takes',[])),
              'errors':[t.get('error') for t in data.get('takes',[]) if t['status']!='ok']}
    print(json.dumps(result),flush=True)
    return result

def quota(result):
    return any(word in json.dumps(result).lower() for word in ['quota','usage limit','rate limit','insufficient','credit','limit reached'])

if __name__=='__main__':
    (ROOT/'inputs').mkdir(exist_ok=True)
    results=[]
    stop=False
    def persist(): (ROOT/'inputs/results.json').write_text(json.dumps({'stopped':stop,'results':results},indent=2)+'\n')
    for cls in CLASSES:
        for action in ACTIONS:
            result=generate(cls,action)
            results.append(result);persist()
            if quota(result): stop=True;break
            if result['status']!='ok':
                timeout='did not finish within' in json.dumps(result)
                if timeout:
                    result=generate(cls,action,attempt=2)
                    results.append(result);persist()
                    if quota(result): stop=True;break
                    if result['status']!='ok' and 'did not finish within' in json.dumps(result): continue
                if result['status']!='ok':
                    result=generate(cls,action,mode='generate')
                    results.append(result);persist()
                    if quota(result): stop=True;break
                    if result['status']!='ok' and 'did not finish within' in json.dumps(result):
                        result=generate(cls,action,mode='generate',attempt=2)
                        results.append(result);persist()
                    if quota(result): stop=True;break
            if result['status']=='ok':
                # Deterministic cleanup only; failed QC is recorded without another image generation.
                subprocess.run([PYTHON,str(ROOT/'prepare_delivery.py'),'--class',cls],cwd=ROOT,check=False)
        if stop: break
    persist()
    print('BATCH FINISHED '+json.dumps({'stopped':stop,'successful':sum(r['status']=='ok' for r in results)}),flush=True)
