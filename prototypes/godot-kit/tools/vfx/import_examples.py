#!/usr/bin/env python3
"""Stage user-provided exports; never execute JavaScript or the bundled agent skill.
Run from repo root. Existing outputs are verified and retained, never overwritten.
Godot subsequently authors the saved scenes with build_library.gd.
"""
import argparse
import hashlib
import json
import re
import shutil
import struct
from pathlib import Path

KIT = Path(__file__).resolve().parents[2]
ROOT = KIT.parents[1]
BASE = KIT / 'addons/proto_kit/vfx'

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def put(path, data):
    if path.exists():
        if path.read_bytes() != data:
            raise ValueError(f'Existing authored file differs; refusing overwrite: {path}')
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('examples', type=Path)
    args = parser.parse_args()
    source = args.examples.resolve()
    entries = []
    for directory in sorted((source / 'scenario-pixel-vfx-skill').iterdir()):
        slug = directory.name
        sheet = directory / f'{slug}.png'
        if not sheet.exists():
            continue
        atlas_path = directory / f'{slug}.json'
        recipe_path = directory / f'{slug}.recipe.json'
        atlas = json.loads(atlas_path.read_text())
        recipe = json.loads(recipe_path.read_text())
        tres = directory / f'{slug}.tres'
        readme = directory / 'README.txt'
        assert 'You can use these frames in commercial and non-commercial projects.' in readme.read_text()
        assert sheet.read_bytes()[:8] == b'\x89PNG\r\n\x1a\n'
        width, height = struct.unpack('>II', sheet.read_bytes()[16:24])
        frames = atlas['frames']
        assert len(frames) == recipe['frames'] and atlas['meta']['fps'] == recipe['fps']
        assert atlas['meta']['loop'] == recipe['loop']
        for frame in frames:
            r = frame['frame']
            assert not frame['rotated'] and not frame['trimmed']
            assert r['x'] >= 0 and r['y'] >= 0 and r['x'] + r['w'] <= width and r['y'] + r['h'] <= height
        target = BASE / 'assets/scenario' / slug
        records = {}
        for original in [sheet, atlas_path, recipe_path, readme]:
            put(target / original.name, original.read_bytes())
            records[original.name] = digest(original)
        text = tres.read_text()
        reference = f'res://addons/proto_kit/vfx/assets/scenario/{slug}/{slug}.png'
        assert text.count(f'res://{slug}.png') == 1
        text = text.replace(f'res://{slug}.png', reference)
        put(target / tres.name, text.encode())
        names = re.findall(r'"name": &"([^"]+)"', text)
        assert len(names) == 1
        entries.append(dict(id=slug, source='scenario', name=recipe['name'], frames=len(frames),
                            fps=recipe['fps'], loop=recipe['loop'], animation=names[0],
                            size=[recipe['w'], recipe['h']], pivot=recipe['pivot'],
                            place=recipe.get('place'), depth=recipe.get('depth'),
                            upstream_sha256=records, upstream_tres_sha256=digest(tres),
                            scene_2d=f'res://addons/proto_kit/vfx/2d/scenario/{slug}.tscn',
                            scene_3d=f'res://addons/proto_kit/vfx/3d/scenario/{slug}.tscn'))
    three = []
    common_notice = None
    for js in sorted((source / 'three-effect').glob('*.js')):
        text = js.read_text()
        notice = text.split('*/', 1)[0] + '*/\n'
        assert 'The MIT License' in notice and '2026 00GameDevs' in notice
        if common_notice is None:
            common_notice = notice
        m = re.search(r'const preset = (\{.*?\n\});', text, re.S)
        if m:
            preset = json.loads(m[1])
        else:
            assert js.stem == 'impact-frame'
            preset = dict(id=js.stem, name='Impact Frame', renderMode='postprocess')
        m = re.search(r'export const defaultOptions = (\{.*?\n\});', text, re.S)
        options = json.loads(m[1]) if m else {}
        three.append(dict(id=js.stem, name=preset['name'], source='00gamedevs',
                          source_file=str(js.relative_to(ROOT)), sha256=digest(js),
                          preset=preset, default_options=options, status='source_available'))
    for record in three:
        scene = BASE / '3d/00gamedevs' / (record['id'] + '.tscn')
        if scene.exists():
            record['status'] = 'ported_native_godot'
            record['scene_3d'] = 'res://addons/proto_kit/vfx/3d/00gamedevs/' + scene.name
    put(BASE / 'licenses/00gamedevs-MIT.txt', common_notice.encode())
    put(BASE / 'assets/scenario/index.json', (json.dumps(entries, ensure_ascii=False, indent=2)+'\n').encode())
    source_index = BASE / 'three_sources.json'
    if source_index.exists():
        existing = {entry['id']: entry for entry in json.loads(source_index.read_text())}
        assert set(existing) == {entry['id'] for entry in three}, 'Source inventory changed; reconcile it explicitly'
        for entry in three:
            assert existing[entry['id']]['sha256'] == entry['sha256'], 'Source changed: ' + entry['id']
        # Keep native port methods and visual acceptance records added after staging.
    else:
        put(source_index, (json.dumps(three, ensure_ascii=False, indent=2)+'\n').encode())
    print(f'Staged {len(entries)} Scenario effects; inventoried {len(three)} Three.js sources')

if __name__ == '__main__':
    main()
