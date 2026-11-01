#!/usr/bin/env python3
"""Serve the built showcase (single-threaded Godot Web does not require COOP/COEP)."""
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--port',type=int,default=8765)
parser.add_argument('--bind',default='127.0.0.1')
args=parser.parse_args()
root=Path(__file__).resolve().parent
if not (root/'godot/index.wasm').exists():
    raise SystemExit('Run tools/vfx/build_showcase.py first, then run build/showcase/serve.py')
class Handler(SimpleHTTPRequestHandler):
    extensions_map={**SimpleHTTPRequestHandler.extensions_map,'.wasm':'application/wasm','.pck':'application/octet-stream'}
    def end_headers(self):
        self.send_header('Cache-Control','no-cache')
        super().end_headers()
with ThreadingHTTPServer((args.bind,args.port),partial(Handler,directory=str(root))) as server:
    print(f'VFX showcase: http://{args.bind}:{args.port}/',flush=True)
    server.serve_forever()
