#!/usr/bin/env python3
"""Read-only capability discovery; deterministic catalog/API/inventory generation."""
import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

KIT = Path(__file__).resolve().parents[1]
REPO = KIT.parents[1]
SKIP = {'.git', '.godot', 'node_modules', 'build', 'dist', '.cache', '__pycache__', '.venv', 'art_src', 'vendor'}
TEXT = {'.gd', '.tscn', '.tres', '.gdshader', '.gdshaderinc', '.py', '.sh', '.mjs', '.js', '.json'}


def files(root):
    # prune before walking: large generated assets never need to be opened
    import os
    for directory, dirs, names in os.walk(root, followlinks=False):
        dirs[:] = sorted(d for d in dirs if d not in SKIP and not Path(directory, d).is_symlink())
        for name in sorted(names):
            p = Path(directory, name)
            if not p.is_symlink():
                yield p


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def api(path):
    source = path.read_text(encoding='utf-8')
    lines = source.splitlines()
    declarations = []
    for i, line in enumerate(lines):
        if re.match(r'^(?:static )?func (?!_(?!init\b))', line):
            end = i
            while not lines[end].rstrip().endswith(':') and end + 1 < len(lines):
                end += 1
            signature = ' '.join(s.strip() for s in lines[i:end+1])
            comment = []
            j = i - 1
            while j >= 0 and lines[j].startswith('##'):
                comment.insert(0, lines[j][2:].lstrip()); j -= 1
            declarations.append({'signature': signature, 'line': i + 1, 'contract': '\n'.join(comment)})
    properties = [l for l in lines if re.match(r'^(?:@export\w*(?:\([^\n]*?\))? )?var [^_]', l)]
    return {'base': next((l[8:] for l in lines if l.startswith('extends ')), ''),
            'documentation': '\n'.join(l[2:].lstrip() for l in lines if l.startswith('##')),
            'methods': declarations, 'properties': properties,
            'signals': [l for l in lines if l.startswith('signal ')],
            'resource_references': sorted(set(re.findall(r'["\'](res://[^"\'\n]+)["\']', source)))}


def build():
    specs = json.loads((KIT / 'catalog/specs.json').read_text())
    scripts = {str(p.relative_to(KIT)): p for p in (KIT / 'addons/proto_kit').rglob('*.gd')}
    entries = []
    for rel, p in sorted(scripts.items()):
        ident = rel.removeprefix('addons/proto_kit/').removesuffix('.gd').replace('/', '.')
        spec = specs.get(ident)
        if spec is None:
            raise ValueError(f'missing curated spec: {ident}')
        entry = {'id': ident, 'path': rel, 'sha256': digest(p), **spec, **api(p)}
        entry['tests'] = [str(t.relative_to(KIT)) for t in sorted((KIT / 'tests').glob('*.gd'))
                          if 'res://' + rel in t.read_text()]
        entries.append(entry)
    stale = set(specs) - {e['id'] for e in entries}
    if stale:
        raise ValueError(f'stale specs: {sorted(stale)}')
    tool_entries = json.loads((KIT / 'catalog/tools.json').read_text())
    for tool in tool_entries:
        tool['sha256'] = digest(KIT / tool['path'])
    return {'schema_version': 1, 'engine': 'Godot 4.7 (project.godot)', 'capabilities': entries, 'tools': tool_entries}


