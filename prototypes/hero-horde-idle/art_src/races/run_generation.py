"""Elf and beastfolk heroes, same pipeline as the humans (hd2 ready stance -> hd2b five action edits).

  run_generation.py ready <race> [cls ...]   generate the ready stance (2 takes) from the human of the same class
  run_generation.py poses <race> [cls ...]   five edits from the chosen ready stance (selected.json, default take 1)

Outputs <race>_<cls>/ready/candidate-NN.png and <race>_<cls>/<action>/candidate-01.png (keyed, 1024 canvas,
soles on y=926 like hd2), plus a contact sheet per character. Raw runs and logs stay in inputs/.
"""
from pathlib import Path
import json, re, subprocess, sys
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent
ART = ROOT.parent
FORGE = Path('/Users/peter/repo/agent-sprite-forge')
PYTHON = str(FORGE / '.venv/bin/python')
MASTER = str(FORGE / 'skills/generate2dsprite/scripts/master_still.py')
sys.path.insert(0, str(FORGE / 'skills/generate2dsprite/scripts'))
from master_still import key_subject, contact_sheet, forge_core  # noqa: E402

CLASSES = ['shield', 'sword', 'spear', 'bow', 'mage', 'healer']
STYLE = re.findall(r'```text\n(.*?)\n```', (ART / 'hd2/BRIEF.md').read_text(), re.S)[0]
GEAR = {  # the human class gear (hd2), so a class reads the same in every race
    'shield': 'a large rectangular tower shield held in front and a short sword',
    'sword': 'a longsword held in both hands',
    'spear': 'a long spear angled forward',
    'bow': 'a longbow and a quiver on the back',
    'mage': 'a wooden staff topped by a softly glowing crystal and a small spellbook on the belt',
    'healer': 'a short staff ending in a golden sun ring and a small satchel',
}
RACES = {
    'elf': {
        'key': 'magenta',
        'word': 'ELF',
        'body': ('an elf with LONG POINTED EARS that stick out clearly sideways and up past the hair, slender graceful '
                 'build, fair skin, {hair} long flowing hair, leaf-and-vine embroidery and small gold leaf ornaments on '
                 'the light outfit'),
        'hair': {'shield': 'silver', 'sword': 'pale blond', 'spear': 'soft mint-green', 'bow': 'pale blond',
                 'mage': 'silver', 'healer': 'soft mint-green'},
        'outfit': {'shield': 'light leaf-pattern half-plate over a pale tabard', 'sword': 'light pale tunic with a short leaf cape',
                   'spear': 'light pale padded coat with vine bracers', 'bow': 'light pale hooded short cloak, hood down',
                   'mage': 'light pale long robe with vine trim', 'healer': 'light pale flowing robe with a leaf stole'},
        'marks': 'the long pointed ears',
    },
    'beast': {
        'key': 'green',
        'word': 'BEASTFOLK',
        'body': ('a beastfolk: fully human-shaped body and human face, with LARGE {animal} EARS on top of the head and a '
                 'big bushy {animal} TAIL clearly visible behind the body, sturdy athletic build, {hair}, fur-trimmed '
                 'brown leather straps and bone or wood beads on the light outfit; NOT an animal, NOT a furry muzzle'),
        'hair': {'shield': 'dark brown bear-fur hair', 'sword': 'grey wolf-fur hair', 'spear': 'red-orange fox-fur hair',
                 'bow': 'tawny cat-fur hair', 'mage': 'white arctic-fox-fur hair', 'healer': 'cream cat-fur hair'},
        'animal': {'shield': 'round BEAR', 'sword': 'pointed WOLF', 'spear': 'pointed FOX', 'bow': 'pointed CAT',
                   'mage': 'pointed white FOX', 'healer': 'pointed CAT'},
        'outfit': {'shield': 'light half-plate over a pale tabard with a fur collar', 'sword': 'light pale tunic with a fur-trimmed short cape',
                   'spear': 'light pale padded coat with fur cuffs', 'bow': 'light pale short cloak with a fur hem',
                   'mage': 'light pale long robe with a fur mantle', 'healer': 'light pale flowing robe with a fur-trimmed stole'},
        'marks': 'the animal ears and the bushy tail',
    },
}
ACTIONS = {  # hd2b, word for word
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
CONTAIN = (' This is one single clear key pose for a character displayed only 40 pixels tall: exaggerate the action and use a bold readable silhouette. '
           'Change only the pose; keep the original head size and standing-equivalent body scale relative to the canvas, do not zoom the camera '
           'and do not shrink the character to fit long weapons. Keep the full body, hands, feet, clothing and every weapon tip inside the square '
           'canvas with generous safe margins, no clipping. Keep the lowest contacting foot near y=90% of canvas height, or the lowest BODY '
           'point at that same ground line for the fallen pose. No ground plate, floor, cast shadow, text, border, motion streaks, detached '
           'attack effects or dust cloud. Crystal or sun-ring glow must stay small and attached, with crisp opaque pixel clusters. '
           'Outside the complete subject use only the specified flat chroma-key colour.')
BASELINE = 926  # hd2 soles


def describe(race, cls):
    r = RACES[race]
    body = r['body'].format(hair=r['hair'][cls], animal=r.get('animal', {}).get(cls, ''))
    return f'{body}; a {cls} hero with {GEAR[cls]}, {r["outfit"][cls]}'


def run(cmd, out):
    out.parent.mkdir(parents=True, exist_ok=True)
    if not (out / 'run.json').exists():
        (out.parent / (out.name + '-command.json')).write_text(json.dumps(cmd, indent=2) + '\n')
        print('START ' + out.name, flush=True)
        with (out.parent / (out.name + '.log')).open('w') as log:
            subprocess.run(cmd, cwd=FORGE, stdout=log, stderr=subprocess.STDOUT)
    if not (out / 'run.json').exists():
        return {'run': out.name, 'status': 'fail', 'error': 'no run.json; see log'}
    data = json.loads((out / 'run.json').read_text())
    result = {'run': out.name, 'status': data['status'], 'seconds': sum(t.get('seconds', 0) for t in data.get('takes', [])),
              'errors': [t.get('error') for t in data.get('takes', []) if t['status'] != 'ok']}
    print(json.dumps(result), flush=True)
    return result


def despill_magenta(a):
    """The model sometimes paints opaque purple 'shadows' in the key's hue under a fallen body or along hair, which
    keying cannot remove. Key-hued pixels reachable from the transparent outside become transparent; the few left
    inside the figure turn grey."""
    rgb = a[..., :3].astype(int)
    hue = (rgb[..., 0] - rgb[..., 1] > 50) & (rgb[..., 2] - rgb[..., 1] > 50) & (a[..., 3] > 0)
    outside = a[..., 3] == 0
    for _ in range(64):
        grow = np.zeros_like(outside)
        grow[1:] |= outside[:-1]; grow[:-1] |= outside[1:]; grow[:, 1:] |= outside[:, :-1]; grow[:, :-1] |= outside[:, 1:]
        reach = grow & hue & ~outside
        if not reach.any():
            break
        outside |= reach
    a[..., 3][outside] = 0
    inner = hue & ~outside
    a[..., :3][inner] = (rgb[inner] @ [0.3, 0.59, 0.11]).astype(np.uint8)[:, None]
    return a


def keyed(run_dir, record, key):
    raw = Image.open(run_dir / record['artifact']['path']).convert('RGBA')
    image, matte = key_subject(np.asarray(raw), key, 'soft')
    if key.upper() in ('#FF00FF', 'MAGENTA'):
        image = despill_magenta(np.array(image))
    image = Image.fromarray(image).convert('RGBa').resize((1024, 1024), Image.Resampling.LANCZOS).convert('RGBA')
    alpha = np.array(image.getchannel('A'))
    alpha[alpha <= 4] = 0
    image.putalpha(Image.fromarray(alpha))
    if key.upper() in ('#FF00FF', 'MAGENTA'):  # resizing blends new key-hued edge pixels
        image = Image.fromarray(despill_magenta(np.array(image)))
    return image, matte


def on_baseline(image, anchor):
    shifted = Image.new('RGBA', image.size)
    shifted.paste(image, (0, BASELINE - anchor))
    return shifted


def solid_box(image):
    return image.getchannel('A').point(lambda a: 255 if a > 16 else 0).getbbox()


def ready(race, cls, attempt=1):
    r = RACES[race]
    desc = describe(race, cls)
    human = ART / 'hd2' / cls / 'candidate-01.png'
    copy = ('ONLY the camera angle, HD-2D pixel-art texture, hand-placed shading, crisp dark outline, warm upper-left light, cool '
            'shadows, the canvas framing, body scale, head size, ready stance and the weapon type and silhouette. Do NOT copy the '
            f'human face, ears, hair or outfit details: draw the {r["word"]} described by the text, facing RIGHT, about 3.5 heads tall.')
    extra = (f'The FIRST image is the approved HUMAN {cls} of the same army: match its size, framing, camera and weapon so the two '
             f'stand side by side as one set, but draw exactly ONE {r["word"]} hero. Make {r["marks"]} large and bold so they still '
             'read when the sprite is shown only 40 pixels tall. All cloth is very light, low-saturation off-white, pale grey or '
             'cream so the game can recolour it; metal, leather, fur, skin and hair keep natural colours. Lock the camera about 45 '
             'degrees above, face and body RIGHT. On the square canvas, the soles are near y=90%, the crown of the head near y=26% '
             '(ears and raised weapon tips may go higher). Keep the whole body, ears, tail and all weapon tips inside the canvas with '
             'safe margins. No ground plate or cast shadow. Use the specified flat key backdrop everywhere outside the subject.')
    out = ROOT / 'inputs' / f'{race}_{cls}-ready-{attempt}'
    cmd = [PYTHON, MASTER, 'generate', '--name', f'races-{race}-{cls}', '--subject', desc,
           '--identity', desc + '\n\n' + STYLE, '--recap', desc, '--extra', extra,
           '--identity-ref', str(human), '--identity-ref-what', f'the approved human {cls} hero of the same army (size, camera and weapon reference)',
           '--identity-copy', copy, '--view', 'elevated three-quarter view about 45 degrees above, body and face turned RIGHT',
           '--route', 'codex-cli', '--finish', 'pixel', '--class', 'hero', '--key', r['key'],
           '--facing', 'right', '--takes', '2', '--timeout', '360', '--output-dir', str(out)]
    result = run(cmd, out)
    if (out / 'run.json').exists():
        data = json.loads((out / 'run.json').read_text())
        rows = []
        for take in data.get('takes', []):
            if take['status'] != 'ok':
                continue
            image, _ = keyed(out, take, data['key'])
            image = on_baseline(image, solid_box(image)[3])
            path = ROOT / f'{race}_{cls}' / 'ready' / f'candidate-{take["take"]:02d}.png'
            path.parent.mkdir(parents=True, exist_ok=True)
            image.save(path)
            rows.append((path, f'take {take["take"]}'))
        rows.append((human, 'human (hd2)'))
        save_contact(rows, ROOT / f'{race}_{cls}' / 'ready-contact.png')
    return result


def chosen(race, cls):
    sel = ROOT / 'selected.json'
    pick = json.loads(sel.read_text()).get(f'{race}_{cls}', 1) if sel.exists() else 1
    return ROOT / f'{race}_{cls}' / 'ready' / f'candidate-{pick:02d}.png'


def pose(race, cls, action, attempt=1):
    r = RACES[race]
    still = chosen(race, cls)
    keep = (f'the EXACT SAME accepted {r["word"]} character identity as the FIRST image: same face, {r["marks"]}, hairstyle and '
            'hair colour, accepted outfit and equipment, very light low-saturation cloth, weapon design, natural metal/leather/fur/'
            'skin/hair colours, body proportions, standing-equivalent anatomical body scale and head size, detailed HD-2D pixel-art '
            'style, warm light from upper-left with cool shadows, elevated three-quarter camera about 45 degrees above; RIGHT-facing '
            f'for every upright action. Keep {r["marks"]} large and visible in every pose. Preserve the accepted image; do not redesign it')
    change = ACTIONS[action]
    if action == 'strike':
        change += ': ' + STRIKES[cls]
    if action == 'run_a':
        change += '; clearly extend the LEFT lead leg in front and the RIGHT leg behind, keep the feet visibly separated'
    if action == 'run_b':
        change += '; clearly lift the RIGHT knee to the chest and kick the LEFT leg behind, use an unmistakably opposite leg phase from run_a'
    spec_path = ROOT / 'inputs' / f'{race}_{cls}-spec.json'
    if not spec_path.exists():
        ready_run = ROOT / 'inputs' / f'{race}_{cls}-ready-1'
        spec = json.loads((ready_run / 'spec.json').read_text())
        for field in ['identity_ref', 'style_ref', 'extra']:
            spec[field] = None
        spec['name'] = f'races-{race}-{cls}-poses'
        spec['subject'] = f'the exact accepted {race} {cls} hero from the FIRST image'
        spec['recap'] = spec['subject']
        spec['identity'] = keep
        spec_path.write_text(json.dumps(spec, indent=2) + '\n')
    out = ROOT / 'inputs' / f'{race}_{cls}-{action}-{attempt}'
    cmd = [PYTHON, MASTER, 'edit', '--spec', str(spec_path), '--name', f'races-{race}-{cls}-{action}',
           '--route', 'codex-cli', '--finish', 'pixel', '--class', 'hero', '--facing', 'right',
           '--key', r['key'], '--takes', '1', '--timeout', '360', '--output-dir', str(out),
           '--still', str(still), '--change', change + CONTAIN, '--keep', keep]
    return run(cmd, out)


def deliver(race, cls):
    """hd2b prepare_delivery: key, fit, and put each pose's feet (the fallen body's lowest point) on the ready baseline."""
    still = chosen(race, cls)
    rows, qc = [(still, 'ready')], []
    for action in ACTIONS:
        good = [p for p in sorted((ROOT / 'inputs').glob(f'{race}_{cls}-{action}-*/run.json'))
                if json.loads(p.read_text())['status'] == 'ok']
        if not good:
            continue
        data = json.loads(good[0].read_text())
        image, matte = keyed(good[0].parent, next(t for t in data['takes'] if t['status'] == 'ok'), data['key'])
        if action == 'down':
            comps = forge_core.connected_components(np.asarray(image.getchannel('A')), threshold=16)
            anchor = max(comps, key=lambda p: p['area'])['bbox'][3]
        else:
            anchor = solid_box(image)[3]
        bounds = image.getbbox()
        fit = min(1.0, (BASELINE - 12) / max(1, anchor - bounds[1]), (1024 - BASELINE - 12) / max(1, bounds[3] - anchor),
                  1000 / max(1, bounds[2] - bounds[0]))
        if fit < 1:
            size = round(1024 * fit)
            small = image.convert('RGBa').resize((size, size), Image.Resampling.LANCZOS).convert('RGBA')
            image = Image.new('RGBA', (1024, 1024))
            image.paste(small, ((1024 - size) // 2, 0))
            anchor = round(anchor * fit)
        image = on_baseline(image, anchor)
        if fit < 1 and RACES[race]['key'] == 'magenta':
            image = Image.fromarray(despill_magenta(np.array(image)))
        path = ROOT / f'{race}_{cls}' / action / 'candidate-01.png'
        path.parent.mkdir(parents=True, exist_ok=True)
        image.save(path)
        rows.append((path, action))
        box = image.getbbox()
        qc.append({'action': action, 'run': good[0].parent.name, 'fit': fit, 'matte': matte,
                   'touches_edge': box[0] <= 0 or box[1] <= 0 or box[2] >= 1024 or box[3] >= 1024})
    save_contact(rows, ROOT / f'{race}_{cls}' / 'poses-contact.png')
    (ROOT / 'inputs' / f'{race}_{cls}-delivery-qc.json').write_text(json.dumps(qc, indent=2) + '\n')


def save_contact(rows, path):
    sheet = Image.new('RGB', (320 * len(rows), 340), (32, 32, 32))
    for i, item in enumerate(rows):
        sheet.paste(contact_sheet([item]), (320 * i, 0))
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)


def quota(result):
    return any(w in json.dumps(result).lower() for w in ['quota', 'usage limit', 'rate limit', 'insufficient', 'credit', 'limit reached'])


def with_retry(fn, *args):
    result = fn(*args)
    if result['status'] != 'ok' and not quota(result) and 'did not finish within' in json.dumps(result):
        result = fn(*args, 2)
    return result


if __name__ == '__main__':
    stage, race, classes = sys.argv[1], sys.argv[2], sys.argv[3:] or CLASSES
    (ROOT / 'inputs').mkdir(exist_ok=True)
    log = ROOT / 'inputs' / f'results-{stage}-{race}.json'
    results = json.loads(log.read_text()) if log.exists() else []
    stop = False
    for cls in classes:
        if stage == 'ready':
            results.append(with_retry(ready, race, cls))
            stop = quota(results[-1])
        else:
            for action in ACTIONS:
                results.append(with_retry(pose, race, cls, action))
                if quota(results[-1]):
                    stop = True
                    break
            deliver(race, cls)
        log.write_text(json.dumps(results, indent=2) + '\n')
        if stop:
            break
    print('BATCH FINISHED ' + json.dumps({'stopped': stop, 'ok': sum(r['status'] == 'ok' for r in results)}), flush=True)
