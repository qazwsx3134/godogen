"""Optional shared Godot lock and isolated user data for local authoring tools."""
from contextlib import contextmanager
import os
from pathlib import Path
import tempfile
import time


@contextmanager
def godot_environment(timeout=None):
    value = os.environ.get('GODOT_LOCK')
    lock = Path(value).expanduser().absolute() if value else None
    acquired = None
    deadline = time.monotonic() + timeout if timeout else None
    try:
        if lock:
            lock.parent.mkdir(parents=True, exist_ok=True)
            while acquired is None:
                try:
                    with lock.open('x') as handle:
                        handle.write('codex\n')
                        acquired = os.fstat(handle.fileno()).st_ino
                except FileExistsError:
                    if deadline and time.monotonic() >= deadline:
                        raise TimeoutError('Godot 正由另一個工作使用，請稍後重試。')
                    time.sleep(0.2)
        with tempfile.TemporaryDirectory(prefix='debt-editor-home-') as test_home:
            yield {**os.environ, 'HOME': test_home}
    finally:
        if acquired is not None:
            try:
                if lock.stat().st_ino == acquired:
                    lock.unlink()
            except FileNotFoundError:
                pass