def inventory():
    projects = []
    hashes = {}
    module_paths = {str(p.relative_to(KIT)): p for p in (KIT / 'addons/proto_kit').rglob('*.gd')}
    # Primary prototypes, not nested asset-authoring projects.
    for project in sorted(KIT.parent.iterdir()):
        if project == KIT or not (project / 'project.godot').exists():
            continue
        counts, references, copies = {}, {}, {}
        source_modules = []
        for p in files(project):
            ext = p.suffix
            counts[ext] = counts.get(ext, 0) + 1
            rel = str(p.relative_to(project))
            if rel in module_paths:
                copies[rel] = 'identical' if digest(p) == digest(module_paths[rel]) else 'drift'
            if ext not in TEXT or 'addons' in p.relative_to(project).parts:
                continue
            source = p.read_text(encoding='utf-8', errors='replace')
            for ref in set(re.findall(r'res://(addons/proto_kit/[^"\'\s)]+)', source)):
                references.setdefault(ref, []).append(rel)
            if ext == '.gd':
                source_modules.append({'path': rel, 'sha256': digest(p), 'base': api(p)['base'],
                                       'summary': next((line[2:].strip() for line in source.splitlines() if line.startswith('##')), ''),
                                       'public_methods': [m['signature'] for m in api(p)['methods']]})
            if ext in {'.gd', '.gdshader', '.gdshaderinc'}:
                hashes.setdefault(digest(p), []).append(str(p.relative_to(REPO)))
        projects.append({'project': project.name, 'file_counts_by_extension': counts,
                         'source_modules': source_modules, 'kit_copies': copies, 'kit_references': references})
    duplicates = [paths for paths in hashes.values() if len({p.split('/')[1] for p in paths}) > 1]
    return {'schema_version': 1, 'scope': 'top-level prototypes with project.godot; source tree snapshot',
            'excluded_directories': sorted(SKIP),
            'limitations': ['references are static textual evidence, not runtime adoption proof',
                           'third-party addons excluded from duplicate detection',
                           'binary assets counted, not reviewed for visual quality or redistribution rights',
                           'byte-identical groups only; divergent copies need semantic review',
                           'nested art projects, moved/external repositories and git history not scanned'],
            'projects': projects, 'identical_source_groups': sorted(duplicates)}


def resource_inventory():
    result = []
    for path in files(KIT / 'addons/proto_kit'):
        if path.suffix not in {'.tscn', '.tres', '.gdshader', '.gdshaderinc'}:
            continue
        source = path.read_text()
        result.append({'path': str(path.relative_to(KIT)), 'sha256': digest(path),
                       'parameters': [line.strip() for line in source.splitlines() if line.strip().startswith('uniform ')],
                       'references': sorted(set(re.findall(r'["\'](res://[^"\'\n]+)["\']', source)))})
    return {'schema_version': 1, 'scope': 'saved scenes, text resources and shader uniforms; binary assets remain in vfx/sources.json', 'resources': result}


def dependency_plan(data, ids):
    entries = {e['id']: e for e in data['capabilities'] + data['tools']}
    unknown = set(ids) - entries.keys()
    if unknown:
        raise ValueError('unknown capabilities: ' + ', '.join(sorted(unknown)))
    pending = [entries[ident]['path'] for ident in ids]
    # Saved scenes carry authored dependencies that the behavior script alone cannot describe.
    for ident in ids:
        scene = (KIT / entries[ident]['path']).with_suffix('.tscn')
        if scene.exists(): pending.append(str(scene.relative_to(KIT)))
    visited, unresolved = set(), set()
    while pending:
        rel = pending.pop()
        if rel in visited: continue
        path = (KIT / rel).resolve()
        if not path.is_relative_to(KIT) or not path.is_file():
            unresolved.add(rel); continue
        visited.add(rel)
        if path.suffix not in TEXT: continue
        source = path.read_text(errors='replace')
        for ref in re.findall(r'["\']res://([^"\'\n]+)["\']', source):
            if ref not in visited: pending.append(ref)
    return {'schema_version': 1, 'selected': ids, 'files': sorted(visited),
            'unresolved_or_example_paths': sorted(unresolved),
            'limitation': 'Read-only static reference plan, not an install manifest. Comments may add example paths; dynamic loads, directory scans, licenses and imports still need the module contract. Use sync.sh for supported installation.'}


