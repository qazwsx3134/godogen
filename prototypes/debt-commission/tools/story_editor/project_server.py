#!/usr/bin/env python3
"""Loopback project server: validate private candidates before publishing graph sources."""
import argparse
import hashlib
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
import math
import os
from pathlib import Path
import re
import secrets
import signal
import shutil
import subprocess
import tempfile
import threading
from urllib.parse import unquote, urlsplit
import uuid

from godot_guard import godot_environment

MAX_BODY = 4 * 1024 * 1024
STORY_PATH = re.compile(r'data/([A-Za-z0-9_]{1,80})_story\.json\Z')
# A story of a work (IMPLEMENTATION.md「故事包」): its registry is that folder's pack.json.
PACK_STORY_PATH = re.compile(r'stories/([A-Za-z_][A-Za-z0-9_]{0,79})/([A-Za-z0-9_]{1,80})_story\.json\Z')
WORK_ID = re.compile(r'[a-z_][a-z0-9_]{0,39}\Z')
# The catalogs the 素材設定 page edits: the game's, or a work's own.
CATALOG_PATH = re.compile(r'(?:data/asset_catalog\.json|stories/([A-Za-z_][A-Za-z0-9_]{0,79})/catalog\.json)\Z')
BASE_CATALOG = 'res://data/asset_catalog.json'
MEDIA = {'.png', '.jpg', '.jpeg', '.webp', '.ogg', '.mp3', '.wav'}
BASE_REGISTRY = 'data/stories.json'


def story_match(relative):
    """(story id from the file name, registry file, work id or None), or None for a path not saved here."""
    if not isinstance(relative, str):
        return None
    match = STORY_PATH.fullmatch(relative)
    if match:
        return match[1], BASE_REGISTRY, None
    match = PACK_STORY_PATH.fullmatch(relative)
    if match:
        return match[2], f'stories/{match[1]}/pack.json', match[1]
    return None


def entry_path(entry, work):
    """The res:// path of a registry entry; a pack's paths are relative to its folder."""
    path = str(entry.get('path', ''))
    return path if work is None or '://' in path else f'res://stories/{work}/{path}'
SERVICE = 'debt-story-editor-v1'


class ProjectError(Exception):
    def __init__(self, status, message, **details):
        super().__init__(message)
        self.status, self.details = status, {'error': message, **details}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def json_bytes(value):
    return (json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + '\n').encode('utf-8')


def parse_json(data):
    def pairs(items):
        result = {}
        for key, value in items:
            if key in result:
                raise ValueError('JSON 有重複欄位：' + key)
            result[key] = value
        return result
    def invalid_number(value):
        raise ValueError('不接受非有限數字：' + value)
    def finite_float(value):
        number = float(value)
        if not math.isfinite(number):
            raise ValueError('數字超出範圍')
        return number
    return json.loads(data.decode('utf-8'), object_pairs_hook=pairs, parse_constant=invalid_number, parse_float=finite_float)


def atomic_write(path, data):
    temp = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, prefix='.' + path.name + '-', suffix='.tmp', delete=False) as handle:
            temp = Path(handle.name)
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp, path)
    finally:
        if temp:
            temp.unlink(missing_ok=True)


def validate_catalog(candidate, root, godot, replaces, pairs):
    """check_catalog.gd: the candidate standing in for `replaces`, and each (story, its catalog)."""
    args = [f'--candidate={candidate}', f'--replaces={replaces}', *[f'{story}={catalog}' for story, catalog in pairs]]
    with godot_environment(timeout=45) as environment:
        run = subprocess.run([godot, '--headless', '--path', str(root), '--script',
                              'res://tools/story_editor/check_catalog.gd', '--', *args],
                             env=environment, capture_output=True, text=True, timeout=120)
    output = run.stdout + '\n' + run.stderr
    errors = [line.strip()[len('ERROR '):] for line in output.splitlines() if line.startswith('ERROR ')]
    if run.returncode or not any(line.startswith('OK ') for line in run.stdout.splitlines()):
        return errors or ['Godot 未能完成驗證。' + ('\n' + output[-3000:] if output.strip() else '')]
    return []


