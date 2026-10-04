#!/usr/bin/env python3
"""Installs only the Godot Web export template you need, out of the official 1.28 GB .tpz, with HTTP Range requests.

    python3 fetch_web_templates.py                       # Godot 4.7, web_nothreads_release.zip (10 MB)
    python3 fetch_web_templates.py --debug               # also web_nothreads_debug.zip
    python3 fetch_web_templates.py --version 4.7 --dest ~/.local/share/godot/export_templates/4.7.stable
    python3 fetch_web_templates.py --check               # say whether the templates are installed
    python3 fetch_web_templates.py --self-test

The .tpz is a zip. Reading its central directory and then only the member you want costs about 13 MB instead of
1.28 GB (measured: GitHub's release download ran at 36 KB/s on a WSL box, the Godot mirror at 9 MB/s). Every extracted
member is checked against its zip CRC-32 before it is written, and written through a temporary file.

Where the templates go: ~/.local/share/godot/export_templates/<version>.stable (Linux). The Windows editor keeps its own
folder (%APPDATA%\\Godot\\export_templates\\<version>.stable): install there from the editor (Editor > Manage Export
Templates), or pass --dest. Thread Support off (the default for itch.io) uses the `web_nothreads_*` files; with
Thread Support on pass --want web_release.zip,web_debug.zip instead.
Replaces debt-commission's tools/fetch_web_templates.py (GitHub only, both debug and release, project-local cache).
"""
import argparse, io, os, struct, sys, tempfile, threading, time, urllib.request, zipfile

BLOCK = 1 << 20
MIRRORS = [
    "https://downloads.godotengine.org/?version={version}&flavor=stable&slug=export_templates.tpz&platform=templates",
    "https://github.com/godotengine/godot-builds/releases/download/{version}-stable/Godot_v{version}-stable_export_templates.tpz",
]


class RemoteFile(io.RawIOBase):
    """A read-only, seekable file over HTTP Range requests; downloaded blocks are cached."""

    def __init__(self, url, block=BLOCK, retries=4):
        self.url, self.block, self.retries = url, block, retries
        self.pos, self.cache, self.fetched = 0, {}, 0
        request = urllib.request.Request(url, method="HEAD")
        with urllib.request.urlopen(request, timeout=60) as response:
            self.size = int(response.headers["Content-Length"])
            if response.headers.get("Accept-Ranges", "").lower() != "bytes":
                raise IOError("the server does not support byte ranges: " + url)

    def seekable(self): return True
    def readable(self): return True
    def tell(self): return self.pos

    def seek(self, offset, whence=0):
        self.pos = offset if whence == 0 else self.pos + offset if whence == 1 else self.size + offset
        return self.pos

    def _block(self, index):
        if index not in self.cache:
            start, end = index * self.block, min((index + 1) * self.block, self.size) - 1
            request = urllib.request.Request(self.url, headers={"Range": "bytes=%d-%d" % (start, end)})
            for attempt in range(self.retries):
                try:
                    with urllib.request.urlopen(request, timeout=60) as response:
                        data = response.read()
                    if len(data) != end - start + 1:
                        raise IOError("short read: %d of %d bytes" % (len(data), end - start + 1))
                    self.cache[index] = data
                    break
                except Exception as error:
                    print("  retry block %d: %s" % (index, error), file=sys.stderr)
                    time.sleep(1 + attempt)
            else:
                raise IOError("could not read block %d of %s" % (index, self.url))
            self.fetched += len(self.cache[index])
        return self.cache[index]

    def read(self, n=-1):
        n = self.size - self.pos if n < 0 else min(n, self.size - self.pos)
        out = bytearray()
        while n > 0:
            index, offset = divmod(self.pos, self.block)
            chunk = self._block(index)[offset:offset + n]
            out += chunk
            self.pos += len(chunk)
            n -= len(chunk)
        return bytes(out)

    def readinto(self, buffer):
        data = self.read(len(buffer))
        buffer[:len(data)] = data
        return len(data)


def default_dest(version):
    return os.path.expanduser("~/.local/share/godot/export_templates/%s.stable" % version)


def installed(dest, wanted):
    return all(os.path.isfile(os.path.join(dest, name)) for name in list(wanted) + ["version.txt"])


def fetch(urls, dest, wanted, log=print):
    """Downloads `wanted` (file names inside the .tpz's templates/ folder) plus version.txt into `dest`."""
    last_error = None
    for url in urls:
        try:
            remote = RemoteFile(url)
            archive = zipfile.ZipFile(remote)
            names = {i.filename for i in archive.infolist()}
            missing = [n for n in list(wanted) + ["version.txt"] if "templates/" + n not in names]
            if missing:
                raise IOError("not in the archive: %s" % ", ".join(missing))
            os.makedirs(dest, exist_ok=True)
            for name in list(wanted) + ["version.txt"]:
                data = archive.read("templates/" + name)     # zipfile checks the member's CRC-32 while reading
                temporary = os.path.join(dest, name + ".part")
                with open(temporary, "wb") as f:
                    f.write(data)
                os.replace(temporary, os.path.join(dest, name))
                log("installed %s (%.1f MB)" % (name, len(data) / 1e6))
            log("downloaded %.1f MB of %.0f MB from %s" % (remote.fetched / 1e6, remote.size / 1e6, url.split("?")[0]))
            return True
        except Exception as error:
            last_error = error
            log("failed with %s: %s" % (url.split("?")[0], error))
    raise SystemExit("could not fetch the templates: %s" % last_error)


