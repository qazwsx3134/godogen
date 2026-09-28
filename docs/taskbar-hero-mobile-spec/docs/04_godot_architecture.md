# 04 — Godot Architecture

實作位置：`prototypes/taskbar-hero/`。使用 Godot 4.7 / GDScript。Scene 是可維護的來源檔，不是執行時程式建 UI 的副產品；規則與依賴見 [16 — 實作契約](16_implementation_contract.md)。

## Scene composition

Main 的 Control tree 負責整體 Margin／VBox、Screen 區及常駐 AdventureStrip；上方切頁只切換 screen，保留同一個戰鬥實例。AdventureStrip 內的 Node2D 戰場實例化 Unit scene。每個單位的靜態 Resource 可共用，HP／target／cooldown 屬於獨立 runtime state。

- 主頁、戰鬥區、單位與重複元件都有實際節點完整的 `.tscn`。
- anchors／Container／Theme／export 參數可在 Inspector 修改，runtime 不覆寫靜態版面與文字。
- `_ready()` 綁定 unique name 與 signals；動態單位用 `PackedScene.instantiate()`。
- scene 用編輯器或一次性 headless pack/save 工具儲存；驗證 owner、序列化節點數、子 scene 引用。一般啟動不重建。
- 存檔寫入與測試基底沿用 `godot-kit` 的 `atomic_file.gd`／`test_kit.gd`，遊戲維護自己的 schema 與 backup 規則。

## Suggested Repository Structure

```text
res://
├── autoload/
│   ├── game.gd
│   ├── save_manager.gd
│   ├── data_registry.gd
│   ├── progression_manager.gd
│   ├── inventory_manager.gd
│   └── event_bus.gd
│
├── data/
│   ├── heroes/
│   ├── skills/
│   ├── enemies/
│   ├── items/
│   ├── affixes/
│   ├── stages/
│   ├── runes/
│   └── loot_tables/
│
├── domain/
│   ├── hero/
│   ├── combat/
│   ├── item/
│   ├── stage/
│   ├── rune/
│   └── offline/
│
├── scenes/
│   ├── main/
│   ├── combat/
│   └── ui/
│
├── ui/
│   ├── components/
│   ├── screens/
│   └── adventure_strip/
│
├── systems/
│   ├── combat/
│   ├── loot/
│   ├── cube/
│   ├── offline/
│   └── save/
│
└── tests/
```

---

## Autoload Responsibilities

以下是責任邊界，不要求每個系統都變成全域 singleton。首版只啟用實際需要的服務；其餘使用最小明確介面，隨所屬里程碑實作。戰鬥單位、技能 runtime 與 UI 頁面仍由各自 scene 擁有。全域服務不得取得或操控 Main 的 UI 節點。

### Game

- Global session state
- Current screen
- Active stage
- Pause state

### DataRegistry

載入 static resources：

- HeroData
- EnemyData
- ItemBaseData
- SkillData
- StageData
- RuneData

### InventoryManager

- Add item
- Remove item
- Equip
- Unequip
- Salvage
- Lock
- Filter

### SaveManager

- Save
- Load
- Migration
- Autosave

### ProgressionManager

- EXP
- Level
- Mastery
- Rune currency
- Stage unlock

### EventBus

Signals：

- enemy_killed
- wave_cleared
- stage_cleared
- item_dropped
- item_equipped
- hero_leveled
- offline_rewards_ready

---

## Runtime vs Static Data

### Static

Resource：

- HeroData
- SkillData
- EnemyData
- StageData
- ItemBaseData
- AffixData

### Runtime

State object：

- HeroState
- ItemInstance
- StageProgress
- RuneProgress
- SaveData

Static data 不直接被改。
