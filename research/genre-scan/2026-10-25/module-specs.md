# godot-kit 新模組規格（Codex 實作用）

來源：`games.md` 的三款遊戲。全部放 `prototypes/godot-kit/addons/proto_kit/`，風格比照既有模組：沒有 `class_name`、`extends RefCounted`、型別完整、用 `preload` 引用、沒有 autoload、亂數一律由呼叫端傳入的 `RandomNumberGenerator`（測試才能固定結果）。**不接進任何原型**（尚無使用者，README 標「尚未採用」）。

## 1. `card_draft.gd` — 升級三選一（來源：遊戲 B 104212、104258）

玩家升級時從池子抽 N 張牌（預設 3）選一張；可重抽（有次數）、可放逐（有次數，之後不再出現）；牌分「佔欄位的技能」與「不佔欄位的強化」；同一分支的牌累積進度，進度滿解鎖終極技能。

```
const CardDraft = preload("res://addons/proto_kit/card_draft.gd")
var d := CardDraft.new(pool, rng, {"rerolls": 3, "banishes": 1, "slots": 7})
```
`pool`: `Array[Dictionary]`，每張 `{id: String, kind: "skill"|"upgrade"|"ultimate", weight: float=1.0, max_level: int=1, branch: String="", requires: Array=[] }`。`requires` 是已選過（level>0）才會出現的 id。

| 方法 | 行為 |
|---|---|
| `offer(count := 3) -> Array` | 回傳 id 陣列。排除：已滿級、已放逐、`requires` 未滿足、欄位滿了時的新技能（升級已持有技能仍可）、`ultimate` 在分支進度不足時。依 `weight` 加權、單次 offer 不重複。候選不足 count 時回傳實際數量。結果存為 `current` |
| `pick(id) -> bool` | id 必須在 `current` 內；level+1；技能第一次選到佔一個欄位；分支進度+1；清空 `current` |
| `reroll() -> bool` | 次數>0 才行；次數-1；新 offer 盡量避開上一組（候選夠時完全不重疊） |
| `banish(id) -> bool` | id 在 `current` 內且次數>0；次數-1；永久排除；`current` 補一張新的（若有候選） |
| `level(id) -> int`, `slots_used() -> int`, `rerolls_left`, `banishes_left` | 查詢 |
| `branch_progress(branch) -> int`、`ultimate_ready(branch, need) -> bool` | 進度與解鎖 |
| `to_dict() / from_dict(d)` | 存讀檔（level、banished、次數、current） |

驗收（headless）：同 seed 同結果；offer 內無重複；放逐的牌之後 200 次 offer 都不出現；reroll 次數歸零後回 false 且 `current` 不變；欄位滿時 offer 不含未持有技能但含強化；分支進度達標前 ultimate 不出現、達標後出現；`to_dict`→`from_dict` 後行為一致。

## 2. `upgrade_tree.gd` — 永久升級／天賦星圖（來源：遊戲 A 103735、103836、103902；遊戲 B 104025）

一個「花貨幣升節點等級、節點提供屬性加成」的結構。星圖有相鄰關係（鄰居有等級或鄰居是 root 才能買）；永久成長商店是沒有邊的特例。

```
var t := UpgradeTree.new(nodes, {"root": "root"})
```
`nodes`: `Array[Dictionary]`，每個 `{id, max_level:int, cost_base:float, cost_growth:float=1.0, adj:Array=[], effect:Dictionary={stat: per_level}, group:String=""}`。`cost(id) = round(cost_base * cost_growth ^ level)`，滿級回 -1。可用 `costs: Array[int]` 覆寫（逐級指定價格）。`adj` 無向（兩邊只寫一邊也成立）。

| 方法 | 行為 |
|---|---|
| `is_available(id) -> bool` | 無 `adj`/`root` 設定：永遠可買；有：任一鄰居是 root 或 level>0 |
| `can_buy(id, currency) -> bool`、`buy(id, currency) -> Dictionary` | `buy` 回 `{ok, spent, remaining, reason}`，reason：`maxed`/`locked`/`short` |
| `preview(id, currency) -> Dictionary` | `{level, max, cost, short_by, now: {stat:v}, after: {stat:v}}`（對應「目前 / 購買後 / 還差 N」） |
| `totals() -> Dictionary` | 所有節點 `effect * level` 依 stat 加總 |
| `count_bought() -> int` | 已買等級總數（對應「12 項強化」） |
| `respec() -> int` | 全部歸零，回傳退款總額 |
| `to_dict() / from_dict(d)` | 存讀檔（只存 level） |

