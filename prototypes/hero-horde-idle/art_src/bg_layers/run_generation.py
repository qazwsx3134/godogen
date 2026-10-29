"""March backdrop layers from docs/bg-layer-prompts.md (first set: countryside).

  run_generation.py [name ...]   default: every layer

Props go through master_still (prop framing, chroma key, QC). Sky, far, mid and ground are wide bands, so they are
plain route_media images at 1536x1024; far, mid and ground ask for a flat magenta backdrop and are keyed here.
Outputs <name>.png beside this script (keyed RGBA, raw size); raw runs and logs in inputs/.
"""
from pathlib import Path
import json, subprocess, sys
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent
FORGE = Path('/Users/peter/repo/agent-sprite-forge')
PYTHON = str(FORGE / '.venv/bin/python')
MASTER = str(FORGE / 'skills/generate2dsprite/scripts/master_still.py')
ROUTE = str(FORGE / 'skills/generate2dmedia/scripts/route_media.py')
sys.path.insert(0, str(FORGE / 'skills/generate2dsprite/scripts'))
from master_still import key_subject  # noqa: E402

COMMON = ('16-bit JRPG pixel art, crisp hard-edged pixels, no anti-aliasing, limited palette (about 32 colors), soft daylight '
          'from the upper left, original high-fantasy countryside, calm warm colors, side view, no text, no UI, no characters')
KEY = ('Everything outside the subject is ONE flat solid pure magenta #FF00FF, no gradient, no shadow, no glow, no sky, '
       'no horizon line, no frame or border.')
BANDS = {  # name: (keyed, prompt)
    'sky': (False, 'Wide landscape image 1536x1024. Wide sky backdrop only, pale blue gradient to a warm horizon, a few soft '
                   'pixel clouds, nothing on the ground, empty bottom third (just the warm horizon haze), no mountains, no hills.'),
    'far': (True, 'Wide landscape image 1536x1024. A distant blue-grey mountain range silhouette running edge to edge across the '
                  'full width, low contrast, hazy, occupying the middle band of the image (about y=35% to y=70%), with a flat '
                  'bottom edge; the left and right ends meet at the same height so the strip tiles horizontally. ' + KEY),
    'mid': (True, 'Wide landscape image 1536x1024. Rolling green hills running edge to edge across the full width, with a small '
                  'stone castle and a stone aqueduct far away on the hills, occupying the band from about y=40% down to y=75% '
                  'with a flat bottom edge; the left and right ends meet at the same height so the strip tiles horizontally. ' + KEY),
    'ground': (True, 'Wide landscape image 1536x1024. A side-view ground strip running edge to edge across the full width: a grass '
                     'top edge with small tufts at about y=55%, packed dirt path below it filling down to the bottom edge of the '
                     'image; the texture repeats evenly so the strip tiles horizontally. Above the grass top edge: ' + KEY),
}
PROPS = {  # name: subject
    'prop_tree_a': 'a single leafy oak tree, full tree with trunk base',
    'prop_tree_b': 'a single tall pine tree, full tree with trunk base',
    'prop_bush': 'a low round green bush with small white and yellow flowers',
    'prop_rock': 'a mossy grey boulder cluster',
    'prop_ruin': 'a broken stone pillar ruin with ivy',
    'prop_lamp': 'a wooden roadside lantern post with a small warm lantern',
    'prop_fence': 'a short wooden fence segment, two posts and two rails, both ends cut straight so it tiles horizontally',
}


def run(cmd, out, marker):
    out.parent.mkdir(parents=True, exist_ok=True)
    if not (out / marker).exists():
        (out.parent / (out.name + '-command.json')).write_text(json.dumps(cmd, indent=2) + '\n')
        print('START ' + out.name, flush=True)
        with (out.parent / (out.name + '.log')).open('w') as log:
            subprocess.run(cmd, cwd=FORGE, stdout=log, stderr=subprocess.STDOUT)
    return (out / marker).exists()


def band(name, attempt=1):
    keyed, prompt = BANDS[name]
    out = ROOT / 'inputs' / f'{name}-{attempt}'
    prompt_file = ROOT / 'inputs' / f'{name}-prompt.txt'
    prompt_file.parent.mkdir(parents=True, exist_ok=True)
    prompt_file.write_text(COMMON + '. ' + prompt + '\n')
    cmd = [PYTHON, ROUTE, 'image', '--prompt-file', str(prompt_file), '--size', '1536x1024', '--route', 'codex-cli',
           '--timeout', '360', '--out-dir', str(out)]
    if not run(cmd, out, 'job.json'):
        return {'name': name, 'status': 'fail', 'error': 'no job.json; see log'}
    raw = next(out.glob('generated.*'), None)
    if raw is None:
        return {'name': name, 'status': 'fail', 'error': json.loads((out / 'job.json').read_text()).get('error')}
    image = Image.open(raw).convert('RGBA')
    matte = None
    if keyed:
        arr, matte = key_subject(np.asarray(image), '#FF00FF', 'soft')
        image = Image.fromarray(arr)
    image.save(ROOT / f'{name}.png')
    return {'name': name, 'status': 'ok', 'size': image.size, 'matte': matte}


def prop(name, attempt=1):
    subject = PROPS[name]
    out = ROOT / 'inputs' / f'{name}-{attempt}'
    cmd = [PYTHON, MASTER, 'generate', '--name', 'bg-' + name.replace('_', '-'), '--subject', subject,
           '--identity', subject + ', isolated scenery prop. ' + COMMON, '--recap', subject,
           '--extra', 'Scenery prop for a side-scrolling march backdrop: no ground plate, no grass patch, no cast shadow, '
                      'nothing else in the image. Keep it complete with safe margins.',
           '--view', 'side view, eye level', '--route', 'codex-cli', '--finish', 'pixel', '--class', 'prop',
           '--facing', 'none', '--key', 'magenta', '--takes', '1', '--timeout', '360', '--output-dir', str(out)]
    if not run(cmd, out, 'run.json'):
        return {'name': name, 'status': 'fail', 'error': 'no run.json; see log'}
    data = json.loads((out / 'run.json').read_text())
    take = next((t for t in data['takes'] if t['status'] == 'ok'), None)
    if take is None:
        return {'name': name, 'status': data['status'], 'error': [t.get('error') for t in data['takes']]}
    arr, matte = key_subject(np.asarray(Image.open(out / take['artifact']['path']).convert('RGBA')), data['key'], 'soft')
    image = Image.fromarray(arr)
    image.crop(image.getbbox()).save(ROOT / f'{name}.png')
    return {'name': name, 'status': 'ok', 'size': image.size, 'matte': matte}


def quota(result):
    return any(w in json.dumps(result).lower() for w in ['quota', 'usage limit', 'rate limit', 'insufficient', 'credit', 'limit reached'])


if __name__ == '__main__':
    names = sys.argv[1:] or [*BANDS, *PROPS]
    log = ROOT / 'inputs' / 'results.json'
    log.parent.mkdir(exist_ok=True)
    results = json.loads(log.read_text()) if log.exists() else []
    for name in names:
        fn = band if name in BANDS else prop
        result = fn(name)
        if result['status'] != 'ok' and not quota(result) and 'did not finish within' in json.dumps(result):
            result = fn(name, 2)
        print(json.dumps(result, default=str), flush=True)
        results.append(result)
        log.write_text(json.dumps(results, indent=2, default=str) + '\n')
        if quota(result):
            break
    print('BATCH FINISHED', flush=True)
