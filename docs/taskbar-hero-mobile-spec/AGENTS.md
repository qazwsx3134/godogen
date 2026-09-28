# AGENTS.md — Codex Project Instructions

## Role

你是這個 Godot 專案的主要 coding agent。

你的目標不是一次做完整遊戲，而是依照 `docs/14_codex_execution_plan.md` 的順序，逐步完成可測試的 Vertical Slice。

---

## Technical Constraints

- Engine: Godot 4.x
- Implementation baseline: 本機 Godot 4.7 stable；專案位於 `prototypes/taskbar-hero/`
- Language: GDScript
- Target: Mobile first
- Orientation: Portrait
- Platforms: Android / iOS
- Runtime: Offline single-player
- Save: Local first
- Architecture: Data Driven
- UI: Godot Control nodes
- Core combat: 2D
- No backend required
- No networking required
- No marketplace
- No server-side inventory

---

## Architecture Rules

### 必須

- 系統與資料分離
- Hero / Skill / Enemy / Item / Stage / Rune 使用 Resource 或資料結構定義
- Runtime 狀態與 Static Data 分離
- 使用 signals 或 event bus 降低系統耦合
- Save schema 有版本號
- Offline progression 不模擬每一個 frame
- Item instance 必須有唯一 ID
- Random generation 要可測試
- 所有公式集中管理，不散落在 UI script

### 不要

- 不要在 UI node 裡寫戰鬥邏輯
- 不要把每個 Stage 寫成獨立 hardcoded script
- 不要使用大量 `if hero_id == ...`
- 不要把 item stats 寫死在 scene
- 不要讓 Offline progression 跑真實逐幀模擬
- 不要一開始引入複雜 ECS
- 不要一開始做 backend
- 不要先做美術 polish 再做系統

### Scene / Node 製作契約

- 主要畫面、常駐 Adventure Strip、單位與重複 UI 元件都必須是有內容的 `.tscn`；打開編輯器即可看見並調整。
- UI anchors／offset／Container 決定版面；Theme／StyleBox／Resource 決定靜態視覺與資料。`_ready()` 綁定 `%UniqueName` 並接 signal，不用 `.new()` 建整頁 UI。
- 戰鬥角色是可重用 scene，使用 `instantiate()` 生成；遊戲中的移動可改 Node2D transform。不要把 UI 排版限制誤套在角色移動上。
- 新建／大改 scene 用 Godot 編輯器或一次性 `PackedScene.pack()`／`ResourceSaver.save()` 工具儲存，檢查 owner 與節點數；一般啟動不得重建 scene。
- 主畫面與戰鬥區保留代表性物件供編輯器預覽；場景不能只有根 node 與一支建立全部畫面的 script。
- 驗收必須直接實例化交付 scene；修改靜態文字／間距後執行須保留。README 列出可編輯節點、資源與執行命令。
- 共用程式先查 `prototypes/godot-kit/README.md`，首版沿用 `atomic_file.gd` 與 `test_kit.gd`。套件副本透過 `sync.sh taskbar-hero` 更新。

規格與實作檢查點見 `docs/16_implementation_contract.md`；此檔明確裁定的規則優先於早期示意流程。

本輪 UI 依使用者提供的六張圖片與 `docs/17_reference_ui_contract.md` 實作。總覽為初始頁，怪獸按鈕開啟詳細頁；本輪圖稿指示優先於舊的 UI 開發排序與頁籤限制。

---

## Development Style

每完成一個 Task：

1. 保證專案可以啟動
2. 保證主要 scene 不報錯
3. 加入最低限度 debug UI
4. 如有公式，加入可重現的測試案例
5. 更新 `docs/DEV_STATUS.md`
6. 不要順便擴大 scope

---

## MVP Definition

MVP 可視為完成，必須至少有：

- 3 Hero party
- Auto combat
- 8 enemy types
- 2 bosses
- 15 stages
- EXP / Level
- Equipment
- Random affix
- 5 rarity tiers
- Chest drop
- Inventory
- Loot filter
- Offline rewards
- Cube: Merge / Salvage / Craft
- Rune tree
- Save / Load

詳細驗收條件見：

`docs/13_acceptance_criteria.md`
