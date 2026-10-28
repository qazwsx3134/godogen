"""Persona editor endpoints: real HTTP and confirmation gates, temporary data only."""
import http.client
import json
from pathlib import Path
import tempfile
import threading
import unittest

import project_server as service

pc = service.persona_context


class PersonaServiceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='debt-persona-service-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.library = self.root / 'authoring'
        for folder in ('characters', 'memories'):
            (self.library / folder).mkdir(parents=True)
        for cid in ('alice', 'bob'):
            self.put('characters/' + cid + '.json', {
                'schema_version': 1, 'kind': 'character', 'id': cid, 'name': cid,
                'revision': 1, 'sources': ['synthetic test fixture'], 'core': {'surface': ['test']},
                'behavior': {'test': 'test'}, 'voice': {'examples': ['test'], 'avoid': ['test']},
                'relationships': {'test': 'test'}, 'boundaries': {'test': 'test'}})
        self.put('memories/alice_private.json', {'schema_version': 1, 'kind': 'memory',
            'id': 'alice_private', 'revision': 1, 'sources': ['synthetic test fixture'],
            'owner': 'alice', 'category': 'story', 'summary': 'Only Alice knows.',
            'known_to': ['alice'], 'mutable': False})
        self.manifest = {'schema_version': 1, 'records': {}}
        for item in pc.load(self.library).values():
            self.approve(item)
        self.server = service.make_server(self.root, 'unused-no-godot-needed', 0)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.addCleanup(self.stop)

    def stop(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()

    def put(self, name, item):
        (self.library / name).write_bytes(service.json_bytes(item))

    def approve(self, item):
        self.manifest['records'][item['id']] = {'decision': 'confirmed', 'sha256': pc.digest(item),
            'reviewer': 'synthetic fixture', 'evidence': 'TEST ONLY, not actual human consent',
            'confirmed_at': '2026-10-28T00:00:00Z'}
        self.put('confirmations.json', self.manifest)

    def request(self, route='/api/personas', data=None, token=True):
        connection = http.client.HTTPConnection('127.0.0.1', self.server.server_port, timeout=5)
        headers = {'Content-Type': 'application/json'}
        if token:
            headers['X-Story-Editor-Token'] = self.server.project.token
        connection.request('GET' if data is None else 'POST', route,
                           body=None if data is None else service.json_bytes(data), headers=headers)
        response = connection.getresponse()
        result = response.status, json.loads(response.read())
        connection.close()
        return result

    def selection(self, memories=None):
        ids = ['alice', 'bob'] + (memories or [])
        records = pc.load(self.library)
        return {'characters': ['alice', 'bob'], 'memories': memories or [],
                'hashes': {key: pc.digest(records[key]) for key in ids}}

    def test_review_and_explicit_memory_selection_are_read_only(self):
        before = {f: f.read_bytes() for f in self.library.rglob('*.json')}
        status, result = self.request()
        self.assertEqual(status, 200)
        self.assertEqual(len(result['records']), 3)
        self.assertTrue(all(x['confirmed'] for x in result['records']))
        status, context = self.request('/api/persona-context', self.selection())
        self.assertEqual(status, 200, context)
        self.assertEqual(context['memories_by_character'], {'alice': [], 'bob': []})
        status, context = self.request('/api/persona-context', self.selection(['alice_private']))
        self.assertEqual(status, 200, context)
        self.assertEqual(context['memories_by_character']['bob'], [])
        self.assertEqual(context['memories_by_character']['alice'][0]['id'], 'alice_private')
        self.assertEqual(before, {f: f.read_bytes() for f in self.library.rglob('*.json')})

    def test_draft_or_changed_content_blocks_entire_context(self):
        payload = self.selection()
        item = pc.read(self.library / 'characters/alice.json')
        item['core']['surface'].append('not approved')
        self.put('characters/alice.json', item)
        status, review = self.request()
        self.assertEqual(status, 200)
        self.assertFalse(next(x for x in review['records'] if x['content']['id'] == 'alice')['confirmed'])
        status, result = self.request('/api/persona-context', payload)
        self.assertEqual(status, 422)
        self.assertNotIn('characters', result)

    def test_reapproved_new_version_requires_review_refresh(self):
        payload = self.selection()
        item = pc.read(self.library / 'characters/alice.json')
        item['revision'] = 2
        self.put('characters/alice.json', item)
        self.approve(item)
        self.assertEqual(self.request('/api/persona-context', payload)[0], 409)
        self.assertEqual(self.request('/api/persona-context', self.selection())[0], 200)

    def test_invalid_selection_and_missing_token(self):
        self.assertEqual(self.request('/api/persona-context', self.selection(), token=False)[0], 403)
        for payload in ([], {'characters': 'alice'}, {'characters': [{}], 'hashes': {}},
                        {'characters': [], 'hashes': {}},
                        {'characters': ['unknown'], 'hashes': {}},
                        {'characters': ['alice', 'alice'], 'hashes': {}},
                        {'characters': ['bob'], 'memories': ['alice_private'], 'hashes': {}}):
            status, result = self.request('/api/persona-context', payload)
            self.assertIn(status, (400, 422), result)
            self.assertNotIn('versions', result)

    def test_archives_and_proposals_are_not_loaded(self):
        for folder in ('archive/old', 'proposals/new'):
            target = self.library / folder / 'characters'
            target.mkdir(parents=True)
            (target / 'broken.json').write_text('invalid JSON')
        status, result = self.request()
        self.assertEqual(status, 200)
        self.assertEqual(len(result['records']), 3)

    def test_symlink_or_broken_library_reports_error(self):
        path = self.library / 'characters/alice.json'
        path.unlink()
        path.symlink_to(self.library / 'characters/bob.json')
        self.assertEqual(self.request()[0], 403)
        path.unlink()
        path.write_text('invalid JSON')
        self.assertEqual(self.request()[0], 422)

    def test_absent_library_is_empty(self):
        self.server.project.root = self.root / 'empty-project'
        status, result = self.request()
        self.assertEqual(status, 200)
        self.assertEqual(result, {'available': False, 'records': []})


if __name__ == '__main__':
    unittest.main()
