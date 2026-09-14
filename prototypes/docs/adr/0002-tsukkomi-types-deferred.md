---
status: accepted
---

# Phase 2 only builds 普通吐槽 (text-only), not 戰鬥吐槽 or Narrative Break

`docs/gintama-like/chat-3.md:196-223` describes three tsukkomi types: 普通吐槽 (text-only), 戰鬥吐槽 (weakens an enemy), and Narrative Break (skips a boss's tutorial monologue). The latter two both presuppose a battle/boss system that doesn't exist in this prototype — there's no HP, no enemy, no boss encounter to weaken or interrupt.

We built the timed-choice mechanic (`TsukkomiSystem`, `missing-strawberry-milk`'s `tsukkomi_reveal` beat) for 普通吐槽 only. Building 戰鬥吐槽 or Narrative Break now would mean inventing a throwaway fake battle context just to have something to point the mechanic at — whatever we validated there wouldn't transfer once a real battle system exists, since we'd be guessing at its shape.

`TsukkomiSystem.resolveOption`/`resolveTimeout` return a beat id (correct/wrong branch) rather than any battle-state mutation, so extending it to weaken an enemy or skip a scene later is additive, not a rewrite.
