#!/usr/bin/env python3
"""Run a command with a temporary HOME and, when set, the GODOT_LOCK file."""
import subprocess
import sys
from godot_guard import godot_environment

if __name__ == '__main__':
    with godot_environment() as environment:
        sys.exit(subprocess.run(sys.argv[1:], env=environment).returncode)
