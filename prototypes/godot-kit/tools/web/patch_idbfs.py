#!/usr/bin/env python3
"""Patches Emscripten's IndexedDB file system in a Godot Web export (index.js), so a user:// save cannot fail on a vanished file.

    python3 patch_idbfs.py build/web/index.js
    python3 patch_idbfs.py --self-test

The bug: IDBFS lists user:// first, then copies each listed file into IndexedDB once the database answers. A file
deleted in between fails the copy with ENOENT (errno 44), logged as "Failed to save IDB file system: undefined".
AtomicFile (addons/proto_kit/atomic_file.gd) writes `path.tmp` and renames it over `path`, and a game may delete a
save right after writing it, so any prototype that saves from a web build can hit it. The patch skips such a file:
the delete marks the file system dirty, so Godot's next sync removes it from IndexedDB.

Written first for debt-commission (tools/build_web.sh). The match is exact and fails loudly when the engine's glue code
changes (a new Godot version): re-check the one-line replacement then, never silently skip it.
Exit codes: 0 patched or already patched, 1 no match.
"""
import sys

OLD = "IDBFS.loadLocalEntry(path,(err,entry)=>{if(err)return done(err);"
NEW = "IDBFS.loadLocalEntry(path,(err,entry)=>{if(err)return err.errno===44?undefined:done(err);"


def patch(source):
    """(new source, status) where status is 'patched', 'already' or 'nomatch'."""
    if source.count(OLD) == 1:
        return source.replace(OLD, NEW), "patched"
    if source.count(NEW) == 1:
        return source, "already"
    return source, "nomatch"


def main(argv):
    if argv[:1] == ["--self-test"]:
        return self_test()
    if len(argv) != 1:
        sys.exit(__doc__)
    path = argv[0]
    with open(path, encoding="utf-8") as f:
        source = f.read()
    result, status = patch(source)
    if status == "nomatch":
        print("%s: IDBFS.loadLocalEntry no longer matches; re-check the vanished-file patch in godot-kit/tools/web/patch_idbfs.py" % path, file=sys.stderr)
        return 1
    if status == "patched":
        with open(path, "w", encoding="utf-8") as f:
            f.write(result)
    print("%s: IDBFS %s" % (path, "patched" if status == "patched" else "was already patched"))
    return 0


def self_test():
    ok = True
    def expect(condition, label):
        nonlocal ok
        print(("ok   " if condition else "FAIL ") + label)
        ok = ok and condition
    glue = "var a=1;" + OLD + "return entry}));var b=2;"
    patched, status = patch(glue)
    expect(status == "patched" and NEW in patched and OLD not in patched, "the exact engine line is replaced")
    expect(patched.startswith("var a=1;") and patched.endswith("return entry}));var b=2;"), "the code around it is untouched")
    again, status = patch(patched)
    expect(status == "already" and again == patched, "a second run changes nothing")
    expect(patch("var a=1;")[1] == "nomatch", "no match is reported, not skipped")
    expect(patch(glue + glue)[1] == "nomatch", "two matches are not guessed at")
    print("patch_idbfs self-test", "PASSED" if ok else "FAILED")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