class _RangeHandler:
    """Just enough of an HTTP server for the self-test: HEAD, and GET with Range."""
    @staticmethod
    def make(payload):
        from http.server import BaseHTTPRequestHandler

        class Handler(BaseHTTPRequestHandler):
            requested = 0
            def log_message(self, *a): pass
            def do_HEAD(self):
                self.send_response(200)
                self.send_header("Content-Length", str(len(payload)))
                self.send_header("Accept-Ranges", "bytes")
                self.end_headers()
            def do_GET(self):
                start, end = 0, len(payload) - 1
                header = self.headers.get("Range")
                if header:
                    a, b = header.split("=")[1].split("-")
                    start, end = int(a), min(int(b), len(payload) - 1)
                part = payload[start:end + 1]
                Handler.requested += len(part)
                self.send_response(206 if header else 200)
                self.send_header("Content-Length", str(len(part)))
                self.send_header("Content-Range", "bytes %d-%d/%d" % (start, end, len(payload)))
                self.end_headers()
                self.wfile.write(part)
        return Handler


def self_test():
    from http.server import HTTPServer
    ok = True
    def expect(condition, label):
        nonlocal ok
        print(("ok   " if condition else "FAIL ") + label)
        ok = ok and condition
    release = os.urandom(300_000)
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w", zipfile.ZIP_STORED) as z:
        z.writestr("templates/version.txt", "4.7.stable")
        z.writestr("templates/web_nothreads_release.zip", release)
        z.writestr("templates/web_nothreads_debug.zip", os.urandom(300_000))
        z.writestr("templates/windows_release.exe", os.urandom(6_000_000))   # the bulk, which must NOT be downloaded
    payload = buffer.getvalue()
    handler = _RangeHandler.make(payload)
    server = HTTPServer(("127.0.0.1", 0), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    url = "http://127.0.0.1:%d/templates.tpz" % server.server_port
    quiet = lambda *a: None
    with tempfile.TemporaryDirectory() as tmp:
        dest = os.path.join(tmp, "4.7.stable")
        expect(not installed(dest, ["web_nothreads_release.zip"]), "nothing installed yet")
        fetch([url], dest, ["web_nothreads_release.zip"], quiet)
        with open(os.path.join(dest, "web_nothreads_release.zip"), "rb") as f:
            expect(f.read() == release, "the extracted member equals the original")
        expect(open(os.path.join(dest, "version.txt")).read() == "4.7.stable", "version.txt is installed")
        expect(installed(dest, ["web_nothreads_release.zip"]), "installed() sees the files")
        expect(not os.path.exists(os.path.join(dest, "web_nothreads_debug.zip")), "only the wanted member is installed")
        expect(handler.requested < 3_000_000, "the 6 MB member nobody asked for was not downloaded (%.1f of %.1f MB)" % (handler.requested / 1e6, len(payload) / 1e6))
        # a corrupted byte inside the wanted member must be caught by the CRC
        bad = bytearray(payload)
        at = bad.index(release[:64]) + 1000
        bad[at] ^= 0xFF
        bad_handler = _RangeHandler.make(bytes(bad))
        bad_server = HTTPServer(("127.0.0.1", 0), bad_handler)
        threading.Thread(target=bad_server.serve_forever, daemon=True).start()
        try:
            fetch(["http://127.0.0.1:%d/bad.tpz" % bad_server.server_port], os.path.join(tmp, "bad"), ["web_nothreads_release.zip"], quiet)
            refused = False
        except SystemExit:
            refused = True
        expect(refused and not os.path.exists(os.path.join(tmp, "bad", "web_nothreads_release.zip")), "a corrupted download is refused and nothing is left behind")
        # the first mirror is dead, the second works
        dest2 = os.path.join(tmp, "second")
        fetch(["http://127.0.0.1:9/dead.tpz", url], dest2, ["web_nothreads_release.zip"], quiet)
        expect(installed(dest2, ["web_nothreads_release.zip"]), "falls back to the next mirror")
        try:
            fetch([url], os.path.join(tmp, "third"), ["web_nonexistent.zip"], quiet)
            refused = False
        except SystemExit:
            refused = True
        expect(refused, "asking for a file that is not in the archive fails clearly")
    server.shutdown()
    bad_server.shutdown()
    print("fetch_web_templates self-test", "PASSED" if ok else "FAILED")
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--version", default="4.7", help="Godot version, e.g. 4.7 (stable releases only)")
    ap.add_argument("--dest", help="template folder (default ~/.local/share/godot/export_templates/<version>.stable)")
    ap.add_argument("--want", default="web_nothreads_release.zip", help="comma separated template files")
    ap.add_argument("--debug", action="store_true", help="also fetch the debug template of the same kind")
    ap.add_argument("--url", action="append", help="a .tpz URL that supports Range (repeatable; replaces the built-in mirrors)")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        return self_test()
    dest = os.path.expanduser(args.dest) if args.dest else default_dest(args.version)
    wanted = [w for w in args.want.split(",") if w]
    if args.debug:
        wanted += [w.replace("_release", "_debug") for w in wanted if "_release" in w]
    if args.check:
        print("%s: %s" % (dest, "installed" if installed(dest, wanted) else "missing " + ", ".join(w for w in wanted + ["version.txt"] if not os.path.isfile(os.path.join(dest, w)))))
        return 0 if installed(dest, wanted) else 1
    if installed(dest, wanted):
        print("already installed in " + dest)
        return 0
    urls = args.url or [m.format(version=args.version) for m in MIRRORS]
    fetch(urls, dest, wanted)
    return 0


if __name__ == "__main__":
    sys.exit(main())
