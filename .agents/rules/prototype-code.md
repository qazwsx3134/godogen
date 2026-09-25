---
paths:
  - "prototypes/**"
---

# Prototype Code Standards (Relaxed)

Prototypes are throwaway code for validating ideas. Standards are intentionally
relaxed to maximize iteration speed. The goal is learning, not production quality.

## What's Allowed in Prototypes
- Hardcoded values (no need for data-driven config)
- Minimal or no doc comments
- Simple architecture (no dependency injection required)
- Singletons and global state
- Copy-pasted code (no need for abstraction)
- Debug output left in place
- Placeholder art and audio
- Quick-and-dirty solutions

## What's Still Required
- Each prototype lives in its own subdirectory: `prototypes/[name]/`
- Every prototype MUST have a `README.md` with:
  - What hypothesis is being tested
  - How to run the prototype
  - Current status (in-progress / concluded)
  - Findings (updated when prototype concludes)
- No production code may reference or import from `prototypes/`
- Prototypes must not modify files outside `prototypes/`
- Prototypes must not be deployed or shipped

## Godot Prototypes: Shared Kit
Godot prototypes share placeholder audio (`synth.gd`), crash-safe save writes
(`atomic_file.gd`), and a headless test base (`test_kit.gd`) from
`prototypes/godot-kit/`, so a new prototype uses these instead of writing its own.
After creating `project.godot`, run `prototypes/godot-kit/sync.sh <name>` and
preload what you need; `prototypes/godot-kit/README.md` covers each module's API
and examples. The `addons/proto_kit/` copies are overwritten on every sync, so
change the kit only in `godot-kit/`. Before designing a system's structure (scene
layout, autoloads, data containers, folder layout, version control), check
`prototypes/godot-kit/GODOT_BEST_PRACTICES.md`: it maps each official Godot best
practice to the installed `godot-*` skill that covers it, and fills the gaps.
Before writing a dialogue system, icon set, or other generic tool, check the
third-party addon catalog in `prototypes/godot-kit/README.md`: each entry is
pinned, tested on Godot 4.7, and lists its install steps and caveats.

## When a Prototype Succeeds
If a prototype validates a concept and the feature moves to production:
1. The prototype code is NOT migrated directly — it is rewritten to production standards
2. The prototype `README.md` findings inform the production design document
3. The prototype directory is preserved for reference but never extended

## Cleanup
Concluded prototypes should be archived or deleted after findings are captured.
Never let prototype code grow into production code through incremental "cleanup."
