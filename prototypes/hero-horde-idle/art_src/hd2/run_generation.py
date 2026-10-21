from pathlib import Path
import json, re, subprocess, sys

ROOT = Path(__file__).resolve().parent
FORGE = Path('/Users/peter/repo/agent-sprite-forge')
PYTHON = str(FORGE/'.venv/bin/python')
MASTER = str(FORGE/'skills/generate2dsprite/scripts/master_still.py')
REFERENCE = ROOT.parent/'hd1/boss/candidate-01.png'
COMMON = re.findall(r'```text\n(.*?)\n```', (ROOT/'BRIEF.md').read_text(), re.S)[0]
SPECS = {
    'shield': ('magenta', 'a stout shield knight with a large rectangular tower shield held in front and a short sword, steel half-plate over a light tabard, open-faced helmet'),
    'sword': ('green', 'a swordsman with a longsword held in both hands, light gambeson coat with a short cape, leather boots, no helmet, short hair'),
    'spear': ('magenta', 'a lancer with a long spear angled forward, light padded coat, round bracers, a simple bandana'),
    'bow': ('magenta', 'an archer with a longbow and a quiver on the back, light hooded short cloak, leather bracer'),
    'mage': ('green', 'a mage with a wooden staff topped by a softly glowing crystal, light long robe with a hood down, a small spellbook on the belt'),
    'healer': ('magenta', 'a cleric healer with a short staff ending in a golden sun ring, light flowing robe with a stole, a small satchel'),
}
STYLE_COPY = ('ONLY the HD-2D pixel-art texture, hand-placed shading, crisp dark outline, warm upper-left dusk light, '
              'cool shadows and elevated 45-degree camera. This image is NOT the subject identity: do NOT copy '
              'its troll anatomy, horns, tusks, green skin, hulking body, armour design, club, pose or left-facing direction. '
              'Draw the new HUMAN class described by the text, facing RIGHT, about 3.5 heads tall.')
EXTRA = ('The FIRST image is strictly a STYLE reference, never a character identity reference. Draw exactly ONE HUMAN hero, '
         'compact heroic proportions about 3.5 heads tall, consistent with a six-class set. All cloth is very light, '
         'low-saturation off-white, pale grey or cream, including tabards, padded coats, cloaks, bandanas, robes and stoles; '
         'no strongly coloured fabric. Metal, leather, skin and hair keep natural colours. '
         'Lock the camera about 45 degrees above, face and body RIGHT. Keep the same standing-equivalent human body height '
         'and head size across classes. On the square canvas, the soles are near y=90%, the crown of the head near y=26%, '
         'leaving room above for raised weapon tips. Keep the whole body, shield, quiver, staff, spear and all weapon tips '
         'inside the canvas with safe margins. Long weapons must not make the human smaller. No ground plate or cast shadow. '
         'Use the specified flat key backdrop everywhere outside the subject; retain opaque pixel art for any crystal glow.')

def run(name, key, desc, takes=2, suffix='generate', attempt=1):
    out = ROOT/'inputs'/f'{name}-{suffix}-{attempt}'
    out.parent.mkdir(exist_ok=True)
    if not (out/'run.json').exists():
        cmd = [PYTHON, MASTER, 'generate', '--name', 'hd2-'+name, '--subject', desc,
               '--identity', desc+'\n\n'+COMMON, '--recap', desc, '--extra', EXTRA,
               '--identity-ref', str(REFERENCE), '--identity-ref-what', 'the same game world pixel-art STYLE reference ONLY; NOT the new human hero identity',
               '--identity-copy', STYLE_COPY, '--view', 'elevated three-quarter view about 45 degrees above, body and face turned RIGHT',
               '--route', 'codex-cli', '--finish', 'pixel', '--class', 'hero', '--key', key,
               '--facing', 'right', '--takes', str(takes), '--timeout', '360', '--output-dir', str(out)]
        (out.parent/(out.name+'-command.json')).write_text(json.dumps(cmd, indent=2)+'\n')
        print('START '+out.name, flush=True)
        with (out.parent/(out.name+'.log')).open('w') as log:
            subprocess.run(cmd, cwd=FORGE, stdout=log, stderr=subprocess.STDOUT)
    if not (out/'run.json').exists():
        return {'name':name, 'status':'fail', 'error':'no run.json; see log', 'run':str(out.relative_to(ROOT))}
    data = json.loads((out/'run.json').read_text())
    result = {'name':name, 'status':data['status'], 'run':str(out.relative_to(ROOT)), 'takes':data.get('takes', [])}
    print(json.dumps(result), flush=True)
    return result

if __name__ == '__main__':
    results = []
    for name, (key, desc) in SPECS.items():
        result = run(name, key, desc)
        results.append(result)
        errors = json.dumps(result).lower()
        if any(s in errors for s in ['quota', 'usage limit', 'rate limit', 'insufficient', 'credit']): break
        fatal = False
        for take in result.get('takes', []):
            if take['status']=='ok': continue
            if 'did not finish within' in take.get('error',''):
                retry = run(name, key, desc, takes=1, suffix=f'retry-take{take["take"]}', attempt=1)
                results.append(retry)
                if retry['status'] != 'ok' and 'did not finish within' not in json.dumps(retry): fatal=True
            else: fatal=True
        (ROOT/'inputs/results.json').write_text(json.dumps(results, indent=2)+'\n')
        if fatal or not result.get('takes'): break
    (ROOT/'inputs/results.json').write_text(json.dumps(results, indent=2)+'\n')
