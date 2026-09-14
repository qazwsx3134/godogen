# 沒事屋 Game Domain

The domain model for the Gintama-style game explored in `docs/gintama-like/` and validated through the disposable builds under `prototypes/`. Covers the shared vocabulary across all prototypes in this folder, not just one of them.

## Language

**委託 (Job)**:
A task the player accepts each day that can resolve normally or spiral into chaos.
_Avoid_: quest, task, mission

**失控判定 (Escalation Check)**:
The moment a 委託 is evaluated to decide whether it stays mundane or escalates into a 小遊戲/Boss branch.
_Avoid_: random check, dice roll, trigger

**小遊戲 (Minigame Node)**:
The escalation branch of a 委託's 失控判定 — the general concept that "this job just became something else," not a specific genre. It is validated in stages: Phase 1 proves it as pure dialogue + choice, Phase 3 turns it into an actual distinct-genre minigame (Reflex/Timing/Drag) behind a common interface.
_Avoid_: mini-game (when specifically meaning the Phase 3 framework), Mini-game Framework (that term is reserved for Phase 3's common `start()`/`result` interface)

**吐槽 (Tsukkomi)**:
A player choice that calls out something absurd happening in the current scene. The Phase 1 prototype's version is an untimed correct/incorrect pick that only branches dialogue. From Phase 2 onward it becomes a timed mechanic with three types: 普通 (text-only), 戰鬥 (weakens an enemy), and Narrative Break (breaks the game's own rules).
_Avoid_: joke choice, punchline choice

**Flag**:
A persisted piece of state set by a player's choice, which later dialogue or NPCs can reference.
_Avoid_: variable (when talking about narrative causality specifically)

**試作 (Prototype)**:
A disposable, narrowly-scoped build whose only purpose is to validate one Phase 0 assumption (e.g. "is the dialogue funny"). Not a step toward shippable code — it is expected to be thrown away or rewritten once the assumption is validated.
_Avoid_: demo, MVP, alpha
