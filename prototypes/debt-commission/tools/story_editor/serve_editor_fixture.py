"""Test-only HTTP fixture: temporary web/data files, actual game validator/catalog."""
import argparse
from pathlib import Path
import signal
from project_server import make_server, validate_candidate

parser = argparse.ArgumentParser()
parser.add_argument('--root', required=True)
parser.add_argument('--port', type=int, required=True)
parser.add_argument('--godot', required=True)
args = parser.parse_args()
actual = Path(__file__).resolve().parents[2]
server = make_server(args.root, args.godot, args.port)


def work_catalog(catalog):
    """A work's catalog: the game's test fixture of that work when there is one (its relative art then
    resolves inside the project), else the fixture's own file (a catalog without art)."""
    if not catalog:
        return None
    work = catalog.split('/')[-2]
    if (actual / 'tests/fixtures/packs' / work / 'catalog.json').is_file():
        return f'res://tests/fixtures/packs/{work}/catalog.json'
    return str(Path(args.root).resolve() / catalog[len('res://'):])


server.project.check = lambda candidate, catalog=None: validate_candidate(candidate, actual, args.godot, work_catalog(catalog))

def stop(signum, frame):
    raise KeyboardInterrupt

signal.signal(signal.SIGTERM, stop)
print('SKIN FIXTURE READY', flush=True)
try:
    server.serve_forever()
except KeyboardInterrupt:
    pass
finally:
    server.server_close()
