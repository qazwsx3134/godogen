#!/usr/bin/env python3
"""Read-only comparison of selected kit copies. Drift is information, not a sync instruction."""
import argparse
import hashlib
import json
from pathlib import Path


def inventory(directory):
    return {str(p.relative_to(directory)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(directory.rglob('*')) if p.is_file()}


def audit(source, copy):
    upstream, downstream = inventory(source), inventory(copy)
    shared = upstream.keys() & downstream.keys()
    return {'identical': sum(upstream[k] == downstream[k] for k in shared),
            'changed': {k: {'kit_sha256': upstream[k], 'copy_sha256': downstream[k]}
                        for k in sorted(shared) if upstream[k] != downstream[k]},
            'only_in_kit': sorted(upstream.keys() - downstream.keys()),
            'only_in_copy': sorted(downstream.keys() - upstream.keys())}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('projects', nargs='+')
    parser.add_argument('--json', action='store_true', help='Full hashes and file lists')
    parser.add_argument('--check', action='store_true', help='Exit 1 when any copy differs')
    args = parser.parse_args()
    prototypes = Path(__file__).resolve().parents[2]
    source = prototypes / 'godot-kit/addons/proto_kit'
    report = {}
    for project in args.projects:
        project_path = Path(project)
        if not project_path.is_absolute():
            project_path = prototypes / project_path
        target = project_path / 'addons/proto_kit'
        if not target.is_dir():
            parser.error(f'Missing kit copy: {project}')
        report[project] = audit(source, target)
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        for project, result in report.items():
            print(f"{project}: identical={result['identical']}, changed={len(result['changed'])}, "
                  f"only_in_kit={len(result['only_in_kit'])}, only_in_copy={len(result['only_in_copy'])}")
            for name in result['changed']:
                print(f'  changed: {name}')
            for name in result['only_in_copy']:
                print(f'  copy only: {name}')
            if result['only_in_kit']:
                print('  Use --json for the complete missing-file list and hashes.')
    different = any(r['changed'] or r['only_in_kit'] or r['only_in_copy'] for r in report.values())
    return 1 if args.check and different else 0


if __name__ == '__main__':
    raise SystemExit(main())
