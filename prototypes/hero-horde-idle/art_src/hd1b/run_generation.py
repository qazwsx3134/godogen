from pathlib import Path
import json, subprocess, sys

ROOT = Path(__file__).resolve().parent
FORGE = Path('/Users/peter/repo/agent-sprite-forge')
PYTHON = str(FORGE/'.venv/bin/python')
MASTER = str(FORGE/'skills/generate2dsprite/scripts/master_still.py')
REFERENCE = ROOT.parent/'hd1/boss/candidate-01.png'
BASE_SPEC = ROOT.parent/'hd1/inputs/boss-01-attempt1/spec.json'
POSES = {
    'windup': 'winding up a huge attack: club raised high overhead with both hands, body leaning back, mouth open roaring',
    'slam': 'the moment of impact: club smashed down onto the ground in front of him (to the left), body bent forward, a few small rock chips flying (no dust cloud covering the body)',
    'stunned': 'staggered and dazed: knees buckling, club dragging on the ground from one hand, head tilted, eyes unfocused, a small cracked plate on the harness',
}
KEEP = ('the exact same troll identity, grey-green skin and warm dusk palette, two curved ivory horns, tusks, '
        'leather and iron-plate harness, same huge spiked wooden club, body proportions, pixel-art style, '
        'warm upper-left sunlight and cool blue-violet shadows, elevated three-quarter camera about 45 degrees above, '
        'entire body and face turned LEFT, same anatomical body scale and canvas proportions')
CONTAIN = (' Keep the complete body, horns, hands, feet and entire club fully inside the square canvas with safe margins. '
           'Do not shrink or zoom the troll to fit the new pose: keep the same head size and standing-equivalent anatomical scale as the FIRST image. '
           'Keep the feet on the same ground baseline at approximately 90 percent of image height. '
           'No ground plate, cast shadow, text, border, aura, or dust cloud. Background outside the subject is flat pure magenta #FF00FF only.')

def generate(name, change, mode):
    for attempt in (1, 2):
        out = ROOT/'inputs'/f'{name}-{mode}-{attempt}'
        if out.exists():
            data = json.loads((out/'run.json').read_text())
        else:
            cmd = [PYTHON, MASTER, mode, '--spec', str(BASE_SPEC), '--name', 'hd1b-'+name,
                   '--route', 'codex-cli', '--finish', 'pixel', '--class', 'hero', '--key', 'magenta',
                   '--facing', 'left', '--takes', '1', '--timeout', '360', '--output-dir', str(out)]
            if mode == 'edit':
                cmd += ['--still', str(REFERENCE), '--change', change+CONTAIN, '--keep', KEEP]
            else:
                cmd += ['--identity-ref', str(REFERENCE), '--identity-ref-what', 'the approved exact troll identity and body-scale reference',
                        '--identity-copy', KEEP, '--pose', change, '--extra', CONTAIN]
            out.parent.mkdir(exist_ok=True)
            (out.parent/(out.name+'-command.json')).write_text(json.dumps(cmd, indent=2)+'\n')
            print('START '+out.name, flush=True)
            with (out.parent/(out.name+'.log')).open('w') as log:
                subprocess.run(cmd, cwd=FORGE, stdout=log, stderr=subprocess.STDOUT)
            if not (out/'run.json').exists():
                return {'name': name, 'mode': mode, 'status': 'fail', 'error': 'no run.json; see log'}
            data = json.loads((out/'run.json').read_text())
        result = {'name': name, 'mode': mode, 'status': data['status'], 'run': str(out.relative_to(ROOT)), 'takes': data.get('takes', [])}
        print(json.dumps(result), flush=True)
        if data['status'] == 'ok': return result
        if 'did not finish within' in json.dumps(result) and attempt == 1: continue
        return result

if __name__ == '__main__':
    results = []
    for name, change in POSES.items():
        result = generate(name, change, 'edit')
        if result['status'] != 'ok':
            if any(word in json.dumps(result).lower() for word in ['quota', 'usage limit', 'rate limit', 'insufficient', 'credit']):
                results.append(result)
                break
            results.append(result)
            result = generate(name, change, 'generate')
        results.append(result)
        (ROOT/'inputs/results.json').write_text(json.dumps(results, indent=2)+'\n')
        if result['status'] != 'ok': break
    (ROOT/'inputs/results.json').write_text(json.dumps(results, indent=2)+'\n')
    sys.exit(0 if len([r for r in results if r['status'] == 'ok']) == 3 else 1)
