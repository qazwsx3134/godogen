# 計畫：對話紀錄的頭像與名字色、第一次出現新功能的教學導覽

狀態：**計畫，尚未實作**（2026-10-24）。
來源：《異獸髮廊》試玩版研究（`docs/interactive-fiction/ref-beastfolk-barber/README.md`）對照本專案現況。
範圍：只借結構，**銀魂和紙風格不變**（`AGENTS.md` 的介面基準）。

## 已決定

| 項目 | 決定 |
|---|---|
| 頭像來源 | 預設用 `scenes/ui/item_picture.tscn` 的「名稱首字色卡」。之後有圖，在 catalog 補選填欄位 `avatar`，有圖就自動取代 |

## 待決定（附預設）

| 項目 | 預設做法 |
|---|---|
| 對齊 | POV 角色（預設新八）與玩家選項靠右，其他人靠左，旁白置中 |
| 教學範圍 | 第一版做「裝傻發言與吐槽」與「調查」兩項，QTE 併入吐槽教學的最後一頁，牌子之後再做 |
| 另外三款風格 | 紀錄名字色與教學只做銀魂和紙，其他三款維持現狀 |
| 教學進度存哪 | `progress.cfg` 的 `[tutorial]` 區段，新遊戲不重設，不動存檔 schema 3 |

---

## A. 紀錄頭像與名字色

### 現況與缺口

- `scenes/ui/log_entry.tscn` 只有「說話者 Label＋文字 Label」兩個 node，同一個深藍色，沒有頭像。
- `main.gd` 的 `_open_log()`（約 2842–2869 行）每次開啟重建所有列，最後呼叫 `_apply_ui_style_recursive(row)`。
- `data/asset_catalog.json` 每個角色已有 `color`，目前只用在立繪色卡；沒有頭像欄位。
- 歷史條目 `_history` 已存 `speaker`、`thought`、`kind`，不需要改存檔。

### 風險：catalog 的 `color` 不能直接當字色

紀錄面板在銀魂和紙下是淺色和紙。以下對比為**估算**（WCAG 相對亮度，正文要求 4.5:1），實作時要用函式量過：

| 角色 | color | 與和紙對比（估算） |
|---|---|---|
| 定春 | `#F4F0E6` | 約 1.0 |
| 伊莉莎白 | `#F4F4F0` | 約 1.0 |
| 銀時 | `#aab6c8` | 約 1.8 |
| 神樂 | `#F08CA8` | 約 2.0 |
| 新八 | `#4f7fcf` | 約 3.5 |
| 登勢 | `#9a6bb0` | 約 3.6 |

六位都不到 4.5:1，直接上色會有四位幾乎看不見。

另一個陷阱：`_apply_ui_style_recursive` 會依 `ui_style_role` 重設 Label 字色，名字色若在它之前設定會被蓋掉。

### 設計

| 項目 | 做法 |
|---|---|
| 名字色資料 | catalog 新增選填 `ink`（深色版）。沒填就從 `color` 往暗調到對比 ≥ 4.5，函式放在 `ui_styles.gd` |
| 套色方式 | `ui_styles.apply_label` 認 meta `ui_style_ink`，有值就覆蓋 role 色，不靠「套完樣式再補丁」 |
| 作用範圍 | 只限銀魂和紙，其餘三款不變 |
| 頭像 | 實例化 `item_picture.tscn`（`item_picture.gd` 已支援「有 `path` 顯示圖、沒有畫首字色卡」）。catalog 之後補 `avatar` 即自動取代 |
| 對齊 | 見「待決定」 |
| 心聲 | `thought` 條目名字尾綴維持「・心聲」，正文用 `palette["thought"]` |
| 合聲 | 說話者為 `a+b` 時，頭像與名字色取第一位，名字照現有「、」串接 |
| 存檔 | 不變，舊存檔直接顯示新版面 |
| 窄螢幕 | 頭像約 48 CSS px；文字寬度約縮 56 px；320 寬要確認不逐字換行 |

### 要動的檔案

