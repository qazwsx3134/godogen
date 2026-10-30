"""Isolated CLI checks: real shell entrypoint, no Godot or game saves."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

KIT = Path(__file__).resolve().parents[1]


class AuditCopiesTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.kit = self.base / 'prototypes/godot-kit'
        (self.kit / 'tools').mkdir(parents=True)
        for name in ['tools/audit_copies.py', 'sync.sh']:
            shutil.copyfile(KIT / name, self.kit / name)
        self.source = self.kit / 'addons/proto_kit'
        self.source.mkdir(parents=True)
        self.game = self.base / 'prototypes/game'
        self.copy = self.game / 'addons/proto_kit'
        self.copy.mkdir(parents=True)
        (self.game / 'project.godot').write_text('config_version=5\n')
        (self.source / 'same.gd').write_text('same\n')
        (self.copy / 'same.gd').write_text('same\n')

    def run_check(self, *targets):
        return subprocess.run(['bash', str(self.kit / 'sync.sh'), '--check', *targets],
                              capture_output=True, text=True, check=False)

    def snapshot(self):
        return {str(p.relative_to(self.copy)): (hashlib.sha256(p.read_bytes()).hexdigest(), p.stat().st_mtime_ns)
                for p in self.copy.rglob('*') if p.is_file()}

    def test_matching_named_and_automatic_checks(self):
        self.assertEqual(self.run_check('game').returncode, 0)
        self.assertEqual(self.run_check().returncode, 0)

    def test_all_difference_classes_are_read_only(self):
        (self.source / 'new.gd').write_text('upstream')
        (self.source / 'changed.gd').write_text('new')
        (self.copy / 'changed.gd').write_text('old')
        (self.copy / 'local.gd').write_text('keep me')
        before = self.snapshot()
        result = self.run_check('game')
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn('changed=1, only_in_kit=1, only_in_copy=1', result.stdout)
        self.assertIn('changed: changed.gd', result.stdout)
        self.assertIn('copy only: local.gd', result.stdout)
        self.assertEqual(self.snapshot(), before)
        result = subprocess.run(['python3', str(self.kit / 'tools/audit_copies.py'), '--check', '--json', 'game'],
                                capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 1)
        data = json.loads(result.stdout)['game']
        self.assertEqual(data['only_in_kit'], ['new.gd'])
        self.assertEqual(self.snapshot(), before)

    def test_external_path_with_spaces(self):
        external = self.base / 'external game'
        shutil.copytree(self.game, external)
        self.assertEqual(self.run_check(str(external)).returncode, 0)

    def test_missing_copy_does_not_create_directory(self):
        shutil.rmtree(self.copy)
        self.assertEqual(self.run_check('game').returncode, 1)
        self.assertFalse(self.copy.exists())

    def test_one_drifting_target_fails_combined_check(self):
        shutil.copytree(self.game, self.base / 'prototypes/other')
        (self.base / 'prototypes/other/addons/proto_kit/same.gd').write_text('different')
        self.assertEqual(self.run_check('game', 'other').returncode, 1)


if __name__ == '__main__':
    unittest.main()
