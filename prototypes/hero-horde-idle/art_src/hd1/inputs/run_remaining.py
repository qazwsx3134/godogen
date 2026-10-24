from pathlib import Path
import json, re, subprocess, sys

ROOT = Path(__file__).resolve().parent.parent
PYTHON = '/Users/peter/repo/agent-sprite-forge/.venv/bin/python'
MASTER = '/Users/peter/repo/agent-sprite-forge/skills/generate2dsprite/scripts/master_still.py'
COMMON = re.findall(r'```text\n(.*?)\n```', (ROOT/'BRIEF.md').read_text(), re.S)[0]
PROP_EXTRA = ('For this object image, the shared style describes pixel shading, palette, outlines and camera only: '
              'ignore its humanoid proportions, head count, standing pose and feet clauses. Do not draw any person or creature. '
              'Draw only the requested object, completely contained with safe margins, no ground plate or cast shadow. '
              'No smooth vector or anime illustration. The flat key colour outside the object is the chroma-key backdrop.')
PROPS = [
    ('pine', 'a tall dark-green mountain pine tree, layered needle clusters, visible trunk base'),
    ('oak', 'a broad leafy deciduous tree with warm autumn-touched green canopy and a thick trunk'),
    ('boulder', 'one large mossy grey granite boulder'),
    ('pillar', 'one broken ancient stone column, fluted, cracked top, ivy at the base'),
    ('gate', 'a ruined ancient stone fortress archway gate, wide and imposing, missing stones, dark opening, moss and hanging vines'),
    ('brazier', 'a stone brazier on a short pedestal with a bright orange fire burning'),
    ('banner', 'a tattered war banner on a wooden pole, deep navy cloth with a faded gold sun emblem (original, not any real crest)'),
    ('fern', 'a small cluster of ferns and tall grass tufts with a few tiny white flowers'),
]

def run(name, number, description, recap, key, cls, facing, extra):
    for attempt in (1, 2):
        out = ROOT/'inputs'/f'{name.replace("/", "-")}-{number:02d}-attempt{attempt}'
        if out.exists():
            data = json.loads((out/'run.json').read_text())
        else:
            cmd = [PYTHON, MASTER, 'generate', '--name', 'hd1-'+name.replace('/', '-'),
                   '--subject', recap, '--identity', description+'\n\n'+COMMON,
                   '--recap', recap, '--extra', extra, '--finish', 'pixel', '--facing', facing,
                   '--view', 'elevated three-quarter view about 45 degrees above',
                   '--class', cls, '--key', key, '--takes', '1', '--timeout', '360',
                   '--route', 'codex-cli', '--output-dir', str(out)]
            if cls == 'hero': cmd += ['--pose', 'standing idle, menacing']
            if name.endswith('banner'): cmd += ['--allowed-text', 'one faded gold sun emblem, no lettering']
            (out.parent/(out.name+'-command.json')).write_text(json.dumps(cmd, indent=2)+'\n')
            print('START '+out.name, flush=True)
            with (out.parent/(out.name+'.log')).open('w') as log:
                p = subprocess.run(cmd, cwd='/Users/peter/repo/agent-sprite-forge', stdout=log, stderr=subprocess.STDOUT)
            if not (out/'run.json').exists():
                print('STOP: generator did not publish run.json; see '+str(out)+'.log', flush=True)
                return False
            data = json.loads((out/'run.json').read_text())
        print('RESULT '+out.name+' '+data['status'], flush=True)
        if data['status'] == 'ok': return True
        error = json.dumps(data.get('takes', []))
        if ('did not finish within' in error or 'nothing was run' in error) and attempt == 1:
            print('TIMEOUT: retry once', flush=True)
            continue
        if 'did not finish within' in error:
            print('SKIP: second timeout', flush=True)
            return True
        print('STOP: '+error, flush=True)
        return False
    return True

if __name__ == '__main__':
    recap = 'a hulking grey-green horned mountain troll with tusks, an iron-plate harness and a huge spiked wooden club'
    desc = ('hulking grey-green mountain troll about three times human height, hunched broad shoulders, two curved ivory horns, '
            'small glowing amber eyes, tusked underbite, crude leather-and-iron-plate harness, carrying a huge spiked wooden club resting on one shoulder.')
    for n in (1, 2, 3):
        if not run('boss', n, desc, recap, 'magenta', 'hero', 'left',
                   'The entire body, face, gaze and chest face LEFT toward the heroes. Full body, both horns, both feet and the complete club inside the image with generous safe margins. The flat magenta outside the subject is only the chroma-key backdrop.'):
            sys.exit(1)
    for name, desc in PROPS:
        if not run('props/'+name, 1, desc, desc, 'green' if name == 'brazier' else 'magenta', 'prop', 'none', PROP_EXTRA):
            sys.exit(1)
