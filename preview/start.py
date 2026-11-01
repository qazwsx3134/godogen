#!/usr/bin/env python3
"""Open the local preview hub and the original story editor on one server."""

import argparse
import errno
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import os
from pathlib import Path
import shutil
import subprocess
import sys
from urllib.parse import unquote, urlsplit
import webbrowser


PREVIEW = Path(__file__).resolve().parent
REPO = PREVIEW.parent
DEBT = REPO / "prototypes/debt-commission"
VFX = REPO / "prototypes/godot-kit/build/showcase"
VFX_BUILDER = REPO / "prototypes/godot-kit/tools/vfx/build_showcase.py"

# Reuse the project server and its same-origin, validation and save protections.
sys.path.insert(0, str(DEBT / "tools/story_editor"))
import project_server  # noqa: E402


def vfx_ready(root=VFX):
    """Check the files needed for both the sprite and Godot previews."""
    files = ("index.html", "data.js", "app.js", "player.js", "styles.css",
             "assets/cinder-explosion.png", "assets/cinder-explosion.recipe.json",
             "godot/index.html", "godot/index.js", "godot/index.wasm", "godot/index.pck",
             "godot/index.audio.worklet.js", "godot/index.audio.position.worklet.js")
    return all((root / name).is_file() and (root / name).stat().st_size for name in files)


def build_vfx(godot):
    print("首次準備特效預覽，正在建立展示包，請稍候…", flush=True)
    environment = dict(os.environ, GODOT_BIN=godot)
    try:
        subprocess.run([sys.executable, str(VFX_BUILDER)], cwd=REPO, env=environment, check=True)
    except (OSError, subprocess.CalledProcessError) as error:
        print(f"特效展示包未能建立：{error}", file=sys.stderr, flush=True)
        print("故事編輯器仍可使用；請確認 Godot 4.7 與對應 Web 匯出範本後重啟。", file=sys.stderr, flush=True)
        return False
    return vfx_ready()


def mounted_path(path, root, prefix):
    """Resolve one public mount without exposing hidden files or symlinks."""
    suffix = unquote(path[len(prefix):])
    parts = [part for part in suffix.split("/") if part]
    if any(part.startswith(".") or "\\" in part or "\x00" in part for part in parts):
        return None
    root = root.resolve()
    target = root
    for part in parts:
        target = target / part
        if target.is_symlink():
            return None
    try:
        target.resolve().relative_to(root)
    except (ValueError, OSError):
        return None
    return target


class PreviewHandler(project_server.ProjectHandler):
    extensions_map = {**project_server.ProjectHandler.extensions_map,
                      ".wasm": "application/wasm", ".pck": "application/octet-stream"}

    def do_GET(self):
        path = urlsplit(self.path).path
        if path in ("/preview", "/preview/vfx"):
            if not self.valid_host():
                self.send_error(403)
                return
            self.send_response(302)
            self.send_header("Location", path + "/")
            self.end_headers()
            return
        if path == "/preview/status.json":
            if not self.valid_host():
                self.send_error(403)
                return
            self.json_response(200, {"vfx_ready": vfx_ready(self.server.vfx_root),
                                     "godot_found": shutil.which(self.server.project.godot) is not None})
            return
        super().do_GET()

    def send_head(self):
        path = urlsplit(self.path).path
        mounts = (("/preview/vfx/", self.server.vfx_root), ("/preview/", PREVIEW))
        for prefix, root in mounts:
            if path.startswith(prefix):
                target = mounted_path(path, root, prefix)
                if target is None:
                    self.send_error(403)
                    return None
                if target.is_dir():
                    for index in ("index.html", "index.htm"):
                        if (target / index).is_symlink():
                            self.send_error(403)
                            return None
                self._mounted_target = target
                try:
                    # ProjectHandler protects project paths; these two mounts have their
                    # own checks above and use the standard HTTP file implementation.
                    return SimpleHTTPRequestHandler.send_head(self)
                finally:
                    self._mounted_target = None
        return super().send_head()

    def translate_path(self, path):
        target = getattr(self, "_mounted_target", None)
        return str(target) if target is not None else super().translate_path(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8000, help="本機連接埠（預設 8000）")
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN") or shutil.which("godot") or
                        ("/Applications/Godot.app/Contents/MacOS/Godot" if sys.platform == "darwin" else "godot"),
                        help="Godot 4.7 執行檔路徑；也可設定 GODOT_BIN")
    parser.add_argument("--no-open", action="store_true", help="不要自動開啟瀏覽器")
    args = parser.parse_args()
    if not 1 <= args.port <= 65535:
        parser.error("--port 須介於 1 到 65535")

    # Bind before building so an occupied port never causes an unnecessary rebuild.
    try:
        server = ThreadingHTTPServer(("127.0.0.1", args.port), PreviewHandler)
    except OSError as error:
        print(f"無法啟動本機預覽（連接埠 {args.port}）：{error}", file=sys.stderr)
        if error.errno == errno.EADDRINUSE:
            print("連接埠已被使用，請先關閉舊服務，或使用 --port 8001。", file=sys.stderr)
        elif error.errno in (errno.EPERM, errno.EACCES):
            print("目前環境不允許建立本機連線，請在一般終端機啟動。", file=sys.stderr)
        return 1

    server.project = project_server.StoryProject(DEBT, args.godot)
    server.vfx_root = VFX
    # Let in-flight validated saves finish before closing, like the original server.
    server.daemon_threads = False
    try:
        if shutil.which(args.godot) is None:
            print("找不到 Godot；故事編輯器可開啟，驗證與試玩需要用 --godot 指定執行檔。", file=sys.stderr, flush=True)
        if not vfx_ready():
            build_vfx(args.godot)
        url = f"http://127.0.0.1:{server.server_port}/preview/"
        print(f"預覽首頁：{url}", flush=True)
        print(f"故事編輯器：http://127.0.0.1:{server.server_port}/tools/story_editor/", flush=True)
        print("保持此視窗開啟；按 Ctrl+C 結束。", flush=True)
        if not args.no_open:
            try:
                webbrowser.open(url)
            except webbrowser.Error:
                pass  # The printed URL also works when no browser is configured.
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n預覽服務已關閉。", flush=True)
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
