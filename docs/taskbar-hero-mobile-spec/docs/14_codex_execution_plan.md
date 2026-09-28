# 14 — Codex Execution Plan

這份檔案是 Codex 的實際工作順序。

不要一次完成所有系統。

執行基準與已裁定的規則見 [16](16_implementation_contract.md)。本次只完成 TASK-001～003、TASK-101～106 的第一個可玩檢查點；三人隊伍、關卡、裝備與離線各自後續驗收。

---

# EPIC 0 — Foundation

## TASK-001 Create project structure

建立文件中建議的 folder。

### Done

- Folder complete
- Main scene exists
- Main／AdventureStrip／Unit 實際節點儲存為 `.tscn`，不是空 scene 掛建 UI script
- 先查 `prototypes/godot-kit/README.md`，同步適用模組
- App launches

---

## TASK-002 Add Autoloads

建立：

- Game
- EventBus
- DataRegistry
- SaveManager
- InventoryManager
- ProgressionManager

先留最小 interface；僅為全域狀態／服務註冊 autoload，不用未完成的 manager 偽造功能。戰鬥與 UI 由 scene 持有。啟動順序與相依服務需有測試。

---

## TASK-003 Save schema v1

建立：

- SaveData
- save
- load
- backup
- version

先儲存：

- timestamp
- gold
- current stage
- kills
- 原子寫入重用 `atomic_file.gd`；壞主檔／合法 backup／future version 有測試

---

# EPIC 1 — Combat Vertical Slice

## TASK-101 Unit base class

建立：

- HP
- attack
- defense
- move speed
- attack speed

---

## TASK-102 Hero auto targeting

Hero：

- search nearest enemy
- move to target
- stop at range

---

## TASK-103 Basic attack

實作 attack interval。

---

## TASK-104 Enemy behavior

Enemy：

- find nearest hero
- move
- attack

---

## TASK-105 Death

- Unit die
- remove from target list
- event emit

---

## TASK-106 Adventure Strip UI

Portrait bottom strip。

顯示：

- Hero
- Enemy
- Stage
- Wave

首版只有固定 1-1 訓練對戰，不展示假的 Wave progression。上方可切概況／角色資料，底部同一戰鬥不中斷；390 × 844、320 × 568 均可操作。基本存檔與戰鬥 10 分鐘模擬通過才結束本檢查點。

---

# EPIC 2 — Stage System

## TASK-201 WaveData

Data-driven wave。

---

## TASK-202 StageData

Data-driven stage。

---

## TASK-203 Wave Controller

- spawn
- detect clear
- next wave

---

## TASK-204 Stage progression

- clear
- unlock next
- retry

---

## TASK-205 Boss

第一隻 Boss。

---

# EPIC 3 — Hero Progression

## TASK-301 HeroData

建立 Knight / Ranger / Mage。

---

## TASK-302 EXP

- kill reward
- level up

---

## TASK-303 Skills

每 Hero：

- 2 active
- 1 passive

---

## TASK-304 Party

最多 3 slots。

---

# EPIC 4 — Loot

## TASK-401 ItemBaseData

建立 6 equipment slots。

---

## TASK-402 ItemInstance

包含：

- uid
- base id
- rarity
- level
- affixes

---

## TASK-403 Affix generator

支援 rarity 對應 affix count。

---

## TASK-404 Chest

Normal Chest。

---

## TASK-405 Inventory

- add
- remove
- equip

---

## TASK-406 Equipment stats

Gear 改變 combat stats。

---

# EPIC 5 — Inventory QoL

## TASK-501 Sorting

- rarity
- power
- slot

---

## TASK-502 Filter

slot + rarity。

---

## TASK-503 Lock

Locked 不能 salvage。

---

## TASK-504 Multi salvage

---

## TASK-505 Auto salvage

配置 rarity rules。

---

# EPIC 6 — Offline

## TASK-601 Save timestamp

---

## TASK-602 Offline calculator

輸入：

- elapsed
- party snapshot
- stage

輸出：

- kills
- exp
- gold
- chest count

---

## TASK-603 Offline loot

批次生成 loot。

---

## TASK-604 Offline report UI

顯示 summary。

---

# EPIC 7 — Cube

## TASK-701 Salvage

Item → material。

---

## TASK-702 Merge

5 same rarity → next rarity。

---

## TASK-703 Craft meter

Salvage / play → craft progress。

---

## TASK-704 Guaranteed craft

滿 meter 可指定 equipment slot。

---

# EPIC 8 — Rune

## TASK-801 RuneData

---

## TASK-802 Rune graph

prerequisite。

---

## TASK-803 Combat modifier

---

## TASK-804 Loot modifier

---

## TASK-805 Offline modifier

---

## TASK-806 QoL unlock

至少：

- Auto Salvage unlock
- Offline +2h

---

# EPIC 9 — Content

## TASK-901 Enemies

8 normal enemies。

---

## TASK-902 Elites

2。

---

## TASK-903 Bosses

2。

---

## TASK-904 Stages

15。

---

## TASK-905 Items

30 base item。

---

## TASK-906 Affixes

15。

---

## TASK-907 Rune nodes

25。

---

# EPIC 10 — Polish

## TASK-1001 Responsive portrait UI

---

## TASK-1002 Android export test

---

## TASK-1003 Save stress test

---

## TASK-1004 Inventory 500 item test

---

## TASK-1005 Offline 24h simulation test

---

# Codex Working Rule

一次只拿一個 Task 或一個小 Epic。

推薦 prompt：

```text
Read AGENTS.md and the relevant files under docs/.
Implement TASK-XXX only.
Do not expand scope.
Before editing, inspect the existing project architecture.
After implementation, verify the project still launches and update docs/DEV_STATUS.md with:
- what changed
- files changed
- known issues
- next recommended task
```
