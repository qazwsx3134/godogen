"""Translate Codex hook payloads to the CCGS shell hooks, preserving feedback."""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path


def changed_paths(payload: dict, root: Path) -> list[str]:
    tool_input = payload.get("tool_input") or {}
    if not isinstance(tool_input, dict):
        return []
    if tool_input.get("file_path"):
        path = Path(str(tool_input["file_path"]))
        if not path.is_absolute():
            path = Path(payload.get("cwd") or root) / path
        try:
            return [path.resolve().relative_to(root.resolve()).as_posix()]
        except ValueError:
            return []
    patch = str(tool_input.get("command") or tool_input.get("patch") or "")
    paths = []
    for match in re.finditer(r"^\*\*\* (?:Add|Update|Delete) File: (.+)$|^\*\*\* Move to: (.+)$", patch, re.M):
        value = match.group(1) or match.group(2)
        path = Path(value)
        if not path.is_absolute():
            path = Path(payload.get("cwd") or root) / path
        try:
            relative = path.resolve().relative_to(root.resolve()).as_posix()
        except ValueError:
            continue
        if relative not in paths:
            paths.append(relative)
    return paths


def run_hook(hook: Path, payload: dict, root: Path) -> subprocess.CompletedProcess:
    env = dict(os.environ, CLAUDE_PROJECT_DIR=str(root))
    return subprocess.run(["bash", str(hook)], input=json.dumps(payload), text=True,
                          capture_output=True, cwd=root, env=env, timeout=30)


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: codex_hooks.py <hook.sh> [hook.sh ...]", file=sys.stderr)
        return 1
    hook_dir = Path(__file__).resolve().parent
    # Installer supplies the root relative to this generated adapter.
    root = (hook_dir / "{{PROJECT_ROOT_FROM_HOOKS}}").resolve()
    try:
        payload = json.load(sys.stdin)
    except (ValueError, TypeError):
        print("CCGS hook received invalid JSON", file=sys.stderr)
        return 1
    event = payload.get("hook_event_name", "")
    tool_input = payload.get("tool_input")
    if isinstance(tool_input, dict) and "cmd" in tool_input and "command" not in tool_input:
        payload = dict(payload, tool_input=dict(tool_input, command=tool_input["cmd"]))
    messages = []
    for name in sys.argv[1:]:
        hook = hook_dir / name
        if name not in {"session-start.sh", "detect-gaps.sh", "validate-commit.sh",
                        "validate-push.sh", "validate-assets.sh", "validate-skill-change.sh",
                        "pre-compact.sh", "post-compact.sh", "session-stop.sh",
                        "log-agent.sh", "log-agent-stop.sh"}:
            print(f"Unknown Studio hook: {name}", file=sys.stderr)
            return 1
        inputs = [payload]
        if name in {"validate-assets.sh", "validate-skill-change.sh"}:
            inputs = [dict(payload, tool_input={"file_path": path})
                      for path in changed_paths(payload, root)]
        for item in inputs:
            result = run_hook(hook, item, root)
            if result.returncode and event == "PreToolUse":
                print(result.stderr or result.stdout or f"Studio hook failed: {name}", file=sys.stderr)
                return 2 if result.returncode == 2 else 1
            if result.stdout.strip():
                try:
                    output = json.loads(result.stdout)
                    context = output.get("hookSpecificOutput", {}).get("additionalContext")
                    context = context or output.get("systemMessage")
                    if context:
                        messages.append(context)
                except ValueError:
                    messages.append(result.stdout.strip())
            if result.stderr.strip():
                messages.append(result.stderr.strip())
            if result.returncode and event != "PostToolUse":
                print(f"Studio hook {name} failed ({result.returncode})", file=sys.stderr)
                return 1
    if messages:
        print(json.dumps({"hookSpecificOutput": {"hookEventName": event,
                                                 "additionalContext": "\n".join(messages)}}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
