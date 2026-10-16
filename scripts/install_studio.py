"""Render and install the vendored Game Studios workflows without erasing a project."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import tomllib
from pathlib import Path

from generate_codex_metadata import parse_frontmatter, title_from_name

SOURCE = Path(__file__).resolve().parents[1]
BEGIN = "<!-- GODOGEN-STUDIO:BEGIN -->"
END = "<!-- GODOGEN-STUDIO:END -->"
POLICY = """## Godogen Studio integration policy

The user's current request and existing project instructions govern this workflow.
Authorization persists across phases: an instruction to implement, fix, or port
authorizes necessary reversible file edits. Resolve routine choices and finish
authorized work before requesting approval for an external or irreversible action.
Apply the project's delegation cost gate before any Agent/team/review dispatch;
when the gate does not justify a worker, perform that role in the main session.
An engine/version/code-root pinned by this project takes precedence over template
examples. Game screens and reusable objects in this repo use editable saved scenes.
Before AI image generation, describe the batch and wait for the user's choice of
direct generation or ready-to-use prompts for opt image. An approved batch needs
no repeated approval. Keep session instructions and final responses in the user's
language. These integration rules take precedence over upstream workflow defaults.

"""
CODEX = """## Codex execution mapping

Use Codex's available file, shell and user-input tools for upstream Read/Glob/Grep/
Write/Edit/Bash/AskUserQuestion steps. Use native custom agents only after the
delegation cost gate; otherwise perform the role locally. Claude tool allowlists,
`@file` imports, model names and `!` inline shell substitutions are not executed
by Codex. Read referenced files explicitly. Run each configuration bootstrap
explicitly with the shell before following the workflow. Use `$skill-name` to
invoke a discovered Codex skill, or read its SKILL.md when using the source catalog.
No workflow changes the active model by editing a rules file.