| 檔案 | 改什麼 |
|---|---|
| `scenes/ui/log_entry.tscn` | 改成 HBox：頭像一側，旁邊 VBox 放說話者與文字。用 Godot 存檔（headless 腳本 `PackedScene.pack()`＋`ResourceSaver.save()`），不手寫 |
| `main.gd` `_open_log` | 填頭像、名字色、對齊，順序在 `_apply_ui_style_recursive` 之前。邏輯抽成小函式 |
| `scripts/ui_styles.gd` | 新增 `ink_for(hex, style_id)`；`apply_label` 認 `ui_style_ink` |
| `scripts/story_runner.gd`（約 1394 行） | 驗證 `ink` 為合法 hex；`avatar` 用 `ResourceLoader.exists`（不用 `FileAccess.file_exists`，匯出版會誤判） |
| `data/asset_catalog.json` | 選填 `ink`、`avatar`；對比不足的角色手動補 `ink` |
| `tests/test_reading_scenes.gd` | `log_entry.tscn` 預期 node 數由 3 改成新數字（此測試刻意鎖編輯器樹） |
| `tests/test_ui_styles.gd`、新增紀錄測試 | 見驗證 |
| `README.md`、`IMPLEMENTATION.md` | 更新「對話紀錄」敘述與 Scene 轉換進度 |

---

## B. 第一次出現新功能的教學導覽

### 要教什麼（優先序）

| 優先 | 功能 | 觸發 | 理由 |
|---|---|---|---|
| 1 | 裝傻發言與吐槽（‹ ›、聽下去、吐槽！、8 秒選詞、消音條） | 進入 `boke_round`（`main.gd:1889`，閱讀階段，倒數尚未開始） | 核心玩法 |
| 2 | 調查（拖曳背景、點線索、收起展開） | 進入 `investigate`（`main.gd:1534`） | 操作不直覺 |
| 3 | QTE 縮圈 | 併入第 1 項最後一頁，用靜態 `qte_ring.tscn` 示意 | 不在實際 QTE 時中斷（見風險 2） |
| 4 | 伊莉莎白的牌子 | 牌子上第一次出現字的那句 | 只有那句有反應，容易漏掉 |

### 流程

```
進入新模式 ─▶ 這個 id 看過嗎?(progress.cfg [tutorial])
                 │是 ──▶ 照常進行
                 │否
                 ▼
   _screen_mode = "tutorial"（記下 _mode_before_overlay）
                 │ 壓暗 → 框住目標 → 和紙說明卡 + 箭頭 → [下一步 ›] / [略過]
                 ▼
   寫入「已看過」 → 還原模式 → 玩家自己操作
```

### 設計

| 項目 | 做法 |
|---|---|
| 資料 | 新增 `data/tutorials.json`：每個教學有 `id`、`trigger`（模式名）、`steps[]`（`target` 節點名、`text`、`arrow` 方向）。每步不超過兩行，每個教學最多 3 步，一步一件事 |
| 暫停倒數 | `_process` 只在 `_screen_mode == "tsukkomi"` 扣時間，所以改成 `"tutorial"` 模式就自然暫停，沿用選單與紀錄的 `_mode_before_overlay` 做法 |
| 擋輸入 | `_open_menu`、`_open_log` 的白名單不含 `"tutorial"`，自動被擋。開啟時 `_set_auto(false)`、`_set_skip(false)` |
| 目標定位 | 用 Scene Unique Name（例如 `%BokeTsukkomi`、`%BokeListen`）取 `get_global_rect()` 轉成遊戲區座標；`_layout()` 與 `_ui_scale` 變動時重算。**只有高亮框是執行時定位**，壓暗與說明卡用 anchor |
| 壓暗 | 四條 `ColorRect` 圍住目標，不用 shader 挖洞（網頁版相容最穩，編輯器也看得到） |
| 風格 | 說明卡沿用和紙（`ui_style_role = "menu"` 走 `GINTAMA_PAPER_ROLES`），標題用雲形名牌 `gintama_heading_plaque.png`，高亮框用深藍銀框，箭頭沿用既有圖示 |
| 掛載 | `PopupLayer`。新增 `scenes/ui/tutorial_overlay.tscn`＋`scripts/tutorial_overlay.gd`，以 headless 腳本生成一次，之後是來源檔，已存在就拒絕覆蓋（`--force` 才重寫，重產前先看 `git diff`） |
| 進度 | `progress.cfg` 新增 `[tutorial] seen = [id…]`。新遊戲不重設 |
| 設定 | 設定面板新增「教學提示」開關與「重看教學」（清除 `[tutorial]`） |
| 略讀 | 略讀遇到第一次教學時停下，與停在選項的規則一致 |

### 要動的檔案

