"""Integration coverage for the CCGS port. No API calls or game changes."""
from __future__ import annotations

import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import tomllib
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from install_studio import install


class StudioTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="godogen-studio-test-")
        self.target = Path(self.temp.name) / "game with spaces"
        self.target.mkdir()

    def tearDown(self):
        self.temp.cleanup()

    def git(self, *args):
        return subprocess.run(["git", "-C", str(self.target), *args], check=True,
                              capture_output=True, text=True)

    def hook(self, scripts, payload):
        return subprocess.run([sys.executable, str(self.target / ".agents/hooks/codex_hooks.py"), *scripts],
                              input=json.dumps(payload), text=True, capture_output=True,
                              cwd=self.target, timeout=30)

    def test_codex_roles_skills_and_all_references(self):
        install(self.target, "codex")
        roles = list((self.target / ".codex/agents").glob("*.toml"))
        skills = list((self.target / ".agents/skills").glob("*/SKILL.md"))
        self.assertEqual(len(roles), 49)
        self.assertEqual(len(skills), 74)
        for role in roles:
            config = tomllib.loads(role.read_text())
            self.assertEqual(config["model"], "gpt-5.6-luna")
            self.assertEqual(config["model_reasoning_effort"], "max")
            self.assertIn("delegation cost gate", config["developer_instructions"])
        for skill in skills:
            text = skill.read_text()
            self.assertNotIn("{{", text)
            self.assertNotIn(".claude/", text)
            self.assertNotRegex(text, r"(?m)^!`")
            self.assertNotRegex(text.split("\n---", 1)[0], r"(?m)^model:")
            self.assertTrue((skill.parent / "agents/openai.yaml").exists())
            for reference in re.findall(r"`(references/[^`]+\.md)`", text):
                self.assertTrue((skill.parent / reference).is_file(), (skill, reference))
        self.assertIn("allow_implicit_invocation: false", (self.target / ".agents/skills/dev-story/agents/openai.yaml").read_text())

    def test_repeat_install_preserves_existing_rules_configs_and_skills(self):
        (self.target / "AGENTS.md").write_text("# My rules\nKeep my scenes editable.\n")
        (self.target / "project.yaml").write_text("schema_version: 1\nengine:\n  name: Godot\n  version: 4.6\n")
        (self.target / ".codex").mkdir()
        (self.target / ".codex/config.toml").write_text('model = "custom-model"\n[agents]\ndefault_subagent_model = "custom-worker"\n')
        (self.target / ".codex/hooks.json").write_text(json.dumps({"hooks": {"Stop": [{"hooks": [{"type": "command", "command": "echo mine"}]}]}}))
        (self.target / ".agents/skills/custom").mkdir(parents=True)
        custom = self.target / ".agents/skills/custom/SKILL.md"
        custom.write_text("---\nname: custom\ndescription: My skill\n---\n")
        before = (self.target / "project.yaml").read_bytes()
        install(self.target, "codex")
        first = {p.relative_to(self.target).as_posix(): p.read_bytes() for p in self.target.rglob("*") if p.is_file()}
        install(self.target, "codex")
        second = {p.relative_to(self.target).as_posix(): p.read_bytes() for p in self.target.rglob("*") if p.is_file()}
        self.assertEqual(first, second)
        self.assertEqual(before, (self.target / "project.yaml").read_bytes())
        self.assertTrue((self.target / "AGENTS.md").read_text().startswith("# My rules"))
        config = tomllib.loads((self.target / ".codex/config.toml").read_text())
        self.assertEqual(config["model"], "custom-model")
        self.assertEqual(config["agents"]["default_subagent_model"], "custom-worker")
        self.assertEqual(len(json.loads((self.target / ".codex/hooks.json").read_text())["hooks"]["Stop"]), 2)
        self.assertTrue(custom.is_file())

    def test_local_modified_workflow_or_metadata_aborts_before_any_write(self):
        for relative in [".agents/skills/settings/SKILL.md", ".agents/skills/settings/agents/openai.yaml"]:
            with self.subTest(relative=relative):
                destination = self.target / relative
                if not destination.exists():
                    install(self.target, "codex")
                original = destination.read_text()
                destination.write_text(original + "\nUSER EDIT\n")
                rules_before = (self.target / "AGENTS.md").read_bytes()
                with self.assertRaisesRegex(ValueError, "Local file differs"):
                    install(self.target, "codex")
                self.assertEqual(rules_before, (self.target / "AGENTS.md").read_bytes())
                self.assertIn("USER EDIT", destination.read_text())
                destination.write_text(original)

    def test_source_repo_uses_catalog_without_writing_native_skills(self):
        old_skill = self.target / ".agents/skills/existing/SKILL.md"
        old_skill.parent.mkdir(parents=True)
        old_skill.write_text("old native skill\n")
        install(self.target, "codex", source_repo=True)
        self.assertEqual(old_skill.read_text(), "old native skill\n")
        self.assertEqual(len(list((self.target / ".agents/skills").glob("*/SKILL.md"))), 1)
        self.assertEqual(len(list((self.target / "studio/runtime/codex/skills").glob("*/SKILL.md"))), 74)
        self.assertFalse((self.target / "src").exists())
        helper = self.target / "studio/runtime/codex/hooks/yaml-helper.sh"
        result = subprocess.run(["bash", str(helper), "resolve_config", "--keys", "workflow,qa.level"],
                                cwd=self.target, text=True, capture_output=True, check=True)
        self.assertIn("minimal", result.stdout)

    def test_claude_settings_hooks_keep_user_permissions(self):
        settings = self.target / ".claude/settings.json"
        settings.parent.mkdir()
        settings.write_text(json.dumps({"permissions": {"allow": ["Bash(custom)"]},
                                       "hooks": {"Stop": [{"hooks": [{"type": "command", "command": "echo mine"}]}]}}))
        install(self.target, "claude")
        config = json.loads(settings.read_text())
        self.assertEqual(config["permissions"], {"allow": ["Bash(custom)"]})
        self.assertEqual(len(config["hooks"]["Stop"]), 2)
        self.assertEqual(len(list((self.target / ".claude/agents").glob("*.md"))), 49)
        self.assertFalse((self.target / ".codex").exists())
        skill = (self.target / ".claude/skills/dev-story/SKILL.md").read_text()
        self.assertIn("!`", skill)

    def test_patch_hook_reports_each_changed_asset_and_moved_destination(self):
        install(self.target, "codex")
        (self.target / "assets/data").mkdir(parents=True)
        (self.target / "assets/data/bad.json").write_text("{broken")
        (self.target / "assets/data/moved.json").write_text("{broken-again")
        result = self.hook(["validate-assets.sh"], {
            "hook_event_name": "PostToolUse", "tool_name": "apply_patch", "cwd": str(self.target),
            "tool_input": {"command": "*** Begin Patch\n*** Add File: assets/data/bad.json\n+x\n*** Update File: assets/data/old.json\n*** Move to: assets/data/moved.json\n*** End Patch"}})
        self.assertEqual(result.returncode, 0, result.stderr)
        context = json.loads(result.stdout)["hookSpecificOutput"]["additionalContext"]
        self.assertIn("bad.json", context)
        self.assertIn("moved.json", context)

    def test_commit_hook_blocks_invalid_staged_json(self):
        install(self.target, "codex")
        self.git("init", "-q")
        (self.target / "assets/data").mkdir(parents=True)
        (self.target / "assets/data/invalid.json").write_text("{invalid")
        self.git("add", "assets/data/invalid.json")
        result = self.hook(["validate-commit.sh", "validate-push.sh"], {
            "hook_event_name": "PreToolUse", "tool_name": "Bash", "cwd": str(self.target),
            "tool_input": {"command": "git commit -m test"}})
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertIn("invalid.json", result.stderr)

    def test_godot_layout_and_local_rigor_resolution(self):
        install(self.target, "codex")
        (self.target / "project.godot").write_text("config_version=5\n")
        (self.target / "scripts").mkdir()
        (self.target / "project.yaml").write_text("schema_version: 1\nmodes:\n  rigor: standard\n")
        (self.target / "project.local.yaml").write_text("modes:\n  automation: autonomous\n")
        helper = self.target / ".agents/hooks/yaml-helper.sh"
        command = 'source "$1"; resolve_code_root; resolve_config --keys workflow,qa.level,automation'
        result = subprocess.run(["bash", "-c", command, "studio-test", str(helper)], cwd=self.target,
                                text=True, capture_output=True, check=True)
        self.assertIn("scripts\tdetected Godot scripts", result.stdout)
        self.assertIn("standard", result.stdout)
        self.assertIn("autonomous", result.stdout)

    def test_dry_run_and_symlink_escape(self):
        install(self.target, "codex", dry_run=True)
        self.assertFalse(list(self.target.iterdir()))
        outside = Path(self.temp.name) / "outside"
        outside.mkdir()
        (self.target / ".codex").symlink_to(outside, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, "symlink"):
            install(self.target, "codex")
        self.assertFalse(list(outside.iterdir()))

    def test_publish_all_engines_hosts_and_preserve_custom_skill(self):
        for engine in ("godot", "bevy", "babylon"):
            for host in ("codex", "claude"):
                with self.subTest(engine=engine, host=host):
                    target = self.target / f"{engine}-{host}"
                    command = ["bash", str(ROOT / "publish.sh"), "--engine", engine,
                               "--agent", host, "--out", str(target), "--studio"]
                    result = subprocess.run(command, capture_output=True, text=True, timeout=40)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    directory = ".agents" if host == "codex" else ".claude"
                    self.assertEqual(len(list((target / directory / "skills").glob("*/SKILL.md"))), 75)
                    self.assertTrue((target / f"{engine}.md").exists())
                    custom = target / directory / "skills/my-skill/SKILL.md"
                    custom.parent.mkdir()
                    custom.write_text("my skill")
                    result = subprocess.run(command, capture_output=True, text=True, timeout=40)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertEqual(custom.read_text(), "my skill")


if __name__ == "__main__":
    unittest.main()
