# 消失的草莓牛奶 — Text Prototype

Validates: is the dialogue funny, and does a 2-second tsukkomi timer feel like pressure or just annoying? See `prototypes/CONTEXT.md` for the shared glossary and `prototypes/docs/adr/` for why this lives here and what's deferred.

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
│   └── TsukkomiSystem.ts             resolves a tsukkomi pick or timeout (普通吐槽 only — see ADR 0002)
├── data/scenes/
│   └── missingStrawberryMilk.ts      the actual scene content
├── main.ts                           DOM rendering, click handling, and the tsukkomi countdown
└── dev-walkthrough.ts                headless script that walks every branch (npm run walkthrough)
```

`portrait` / `sfx` fields exist on `Line` but are unused placeholders — no real art or audio yet, by design.

## What's deliberately not here

Scoring, 戰鬥吐槽 / Narrative Break (they need a battle/boss system this prototype doesn't have — ADR 0002), timeline/loop system, mini-game framework. Those are later phases per `docs/gintama-like/chat-3.md`'s roadmap.
