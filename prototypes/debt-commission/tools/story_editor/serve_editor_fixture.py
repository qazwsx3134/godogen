"""Test-only HTTP fixture: temporary web/data files, actual game validator/catalog."""
import argparse
from pathlib import Path
import signal
import subprocess
from project_server import make_server, validate_candidate, validate_catalog

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
server.project.check_preview = lambda candidate, catalog=None: validate_candidate(
    candidate, actual, args.godot, work_catalog(catalog), allow_unreachable=True)
server.project.launch_preview = lambda config, environment: subprocess.Popen(
    [args.godot, '--headless', '--path', str(actual), '--quit-after', '180', '--scene',
     'res://tools/story_build/preview.tscn', '--', f'--editor-preview={config}'],
    env=environment, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def catalog_check(candidate, replaces, pairs):
    """An edited work catalog stands in for the game's test fixture of that work (same folder rule as
    work_catalog), so its relative art resolves inside the project; stories are the fixture's files."""
    stand_in = work_catalog(replaces) if replaces.startswith('res://stories/') else replaces
    stand_in = stand_in if stand_in.startswith('res://') else replaces
    local = lambda path: path if not path.startswith('res://') else str(Path(args.root).resolve() / path[len('res://'):])
    return validate_catalog(candidate, actual, args.godot, stand_in,
                            [(local(story), stand_in if catalog == replaces else local(catalog)) for story, catalog in pairs])


server.project.check_catalog = catalog_check

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
