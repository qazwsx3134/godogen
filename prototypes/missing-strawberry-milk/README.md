# 消失的草莓牛奶 — Phase 1 Prototype

Validates one thing only: is the dialogue + tsukkomi pacing funny? See `prototypes/CONTEXT.md` for the shared glossary and `prototypes/docs/adr/` for why this lives here.

## Run it

```
npm install
npm run dev
```

## Structure

```
src/
├── types.ts                          scene/beat/line data shapes
├── core/
│   ├── DialogueManager.ts            owns current beat + Flag state
│   ├── ChoiceSystem.ts               resolves a picked choice option
│   └── TsukkomiSystem.ts             resolves a picked tsukkomi option (Phase 1: untimed, no scoring)
├── data/scenes/
│   └── missingStrawberryMilk.ts      the actual scene content
├── main.ts                           DOM rendering + click handling
└── dev-walkthrough.ts                headless script that walks every branch (npm run walkthrough)
```

`portrait` / `sfx` fields exist on `Line` but are unused placeholders in Phase 1 — no real art or audio yet, by design.

## What's deliberately not here

Timer, scoring, tsukkomi types (普通/戰鬥/Narrative Break), timeline/loop system, mini-game framework. Those are Phase 2/3 per `docs/gintama-like/chat-3.md`'s roadmap — building them now would be guessing at requirements Phase 1 hasn't validated yet.
