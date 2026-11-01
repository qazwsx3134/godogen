"""Exercise real HTTP handlers in memory, without opening a listening socket."""

import io
import json
from pathlib import Path
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch

import start


class MemoryConnection:
    def __init__(self, request):
        self.input = io.BytesIO(request)
        self.output = bytearray()

    def makefile(self, mode, *args, **kwargs):
        assert mode == "rb"
        return self.input

    def sendall(self, data):
        self.output.extend(data)

    def settimeout(self, timeout):
        pass


class PreviewHTTPTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.vfx = Path(self.temporary.name)
        for name in ("index.html", "data.js", "app.js", "player.js", "styles.css",
                     "assets/cinder-explosion.png", "assets/cinder-explosion.recipe.json",
                     "godot/index.html", "godot/index.js", "godot/index.wasm", "godot/index.pck",
                     "godot/index.audio.worklet.js", "godot/index.audio.position.worklet.js"):
            file = self.vfx / name
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_bytes(b"fixture")
        self.server = SimpleNamespace(server_port=8000, vfx_root=self.vfx,
                                      project=start.project_server.StoryProject(start.DEBT, "godot"))

    def request(self, path, method="GET", host="127.0.0.1:8000", headers="", body=b""):
        raw = f"{method} {path} HTTP/1.0\r\nHost: {host}\r\n{headers}\r\n".encode() + body
        connection = MemoryConnection(raw)
        with patch.object(start.PreviewHandler, "log_message"):
            start.PreviewHandler(connection, ("127.0.0.1", 12345), self.server)
        header, _, content = bytes(connection.output).partition(b"\r\n\r\n")
        return header.decode("latin1"), content

    def test_home_links_to_real_tools_and_redirects_slash(self):
        header, body = self.request("/preview/")
        self.assertIn("200 OK", header)
        self.assertIn(b'href="/tools/story_editor/"', body)
        self.assertIn(b'href="/preview/vfx/"', body)
        header, _ = self.request("/preview")
        self.assertIn("Location: /preview/", header)
        header, _ = self.request("/preview/vfx")
        self.assertIn("Location: /preview/vfx/", header)

    def test_story_editor_and_existing_project_service_still_work(self):
        header, body = self.request("/tools/story_editor/")
        self.assertIn("200 OK", header)
        self.assertIn(b"editor.js", body)
        header, body = self.request("/api/capabilities")
        self.assertIn("200 OK", header)
        capabilities = json.loads(body)
        self.assertEqual(capabilities["service"], "debt-story-editor-v1")
        self.assertTrue(capabilities["token"])
        self.assertTrue(capabilities["registry"])
        for path in ("/tools/story_editor/editor.js", "/data/stories.json", "/scripts/story_runner.gd"):
            with self.subTest(path=path):
                self.assertIn("200 OK", self.request(path)[0])
        header, _ = self.request("/data/stories.json", method="HEAD")
        self.assertIn("200 OK", header)
        # A request without the original service token must not write the project.
        header, _ = self.request("/api/save", method="POST", headers="Content-Type: application/json\r\nContent-Length: 2\r\n", body=b"{}")
        self.assertIn("403", header)

    def test_katsura_story_and_new_background_are_available_to_editor(self):
        capabilities = json.loads(self.request("/api/capabilities")[1])
        self.assertTrue(any(pack["id"] == "katsura_dog_ears" for pack in capabilities["packs"]))
        header, raw = self.request("/stories/katsura_dog_ears/catalog.json")
        self.assertIn("200 OK", header)
        relative = json.loads(raw)["backgrounds"]["yorozuya_living_room"]["path"]
        header, image = self.request("/stories/katsura_dog_ears/" + relative)
        self.assertIn("200 OK", header)
        self.assertTrue(image.startswith(b"\x89PNG\r\n\x1a\n"))

    def test_story_save_and_conflict_through_hub_handler_in_temporary_project(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "data").mkdir()
            original = (start.DEBT / "data/phase3_story.json").read_bytes()
            target = root / "data/phase3_story.json"
            target.write_bytes(original)
            registry = {"stories": [{"id": "phase3", "path": "res://data/phase3_story.json",
                                     "authoring": "graph", "save": "user://phase3.save"}]}
            (root / "data/stories.json").write_bytes(start.project_server.json_bytes(registry))
            project = start.project_server.StoryProject(root, "godot")
            project.check = lambda candidate, catalog=None: []  # No Godot validation in this routing test.
            self.server.project = project
            story = json.loads(original)
            story["title"] = "預覽入口測試"
            data = {"path": "data/phase3_story.json", "base_hash": start.project_server.digest(original), "story": story}
            body = start.project_server.json_bytes(data)
            headers = (f"Content-Type: application/json\r\nContent-Length: {len(body)}\r\n"
                       f"X-Story-Editor-Token: {project.token}\r\n")
            header, _ = self.request("/api/save", method="POST", headers=headers, body=body)
            self.assertIn("200 OK", header)
            self.assertEqual(json.loads(target.read_bytes())["title"], "預覽入口測試")
            header, _ = self.request("/api/save", method="POST", headers=headers, body=body)
            self.assertIn("409", header)  # The stale base hash cannot overwrite the first save.

    def test_vfx_mount_mime_and_missing_build_status(self):
        header, body = self.request("/preview/vfx/")
        self.assertIn("200 OK", header)
        self.assertEqual(body, b"fixture")
        header, body = self.request("/preview/vfx/godot/index.wasm")
        self.assertIn("Content-type: application/wasm", header)
        self.assertEqual(body, b"fixture")
        self.assertTrue(json.loads(self.request("/preview/status.json")[1])["vfx_ready"])
        self.server.project.godot = "godot-executable-that-does-not-exist"
        self.assertFalse(json.loads(self.request("/preview/status.json")[1])["godot_found"])
        (self.vfx / "godot/index.pck").unlink()
        self.assertFalse(json.loads(self.request("/preview/status.json")[1])["vfx_ready"])
        self.assertIn("200 OK", self.request("/tools/story_editor/")[0])

    def test_real_vfx_build_routes_when_available(self):
        if not start.vfx_ready():
            self.skipTest("VFX build has not been generated")
        self.server.vfx_root = start.VFX
        header, page = self.request("/preview/vfx/")
        self.assertIn("200 OK", header)
        self.assertIn(b"data.js", page)
        header, data = self.request("/preview/vfx/data.js")
        self.assertIn("200 OK", header)
        self.assertIn(b"window.VFX_DATA", data)
        header, image = self.request("/preview/vfx/assets/cinder-explosion.png")
        self.assertIn("200 OK", header)
        self.assertTrue(image.startswith(b"\x89PNG\r\n\x1a\n"))
        header, godot = self.request("/preview/vfx/godot/index.html")
        self.assertIn("200 OK", header)
        self.assertIn(b"index.pck", godot)

    def test_mounts_block_traversal_hidden_files_symlinks_and_bad_hosts(self):
        for path in ("/preview/../Progress.md", "/preview/%2e%2e/Progress.md",
                     "/preview/vfx/.secret", "/preview/vfx/%5csecret"):
            with self.subTest(path=path):
                self.assertIn("403", self.request(path)[0])
        self.assertIn("403", self.request("/preview/", host="attacker.example:8000")[0])
        self.assertIn("403", self.request("/preview/status.json", host="attacker.example:8000")[0])
        try:
            (self.vfx / "escape").symlink_to(start.REPO / "Progress.md")
        except (OSError, NotImplementedError):
            return  # Windows accounts may not have symlink permission.
        self.assertIn("403", self.request("/preview/vfx/escape")[0])
        (self.vfx / "unsafe").mkdir()
        (self.vfx / "unsafe/index.html").symlink_to(start.REPO / "Progress.md")
        self.assertIn("403", self.request("/preview/vfx/unsafe/")[0])

    def test_occupied_port_does_not_rebuild(self):
        with patch.object(start, "ThreadingHTTPServer", side_effect=OSError("in use")), \
             patch.object(start, "build_vfx") as build, \
             patch("sys.argv", ["start.py", "--no-open"]), \
             patch("sys.stderr", new_callable=io.StringIO):
            self.assertEqual(start.main(), 1)
            build.assert_not_called()

    def test_main_opens_original_project_and_closes_server(self):
        server = SimpleNamespace(server_port=8000)
        server.serve_forever = lambda: None
        server.server_close = lambda: setattr(server, "closed", True)
        with patch.object(start, "ThreadingHTTPServer", return_value=server) as factory, \
             patch.object(start, "vfx_ready", return_value=True), \
             patch.object(start.shutil, "which", return_value="/tmp/my-godot"), \
             patch.object(start.webbrowser, "open") as browser, \
             patch("sys.argv", ["start.py", "--godot", "/tmp/my-godot"]), \
             patch("sys.stdout", new_callable=io.StringIO) as output:
            self.assertEqual(start.main(), 0)
        factory.assert_called_once_with(("127.0.0.1", 8000), start.PreviewHandler)
        browser.assert_called_once_with("http://127.0.0.1:8000/preview/")
        self.assertEqual(server.project.root, start.DEBT.resolve())
        self.assertEqual(server.project.godot, "/tmp/my-godot")
        self.assertFalse(server.daemon_threads)
        self.assertTrue(server.closed)
        self.assertIn("http://127.0.0.1:8000/tools/story_editor/", output.getvalue())

    def test_failed_vfx_build_still_serves_story_editor(self):
        server = SimpleNamespace(server_port=8000, served=False)
        server.serve_forever = lambda: setattr(server, "served", True)
        server.server_close = lambda: None
        with patch.object(start, "ThreadingHTTPServer", return_value=server), \
             patch.object(start, "vfx_ready", return_value=False), \
             patch.object(start.shutil, "which", return_value="/tmp/my-godot"), \
             patch.object(start, "build_vfx", return_value=False) as build, \
             patch("sys.argv", ["start.py", "--godot", "/tmp/my-godot", "--no-open"]), \
             patch("sys.stdout", new_callable=io.StringIO):
            self.assertEqual(start.main(), 0)
        build.assert_called_once_with("/tmp/my-godot")
        self.assertTrue(server.served)
        self.assertEqual(server.project.root, start.DEBT.resolve())


if __name__ == "__main__":
    unittest.main()