| 檔案 | 改什麼 |
|---|---|
| `scenes/ui/tutorial_overlay.tscn`、`scripts/tutorial_overlay.gd` | 新增 |
| `data/tutorials.json` | 新增；教學文字集中在此，之後做多語 |
| `main.gd` | 模式 `"tutorial"`、在 `investigate`／`boke_round` 進入點呼叫、讀寫 `[tutorial]`、`_layout()` 後重算高亮框、QA 狀態加 `screen: tutorial` |
| `scripts/settings.gd`、`scenes/ui/settings_panel.tscn`（及 `settings_panel_gintama.tscn`） | 新增兩列 |
| `tools/make_tutorial_scenes.gd` | 新增，一次性生成 scene |
| `README.md`、`IMPLEMENTATION.md` | 更新玩法表、VN 外殼與 Scene 轉換進度 |

---

## 風險

1. **現有約 30 個測試會被卡住**：它們走到調查、吐槽畫面，教學遮罩會攔下點擊；用乾淨的 `progress_path` 反而變成「全都沒看過」。對策二選一，實作時決定：
   - 測試啟動腳本設環境變數 `DEBT_NO_TUTORIAL=1`；
   - `main.gd` 加 `@export var tutorials_enabled: bool = true`，測試逐檔設 `false`。
   - 另外新增專門測試教學本身。
2. **QTE 用牆上時鐘計時**（`Time.get_ticks_usec`）：教學若在 QTE 進行中彈出會讓判定失真，所以不在實際 QTE 時中斷，改在吐槽教學最後一頁用靜態示意。
3. **倒數要先教、後開始**：教學掛 `boke_round`，不能掛 `tsukkomi`，否則玩家看教學時已在倒數。
4. **窄手機 320×568**：說明卡與高亮框可能蓋住目標。要有規則決定卡片放目標上方或下方，並做邊界裁切。
5. **編輯器開著同一專案時改 scene**：實作前先提醒使用者重新載入，避免被存檔蓋回舊版。
6. **其他三款風格**：說明卡走 `menu` role 的預設面板，視覺不如和紙一致；預設不做變體。
7. **對比數字是估算**：頭像色卡的前景字色也要量對比。

## 驗證

沿用專案現有的 `_expect` 測試寫法（`addons/proto_kit/test_kit.gd`），測試訊息寫「系統＋情境＋預期」。

**紀錄**
- 新 scene 預期 node 數正確；`PackedScene.pack()` 後數量不變；執行不重寫 scene 原始碼。
- 編輯器改動（頭像大小、間距）在 `_ready`、`_layout`、開啟紀錄後保留。
- 每位角色的 `ink` 與銀魂和紙面板色對比 ≥ 4.5。
- 其餘三款風格的紀錄與改動前逐項一致。
- 舊存檔載入後紀錄正常顯示，不需遷移。
- 旁白、心聲、合聲、選擇條目各一筆，頭像與對齊正確。

**教學**
- 沒看過就彈出；看過不再彈；「重看教學」會清除。
- 彈出期間倒數不動，關閉後從原值繼續。
- 略過與完成都會記錄；關閉「教學提示」後完全不彈。
- 彈出時選單、紀錄、自動、略讀被擋；關閉後還原原模式。
- 390×844、360×800、320×568 都不超出畫面，按鈕 ≥ 48 CSS px。
- 現有 `test_vn_shell`、`test_phase3_ui`、`test_phase4_rounds_ui` 等在關閉教學的設定下全數通過。

**人工**：Web 匯出版用手機尺寸走一次第一章，確認箭頭與框準確、略過可用。
**範圍外**：Android／iOS 實機手感仍待真人試玩，與 README 現況一致。

## 建議順序

1. **PR 1：紀錄名字色＋頭像。** 範圍小、資料現成，先處理對比問題。
2. **PR 2：教學導覽引擎**，含 scene、進度、設定開關與測試隔離，暫不放內容。
3. **PR 3：教學內容**，依序放吐槽、調查，之後是牌子。

## 不借的部分（維持現狀）

- 異獸髮廊的像素邊框、橄欖綠、焦糖按鈕。
- 鋸齒或波浪輪廓直接當對話框外框（會破壞整張和紙加 NinePatch 四角的設計）；要做情緒只能疊小貼紙或沿用 `ComedyLayer`。
- 讓對話泡泡跟著說話者移動（直式手機版面與固定站位是刻意取捨，見 `IMPLEMENTATION.md`「VN 外殼」）。
- 把紀錄做成真正的聊天氣泡外觀。