def render(data):
    rows = ['# 能力目錄（由 tools/capabilities.py build 產生）', '',
            '用途與範例由 catalog/specs.json 維護；參數、回傳型別、訊號與原碼註解由來源擷取。',
            '完整結構化契約見 catalog/capabilities.json；先讀 docs/COMPOSITION.md。', '',
            '| ID | 用途／情境 | 類型 |', '|---|---|---|']
    for e in data['capabilities']:
        rows.append(f"| [{e['id']}](#{e['id'].replace('.', '-')}) | {e['purpose']} | {e['kind']} |")
    for e in data['capabilities']:
        rows += ['', f"## {e['id']}", '', e['purpose'], '', f"適用：{e['use_when']}", '',
                 f"入口：[{e['path']}](../../{e['path']}) · {e['kind']} · {e['status']}", '',
                 f"限制／副作用：{e['constraints']}", '', '### 使用範例', '', '```gdscript', e['example'], '```', '',
                 '### 參數、輸出與訊號', '', '```gdscript']
        rows += e['properties'] + e['signals'] + [m['signature'] for m in e['methods']] + ['```', '', e['documentation']]
        rows += ['', '測試引用（存在不等於本輪已重跑）：' + (', '.join(e['tests']) or '無直接引用；可能由場景或上層測試涵蓋，需個別驗證。')]
    rows += ['', '## 製作與維護工具', '', '以下命令由 godot-kit 目錄執行；外部檔案路徑為使用者提供的輸入。']
    for e in data['tools']:
        rows += ['', '### ' + e['id'], '', e['purpose'], '', '輸入：' + e['parameters'], '', '輸出：' + e['outputs'], '', '限制：' + e['constraints'], '', '```sh', e['example'], '```']
    return '\n'.join(rows) + '\n'


def validate(data):
    errors = []
    for e in data['capabilities'] + data['tools']:
        for key in ('purpose', 'use_when', 'kind', 'status', 'constraints', 'example'):
            if not isinstance(e.get(key), str) or not e[key].strip(): errors.append(f"{e['id']}: empty {key}")
        if e['kind'] not in ('rule', 'resource', 'node', 'authoring', 'inspection', 'internal', 'tool'):
            errors.append(f"{e['id']}: invalid kind")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    sub.add_parser('build', help='update generated catalog, API reference and inventory')
    sub.add_parser('check', help='fail on undocumented modules or stale generated API files')
    listing = sub.add_parser('list'); listing.add_argument('--query', default=''); listing.add_argument('--kind'); listing.add_argument('--json', action='store_true')
    show = sub.add_parser('show'); show.add_argument('id')
    plan = sub.add_parser('plan'); plan.add_argument('ids', nargs='+')
    sub.add_parser('inventory', help='print fresh read-only repository inventory')
    args = parser.parse_args()
    if args.command == 'inventory':
        print(json.dumps(inventory(), ensure_ascii=False, indent=2)); return 0
    data = build()
    errors = validate(data)
    if errors: raise ValueError('\n'.join(errors))
    products = {KIT / 'catalog/capabilities.json': json.dumps(data, ensure_ascii=False, indent=2) + '\n',
                KIT / 'docs/capabilities/REFERENCE.md': render(data),
                KIT / 'catalog/resources.json': json.dumps(resource_inventory(), ensure_ascii=False, indent=2) + '\n'}
    if args.command == 'build':
        products[KIT / 'catalog/inventory.json'] = json.dumps(inventory(), ensure_ascii=False, indent=2) + '\n'
        for p, content in products.items(): p.parent.mkdir(parents=True, exist_ok=True); p.write_text(content)
        print(f"built {len(data['capabilities'])} capabilities"); return 0
    if args.command == 'check':
        stale = [str(p.relative_to(KIT)) for p, content in products.items() if not p.exists() or p.read_text() != content]
        if stale: print('stale: ' + ', '.join(stale), file=sys.stderr); return 1
        print(f"PASS: {len(data['capabilities'])} capability contracts match source"); return 0
    if args.command == 'plan':
        print(json.dumps(dependency_plan(data, args.ids), ensure_ascii=False, indent=2)); return 0
    if args.command == 'show':
        found = [e for e in data['capabilities'] + data['tools'] if e['id'] == args.id]
        if not found: parser.error(f'unknown capability: {args.id}')
        print(json.dumps(found[0], ensure_ascii=False, indent=2)); return 0
    found = [e for e in data['capabilities'] + data['tools'] if args.query.casefold() in json.dumps(e, ensure_ascii=False).casefold()
             and (not args.kind or e['kind'] == args.kind)]
    if args.json: print(json.dumps(found, ensure_ascii=False, indent=2))
    else:
        for e in found: print(f"{e['id']:44} {e['kind']:12} {e['purpose']}")
    return 0

if __name__ == '__main__':
    try: sys.exit(main())
    except (ValueError, OSError) as exc:
        print(str(exc), file=sys.stderr); sys.exit(1)