"""


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def render(text: str, runtime: str, manifest: str, codex: bool) -> str:
    text = text.replace("{{STUDIO_DIR}}", runtime).replace("{{MANIFEST}}", manifest)
    if codex:
        # Remove Claude-only frontmatter. Codex uses agents/openai.yaml for policy.
        if text.startswith("---\n"):
            end = text.find("\n---", 4)
            if end >= 0:
                head = text[4:end]
                head = re.sub(r"^(?:model|allowed-tools|argument-hint|user-invocable|disable-model-invocation):.*\n?", "", head, flags=re.M)
                text = "---\n" + head.rstrip() + "\n---" + text[end + 4:]
        text = text.replace("${CLAUDE_SKILL_DIR}/../..", runtime)
        text = re.sub(r"^!`(.+)`$", r"Configuration bootstrap — run explicitly from the project root:\n\n```bash\n\1\n```", text, flags=re.M)
        # CLI invocation names in instructions/catalogs; never rewrite shell paths.
        text = re.sub(r"(?<![\w./])/(start|settings|" + "|".join(SKILL_NAMES) + r")(?=[\s`\]\[(),.\"'*:—]|$)", r"$\1", text)
    return text


SKILL_NAMES = sorted(p.parent.name for p in (SOURCE / "studio/upstream/framework/skills").glob("*/SKILL.md"))


def policy_insert(text: str, prefix: str) -> str:
    if text.startswith("---\n"):
        end = text.find("\n---", 4)
        if end >= 0:
            return text[:end + 4] + "\n\n" + prefix + text[end + 4:].lstrip("\n")
    return prefix + text


def update_manifest(existing: str, runtime: str, host: str, source_repo: bool) -> str:
    content = (f"## Game Studios\n\nRead `{runtime}/CATALOG.md` for the 74 workflows and 49 roles.\n"
               f"Read `{runtime}/docs/config-resolution.md` before resolving Studio settings.\n"
               f"`project.yaml` controls rigor and automation; start at minimal unless the user specifies otherwise.\n"
               f"Use `{runtime}/docs/workflow-catalog.yaml` to choose the next workflow.\n"
               f"Read `{runtime}/rules/*.md` only for the paths in each rule's frontmatter.\n"
               "Resume from `production/session-state/active.md` when it exists.\n\n" + POLICY)
    if host == "codex":
        content += CODEX
    if source_repo:
        content += ("This is the Godogen generator source. Studio workflow sources live in\n"
                    "`studio/upstream/`; `studio/runtime/` is generated. Source workflows are\n"
                    "loaded by their paths in the catalog. Native skill directories are generated\n"
                    "only for destination game repos. Run game-specific workflows from that game's\n"
                    "root; do not treat all prototypes as one game or pin one engine for this source repo.\n"
                    "For Studio workflows, the catalog is authoritative over legacy `.agents/` copies.\n")
    block = f"{BEGIN}\n{content.rstrip()}\n{END}"
    if BEGIN in existing:
        if existing.count(BEGIN) != 1 or existing.count(END) != 1:
            raise ValueError("Malformed existing Studio manifest section")
        return re.sub(re.escape(BEGIN) + r".*?" + re.escape(END), lambda _: block,
                      existing, flags=re.S)
    return existing.rstrip() + ("\n\n" if existing.strip() else "") + block + "\n"


def merge_codex_config(text: str, commander: str, worker: str, effort: str) -> str:
    data = tomllib.loads(text)
    additions = []
    for key, value in (("model", commander), ("model_reasoning_effort", effort)):
        if key not in data:
            additions.append(f"{key} = {json.dumps(value)}")
    if additions:
        text = "# Game Studios defaults (existing settings take precedence).\n" + "\n".join(additions) + "\n" + text
    agents = data.get("agents", {})
    defaults = {"default_subagent_model": worker, "default_subagent_reasoning_effort": effort}
    lines = [f"{key} = {json.dumps(value)}" for key, value in defaults.items() if key not in agents]
    if lines:
        if "agents" not in data:
            text = text.rstrip() + "\n\n[agents]\n" + "\n".join(lines) + "\n"
        elif re.search(r"^\[agents\]\s*$", text, re.M):
            text = re.sub(r"^\[agents\]\s*$", lambda m: m.group(0).rstrip() + "\n" + "\n".join(lines), text, count=1, flags=re.M)
        else:
            raise ValueError("Existing inline/dotted agents configuration: add subagent defaults manually")
    tomllib.loads(text)
    return text


def install(target: Path, host: str, source_repo: bool = False,
            commander: str = "gpt-6-astra", worker: str = "gpt-5.6-luna",
            effort: str = "max", dry_run: bool = False) -> dict:
    target = target.resolve()
    if target == SOURCE and not source_repo:
        raise ValueError("Use --source-repo for the generator; native skill directories belong to published games")
    upstream = SOURCE / "studio/upstream"
    runtime = f"studio/runtime/{host}" if source_repo else (".agents" if host == "codex" else ".claude")
    manifest = "AGENTS.md" if host == "codex" else "CLAUDE.md"
    record_path = target / ".studio" / f"{host}-installation.json"
    previous = json.loads(record_path.read_text()) if record_path.is_file() else {}
    owned = previous.get("files", {})
    generated: dict[str, bytes] = {}
    merged: dict[str, bytes] = {}

    def emit(relative: str, text: str) -> None:
        generated[relative] = text.encode("utf-8")

    for source in sorted((upstream / "framework").rglob("*")):
        if not source.is_file() or source.name == "settings.json":
            continue
        relative = source.relative_to(upstream / "framework").as_posix()
        text = render(source.read_text(), runtime, manifest, host == "codex")
        if source.suffix == ".sh":
            # Helpers derive roots from their own directory when no env is set.
            root_relative = os.path.relpath(target, target / runtime / Path(relative).parent)
            text = text.replace('/../.."', f'/{root_relative}"')
            if source_repo and relative == "scripts/artifact-check.sh":
                # A shared source runtime checks other game roots with its own catalog;
                # resolve it before the no-argument branch changes directory.
                text = text.replace('if [ -n "$ROOT_ARG" ]; then',
                                    'CATALOG_DIR="$(cd "$(dirname "$0")/../docs" && { pwd -W 2>/dev/null || pwd; })"\n'
                                    'if [ -n "$ROOT_ARG" ]; then', 1)
                text = text.replace(f'CATALOG="$ROOT/{runtime}/docs/workflow-catalog.yaml"',
                                    'CATALOG="$CATALOG_DIR/workflow-catalog.yaml"')
        if relative == "hooks/yaml-helper.sh":
            text = text.replace("engine.name::Godot|Unity|Unreal", "engine.name::Godot|Unity|Unreal|Bevy|Babylon")
            text = text.replace('    unreal*) root="Source" ;;', '    unreal*) root="Source" ;;\n    bevy|babylon|babylon.js) root="src" ;;')
            text = text.replace('  # 1. The configured engine, through the normal chain.',
                                '  # Godogen explicit source layout; prototypes may use scripts/.\n'
                                '  root=$(get_effective_yaml_key paths.code_root)\n'
                                '  if [ -n "$root" ]; then printf "%s\\t%s" "$root" "paths.code_root"; return; fi\n'
                                '  if [ -f "$_YH_ROOT/project.godot" ] && [ -d "$_YH_ROOT/scripts" ]; then\n'
                                '    printf "%s\\t%s" "scripts" "detected Godot scripts"; return\n'
                                '  fi\n\n  # 1. The configured engine, through the normal chain.')
        if source.suffix == ".md" and (source.name == "SKILL.md" or relative.startswith("agents/")):
            text = policy_insert(text, POLICY + (CODEX if host == "codex" else ""))
        emit(f"{runtime}/{relative}", text)
        if host == "codex" and relative.startswith("skills/") and source.name == "SKILL.md":
            meta = parse_frontmatter(source)
            name = str(meta.get("name") or source.parent.name)
            description = " ".join(str(meta.get("description") or name).split())
            description = description if len(description) <= 120 else description[:117].rstrip() + "..."
            metadata = ("interface:\n"
                        f"  display_name: {json.dumps(title_from_name(name))}\n"
                        f"  short_description: {json.dumps(description)}\n"
                        f"  default_prompt: {json.dumps('Use $' + name + ' for this workflow.')}\n")
            if meta.get("disable-model-invocation"):
                metadata += "\npolicy:\n  allow_implicit_invocation: false\n"
            emit(f"{runtime}/skills/{source.parent.name}/agents/openai.yaml", metadata)
        if host == "codex" and relative.startswith("agents/") and source.suffix == ".md":
            meta = parse_frontmatter(source)
            body = text.split("\n---", 1)[1].lstrip() if text.startswith("---\n") else text
            role = {"name": source.stem, "description": str(meta.get("description", source.stem)),
                    "model": worker, "model_reasoning_effort": effort,
                    "developer_instructions": body + "\nDo not recursively delegate. Return results to the commander.\n"}
            emit(f".codex/agents/{source.stem}.toml", "\n".join(f"{k} = {json.dumps(v, ensure_ascii=False)}" for k, v in role.items()) + "\n")

    # Root and subtree instructions are merged, never used to replace user rules.
    existing = (target / manifest).read_text() if (target / manifest).is_file() else ""
    merged[manifest] = update_manifest(existing, runtime, host, source_repo).encode()
    for source in sorted((upstream / "project").rglob("*")):
        if not source.is_file():
            continue
        relative = source.relative_to(upstream / "project").as_posix()
        text = render(source.read_text(), runtime, manifest, host == "codex")
        if source_repo:
            emit(f"{runtime}/project/{relative}", text)
        elif source.name == "manifest.md":
            destination = target / Path(relative).parent / manifest
            if not destination.exists():
                emit(destination.relative_to(target).as_posix(), POLICY + text)
        elif not (target / relative).exists():
            emit(relative, text)

    # New projects leave rigor-fronted individual knobs unset.
    if not (target / "project.yaml").exists():
        emit("project.yaml", render((upstream / "project.yaml").read_text(), runtime, manifest, host == "codex"))
    emit(f"{runtime}/LICENSE", (upstream / "LICENSE").read_text())
    emit(f"{runtime}/provenance.json", (upstream / "provenance.json").read_text())
    emit(f"{runtime}/INTEGRATION.md", POLICY + (CODEX if host == "codex" else ""))

    catalog = ["# Game Studios catalog", "", "Read only the workflow/role needed for the current task.", "", "## Workflows", ""]
    for source in sorted((upstream / "framework/skills").glob("*/SKILL.md")):
        meta = parse_frontmatter(source)
        name = source.parent.name
        invocation = (f"Read `{runtime}/skills/{name}/SKILL.md`" if source_repo else
                      f"`${name}`" if host == "codex" else f"`/{name}`")
        catalog.append(f"- {invocation} — {meta.get('description', name)}")
    catalog += ["", "## Roles", ""]
    for source in sorted((upstream / "framework/agents").glob("*.md")):
        catalog.append(f"- `{source.stem}` — read `{runtime}/agents/{source.name}`")
    emit(f"{runtime}/CATALOG.md", "\n".join(catalog) + "\n")

    hook_groups = {"SessionStart": ["session-start.sh", "detect-gaps.sh"],
                   "PreToolUse": ["validate-commit.sh", "validate-push.sh"],
                   "PostToolUse": ["validate-assets.sh", "validate-skill-change.sh"],
                   "PreCompact": ["pre-compact.sh"], "PostCompact": ["post-compact.sh"],
                   "Stop": ["session-stop.sh"], "SubagentStart": ["log-agent.sh"],
                   "SubagentStop": ["log-agent-stop.sh"]}
    if source_repo:
        hook_groups["SessionStart"] = ["session-start.sh"]
    if host == "codex":
        adapter = (SOURCE / "studio/adapters/codex_hooks.py").read_text()
        adapter = adapter.replace("{{PROJECT_ROOT_FROM_HOOKS}}", os.path.relpath(target, target / runtime / "hooks"))
        emit(f"{runtime}/hooks/codex_hooks.py", adapter)
        config_path = target / ".codex/config.toml"
        config = config_path.read_text() if config_path.exists() else ""
        merged[".codex/config.toml"] = merge_codex_config(config, commander, worker, effort).encode()
        hooks_path = target / ".codex/hooks.json"
        hook_config = json.loads(hooks_path.read_text()) if hooks_path.exists() else {"hooks": {}}
        for event, names in hook_groups.items():
            command = f'python3 "$(git rev-parse --show-toplevel)/{runtime}/hooks/codex_hooks.py" ' + " ".join(names)
            matcher = "Bash|exec_command|shell_command" if event == "PreToolUse" else "apply_patch|Write|Edit" if event == "PostToolUse" else ""
            group = {"matcher": matcher, "hooks": [{"type": "command", "command": command, "timeout": 60}]}
            groups = hook_config.setdefault("hooks", {}).setdefault(event, [])
            # Replace only this installer's own group; preserve unrelated hooks.
            groups[:] = [g for g in groups if not any(f"/{runtime}/hooks/codex_hooks.py" in h.get("command", "") for h in g.get("hooks", []))]
            groups.append(group)
        merged[".codex/hooks.json"] = (json.dumps(hook_config, indent=2) + "\n").encode()
    else:
        path = target / ".claude/settings.json"
        settings = json.loads(path.read_text()) if path.exists() else {}
        for event, names in hook_groups.items():
            groups = settings.setdefault("hooks", {}).setdefault(event, [])
            commands = [f'bash "$CLAUDE_PROJECT_DIR/{runtime}/hooks/{name}"' for name in names]
            groups[:] = [g for g in groups if not any(h.get("command", "") in commands for h in g.get("hooks", []))]
            matcher = "Bash|PowerShell" if event == "PreToolUse" else "Write|Edit" if event == "PostToolUse" else ""
            groups.append({"matcher": matcher, "hooks": [{"type": "command", "command": c, "timeout": 30} for c in commands]})
        settings.setdefault("statusLine", {"type": "command", "command": f'bash "$CLAUDE_PROJECT_DIR/{runtime}/statusline.sh"'})
        merged[".claude/settings.json"] = (json.dumps(settings, indent=2) + "\n").encode()

    gitignore = (target / ".gitignore").read_text() if (target / ".gitignore").exists() else ""
    for line in ("project.local.yaml", "production/session-logs/", ".studio/", "studio/runtime/" if source_repo else ""):
        if line and line not in gitignore.splitlines():
            gitignore = gitignore.rstrip() + "\n" + line + "\n"
    merged[".gitignore"] = gitignore.encode()

    # Preserve existing projects and native skills. A changed owned file needs review.
    for relative in [*generated, *merged, record_path.relative_to(target).as_posix()]:
        if not (target / relative).resolve().is_relative_to(target):
            raise ValueError(f"Refusing to write outside target through a symlink: {relative}")
    for relative, data in generated.items():
        path = target / relative
        if path.exists() and path.read_bytes() != data and digest(path.read_bytes()) != owned.get(relative):
            raise ValueError(f"Local file differs: {path}. Review it before installing; no files written.")
    result = {"target": str(target), "host": host, "source_repo": source_repo,
              "roles": 49, "workflows": len(SKILL_NAMES), "files": len(generated) + len(merged),
              "revision": json.loads((upstream / "provenance.json").read_text())["revision"]}
    if dry_run:
        return result
    target.mkdir(parents=True, exist_ok=True)
    for relative, data in {**generated, **merged}.items():
        path = target / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        if not path.exists() or path.read_bytes() != data:
            path.write_bytes(data)
    record = {**result, "files": {**owned, **{path: digest(data) for path, data in generated.items()}}}
    record_path.parent.mkdir(parents=True, exist_ok=True)
    record_path.write_text(json.dumps(record, indent=2) + "\n")
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", required=True, type=Path)
    parser.add_argument("--agent", choices=("claude", "codex"), required=True)
    parser.add_argument("--source-repo", action="store_true")
    parser.add_argument("--commander-model", default="gpt-6-astra")
    parser.add_argument("--worker-model", default="gpt-5.6-luna")
    parser.add_argument("--reasoning-effort", default="max")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    try:
        result = install(args.target, args.agent, args.source_repo,
                         args.commander_model, args.worker_model, args.reasoning_effort, args.dry_run)
    except (ValueError, OSError) as exc:
        print(f"Studio install failed: {exc}", file=sys.stderr)
        return 1
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
