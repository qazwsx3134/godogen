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
server.project.check = lambda candidate: validate_candidate(candidate, actual, args.godot)

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
