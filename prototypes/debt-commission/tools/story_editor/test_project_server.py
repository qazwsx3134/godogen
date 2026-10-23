#!/usr/bin/env python3
"""HTTP/storage integration against temporary data and the real project's Godot validator."""
from copy import deepcopy
import http.client
import json
import os
from pathlib import Path
import shutil
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
        self.server.project.check = lambda candidate: service.validate_candidate(candidate, ROOT, GODOT)
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
        def concurrent(candidate):
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
        def concurrent(candidate):
            latest=deepcopy(self.registry);latest['other_writer']='keep'
            self.registry_path.write_bytes(service.json_bytes(latest))
            return []
        self.server.project.check=concurrent
        status,result=self.request(payload)
        self.assertEqual(status,409,result)
        self.assertEqual((self.root/'data/phase3_story.json').read_bytes(),self.original)
        self.assertEqual(json.loads(self.registry_path.read_bytes())['other_writer'],'keep')


if __name__ == '__main__':
    unittest.main()
