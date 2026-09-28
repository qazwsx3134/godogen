# 02 — Mobile Game Loop

## Main Loop

```text
Offline / Online Combat
        ↓
      Loot
        ↓
 Equipment / Materials
        ↓
  Equip / Salvage / Merge
        ↓
      Power
        ↓
    New Stage
        ↓
      Boss
        ↓
 New Difficulty / Meta Progress
```

---

## Online Loop

```text
Stage Start
   ↓
Spawn Wave
   ↓
Heroes Auto Battle
   ↓
Wave Clear
   ↓
Rewards
   ↓
Next Wave
   ↓
Boss / Stage Clear
   ↓
Repeat or Advance
```

---

## Offline Loop

```text
App Closed
   ↓
Save Snapshot
   ↓
Elapsed Time
   ↓
Offline Simulation
   ↓
Kills / Gold / EXP / Chests / Materials
   ↓
Adventure Report
   ↓
Collect
```

---

## Session Structure

### 30 seconds

- Collect
- Check rare drop
- Quick equip
- Exit

### 3–5 minutes

- Collect
- Inventory
- Cube
- Rune
- Stage progress

### 10–20 minutes

- Boss
- Build test
- Formation
- Skill choices
- Challenge mode

---

## App Open State

遊戲主要 UI 上方切換功能。

底部 Adventure Strip 永遠存在。

```text
┌────────────────────────┐
│                        │
│     Current Screen     │
│                        │
│ Hero / Gear / Rune     │
│ Cube / Map / Quest     │
│                        │
├────────────────────────┤
│ 🛡️  🧙  🏹  → 👹 👹 │
│ Stage 2-4  Wave 7/10   │
└────────────────────────┘
```
