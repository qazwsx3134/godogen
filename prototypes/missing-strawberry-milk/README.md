# 消失的草莓牛奶 — Prototype

第一篇 2D 主觀視角互動小說的起點，採用 [銀魂概念文件](../../docs/gintama-like/chat-3.md) 的日常失控、角色互動與吐槽。現有版本是文字雛形：三位詢問對象、兩秒吐槽與兩種收尾。

目前先測文本與吐槽，再依 [Roadmap](../../docs/interactive-fiction/ROADMAP.md) 加入銀時的主觀視角、場景、立繪與調查互動。短篇完成後，再整理朋友反覆需要的製作功能。

## Run it

```
npm ci
npm run dev -- --host 127.0.0.1 --port 5191 --strictPort
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
└── dev-walkthrough.ts                12 input combinations, expected endings/Flags, reset and guard checks
```

`portrait` / `sfx` fields exist on `Line` but are unused placeholders — no real art or audio yet, by design.

## Test it

```bash
npm run walkthrough
npm run build
```

Browser smoke requires an available Playwright installation and Chromium. With a server running, use `node browser-check.mjs --url http://127.0.0.1:5191`; if Playwright is installed elsewhere, add `--playwright /absolute/path/to/@playwright/test`. The script saves screenshots and `evidence.json` under `qa/browser-smoke/` (`--out` overrides this path).

- [QA baseline](QA-BASELINE.md): executed build and 12 state-path results.
- [Browser evidence](qa/browser-smoke/evidence.json): executed UI paths, timers, endings and restart.
- [Playtest plan](PLAYTEST.md): pending human tests for comedy, reading pressure and immersion.

## Next milestones

The [current roadmap](../../docs/interactive-fiction/ROADMAP.md) specifies first-person staging, scene inspection, clue-based responses, character callbacks and saved progress. The [repo boundary ADR](../docs/adr/0001-prototypes-live-in-godogen.md) keeps this prototype independent of `publish.sh`.
