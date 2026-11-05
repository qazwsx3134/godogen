#!/usr/bin/env python3
"""Open the local preview hub and the original story editor on one server."""

import argparse
import base64
from datetime import datetime
import hashlib
import json
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
PROTOTYPES = REPO / "prototypes"
# Sprite 檢視器只列出與提供這些圖片格式；略過套件、建置產物與 Godot 匯入快取。
IMAGE_EXT = {".png", ".webp", ".jpg", ".jpeg", ".gif"}
BACKUPS = PREVIEW / ".sprite-backups"  # 存回原檔前的備份（不進版控）
MAX_SPRITE_BYTES = 16 * 1024 * 1024
SKIP_DIRS = {"node_modules", ".godot", ".import", "dist", "build", "addons", "__pycache__", ".git"}

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


def png_size(path):
    """讀 PNG 檔頭取得寬高；不是 PNG 時回傳 None。"""
    try:
        with open(path, "rb") as handle:
            head = handle.read(24)
    except OSError:
        return None
    if head[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    return int.from_bytes(head[16:20], "big"), int.from_bytes(head[20:24], "big")


def sprite_index(root=PROTOTYPES, limit=6000):
    """列出各原型的圖片：專案、相對路徑、大小與（PNG）寬高。"""
    items = []
    for project in sorted(p for p in root.iterdir() if p.is_dir() and not p.name.startswith(".")):
        for dirpath, dirnames, filenames in os.walk(project):
            dirnames[:] = sorted(d for d in dirnames if d not in SKIP_DIRS and not d.startswith("."))
            for name in sorted(filenames):
                file = Path(dirpath) / name
                if name.startswith(".") or file.suffix.lower() not in IMAGE_EXT or file.is_symlink():
                    continue
                size = png_size(file)
                items.append({"project": project.name, "path": file.relative_to(project).as_posix(),
                              "bytes": file.stat().st_size, "w": size[0] if size else None,
                              "h": size[1] if size else None})
                if len(items) >= limit:
                    return items
    return items


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
        if path == "/preview/sprites/index.json":
            if not self.valid_host():
                self.send_error(403)
                return
            self.json_response(200, {"images": sprite_index(self.server.files_root),
                                     "token": self.server.project.token})
            return
        if path == "/preview/sprites":
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

    def sprite_target(self, project, relative):
        """存檔目標：prototypes/<專案>/<路徑>，必須是已存在的 .png，不能在略過的資料夾、隱藏路徑或符號連結裡。"""
        if not isinstance(project, str) or not isinstance(relative, str):
            return None
        target = mounted_path("/" + project + "/" + relative, self.server.files_root, "/")
        if target is None or target.suffix.lower() != ".png" or not target.is_file():
            return None
        parts = target.relative_to(self.server.files_root.resolve()).parts
        if len(parts) < 2 or any(part in SKIP_DIRS for part in parts):
            return None
        return target

    def save_sprite(self):
        """寫回編輯後的 PNG：同源＋憑證＋JSON＋大小限制，比對開檔時的 hash，先備份再原子寫入。"""
        origin = self.headers.get("Origin")
        if not self.valid_host() or (origin and origin != "http://" + self.headers.get("Host", "")):
            return self.json_response(403, {"error": "請從本機 Sprite 檢視器存檔。"})
        if self.headers.get("X-Preview-Token") != self.server.project.token:
            return self.json_response(403, {"error": "本機服務憑證不符，請重新整理頁面。"})
        if self.headers.get("Content-Type", "").split(";")[0].strip().lower() != "application/json":
            return self.json_response(415, {"error": "只接受 JSON。"})
        try:
            length = int(self.headers.get("Content-Length", ""))
        except ValueError:
            return self.json_response(411, {"error": "需要 Content-Length。"})
        if not 0 < length <= MAX_SPRITE_BYTES * 2:
            return self.json_response(413, {"error": "請求大小超過限制。"})
        try:
            request = json.loads(self.rfile.read(length))
            data = base64.b64decode(request["png"], validate=True)
        except (ValueError, KeyError, TypeError):
            return self.json_response(400, {"error": "內容格式不對。"})
        if not data.startswith(b"\x89PNG\r\n\x1a\n") or len(data) > MAX_SPRITE_BYTES:
            return self.json_response(400, {"error": "只能存 PNG。"})
        target = self.sprite_target(request.get("project"), request.get("path"))
        if target is None:
            return self.json_response(403, {"error": "只能寫回 prototypes 裡已存在的 PNG。"})
        current = target.read_bytes()
        if request.get("base_hash") != hashlib.sha256(current).hexdigest():
            return self.json_response(409, {"error": "檔案在你開啟之後被改過，未覆寫。請重新開啟這張圖再編輯。"})
        backup = BACKUPS / request["project"] / (request["path"] + "." + datetime.now().strftime("%Y%m%d-%H%M%S") + ".png")
        backup.parent.mkdir(parents=True, exist_ok=True)
        backup.write_bytes(current)
        project_server.atomic_write(target, data)
        return self.json_response(200, {"ok": True, "hash": hashlib.sha256(data).hexdigest(),
                                        "backup": backup.relative_to(REPO).as_posix()})

    def do_POST(self):
        if urlsplit(self.path).path == "/preview/sprites/save":
            self.close_connection = True
            return self.save_sprite()
        return super().do_POST()

    def send_head(self):
        path = urlsplit(self.path).path
        if path.startswith("/preview/files/") and Path(unquote(path)).suffix.lower() not in IMAGE_EXT:
            self.send_error(403)
            return None
        mounts = (("/preview/vfx/", self.server.vfx_root), ("/preview/files/", self.server.files_root),
                  ("/preview/", PREVIEW))
        for prefix, root in mounts:
            if path.startswith(prefix):
                target = mounted_path(path, root, prefix)
                if target is None:
                    self.send_error(403)
                    return None
                if prefix == "/preview/files/" and (not target.is_file() or any(
                        part in SKIP_DIRS for part in target.relative_to(root.resolve()).parts)):
                    self.send_error(404)
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
    server.files_root = PROTOTYPES
    # Let in-flight validated saves finish before closing, like the original server.
    server.daemon_threads = False
    try:
        if shutil.which(args.godot) is None:
            print("找不到 Godot；故事編輯器可開啟，驗證與試玩需要用 --godot 指定執行檔。", file=sys.stderr, flush=True)
        if not vfx_ready():
            build_vfx(args.godot)
        url = f"http://127.0.0.1:{server.server_port}/preview/"
        print(f"預覽首頁：{url}", flush=True)
        print(f"Sprite 檢視器：http://127.0.0.1:{server.server_port}/preview/sprites/", flush=True)
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