def validate_candidate(candidate, root, godot, catalog=None):
    flags = [f'--catalog={catalog}'] if catalog else []
    with godot_environment(timeout=45) as environment:
        run = subprocess.run([godot, '--headless', '--path', str(root), '--script',
                              'res://tools/story_editor/check_story.gd', '--', str(candidate), '--write', *flags],
                             env=environment, capture_output=True, text=True, timeout=90)
    output = run.stdout + '\n' + run.stderr
    errors = [line.strip() for line in output.splitlines() if line.startswith(('ERROR ', 'FAILED '))]
    if run.returncode or not any(line.startswith('OK ') for line in run.stdout.splitlines()):
        return errors or ['Godot 未能完成驗證。' + ('\n' + output[-3000:] if output.strip() else '')]
    return []


class StoryProject:
    def __init__(self, root, godot):
        self.root = Path(root).resolve()
        self.godot = godot
        self.token = secrets.token_urlsafe(32)
        self.mutex = threading.Lock()

    def safe_path(self, relative):
        if not isinstance(relative, str) or not relative or relative.startswith('/') or '\\' in relative:
            raise ProjectError(400, '路徑不合法。')
        parts = relative.split('/')
        if any(part in ('', '.', '..') for part in parts):
            raise ProjectError(400, '路徑不合法。')
        target = self.root
        for part in parts:
            target = target / part
            if target.is_symlink():
                raise ProjectError(403, '不允許符號連結。')
        if not target.resolve().is_relative_to(self.root):
            raise ProjectError(403, '路徑超出專案。')
        return target

    def read_bytes(self, path):
        if path.exists():
            if not path.is_file():
                raise ProjectError(400, '目標不是檔案。')
            if path.stat().st_size > MAX_BODY:
                raise ProjectError(413, '專案檔案超過大小限制。')
            return path.read_bytes()
        return None

    def registry(self, relative=BASE_REGISTRY):
        path = self.safe_path(relative)
        raw = self.read_bytes(path)
        if raw is None and relative != BASE_REGISTRY:
            raise ProjectError(404, f'作品資料夾沒有 pack.json：{relative}')
        try:
            value = parse_json(raw or b'')
            if not isinstance(value, dict) or not isinstance(value.get('stories'), list) or not all(isinstance(e, dict) for e in value['stories']):
                raise ValueError('stories 必須是陣列')
        except (ValueError, UnicodeError, RecursionError) as error:
            raise ProjectError(500, f'無法讀取故事登記 {relative}：' + str(error)) from error
        return path, raw, value

    def list_packs(self):
        """Every stories/<work>/pack.json that reads: [{id, title, path, hash, pack}]."""
        root = self.safe_path('stories')
        packs = []
        if not root.is_dir():
            return packs
        for directory in sorted(root.iterdir()):
            if directory.is_symlink() or not directory.is_dir() or not PACK_STORY_PATH.fullmatch(f'stories/{directory.name}/x_story.json'):
                continue
            relative = f'stories/{directory.name}/pack.json'
            try:
                _, raw, pack = self.registry(relative)
            except ProjectError:
                continue
            packs.append({'id': directory.name, 'title': str(pack.get('title', directory.name)), 'path': relative,
                          'hash': digest(raw), 'pack': pack})
        return packs

    def taken_ids(self):
        ids = {e.get('id') for e in self.registry()[2]['stories']}
        for pack in self.list_packs():
            ids.update(e.get('id') for e in pack['pack']['stories'])
        return ids

    def catalog_for(self, work):
        """The --catalog for check_story: the work's catalog.json when it has one (StoryRunner.catalog_path_for)."""
        if work is None:
            return None
        return f'res://stories/{work}/catalog.json' if self.safe_path(f'stories/{work}/catalog.json').is_file() else None

    def catalog_stories(self, relative):
        """(story res:// path, its catalog res:// path) for every story an edit of `relative` can break:
        a work's own stories, or for the game's catalog every story there is (works may extend it)."""
        match = CATALOG_PATH.fullmatch(relative)
        pairs = []
        packs = self.list_packs()
        if match[1] is None:
            for entry in self.registry()[2]['stories']:
                path = str(entry.get('path', ''))
                if path.startswith('res://data/') and self.safe_path(path[6:]).is_file():
                    pairs.append((path, BASE_CATALOG))
        for pack in packs:
            if match[1] is not None and pack['id'] != match[1]:
                continue
            catalog = self.catalog_for(pack['id']) or BASE_CATALOG
            for entry in pack['pack']['stories']:
                path = entry_path(entry, pack['id'])
                if path.startswith('res://') and self.safe_path(path[6:]).is_file():
                    pairs.append((path, catalog))
        return pairs

    def catalog_files(self, relative):
        """Pictures and sounds a catalog can point at, in its own form: a work's relative to its
        folder, the game's as res://assets/…"""
        match = CATALOG_PATH.fullmatch(relative)
        root = self.safe_path(f'stories/{match[1]}' if match[1] else 'assets')
        files = []
        for path in sorted(root.rglob('*')) if root.is_dir() else []:
            parts = path.relative_to(root).parts
            if path.is_file() and not path.is_symlink() and path.suffix.lower() in MEDIA and not any(p.startswith('.') for p in parts):
                files.append('/'.join(parts) if match[1] else 'res://assets/' + '/'.join(parts))
        return files

    def read_catalog(self, relative):
        if not isinstance(relative, str) or not CATALOG_PATH.fullmatch(relative):
            raise ProjectError(400, '只能編輯 data/asset_catalog.json 或 stories/<作品>/catalog.json。')
        raw = self.read_bytes(self.safe_path(relative))
        try:
            catalog = parse_json(raw) if raw is not None else {'backgrounds': {}, 'characters': {}, 'items': {}}
        except (ValueError, UnicodeError, RecursionError) as error:
            raise ProjectError(409, '素材設定無法解析，請先修正檔案：' + str(error)) from error
        return {'path': relative, 'catalog': catalog, 'hash': digest(raw) if raw is not None else None,
                'files': self.catalog_files(relative)}

    def check_catalog(self, candidate, replaces, pairs):
        return validate_catalog(candidate, self.root, self.godot, replaces, pairs)

    def save_catalog(self, request):
        if not isinstance(request, dict) or not isinstance(request.get('catalog'), dict):
            raise ProjectError(400, '需要素材設定物件。')
        relative, base = request.get('path'), request.get('base_hash')
        if not isinstance(relative, str) or not CATALOG_PATH.fullmatch(relative):
            raise ProjectError(400, '只能編輯 data/asset_catalog.json 或 stories/<作品>/catalog.json。')
        if 'base_hash' not in request or base is not None and (not isinstance(base, str) or not re.fullmatch('[0-9a-f]{64}', base)):
            raise ProjectError(400, '缺少開檔時的基底 hash。')
        target = self.safe_path(relative)
        if not target.parent.is_dir():
            raise ProjectError(404, '作品資料夾不存在。')
        with self.mutex:
            current = self.read_bytes(target)
            if base != (digest(current) if current is not None else None):
                raise ProjectError(409, '素材設定已被別人改過，未覆寫。請重新開啟素材設定再改。')
            data = json_bytes(request['catalog'])
            # Beside the catalog it replaces, so relative art paths resolve the same; never left behind.
            candidate = target.parent / f'.catalog-candidate-{uuid.uuid4().hex}.json'
            try:
                atomic_write(candidate, data)
                try:
                    errors = self.check_catalog(str(candidate), 'res://' + relative, self.catalog_stories(relative))
                except (OSError, subprocess.TimeoutExpired, TimeoutError) as error:
                    raise ProjectError(503, '驗證未完成，素材設定沒有存。', errors=[str(error)]) from error
            finally:
                candidate.unlink(missing_ok=True)
            if errors:
                raise ProjectError(422, '驗證未通過，素材設定沒有存。', errors=errors)
            if self.read_bytes(target) != current:
                raise ProjectError(409, '驗證期間素材設定被改過，未覆寫。')
            atomic_write(target, data)
            return {'ok': True, 'path': relative, 'hash': digest(data), 'catalog': request['catalog'],
                    'message': '素材設定驗證通過，已存回專案。'}

    def new_work(self, request):
        """A new work folder: pack.json without stories and a starting catalog of its own."""
        if not isinstance(request, dict):
            raise ProjectError(400, '需要作品物件。')
        work, title = request.get('id'), request.get('title')
        if not isinstance(work, str) or not WORK_ID.fullmatch(work):
            raise ProjectError(400, '作品 id 只能用英文小寫、數字與底線，且不以數字開頭。')
        if not isinstance(title, str) or not title.strip() or len(title) > 80:
            raise ProjectError(400, '請填作品名稱（80 字以內）。')
        with self.mutex:
            folder = self.safe_path(f'stories/{work}')
            if folder.exists():
                raise ProjectError(409, f'已經有 stories/{work}/ 這個作品資料夾。')
            pack = {'id': work, 'title': title.strip(), 'stories': []}
            catalog = {'default_pov': 'hero', 'default_background': 'room',
                       'backgrounds': {'room': {'label': '房間', 'top': '#2e2a45', 'bottom': '#b9794f'}},
                       'characters': {'hero': {'name': '主角', 'color': '#d98c5f', 'slot': 'center'}},
                       'items': {}, 'sounds': {}, 'music': {}}
            folder.mkdir(parents=True)
            (folder / 'art').mkdir()
            atomic_write(folder / 'catalog.json', json_bytes(catalog))
            atomic_write(folder / 'pack.json', json_bytes(pack))
            return {'ok': True, 'packs': self.list_packs(), 'catalog': catalog,
                    'message': f'已建立作品 stories/{work}/：pack.json、catalog.json（主角與一張漸層背景）、art/。'}

    def list_skins(self):
        root = self.safe_path('skins')
        if not root.is_dir():
            return []
        skins = []
        for directory in sorted(root.iterdir()):
            if directory.is_symlink() or not directory.is_dir() or not re.fullmatch(r'[A-Za-z0-9_-]{1,80}', directory.name):
                continue
            try:
                raw = self.read_bytes(self.safe_path(f'skins/{directory.name}/skin.json'))
                value = parse_json(raw or b'')
                if isinstance(value, dict):
                    skins.append({'id': directory.name, 'name': str(value.get('name', directory.name))})
            except (ProjectError, ValueError, UnicodeError, RecursionError):
                continue
        return skins

    def metadata(self, entry):
        if not isinstance(entry, dict):
            raise ProjectError(400, '需要故事登記物件。')
        if 'skin' in entry and (not isinstance(entry['skin'], str) or entry['skin'] != '' and not re.fullmatch(r'[A-Za-z0-9_-]{1,80}', entry['skin'])):
            raise ProjectError(400, '外觀包 id 格式不合法。')
        if 'cover' in entry:
            cover = entry['cover']
            if cover == '':
                return {key: entry[key] for key in ('skin', 'cover') if key in entry}
            if not isinstance(cover, str) or not cover.startswith('res://'):
                raise ProjectError(400, '封面必須是 res:// 專案圖片路徑。')
            self.safe_path(cover[6:])
        return {key: entry[key] for key in ('skin', 'cover') if key in entry}

    def change_metadata(self, request, raw, registry, entry):
        if request.get('registry_hash') != digest(raw):
            raise ProjectError(409, '故事登記已變更，未覆寫外觀設定。請下載目前登記，再重新開啟比較。')
        changes = self.metadata(request.get('registry_entry'))
        before = dict(entry)
        for key in ('skin', 'cover'):
            if key in changes:
                entry[key] = changes[key]
            else:
                entry.pop(key, None)
        return before != entry

    def registry_reply(self, owner, registry, raw):
        """The saved registry in a reply: the base registry, or the work's pack with its owner path."""
        if owner == BASE_REGISTRY:
            return {'registry': registry, 'registry_hash': digest(raw)}
        return {'owner': owner, 'pack': registry, 'pack_hash': digest(raw)}

    def save_registry(self, request):
        if not isinstance(request, dict):
            raise ProjectError(400, '需要外觀設定物件。')
        relative = request.get('path')
        matched = story_match(relative)
        if not matched:
            raise ProjectError(400, '故事路徑不合法。')
        _, owner, work = matched
        self.safe_path(relative)
        with self.mutex:
            target, raw, registry = self.registry(owner)
            entries = [e for e in registry['stories'] if entry_path(e, work) == 'res://' + relative]
            if len(entries) != 1:
                raise ProjectError(409, '外觀設定需要唯一的既有故事登記。')
            self.change_metadata(request, raw, registry, entries[0])
            updated = json_bytes(registry)
            atomic_write(target, updated)
            return {'ok': True, **self.registry_reply(owner, registry, updated), 'message': '外觀設定已存回專案。'}

    def authorize(self, relative, story):
        matched = story_match(relative)
        if not matched:
            raise ProjectError(400, '只能儲存 data/<名稱>_story.json 或 stories/<作品>/<名稱>_story.json。')
        new_id, owner, work = matched
        path = self.safe_path(relative)
        registry_path, registry_raw, registry = self.registry(owner)
        entries = [e for e in registry['stories'] if entry_path(e, work) == 'res://' + relative]
        if len(entries) > 1:
            raise ProjectError(409, '故事登記的路徑重複，請先修正 registry。')
        if entries and entries[0].get('authoring') != 'graph':
            raise ProjectError(403, '此故事由來源檔建置，請先轉成圖編輯來源。')
        current = self.read_bytes(path)
        if current:
            try:
                old_story = parse_json(current)
            except (ValueError, UnicodeError, RecursionError) as error:
                raise ProjectError(409, '磁碟故事無法解析；保留現況，請先另存新故事。') from error
            if isinstance(old_story, dict) and 'generated_from' in old_story:
                raise ProjectError(403, '不可覆寫建置產物。')
        if 'generated_from' in story:
            raise ProjectError(403, '建置產物必須先複製成圖編輯來源。')
        return path, current, registry_path, registry_raw, registry, entries, new_id, owner, work

    def check(self, candidate, catalog=None):
        return validate_candidate(candidate, self.root, self.godot, catalog)

    def save(self, request):
        if not isinstance(request, dict) or not isinstance(request.get('story'), dict):
            raise ProjectError(400, '需要 story JSON 物件。')
        relative, story, base = request.get('path'), request['story'], request.get('base_hash')
        if base is not None and (not isinstance(base, str) or not re.fullmatch('[0-9a-f]{64}', base)):
            raise ProjectError(400, '基底 hash 格式不合法。')
        if 'base_hash' not in request:
            raise ProjectError(400, '缺少開檔時的基底 hash。')
        with self.mutex:
            target, current, registry_path, registry_raw, registry, entries, new_id, owner, work = self.authorize(relative, story)
            if base != (digest(current) if current is not None else None):
                raise ProjectError(409, '磁碟檔案已變更，未覆寫。請先匯出目前修改，再重新開啟專案版本比較。')
            if not entries:
                if story.get('id') != new_id or new_id in self.taken_ids():
                    raise ProjectError(409, '新故事的檔名、id 必須一致，且不能與既有登記重複。')
            if entries and request.get('update_registry'):
                self.change_metadata(request, registry_raw, registry, entries[0])
            if not entries and request.get('registry_entry') is not None:
                self.metadata(request['registry_entry'])
            # Candidates are private and persistent on failure; no invalid file is published to data/.
            draft_root = self.safe_path('tools/story_editor/.drafts')
            draft_root.mkdir(parents=True, exist_ok=True)
            candidate_dir = draft_root / uuid.uuid4().hex
            candidate_dir.mkdir()
            candidate = candidate_dir / target.name
            atomic_write(candidate, json_bytes(story))
            try:
                errors = self.check(candidate, self.catalog_for(work))
            except (OSError, subprocess.TimeoutExpired, TimeoutError) as error:
                raise ProjectError(503, '驗證未完成；修改已保留為待修草稿。', errors=[str(error)], draft=candidate_dir.name) from error
            if errors:
                raise ProjectError(422, '驗證未通過；修改已保留，遊戲仍使用上次通過的版本。', errors=errors, draft=candidate_dir.name)
            validated = candidate.read_bytes()
            # Re-read after Godot: an external editor may have changed the story or registry while checking.
            target, latest, registry_path, registry_raw, registry, entries, new_id, owner, work = self.authorize(relative, story)
            if base != (digest(latest) if latest is not None else None):
                raise ProjectError(409, '驗證期間磁碟檔案已變更，未覆寫；修改已保留為待修草稿。', draft=candidate_dir.name)
            registered = None
            registry_changed = False
            if entries and request.get('update_registry'):
                registry_changed = self.change_metadata(request, registry_raw, registry, entries[0])
            if not entries:
                if new_id in self.taken_ids():
                    raise ProjectError(409, '驗證期間已有同名故事登記，未覆寫。', draft=candidate_dir.name)
                registered = dict(request.get('registry_entry') or {})
                self.metadata(registered)
                if work is None:
                    registered.update({'id': new_id, 'kind': 'sample', 'path': 'res://' + relative,
                                       'save': 'user://' + new_id + '.save', 'authoring': 'graph'})
                else:  # the game derives save, work and work_title of a pack's story
                    kind = registered.get('kind') if registered.get('kind') in ('chapter', 'sample') else 'chapter'
                    registered = {key: registered[key] for key in ('skin', 'cover') if registered.get(key)}
                    registered.update({'id': new_id, 'kind': kind, 'path': relative.rsplit('/', 1)[1], 'authoring': 'graph'})
                registry_changed = True
                registry['stories'].append(registered)
            try:
                atomic_write(target, validated)
                if registry_changed:
                    try:
                        atomic_write(registry_path, json_bytes(registry))
                    except OSError:
                        if latest is None:
                            target.unlink()
                        else:
                            atomic_write(target, latest)
                        raise
            except OSError as error:
                raise ProjectError(500, '檔案未能完整儲存；修改已保留為待修草稿。', errors=[str(error)], draft=candidate_dir.name) from error
            shutil.rmtree(candidate_dir, ignore_errors=True)
            return {'ok': True, 'path': relative, 'hash': digest(validated), 'text': validated.decode('utf-8'),
                    'registered': registered, **self.registry_reply(owner, registry, json_bytes(registry) if registry_changed else registry_raw),
                    'message': '驗證通過，已存回專案。'}


