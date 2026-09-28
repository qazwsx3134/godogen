# 12 — Development Roadmap

按 [16 的檢查點](16_implementation_contract.md) 分段驗收。本次啟動 Phase 0 + 1；後續範圍不可提前標記完成。

## Phase 0 — Project Foundation

建立：

- Godot project
- Folder structure
- Autoloads
- Data Registry
- Debug screen
- Save skeleton

Done when：

- App opens
- Main scene loads
- Save can write/read basic data

---

## Phase 1 — Combat Vertical Slice

內容：

- Portrait UI
- Adventure Strip
- 1 Hero
- 1 Enemy
- Auto target
- Move
- Basic attack
- HP
- Death
- Respawn

Done when：

- 可以無限自動打怪 10 分鐘不 crash
- 主 scene／AdventureStrip／Unit scene 可在編輯器直接調整；一般執行保留人工修改
- 390 × 844 與 320 × 568 可操作；小螢幕上方可捲動、底部戰鬥持續
- 使用實際 scene 跑 10 分鐘模擬 soak，另記實際執行與視覺檢查，勿混稱實機效能

---

## Phase 2 — Party & Stage

內容：

- 3 Heroes
- 5 enemies
- Party
- Wave
- Stage
- Boss 控制器測試資料（正式 Boss 於 1-10／1-15，Phase 8 加入）
- EXP
- Level

Done when：

- Stage 1-1 ~ 1-5 可推進
- Party 全滅會 fail
- clear 會 unlock next

---

## Phase 3 — Loot & Equipment

內容：

- Chest
- Item generator
- Rarity
- Affix
- Inventory
- 6 slots
- Compare
- Equip

Done when：

- 戰鬥掉 Chest
- Chest 會生成裝備
- 裝備會改變 combat stats

---

## Phase 4 — Inventory QoL

內容：

- Filter
- Sort
- Lock
- Multi salvage
- Auto salvage

Done when：

- 100+ items 仍可快速管理

---

## Phase 5 — Offline

內容：

- Timestamp
- Snapshot
- Offline calculation
- Reward
- Offline report

Done when：

- 關閉 10 分鐘後重開有合理收益
- 不需要逐 frame simulation

---

## Phase 6 — Cube

內容：

- Salvage
- Merge
- Craft meter

Done when：

- 垃圾裝可以轉換成 deterministic progress

---

## Phase 7 — Rune

內容：

- 25 nodes
- prerequisite
- effects
- QoL unlocks

Done when：

- Rune effect 真正改變戰鬥 / loot / offline

---

## Phase 8 — MVP Content Complete

加入：

- 8 enemies
- 2 elite
- 2 bosses
- 15 stages
- 30 base items
- Balance pass

Done when：

- 新 save 可以完整玩到 1-15

---

## Phase 9 — Mobile Polish

- Android export
- iOS safe-area layout
- responsive UI
- performance
- low battery mode
- animation polish
- haptic hooks

---

## Phase 10 — Post MVP

依測試決定：

- Pets
- Mastery
- Challenge dungeon
- Endless mode
- Additional acts