驗收：成本曲線 5 級逐級對；鎖定節點買不了、買了鄰居後可買；`short_by = max(0, cost-currency)`；`totals` 與手算一致；`respec` 退款 = 已花總額；`from_dict` 忽略不存在的 id（舊存檔相容）。

## 3. `run_goals.gd` — 局內目標與解鎖獎勵（來源：遊戲 C 104703/104748 的任務頁；遊戲 B 104057 圖鑑）

目標分層（「Fracture 0+」、「Fracture 1+」：難度到了才顯示進度），每個目標有「單局內累計」的計數、完成後永久解鎖一個獎勵（角色／武器）；頁面顯示 `已領 / 總數`。

`goals`: `Array[Dictionary]` `{id, tier:int=0, event:String, need:int, per_run:bool=true, reward:String}`。

| 方法 | 行為 |
|---|---|
| `begin_run(tier := 0)` | per_run 計數歸零；記下本局 tier |
| `note(event, amount := 1) -> Array` | 只累計 `tier <= 本局 tier` 的目標；達標回傳新完成的 goal id（完成只觸發一次，永久記錄） |
| `progress(id) -> Vector2i` | `(現在, need)`；尚未到該 tier 回 `(-1, need)`（UI 顯示鎖定文字，不顯示進度條） |
| `claimed() -> int`、`total() -> int` | 對應 `0 / 12` |
| `rewards_unlocked() -> Array` | 已解鎖獎勵 |
| `to_dict() / from_dict(d)` | 存永久完成與 `claimed`，不存局內計數 |

驗收：per_run 目標跨局不累計；非 per_run 跨局累計；tier 不足時 `note` 不計數；完成不重複觸發；`from_dict` 後 `claimed` 相同。

## 4. UI 樣式與版型模組（資料與 scene，來源：`ui-style-catalog.md`）

放在 `addons/proto_kit/ui/`：

- `ui_styles.json`：`ui-style-catalog.md` 裡每個樣式的 token（色票、邊框寬、圓角、字級階、間距）。**先照該文件的表格轉成 JSON，數值不要自己改。**
- `ui_theme.gd`：`static func build(style_id: String) -> Theme`，讀 JSON，回傳有 `Button/Panel/PanelContainer/Label/ProgressBar/TabContainer` 的 StyleBoxFlat Theme（純色與邊框，不依賴貼圖，所以不需要素材授權）。`static func ids() -> Array`。
- `layouts/*.tscn`：每個版型一個可在編輯器打開的 scene（節點用 anchor／Container，不在程式裡排位置；根節點無腳本即可，`%唯一名稱` 標好關鍵節點）：
  `idle_split_panel`（上：舞台；下左：屬性＋技能格；下右：角色＋背包格）、`tabbed_modal`（Q/E 分頁頁籤＋捲動列表＋關閉）、`card_draft`（標題＋三張牌＋重抽／放逐按鈕＋右側說明欄）、`settings_list`（分頁＋左右箭頭列＋底部兩顆按鈕）、`quest_list`（分段標題＋目標列＋進度條＋獎勵圖示）、`hud_arpg`（左上頭像血條、底部技能列、左下自動施放開關）。
- 用 `tools/make_ui_layouts.gd`（`scene_builder.gd` 的 `save_scene`）產生 scene，存完載回驗證節點數與 owner，**已存在的 scene 不覆蓋**（比照 `tools/make_tutorial_scenes.gd`）。
- 預覽：`tools/ui_gallery.gd`（SceneTree 腳本）把每個樣式×每個版型截圖到 `user://`，用 `xvfb-run` 跑；不要在使用者桌面開視窗。

驗收：每個 `ui_theme` 樣式都能 `build` 且 Button 有 normal/hover/pressed/disabled；每個 scene 能載入、節點數符合 `make_ui_layouts` 的輸出、`%` 名稱都存在；`ui_styles.json` 每個顏色對比：內文字/面板底 ≥ 4.5:1（不足的在報告列出，不要偷改數值）。

## 共同規定

- 測試放新檔 `prototypes/godot-kit/tests/test_genre_modules.gd`（不要改 `test_proto_kit.gd`），用 `extends "res://addons/proto_kit/test_kit.gd"`，最後印 `GENRE MODULES TESTS PASSED`。
- 跑法：`prototypes/godot-kit/tools/run_tests.sh prototypes/godot-kit genre_modules`（先看該腳本用法）。
- 只動自己獨占的檔案（見開工訊息）。不 commit、不 push、不 `git add -A`。
- 完成後寫 `research/genre-scan/2026-10-25/codex-report.md`（改動檔、測試指令與輸出、偏離規格處、沒做的），這個檔出現就是完成訊號。