class ProjectHandler(SimpleHTTPRequestHandler):
    def __init__(self, request, client_address, server):
        super().__init__(request, client_address, server, directory=str(server.project.root))

    def setup(self):
        super().setup()
        self.connection.settimeout(30)

    def end_headers(self):
        self.send_header('X-Story-Editor-Service', SERVICE)
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        super().end_headers()

    def valid_host(self):
        port = self.server.server_port
        return self.headers.get('Host') in (f'127.0.0.1:{port}', f'localhost:{port}')

    def json_response(self, status, value):
        data = json_bytes(value)
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if not self.valid_host():
            self.send_error(403)
            return
        parsed = urlsplit(self.path)
        if parsed.path == '/api/capabilities':
            try:
                _, raw, registry = self.server.project.registry()
                self.json_response(200, {'service': SERVICE, 'token': self.server.project.token,
                                        'registry': registry, 'registry_hash': digest(raw), 'skins': self.server.project.list_skins(),
                                        'packs': self.server.project.list_packs()})
            except ProjectError as error:
                self.json_response(error.status, error.details)
            return
        if parsed.path == '/api/catalog':
            try:
                query = dict(part.split('=', 1) for part in parsed.query.split('&') if '=' in part)
                self.json_response(200, self.server.project.read_catalog(unquote(query.get('path', ''))))
            except ProjectError as error:
                self.json_response(error.status, error.details)
            return
        if parsed.path == '/':
            self.send_response(302)
            self.send_header('Location', '/tools/story_editor/')
            self.end_headers()
            return
        super().do_GET()

    def do_HEAD(self):
        if not self.valid_host():
            self.send_error(403)
            return
        super().do_HEAD()

    def send_head(self):
        try:
            parts = unquote(urlsplit(self.path).path).strip('/').split('/')
            if any(p.startswith('.') or p == '..' or '\\' in p for p in parts):
                raise ProjectError(403, '私有路徑不可讀取。')
            self.server.project.safe_path('/'.join(p for p in parts if p))
        except ProjectError:
            self.send_error(403)
            return None
        return super().send_head()

    def list_directory(self, path):
        self.send_error(403)
        return None

    def do_POST(self):
        try:
            origin = self.headers.get('Origin')
            if not self.valid_host() or (origin and origin != 'http://' + self.headers.get('Host', '')):
                raise ProjectError(403, '請從本機編輯器頁面存檔。')
            if self.headers.get('X-Story-Editor-Token') != self.server.project.token:
                raise ProjectError(403, '本機服務憑證不符，請重新開啟編輯器。')
            if urlsplit(self.path).path not in ('/api/save', '/api/registry', '/api/work', '/api/catalog'):
                raise ProjectError(404, '沒有這個操作。')
            if self.headers.get('Content-Type', '').split(';')[0].strip().lower() != 'application/json':
                raise ProjectError(415, '只接受 JSON。')
            if self.headers.get('Transfer-Encoding'):
                raise ProjectError(400, '不接受分塊請求。')
            try:
                length = int(self.headers.get('Content-Length', ''))
            except ValueError:
                raise ProjectError(411, '需要 Content-Length。')
            if not 0 < length <= MAX_BODY:
                raise ProjectError(413, '請求大小超過限制。')
            body = self.rfile.read(length)
            if len(body) != length:
                raise ProjectError(400, '請求內容不完整。')
            try:
                request = parse_json(body)
            except (ValueError, UnicodeError, RecursionError) as error:
                raise ProjectError(400, '不是合法 JSON。') from error
            action = urlsplit(self.path).path
            project = self.server.project
            result = (project.save_registry(request) if action == '/api/registry'
                      else project.new_work(request) if action == '/api/work'
                      else project.save_catalog(request) if action == '/api/catalog' else project.save(request))
            self.json_response(200, result)
        except ProjectError as error:
            self.close_connection = True
            self.json_response(error.status, error.details)
        except (OSError, ValueError, RecursionError) as error:
            self.close_connection = True
            self.json_response(500, {'error': '服務未能儲存；目前修改仍在編輯器。', 'errors': [str(error)]})


def make_server(root, godot, port):
    server = ThreadingHTTPServer(('127.0.0.1', port), ProjectHandler)
    server.daemon_threads = False
    server.project = StoryProject(root, godot)
    return server


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', default=str(Path(__file__).resolve().parents[2]))
    parser.add_argument('--port', type=int, default=8000)
    parser.add_argument('--godot', default=shutil.which('godot') or '/Applications/Godot.app/Contents/MacOS/Godot')
    args = parser.parse_args()
    server = make_server(args.project, args.godot, args.port)
    def stop(signum, frame):
        raise KeyboardInterrupt
    signal.signal(signal.SIGTERM, stop)
    print(f'Story editor: http://127.0.0.1:{server.server_port}/tools/story_editor/', flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == '__main__':
    main()
