"""Contract tooling L1: multiline signatures, stale detection, omissions and CLI failures."""
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).with_name('capabilities.py')
spec = importlib.util.spec_from_file_location('capabilities', SCRIPT)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class Contracts(unittest.TestCase):
    def test_multiline_and_visibility(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / 'example.gd'
            path.write_text('extends RefCounted\n## Seconds -> result.\nstatic func apply(value: float,\n    options: Dictionary = {}) -> Dictionary:\n    return {}\nfunc _private():\n    pass\nfunc _init(seed: int = 42):\n    pass\nsignal done(value: int)\n')
            result = module.api(path)
            self.assertEqual(len(result['methods']), 2)
            self.assertEqual(result['methods'][0]['signature'], 'static func apply(value: float, options: Dictionary = {}) -> Dictionary:')
            self.assertEqual(result['methods'][0]['contract'], 'Seconds -> result.')
            self.assertEqual(result['signals'], ['signal done(value: int)'])

    def test_unknown_id_fails(self):
        result = subprocess.run([sys.executable, str(SCRIPT), 'show', 'nonexistent'], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('unknown capability', result.stderr)

    def test_source_changes_detected(self):
        data = module.build()
        self.assertEqual(module.validate(data), [])
        generated = json.loads((module.KIT / 'catalog/capabilities.json').read_text())
        self.assertEqual(data, generated)
        entry = data['capabilities'][0]
        original = entry['purpose']
        entry['purpose'] = ''
        self.assertIn(f"{entry['id']}: empty purpose", module.validate(data))
        entry['purpose'] = original
        entry['sha256'] = 'broken'
        self.assertNotEqual(data, generated)

    def test_dependency_plan(self):
        plan = module.dependency_plan(module.build(), ['save_slots', 'fixed_step'])
        self.assertEqual(plan['unresolved_or_example_paths'], [])
        self.assertEqual(set(plan['files']), {'addons/proto_kit/save_slots.gd', 'addons/proto_kit/atomic_file.gd', 'addons/proto_kit/fixed_step.gd'})
        with self.assertRaises(ValueError):
            module.dependency_plan(module.build(), ['missing'])
        scene_plan = module.dependency_plan(module.build(), ['damage_numbers_3d'])
        self.assertIn('addons/proto_kit/damage_number_3d.tscn', scene_plan['files'])

    def test_catalog_covers_all_scripts(self):
        data = module.build()
        paths = {e['path'] for e in data['capabilities']}
        actual = {str(p.relative_to(module.KIT)) for p in (module.KIT / 'addons/proto_kit').rglob('*.gd')}
        self.assertEqual(paths, actual)
        self.assertTrue(all(e['example'].strip() for e in data['capabilities']))

if __name__ == '__main__':
    unittest.main()
