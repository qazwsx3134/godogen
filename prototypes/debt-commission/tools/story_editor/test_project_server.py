#!/usr/bin/env python3
"""HTTP/storage integration against temporary data and the real project's Godot validator."""
from copy import deepcopy
import http.client
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import threading
import unittest
from unittest.mock import patch

import project_server as service

ROOT = Path(__file__).resolve().parents[2]
GODOT = os.environ.get('GODOT_BIN', shutil.which('godot') or '/Applications/Godot.app/Contents/MacOS/Godot')


class ProjectServiceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='debt-project-service-')
        self.root = Path(self.temp.name).resolve()
        (self.root / 'data').mkdir()
        self.original = (ROOT / 'data/phase3_story.json').read_bytes()
        (self.root / 'data/phase3_story.json').write_bytes(self.original)
        self.registry = {'extra': {'keep': True}, 'stories': [
            {'id': 'phase3', 'path': 'res://data/phase3_story.json', 'authoring': 'graph', 'save': 'user://phase3.save'},
            {'id': 'built', 'path': 'res://data/built_story.json', 'authoring': 'dialogue'}]}
        self.registry_path = self.root / 'data/stories.json'
        self.registry_path.write_bytes(service.json_bytes(self.registry))
        self.server = service.make_server(self.root, GODOT, 0)
        # Target files are temporary; validation still uses the game's actual runner/catalog/build code.
        # A work's catalog (res://stories/<作品>/catalog.json) is read from the temporary project.
        self.server.project.check = lambda candidate, catalog=None: service.validate_candidate(
            candidate, ROOT, GODOT, catalog and str(self.root / catalog[len('res://'):]))
        # Catalog checks read the temporary project; the replaced catalog keeps its res:// name so
        # works that extend it read the candidate.
        local = lambda path: path if not path.startswith('res://') else str(self.root / path[len('res://'):])
        self.server.project.check_catalog = lambda candidate, replaces, pairs: service.validate_catalog(
            candidate, ROOT, GODOT, replaces, [(local(story), catalog if catalog == replaces else local(catalog)) for story, catalog in pairs])
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.token = self.server.project.token

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()
        self.temp.cleanup()

    def request(self, data, route='/api/save', **headers):
        connection = http.client.HTTPConnection('127.0.0.1', self.server.server_port, timeout=180)
        body = service.json_bytes(data) if isinstance(data, dict) else data
        connection.request('POST', route, body=body,
                           headers={'Content-Type': 'application/json', 'X-Story-Editor-Token': self.token, **headers})
        response = connection.getresponse()
        result = response.read()
        connection.close()
        return response.status, json.loads(result)

    def payload(self):
        story = json.loads(self.original)
        story['version'] = 's-unset'
        story['nodes']['phase3_open']['steps'][3]['text'] = '服務測試的台詞。'
        story['credits'] = [{'role': '劇本', 'names': ['測試作者']}]
        return {'path': 'data/phase3_story.json', 'base_hash': service.digest(self.original), 'story': story}

    def test_save_success_conflict_and_invalid_candidate(self):
        payload = self.payload()
        payload.update({'registry_entry':{'skin':'alpha','cover':'res://assets/image/cover.png'},'update_registry':True,'registry_hash':service.digest(self.registry_path.read_bytes())})
        status, result = self.request(payload)
        self.assertEqual(status, 200, result)
        written = (self.root / payload['path']).read_bytes()
        self.assertEqual(result['registry']['stories'][0]['skin'],'alpha')
        self.assertEqual(result['registry']['stories'][1],self.registry['stories'][1])
        self.assertEqual(result['hash'], service.digest(written))
        self.assertEqual(result['text'].encode(), written)
        story = json.loads(written)
        self.assertRegex(story['version'], r'^s-[0-9a-f]{12}$')
        self.assertEqual(story['nodes']['phase3_open']['steps'][3]['text'], '服務測試的台詞。')
        self.assertEqual(story['credits'], payload['story']['credits'])
        # Independently run read-only check against the persisted disk bytes.
        import subprocess
        from godot_guard import godot_environment
        with godot_environment(timeout=45) as env:
            checked = subprocess.run([GODOT, '--headless', '--path', str(ROOT), '--script',
                                      'res://tools/story_editor/check_story.gd', '--', str(self.root / payload['path'])],
                                     env=env, text=True, capture_output=True, timeout=90)
        self.assertEqual(checked.returncode, 0, checked.stdout + checked.stderr)
        self.assertEqual(self.request(payload)[0], 409)
        self.assertEqual((self.root / payload['path']).read_bytes(), written)
        bad = deepcopy(payload)
        bad['base_hash'] = result['hash']
        bad['registry_hash'] = result['registry_hash']
        bad['story']['nodes']['phase3_open']['steps'][0]['id'] = 'missing_background'
        status, rejected = self.request(bad)
        self.assertEqual(status, 422, rejected)
        self.assertTrue(any('background' in e or 'bg id' in e for e in rejected['errors']))
        draft = self.root / 'tools/story_editor/.drafts' / rejected['draft'] / 'phase3_story.json'
        self.assertEqual(json.loads(draft.read_bytes()), bad['story'])
        self.assertEqual((self.root / payload['path']).read_bytes(), written)

    def test_preview_unsaved_scene_flags_items_and_isolated_user_data(self):
        story = {'id': 'preview_test', 'version': 's-unset', 'title': '試玩測試', 'entry': 'start',
                 'initial_flags': {'seen': False}, 'nodes': {
                     'start': {'title': '起點', 'steps': [{'op': 'say', 'speaker': 'narrator', 'text': '起點'}], 'next': 'middle'},
                     'middle': {'title': '中途', 'steps': [{'op': 'say', 'speaker': 'narrator', 'text': '未存檔的場景'},
                                          {'op': 'condition', 'flag': 'seen', 'equals': True, 'then': 'yes', 'else': 'no'}]},
                     'yes': {'title': '是', 'steps': [{'op': 'end', 'text': '是'}]},
                     'no': {'title': '否', 'steps': [{'op': 'end', 'text': '否'}]}}}
        request = {'path': 'data/preview_test_story.json', 'story': story, 'node': 'middle',
                   'flags': {'seen': True}, 'items': ['milk_bottle']}
        project = self.server.project
        project.check_preview = lambda candidate, catalog=None: service.validate_candidate(
            candidate, ROOT, GODOT, catalog, allow_unreachable=True)
        launched = {}
        def launch(config, environment):
            launched['config'] = json.loads(config.read_text())
            launched['environment'] = environment
            process = subprocess.Popen([GODOT, '--headless', '--path', str(ROOT), '--quit-after', '600',
                                        '--scene', 'res://tools/story_build/preview.tscn', '--',
                                        f'--editor-preview={config}'], env=environment,
                                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            launched['process'] = process
            return process
        project.launch_preview = launch
        try:
            status, response = self.request(request, route='/api/preview')
            self.assertEqual(status, 200, response)
            report = json.loads(Path(launched['config']['status']).read_text())
            self.assertTrue(report['ok'])
            self.assertEqual(report['snapshot']['node_id'], 'middle')
            self.assertEqual(report['snapshot']['flags']['seen'], True)
            self.assertEqual(report['snapshot']['items'], ['milk_bottle'])
            self.assertTrue(report['user_dir'].startswith(launched['environment']['HOME']))
            self.assertFalse((self.root / request['path']).exists(), 'preview does not save or register a draft')
            self.assertEqual(json.loads(self.registry_path.read_bytes()), self.registry)
            self.assertEqual((self.root / 'data/phase3_story.json').read_bytes(), self.original)
        finally:
            if launched.get('process') and launched['process'].poll() is None:
                launched['process'].terminate()
                launched['process'].wait(timeout=5)

        self.assertEqual(self.request({**request, 'node': 'missing'}, route='/api/preview')[0], 400)
        self.assertEqual(self.request({**request, 'flags': {'seen': 'yes'}}, route='/api/preview')[0], 400)
        self.assertEqual(self.request({**request, 'flags': {'other': True}}, route='/api/preview')[0], 400)
        self.assertEqual(self.request({**request, 'path': '../outside_story.json'}, route='/api/preview')[0], 400)
        status, response = self.request({**request, 'items': ['not_a_real_item']}, route='/api/preview')
        self.assertEqual(status, 422, response)
        self.assertFalse((self.root / request['path']).exists())
        with patch.object(project, 'launch_preview', side_effect=OSError('missing executable')):
            status, response = self.request(request, route='/api/preview')
        self.assertEqual(status, 503, response)
        self.assertIn('Godot', response['error'])
        self.assertEqual(json.loads(self.registry_path.read_bytes()), self.registry)

    def test_preview_uses_work_catalog_and_skin_for_a_built_story(self):
        work = self.root / 'stories/example'
        work.mkdir(parents=True)
        (work / 'pack.json').write_bytes(service.json_bytes({'id': 'example', 'skin': 'example', 'stories': []}))
        (work / 'catalog.json').write_bytes((ROOT / 'stories/example/catalog.json').read_bytes())
        story = {'id': 'preview_work', 'title': '作品試玩', 'version': 's-unset', 'entry': 'start',
                 'generated_from': 'ch1.dialogue', 'initial_flags': {}, 'nodes': {
                     'start': {'title': '月台', 'steps': [{'op': 'say', 'speaker': 'aki', 'text': '測試作品角色'},
                                                        {'op': 'end', 'text': '完'}]}}}
        project = self.server.project
        project.check_preview = lambda candidate, catalog=None: service.validate_candidate(
            candidate, ROOT, GODOT, catalog, allow_unreachable=True)
        launched = {}
        def launch(config, environment):
            launched['config'] = json.loads(config.read_text())
            launched['process'] = subprocess.Popen(
                [GODOT, '--headless', '--path', str(ROOT), '--quit-after', '600',
                 '--scene', 'res://tools/story_build/preview.tscn', '--', f'--editor-preview={config}'],
                env=environment, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return launched['process']
        project.launch_preview = launch
        try:
            status, result = self.request({'path': 'stories/example/preview_work_story.json', 'story': story,
                                           'node': 'start', 'skin': 'example'}, route='/api/preview')
            self.assertEqual(status, 200, result)
            report = json.loads(Path(launched['config']['status']).read_text())
            self.assertEqual(report['skin'], 'example')
            self.assertEqual(report['snapshot']['node_id'], 'start')
            self.assertEqual(launched['config']['catalog'], 'res://stories/example/catalog.json')
            self.assertFalse((work / 'preview_work_story.json').exists())
            self.assertEqual(json.loads((work / 'pack.json').read_bytes())['stories'], [])
        finally:
            if launched.get('process') and launched['process'].poll() is None:
                launched['process'].terminate()
                launched['process'].wait(timeout=5)

    def test_register_new_story_and_preserve_registry_rows(self):
        story = {'id': 'new_graph', 'title': '新故事', 'entry': 'start', 'version': 's-unset', 'initial_flags': {},
                 'credits': [{'role': '繪', 'names': ['畫師']}],
                 'nodes': {'start': {'title': '起點', 'steps': [{'op': 'say', 'speaker': 'narrator', 'text': '你好'}, {'op': 'end', 'text': ''}]}}}
        status, result = self.request({'path': 'data/new_graph_story.json', 'base_hash': None, 'story': story, 'registry_entry':{'skin':'alpha','cover':'res://assets/image/cover.png','future':{'nested':['保留',2]}}})
        self.assertEqual(status, 200, result)
        registry = json.loads(self.registry_path.read_bytes())
        self.assertEqual(registry['stories'][:-1], self.registry['stories'])
        self.assertEqual(registry['extra'], self.registry['extra'])
        self.assertEqual(registry['stories'][-1]['authoring'], 'graph')
        self.assertEqual(result['registered']['id'], 'new_graph')
        self.assertEqual(result['registered']['skin'],'alpha')
        self.assertEqual(result['registered']['cover'],'res://assets/image/cover.png')
        self.assertEqual(result['registered']['future'],{'nested':['保留',2]})
        self.assertEqual(json.loads((self.root / 'data/new_graph_story.json').read_bytes())['credits'], story['credits'])
        self.assertEqual(self.request({'path': 'data/new_graph_story.json', 'base_hash': None, 'story': story, 'registry_entry':{'skin':'alpha','cover':'res://assets/image/cover.png','future':{'nested':['保留',2]}}})[0], 409)

    def test_generated_products_and_bad_paths_rejected(self):
        payload = self.payload()
        for path in ('../escape_story.json', '/tmp/escape_story.json', 'data/../escape_story.json',
                     'data/x/escape_story.json', 'data/stories.json', 'data/%2e%2e_story.json', 'data\\escape_story.json'):
            self.assertEqual(self.request({**payload, 'path': path})[0], 400, path)
        self.assertEqual(self.request({**payload, 'path': 'data/built_story.json', 'base_hash': None})[0], 403)
        generated = {**payload['story'], 'generated_from': 'story_src/fake.dialogue'}
        self.assertEqual(self.request({**payload, 'story': generated})[0], 403)
        (self.root / 'data/phase3_story.json').write_bytes(service.json_bytes(generated))
        self.assertEqual(self.request({**payload, 'base_hash': service.digest(service.json_bytes(generated))})[0], 403)
        (self.root / 'data/phase3_story.json').unlink()
        outside = self.root / 'outside.json'
        outside.write_bytes(self.original)
        (self.root / 'data/phase3_story.json').symlink_to(outside)
        self.assertEqual(self.request(payload)[0], 403)
        (self.root / 'data/phase3_story.json').unlink()
        self.registry_path.unlink()
        self.registry_path.symlink_to(outside)
        self.assertEqual(self.request(payload)[0], 403)
        self.assertEqual(outside.read_bytes(), self.original)

    def test_http_limits_token_and_private_paths(self):
        payload = self.payload()
        self.assertEqual(self.request(payload, **{'Content-Type': 'text/plain'})[0], 415)
        self.assertEqual(self.request(payload, **{'X-Story-Editor-Token': 'wrong'})[0], 403)
        self.assertEqual(self.request(payload, Origin='https://example.invalid')[0], 403)
        self.assertEqual(self.request(b'{broken')[0], 400)
        self.assertEqual(self.request(b'{"story":{},"story":{}}')[0], 400)
        self.assertEqual(self.request(b'{"story":{"x":1e999}}')[0], 400)
        self.assertEqual(self.request(b'{}', **{'Content-Length': str(service.MAX_BODY + 1)})[0], 413)
        conn = http.client.HTTPConnection('127.0.0.1', self.server.server_port)
        conn.request('GET', '/tools/story_editor/.drafts/nope.json')
        self.assertEqual(conn.getresponse().status, 403)
        conn.close()
        self.assertEqual((self.root / 'data/phase3_story.json').read_bytes(), self.original)

    def test_external_change_during_validation_is_not_overwritten(self):
        payload = self.payload()
        changed = self.original + b'\n'
        def concurrent(candidate, catalog=None):
            (self.root / payload['path']).write_bytes(changed)
            return []
        self.server.project.check = concurrent
        status, result = self.request(payload)
        self.assertEqual(status, 409, result)
        self.assertEqual((self.root / payload['path']).read_bytes(), changed)

    def test_registry_failure_restores_target_and_keeps_candidate(self):
        real_write = service.atomic_write
        def fail_registry(path, data):
            if path == self.registry_path:
                raise OSError('simulated registry write failure')
            return real_write(path, data)
        story = {'id': 'failed_graph', 'version': 's-unset', 'title': '保留', 'entry': 'start', 'initial_flags': {},
                 'nodes': {'start': {'title': '起點', 'steps': [{'op': 'end', 'text': ''}]}}}
        with patch.object(service, 'atomic_write', fail_registry):
            status, result = self.request({'path': 'data/failed_graph_story.json', 'base_hash': None, 'story': story})
        self.assertEqual(status, 500, result)
        self.assertFalse((self.root / 'data/failed_graph_story.json').exists())
        self.assertEqual(json.loads(self.registry_path.read_bytes()), self.registry)
        self.assertTrue((self.root / 'tools/story_editor/.drafts' / result['draft'] / 'failed_graph_story.json').exists())

    def test_readonly_registry_metadata_and_conflicts(self):
        built = self.root / 'data/built_story.json'
        original = service.json_bytes({'generated_from':'story_src/built.dialogue','id':'built'})
        built.write_bytes(original)
        self.registry['stories'][1]['future'] = {'keep':['甲']}
        self.registry_path.write_bytes(service.json_bytes(self.registry))
        payload = {'path':'data/built_story.json','registry_hash':service.digest(self.registry_path.read_bytes()),
                   'registry_entry':{'skin':'alpha','cover':'res://assets/image/cover.png','id':'changed','authoring':'graph','future':'overwrite'}}
        status,result = self.request(payload,route='/api/registry')
        self.assertEqual(status,200,result)
        entry=result['registry']['stories'][1]
        self.assertEqual(entry['skin'],'alpha')
        self.assertEqual(entry['cover'],'res://assets/image/cover.png')
        self.assertEqual(entry['id'],'built')
        self.assertEqual(entry['authoring'],'dialogue')
        self.assertEqual(entry['future'],{'keep':['甲']})
        self.assertEqual(built.read_bytes(),original)
        self.assertEqual(self.request(payload,route='/api/registry')[0],409)
        for metadata in [{'skin':'../escape'},{'cover':'res://../escape.png'},{'cover':'https://example.invalid/x.png'}]:
            status,_=self.request({**payload,'registry_hash':result['registry_hash'],'registry_entry':metadata},route='/api/registry')
            self.assertIn(status,(400,403))
        status,cleared=self.request({**payload,'registry_hash':result['registry_hash'],'registry_entry':{}},route='/api/registry')
        self.assertEqual(status,200,cleared)
        self.assertNotIn('skin',cleared['registry']['stories'][1])
        self.assertNotIn('cover',cleared['registry']['stories'][1])
        self.assertEqual(built.read_bytes(),original)

    def test_skin_discovery_ignores_symlinks(self):
        for skin,name in [('gintama','銀魂和紙'),('alpha','測試外觀')]:
            folder=self.root/'skins'/skin
            folder.mkdir(parents=True)
            (folder/'skin.json').write_bytes(service.json_bytes({'name':name}))
        (self.root/'skins'/'escape').symlink_to(self.root/'skins'/'alpha',target_is_directory=True)
        connection=http.client.HTTPConnection('127.0.0.1',self.server.server_port)
        connection.request('GET','/api/capabilities')
        response=connection.getresponse();value=json.loads(response.read());connection.close()
        self.assertEqual(response.status,200)
        self.assertEqual(value['skins'],[{'id':'alpha','name':'測試外觀'},{'id':'gintama','name':'銀魂和紙'}])
        self.assertEqual(value['registry_hash'],service.digest(self.registry_path.read_bytes()))

    def test_registry_change_during_check_preserves_story(self):
        payload=self.payload()
        payload.update({'update_registry':True,'registry_hash':service.digest(self.registry_path.read_bytes()),'registry_entry':{'skin':'alpha'}})
        def concurrent(candidate, catalog=None):
            latest=deepcopy(self.registry);latest['other_writer']='keep'
            self.registry_path.write_bytes(service.json_bytes(latest))
            return []
        self.server.project.check=concurrent
        status,result=self.request(payload)
        self.assertEqual(status,409,result)
        self.assertEqual((self.root/'data/phase3_story.json').read_bytes(),self.original)
        self.assertEqual(json.loads(self.registry_path.read_bytes())['other_writer'],'keep')

    def pack_story(self, story_id, speaker):
        return {'id': story_id, 'title': '作品的一章', 'entry': 'start', 'version': 's-unset', 'initial_flags': {},
                'nodes': {'start': {'title': '起點', 'steps': [{'op': 'say', 'speaker': speaker, 'text': '你好'},
                                                             {'op': 'end', 'text': '完'}]}}}

    def add_example_work(self):
        folder = self.root / 'stories/example'
        folder.mkdir(parents=True)
        for name in ('pack.json', 'catalog.json'):
            shutil.copy(ROOT / 'stories/example' / name, folder / name)
        return folder

    def test_pack_story_uses_its_work_catalog_and_pack(self):
        folder = self.add_example_work()
        pack_before = json.loads((folder / 'pack.json').read_bytes())
        registry_before = self.registry_path.read_bytes()
        story = self.pack_story('example_ch3', 'aki')  # 秋 is only in the work's catalog
        status, result = self.request({'path': 'stories/example/example_ch3_story.json', 'base_hash': None, 'story': story,
                                       'registry_entry': {'kind': 'chapter', 'save': 'user://x.save', 'skin': 'example'}})
        self.assertEqual(status, 200, result)
        pack = json.loads((folder / 'pack.json').read_bytes())
        self.assertEqual(pack['stories'][:-1], pack_before['stories'])
        self.assertEqual(pack['stories'][-1], {'id': 'example_ch3', 'kind': 'chapter', 'path': 'example_ch3_story.json',
                                               'authoring': 'graph', 'skin': 'example'})
        self.assertEqual((result['owner'], result['pack']), ('stories/example/pack.json', pack))
        self.assertEqual(result['pack_hash'], service.digest((folder / 'pack.json').read_bytes()))
        self.assertNotIn('registry', result)
        self.assertEqual(self.registry_path.read_bytes(), registry_before)
        self.assertRegex(json.loads((folder / 'example_ch3_story.json').read_bytes())['version'], r'^s-[0-9a-f]{12}$')
        # The same lines under data/ are checked against the game's catalog, which has no 秋.
        story['id'] = 'example_base'
        status, result = self.request({'path': 'data/example_base_story.json', 'base_hash': None, 'story': story})
        self.assertEqual(status, 422, result)
        self.assertIn('aki', '\n'.join(result['errors']))
        # Saving it again edits the registered graph story; its metadata goes to the pack.
        written = (folder / 'example_ch3_story.json').read_bytes()
        status, result = self.request({'path': 'stories/example/example_ch3_story.json', 'base_hash': service.digest(written),
                                       'story': json.loads(written), 'registry_entry': {'cover': 'res://stories/example/art/c.png'},
                                       'update_registry': True, 'registry_hash': service.digest((folder / 'pack.json').read_bytes())})
        self.assertEqual(status, 200, result)
        self.assertEqual(result['pack']['stories'][-1].get('cover'), 'res://stories/example/art/c.png')

    def test_story_ids_are_unique_across_works_and_folders_need_a_pack(self):
        self.add_example_work()
        status, result = self.request({'path': 'stories/example/phase3_story.json', 'base_hash': None,
                                       'story': self.pack_story('phase3', 'aki')})
        self.assertEqual(status, 409, result)
        status, result = self.request({'path': 'data/example_ch1_story.json', 'base_hash': None,
                                       'story': self.pack_story('example_ch1', 'narrator')})
        self.assertEqual(status, 409, result)
        status, result = self.request({'path': 'stories/nowork/nowork_ch1_story.json', 'base_hash': None,
                                       'story': self.pack_story('nowork_ch1', 'narrator')})
        self.assertEqual(status, 404, result)
        self.assertFalse((self.root / 'stories/nowork').exists())

    def test_new_work_scaffold_lists_and_validates(self):
        status, result = self.request({'id': 'titan', 'title': '城牆'}, '/api/work')
        self.assertEqual(status, 200, result)
        folder = self.root / 'stories/titan'
        self.assertEqual(json.loads((folder / 'pack.json').read_bytes()), {'id': 'titan', 'title': '城牆', 'stories': []})
        self.assertTrue((folder / 'art').is_dir())
        self.assertEqual([p['id'] for p in result['packs']], ['titan'])
        self.assertEqual(self.request({'id': 'titan', 'title': 'again'}, '/api/work')[0], 409)
        for bad in ({'id': 'Titan', 'title': 'x'}, {'id': '1st', 'title': 'x'}, {'id': '../x', 'title': 'x'}, {'id': 'ok_id', 'title': ' '}):
            self.assertEqual(self.request(bad, '/api/work')[0], 400, bad)
        # The scaffold's own 主角 passes the game's validation; the chapter joins the pack.
        status, result = self.request({'path': 'stories/titan/titan_ch1_story.json', 'base_hash': None,
                                       'story': self.pack_story('titan_ch1', 'hero'), 'registry_entry': {'kind': 'chapter'}})
        self.assertEqual(status, 200, result)
        self.assertEqual([e['id'] for e in result['pack']['stories']], ['titan_ch1'])
        connection = http.client.HTTPConnection('127.0.0.1', self.server.server_port, timeout=30)
        connection.request('GET', '/api/capabilities')
        capabilities = json.loads(connection.getresponse().read())
        connection.close()
        self.assertEqual(capabilities['packs'][0]['pack']['stories'][0]['id'], 'titan_ch1')

    def get(self, route):
        connection = http.client.HTTPConnection('127.0.0.1', self.server.server_port, timeout=60)
        connection.request('GET', route)
        response = connection.getresponse()
        value = json.loads(response.read())
        connection.close()
        return response.status, value

    def add_catalog_project(self):
        shutil.copy(ROOT / 'data/asset_catalog.json', self.root / 'data/asset_catalog.json')
        folder = self.root / 'stories/titan'
        (folder / 'art').mkdir(parents=True)
        (folder / 'art/wall.png').write_bytes((ROOT / 'tests/fixtures/packs/titan/art/wall.png').read_bytes())
        (folder / 'art/.hidden.png').write_bytes(b'x')
        (folder / 'art/wall.png.import').write_bytes(b'x')
        (folder / 'pack.json').write_bytes(service.json_bytes({'id': 'titan', 'title': '城牆', 'stories': [{'id': 'titan_ch1', 'path': 'titan_ch1_story.json'}]}))
        (folder / 'catalog.json').write_bytes(service.json_bytes({'extends': 'res://data/asset_catalog.json',
            'characters': {'eren': {'name': '艾連', 'color': '#7a9a6a', 'slot': 'center'}}}))
        story = self.pack_story('titan_ch1', 'eren')
        story['nodes']['start']['steps'].insert(1, {'op': 'say', 'speaker': 'elisabeth', 'text': '（看板）'})
        (folder / 'titan_ch1_story.json').write_bytes(service.json_bytes(story))
        return folder

    def candidates_left(self):
        return list(self.root.rglob('.catalog-candidate-*'))

    def test_catalog_round_trip_unknown_fields_and_files(self):
        folder = self.add_catalog_project()
        status, base = self.get('/api/catalog?path=data/asset_catalog.json')
        self.assertEqual(status, 200, base)
        before = (self.root / 'data/asset_catalog.json').read_bytes()
        status, result = self.request({'path': 'data/asset_catalog.json', 'base_hash': base['hash'], 'catalog': base['catalog']}, '/api/catalog')
        self.assertEqual(status, 200, result)
        self.assertEqual((self.root / 'data/asset_catalog.json').read_bytes(), before, 'an unchanged save keeps the bytes')
        status, work = self.get('/api/catalog?path=stories/titan/catalog.json')
        self.assertEqual(work['files'], ['art/wall.png'], 'pictures in the work, in its own relative form')
        self.assertEqual(work['catalog']['extends'], 'res://data/asset_catalog.json', 'the raw file, not the merged catalog')
        catalog = work['catalog']
        picture = 'res://tests/fixtures/packs/titan/art/wall.png'  # validation runs in the real project
        catalog['characters']['eren'].update({'path': picture, 'future': {'keep': [1]},
                                              'license': {'author': ['畫師甲'], 'source': '委託', 'license': '自有', 'approved': False}})
        status, result = self.request({'path': 'stories/titan/catalog.json', 'base_hash': work['hash'], 'catalog': catalog}, '/api/catalog')
        self.assertEqual(status, 200, result)
        saved = json.loads((folder / 'catalog.json').read_bytes())
        self.assertEqual(saved['characters']['eren']['future'], {'keep': [1]})
        self.assertEqual(saved['characters']['eren']['path'], picture)
        self.assertNotIn('shinpachi', saved['characters'], 'what it extends is not copied in')
        self.assertEqual(self.request({'path': 'stories/titan/catalog.json', 'base_hash': work['hash'], 'catalog': catalog}, '/api/catalog')[0], 409)
        self.assertEqual(self.request({'path': 'data/stories.json', 'base_hash': None, 'catalog': {}}, '/api/catalog')[0], 400)
        self.assertEqual(self.get('/api/catalog?path=../x/catalog.json')[0], 400)
        self.assertEqual(self.candidates_left(), [])

    def test_catalog_edits_that_break_stories_are_refused(self):
        folder = self.add_catalog_project()
        status, work = self.get('/api/catalog?path=stories/titan/catalog.json')
        before = (folder / 'catalog.json').read_bytes()
        catalog = deepcopy(work['catalog']); del catalog['characters']['eren']
        status, result = self.request({'path': 'stories/titan/catalog.json', 'base_hash': work['hash'], 'catalog': catalog}, '/api/catalog')
        self.assertEqual(status, 422, result)
        self.assertIn('titan_ch1_story.json', '\n'.join(result['errors']))
        self.assertEqual((folder / 'catalog.json').read_bytes(), before)
        # The game's catalog: a work that extends it uses 伊莉莎白, so removing her there is refused too.
        status, base = self.get('/api/catalog?path=data/asset_catalog.json')
        catalog = deepcopy(base['catalog']); del catalog['characters']['elisabeth']
        status, result = self.request({'path': 'data/asset_catalog.json', 'base_hash': base['hash'], 'catalog': catalog}, '/api/catalog')
        self.assertEqual(status, 422, result)
        self.assertIn('titan_ch1_story.json', '\n'.join(result['errors']))
        catalog = deepcopy(base['catalog']); catalog['backgrounds']['bad'] = {'label': '壞', 'top': '#000'}
        status, result = self.request({'path': 'data/asset_catalog.json', 'base_hash': base['hash'], 'catalog': catalog}, '/api/catalog')
        self.assertEqual(status, 422, result)
        self.assertIn('bad', '\n'.join(result['errors']))
        self.assertEqual(self.candidates_left(), [])


if __name__ == '__main__':
    unittest.main()
