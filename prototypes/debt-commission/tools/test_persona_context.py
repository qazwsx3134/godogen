import copy
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

import persona_context as pc


class PersonaContextTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / 'authoring'
        shutil.copytree(pc.DEFAULT_ROOT, self.root)
        self.manifest = {'schema_version': 1, 'records': {}}
        self.save_manifest()

    def save_manifest(self):
        (self.root / 'confirmations.json').write_text(json.dumps(self.manifest))

    def approve_fixture(self, key):
        item = pc.load(self.root)[key]
        self.manifest['records'][key] = {'decision': 'confirmed', 'sha256': pc.digest(item),
            'reviewer': 'test fixture human', 'evidence': 'unit test only, not actual author consent',
            'confirmed_at': '2026-10-28T00:00:00Z'}
        self.save_manifest()

    def test_drafts_cannot_generate_context(self):
        with self.assertRaisesRegex(ValueError, 'human confirmation'):
            pc.context(self.root, ['shinpachi'], [])

    def test_confirmed_persona_with_no_selected_memories(self):
        self.approve_fixture('shinpachi')
        result = pc.context(self.root, ['shinpachi'], [])
        self.assertEqual(result['memories_by_character']['shinpachi'], [])
        self.assertEqual(result['characters'][0]['id'], 'shinpachi')

    def test_each_selected_memory_also_needs_confirmation(self):
        self.approve_fixture('shinpachi')
        with self.assertRaisesRegex(ValueError, 'human confirmation'):
            pc.context(self.root, ['shinpachi'], ['shinpachi_yorozuya_baseline'])

    def test_changed_content_invalidates_confirmation(self):
        self.approve_fixture('shinpachi')
        path = self.root / 'characters/shinpachi.json'
        item = pc.read(path)
        item['core']['surface'].append('unreviewed alteration')
        path.write_text(json.dumps(item))
        with self.assertRaisesRegex(ValueError, 'content changed'):
            pc.context(self.root, ['shinpachi'], [])

    def test_record_cannot_self_confirm(self):
        path = self.root / 'characters/shinpachi.json'
        item = pc.read(path)
        item['status'] = 'confirmed'
        path.write_text(json.dumps(item))
        with self.assertRaisesRegex(ValueError, 'human confirmation'):
            pc.context(self.root, ['shinpachi'], [])

    def test_memory_is_visible_only_to_known_characters(self):
        path = self.root / 'memories/shinpachi_yorozuya_baseline.json'
        item = pc.read(path)
        item['known_to'] = ['shinpachi']
        path.write_text(json.dumps(item))
        for key in ['shinpachi', 'gintoki', item['id']]:
            self.approve_fixture(key)
        result = pc.context(self.root, ['shinpachi', 'gintoki'], [item['id']])
        self.assertEqual(len(result['memories_by_character']['shinpachi']), 1)
        self.assertEqual(result['memories_by_character']['gintoki'], [])

    def test_unknown_owner_is_rejected(self):
        path = self.root / 'memories/shinpachi_yorozuya_baseline.json'
        item = pc.read(path)
        item['owner'] = 'missing'
        path.write_text(json.dumps(item))
        with self.assertRaisesRegex(ValueError, 'owner/known_to'):
            pc.load(self.root)

    def test_duplicate_id_is_rejected(self):
        shutil.copy(self.root / 'characters/shinpachi.json', self.root / 'characters/duplicate.json')
        with self.assertRaisesRegex(ValueError, 'duplicate id'):
            pc.load(self.root)

    def test_missing_confirmation_evidence_is_rejected(self):
        self.approve_fixture('shinpachi')
        self.manifest['records']['shinpachi']['evidence'] = ''
        self.save_manifest()
        with self.assertRaisesRegex(ValueError, 'human confirmation'):
            pc.context(self.root, ['shinpachi'], [])

    def test_hash_ignores_formatting_but_covers_revision(self):
        item = pc.load(self.root)['shinpachi']
        self.assertEqual(pc.digest(item), pc.digest(dict(reversed(list(item.items())))))
        changed = copy.deepcopy(item)
        changed['revision'] += 1
        self.assertNotEqual(pc.digest(item), pc.digest(changed))

    def test_confirmation_command_rejects_stale_review(self):
        before = (self.root / 'confirmations.json').read_bytes()
        result = subprocess.run([sys.executable, str(Path(pc.__file__)), '--root', str(self.root),
            'confirm', '--id', 'shinpachi', '--sha256', '0' * 64,
            '--reviewer', 'test only', '--evidence', 'fixture only'], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('reviewed hash differs', result.stderr)
        self.assertEqual((self.root / 'confirmations.json').read_bytes(), before)


if __name__ == '__main__':
    unittest.main()
