# debt-commission 程式改善：實作方式

日期：2026-11-11。對應 [TODO.md](../TODO.md)「程式碼檢視」的 D1–D7。

來源是靜態閱讀：`scripts/story_runner.gd` 與 `main.gd` 的函式結構與局部片段，沒有逐行讀完，也沒有實作或跑測試。下面的程式片段是草稿，沒有執行過；行號是 2026-11-11 的版本。動手前先讀該段原始碼確認。

## 實作結果（2026-11-12）

下面各節是 2026-11-11 寫的原始方案。實作時讀了完整原始碼，有幾項照實際情況調整；與原方案不同的地方記在這張表，以表為準。驗證命令與結果在 [PROGRESS.md](../PROGRESS.md) 2026-11-12 段。

| 項目 | 結果 | 與原方案的差異與理由 |
|---|---|---|
| D4 具型別呼叫 | 已做 | `main.gd`、`main_*.gd` 的 48 處 `_runner.call(...)`／`get`／`set` 改成直接呼叫，`_runner: StoryRunner`。`const STORY_RUNNER_SCRIPT: Script` 加了 `: Script` 型別就不能當型別用，所以改名 `StoryRunner` 且不加型別。`_runner_string` **保留**：它也用在 `"node_id"`，而且「空字串就用預設文字」的規則決定 toast 內容。沒有找到當初用 `call` 的必要原因（`story_library.gd` 早就直接呼叫）。 |
| D5 畫面 enum | 已做 | `enum Screen`（21 個值）是唯一的狀態；`_screen_mode` 變成讀寫轉接屬性，回傳小寫名稱，寫入未知名稱會報錯並保持原畫面。QA、測試、教學觸發、存檔裡的回合畫面仍用字串，透過轉接屬性取得。`main.gd` 與分段檔裡所有字面比對都改成 enum，`_mode_before_overlay`、`_settings_return` 也是 `Screen`。**沒有做「故事層／覆蓋層兩個變數」**：原方案標為可不做，而 `_mode_before_overlay` 已經是那個返回點。**沒有做整張顯示表**：五個 `_present_*` 要隱藏的元件集合不同（選項畫面不碰重試鈕、結算只清三樣），整張表會改變行為；改成 `_hide_story_parts()` 只收共同的四件事（調查熱區、調查的「繼續」、回合操作列、結尾按鈕），重試鈕與選項清除照原樣各自處理。**`BUSY` 與 `_story_busy` 都保留**：兩者不同步（`_show_story_screen` 設 BUSY 但旗標不動；`main_round.gd` 有 BUSY 搭配旗標 false），是兩個概念。 |
| D6 分段檔 | 已做 | 69 個被其他檔呼叫的函式去掉底線（`_round.on_boke_timeout()`、`_qa_ctl.publish_qa_state()` 等），`tests/test_phase4_ui.gd` 一併更新；`tools/` 裡 `_game.call("_start_qte")` 這類呼叫的是 `main.gd` 的轉接函式，名字沒變。回合倒數的每幀處理搬到 `main_round.gd` 的 `process(delta)`，QA 定時發布搬到 `main_qa.gd` 的 `process(delta)`，連同各自的計時變數。**倒數秒數本身留在 `main.gd`**：它由 round、saves、qa 三個分段檔與兩個測試共用，不屬於單一分段。 |
| D1 驗證搬出 | 已做 | 劇本與 catalog 驗證（34 個函式、16 個常數）搬到 `scripts/story_validator.gd`，全部 static，函式內容原樣搬移；runner 從 2875 行變成約 1730 行。runner 還在用的 8 個函式改成公開名稱（`validate_story`、`validate_asset_catalog`、`flag_kind`…），runner 與外部仍在用的 5 個常數在 runner 留別名。**存檔快照驗證留在 runner**：它要讀已載入的劇本、catalog、旗標允許值，並呼叫 `_investigation_places` 等執行期函式；搬出去只能反過來持有 runner 的參照，沒有真的分開。另外修正兩個直接呼叫舊私有函式的地方：`tests/test_character_height.gd`、`tools/story_editor/check_catalog.gd`；`tools/story_build/dm_source.gd` 改從 validator 讀常數。 |
| D2 欄位表 | 改做法 | 讀完整個 `_validate_step` 後發現各欄位的檢查並不一致：`char.position` 會檢查型別，`show.at`、`shake.strength` 不檢查；`fade.direction` 預設 `"out"`；錯誤訊息嵌入 id 的位置各不相同。要逐字保留訊息與行為，欄位表需要約八種規則，幾乎省不了行數。改成把四個大分支（`choice`、舊式 `boke_round`、`comedy`、`result`）原樣搬成各自的 static 函式，短分支留在 `match` 裡；`_validate_step` 從約 350 行變成約 180 行，訊息與檢查順序不變。 |
| D3 op 登記表 | 延後 | 原方案自己的條件是「下次要新增 op 之前」，目前沒有要新增的 op。也沒有先抽一個共用常數：`_drive_story` 的清單（清掉上一句吐槽）與 `advance()` 的清單（禁止往下走）內容不同、意義也不同，合併正是 D3 要防的錯。 |
| D7 倒數移進 runner | 改做法 | 原方案要解決的是「機器人量不到時間壓力」。回合指令本來就帶 `timer_seconds`（`tsukkomi_round.gd` 的 `decorate`，連擊回合會隨連擊數變短），所以改在 `tools/bot_players.gd` 加兩種策略：`slow`（每次想 `--think` 秒，預設 5）與 `hesitant`（每次想該句時限的 0.5～1.3 倍），想太久就呼叫 `timeout_boke()`；`--assist` 乘上設定的輔助係數。倒數、存檔格式與它散在 `main.gd`／`main_round.gd`／`main_saves.gd` 的生命週期都不動。原有五種策略的輸出逐字不變。 |

## 先知道的事

- **`story_runner.gd` 刻意不用 `class_name`**（檔案第 4 行註解），呼叫端用 `preload`。D4 的做法不需要 `class_name`。
- **runner 是純邏輯**：`extends RefCounted`、沒有 signal、不碰任何 node。`tools/bot_players.gd` 靠這點直接驅動它。所有改動都要保住這個性質。
- **測試與瀏覽器檢查會讀畫面狀態字串**：`main_qa.gd:158` 把 `_screen_mode` 以 `"screen"` 欄位發布出去，`tests/` 裡至少 20 個檔與 Web 檢查腳本比對這些字串（`"story"`、`"tsukkomi"`、`"busy"` 等）。D5 必須讓對外的字串維持不變。
- **存檔裡有倒數秒數**：`main_saves.gd:442` 把 `_boke_time_remaining` 寫進 payload 的 `boke_timer_remaining`。D7 要處理舊存檔。
- **測試層級**：D1–D6 都是不改行為的重構，屬 L2；每一步改完跑受影響的幾組，全部做完再跑完整 `run_tests.sh`（57 組）。指令在 README「驗證」。跑測試前照 `prototypes/LESSONS.md` 的做法把 `user://` 導到暫存目錄，避免動到真實存檔。

## 建議的實作順序

```
D4 runner 具型別呼叫 ──→ D5 畫面狀態 enum ──→ D6 分段檔各管各的狀態
   （半天，純機械）        （1 天）               （跟著 D5 一塊一塊做）

D1 驗證搬出去 ──→ D2 欄位表 ──→ D3 op 登記表
   （純搬移）       （逐個 op）     （下次要加 op 之前）

D7 倒數移進 runner（獨立，會改存檔格式，最後做）
```

兩條線互不相依。D4 最便宜而且之後每次改動都受益，先做。

---

## D4 runner 改成具型別呼叫

**現況**：`main.gd:696` 是 `_runner = STORY_RUNNER_SCRIPT.new() as RefCounted`，之後所有呼叫都走字串：`_runner.call("advance")`、`_runner.call("story_info") as Dictionary`、`_runner.get("error_message")`、`_runner.set("cast", on_stage)`。`main.gd` 23 處、`scripts/main_*.gd` 25 處。方法名打錯、參數數量錯、回傳型別變了，都要到執行那一行才會出錯。

**做法**：GDScript 可以把 preload 的腳本常數當型別用，不需要 `class_name`。

```gdscript
const StoryRunner = preload("res://scripts/story_runner.gd")
var _runner: StoryRunner

_runner = StoryRunner.new()
_story_ready = _runner.load_story(story_path, story_catalog_override)
var info: Dictionary = _runner.story_info()
_runner.cast = on_stage
```

步驟：

1. `main.gd` 第 10 行的 `STORY_RUNNER_SCRIPT` 改名為 `StoryRunner`（或另加一個別名常數），`_runner` 的宣告加型別。
2. 用搜尋取代把 `_runner.call("X", a, b)` 改成 `_runner.X(a, b)`，`_runner.call("X")` 改成 `_runner.X()`；去掉多餘的 `as Dictionary`、`bool(...)`、`str(...)` 包裝（runner 的函式本來就有回傳型別）。
3. `main_*.gd` 透過 `m._runner` 取用，同樣替換。這些檔的 `m` 如果宣告成 `DebtMain`，型別會自動帶過去；如果是無型別，要補上。
4. `_runner_string(property_name, fallback)`（`main.gd:2707`）只用在 `error_message`，改成直接讀 `_runner.error_message`，刪掉這個函式。
5. `_runner != null` 的防護（2692、2698、2708 行）保留。
6. 改完做一次 headless 匯入（`--headless --editor --quit`）：這時所有打錯的方法名會在解析階段報錯，這就是這項改動的價值。

**要先確認的事**：當初為什麼用 `call`。可能的原因是 `main.gd` 與 runner 之間有循環 preload，或 headless 測試在類別快取還沒建立時載入。`prototypes/LESSONS.md` 沒有記載。先只改 `main.gd` 的宣告與一兩個呼叫、跑 `test_chapter_flow.gd`，確認沒有載入順序問題再全面替換。

**驗證**：headless 匯入無解析錯誤；`test_chapter_flow`、`test_choices`、`test_phase4_rounds_ui`、`test_katsura_dog_ears` 通過。

---

## D5 畫面狀態改 enum，進出各收成一個函式

**現況**：`_screen_mode` 是字串，目前有 22 個值：`title`、`chapter_select`、`story`、`busy`、`choice`、`tsukkomi`、`boke_round`、`qte`、`investigate`、`result`、`end`、`menu`、`settings`、`log`、`case_file`、`gallery`、`flowchart`、`credits`、`save`、`save_slots`、`load_slots`、`slot_confirm`。`main.gd` 比對 40 次，分段檔 48 次。

每個 `_present_*` 函式開頭各自關掉別的畫面的元件。例如 `_present_say`（`main.gd` 1749 行起）開頭是：

```gdscript
_investigation._clear_hotspots()
_investigation_continue_button.visible = false
_boke_controls.visible = false
_game_over_retry_button.visible = false
_dialog_panel.set_reading_enabled(true)
...
_clear_choices()
_end_box.visible = false
_screen_mode = "story"
```

新增一個畫面元件時，要記得去每個 `_present_*` 補一行隱藏；漏了就會殘留在別的畫面上。

**做法**：

1. **enum 加對外名稱表**，對外字串維持原樣。

   ```gdscript
   enum Screen { TITLE, CHAPTER_SELECT, STORY, BUSY, CHOICE, TSUKKOMI, BOKE_ROUND, QTE, INVESTIGATE,
       RESULT, END, MENU, SETTINGS, LOG, CASE_FILE, GALLERY, FLOWCHART, CREDITS,
       SAVE, SAVE_SLOTS, LOAD_SLOTS, SLOT_CONFIRM }
   var _screen: Screen = Screen.TITLE

   func screen_name() -> String:
       return Screen.keys()[_screen].to_lower()
   ```

   `main_qa.gd:158` 的 `m._screen_mode` 改成 `m.screen_name()`。測試如果直接讀 `_screen_mode` 屬性，留一個唯讀轉接：

   ```gdscript
   var _screen_mode: String:
       get: return screen_name()
   ```

   這樣第一步不用動任何測試。

2. **分成兩層**。22 個值其實是兩種東西混在一起：

   - 故事層（互斥，由目前的故事指令決定）：`STORY`、`BUSY`、`CHOICE`、`TSUKKOMI`、`BOKE_ROUND`、`QTE`、`INVESTIGATE`、`RESULT`、`END`。
   - 覆蓋層（蓋在故事層上面，關掉後回到原本的故事層）：`MENU`、`SETTINGS`、`LOG`、`CASE_FILE`、`GALLERY`、`FLOWCHART`、`CREDITS`、`SAVE`、`SAVE_SLOTS`、`LOAD_SLOTS`、`SLOT_CONFIRM`。

   先確認現在關掉覆蓋層時怎麼回到原狀態（可能是存了一個「上一個模式」變數，或重新呼叫 `_present_*`）。如果是後者，可以改成 `_story_screen` 與 `_overlay` 兩個變數，關覆蓋層只要清 `_overlay`。這一步風險比第 1、3 步高，可以晚點做或不做。

3. **進出函式**。把「這個畫面需要哪些元件」寫成一張表，切換時由一個函式統一顯示／隱藏：

   ```gdscript
   ## 每個故事層畫面要顯示的元件；沒列到的一律隱藏。
   var _screen_parts: Dictionary = {}   # Screen -> Array[CanvasItem]，在 _ready 填

   func _set_screen(next: Screen) -> void:
       if next == _screen: return
       _exit_screen(_screen)
       _screen = next
       for part: CanvasItem in _all_story_parts:
           part.visible = part in _screen_parts.get(next, [])
       _enter_screen(next)
       _qa_ctl._publish_qa_state()

   func _exit_screen(prev: Screen) -> void:
       match prev:
           Screen.INVESTIGATE: _investigation._clear_hotspots()
           Screen.CHOICE, Screen.TSUKKOMI: _clear_choices()

   func _enter_screen(next: Screen) -> void:
       match next:
           Screen.STORY: _dialog_panel.set_reading_enabled(true)
   ```

   `_all_story_parts` 是 `_investigation_continue_button`、`_boke_controls`、`_game_over_retry_button`、`_end_box` 這類只屬於某些畫面的元件。之後 `_present_say` 開頭那串隱藏只剩 `_set_screen(Screen.STORY)`。

4. **遷移方式**：一次搬一個 `_present_*`。先搬 `_present_say`，跑 `test_reading_feel`、`test_landscape_reading`；再搬 `_present_choice`、回合、調查。每搬一個就把該函式裡被表格取代的 `visible = false` 刪掉。不要一次全改。

5. `"busy"` 被設定 11 次，是「故事正在自動推進、不接受輸入」。它和 `_story_busy` 布林重複（`_drive_story` 1557–1558 行兩個一起設）。確認兩者永遠同步後，留一個。

**驗證**：每搬一個畫面跑對應的測試（閱讀：`test_reading_feel`、`test_landscape_reading`；選項：`test_choices`；回合：`test_phase4_rounds_ui`、`test_phase4_ui`；調查：`test_phase3_ui`；選單類：`test_settings`、`test_gallery`、`test_flowchart`）。全部搬完跑完整套，再跑一次 Web 冒煙檢查，因為它讀的是發布出去的 `"screen"` 字串。

---

## D6 分段檔各管各的狀態

**現況**：`main.gd` 在 2026-11-05 拆出五個 `scripts/main_*.gd`（`main_round`、`main_saves`、`main_investigation`、`main_qa`、`main_tutorial`）。它們是 `RefCounted`，持有 `m`（主場景）的參考。實際上只是把函式搬到別的檔：

- 狀態變數全部留在 `main.gd`：分段檔讀寫 `m._boke_time_remaining`、`m._screen_mode`、`m._restored_boke_timer_remaining` 等底線開頭的變數。
- 互相呼叫底線開頭的函式：`main.gd` 呼叫 `_round._on_boke_timeout()`、`_qa_ctl._publish_qa_state()`、`_saves._build_save_payload("")`、`_investigation._clear_hotspots()`、`_tutorial_ctl._maybe_tutorial`。

**做法**（不用一次做完，跟著 D5 一塊一塊做）：

1. **公開介面去掉底線**。被別的檔呼叫的函式就是公開的：`_round.on_timeout()`、`_qa_ctl.publish()`、`_saves.build_payload()`、`_investigation.clear_hotspots()`。底線只留給檔內自用的。這一步是純改名，用搜尋取代。

2. **狀態搬到擁有者**。判斷標準：一個變數如果只有某個分段檔在寫，它就屬於那個檔。

   | 變數（現在在 `main.gd`） | 搬到 |
   |---|---|
   | `_boke_time_remaining`、`_last_boke_display_second`、`_restored_boke_timer_remaining`、`_pending_round_mode` | `main_round.gd`（做了 D7 之後前兩個會消失） |
   | `_qa_enabled`、`_qa_elapsed` | `main_qa.gd` |
   | 熱區清單、調查列的狀態 | `main_investigation.gd` |

   搬之前用搜尋確認誰在讀寫。`main_saves.gd` 與 `main_qa.gd` 需要讀別人的狀態來存檔或發布，讓擁有者提供 `snapshot() -> Dictionary`，不要直接伸手拿變數。

3. **`_process` 分派**。`main.gd:2325` 的 `_process` 現在自己扣回合倒數、自己算 QA 發布間隔。改成：

   ```gdscript
   func _process(delta: float) -> void:
       if _dialog_panel == null: return
       _round.process(delta)
       _qa_ctl.process(delta)
   ```

4. **不要做的事**：不要把分段檔改成 node 或 autoload，也不要引入事件匯流排。它們現在是 `RefCounted` 加一個回指 `m` 的參考，這個結構夠用。

**驗證**：每搬一組變數跑該分段對應的測試；改名那一步做 headless 匯入確認沒有漏改。

---

## D1 把驗證搬出 `story_runner.gd`

**現況**：2875 行、110 個函式。依函式清單，大致分布是：

| 行數範圍 | 內容 |
|---|---|
| 1–124 | 常數與狀態變數 |
| 125–1320 | 執行核心：載入、`current`／`advance`、調查、回合動作、選擇、`snapshot`／`restore`、位置正規化 |
| 1322–1607 | catalog 查詢與 `_validate_asset_catalog` |
| 1608–2316 | 劇本驗證：`_validate_story`、`_validate_node`、`_validate_step`（1728–2076）、調查、熱區、話題、旗標一致性 |
| 2317–2624 | 存檔快照驗證：`_validate_snapshot` 與各欄位 |
| 2625–2875 | 旗標允許值收集、結局、條件判斷（`_test_passes`）、小工具 |

驗證約佔 1300 行。它只在載入劇本與讀檔時執行，卻和每一步都會跑的核心放在同一個檔。

**做法**：搬成兩個靜態函式檔，寫法照已經存在的 `scripts/tsukkomi_round.gd`（它全部是 `static func`，驗證用 `Callable` 參數查 node 與 item）。

1. **`scripts/story_validator.gd`**：劇本與 catalog 的驗證。

   ```gdscript
   extends RefCounted
   ## 載入時檢查劇本與 catalog；回傳錯誤訊息，空字串表示通過。不保存任何狀態。

   static func validate_catalog(value: Variant) -> String
   static func validate_story(value: Variant, catalog: Dictionary) -> String
   ```

   搬過去的函式：`_validate_asset_catalog`、`_validate_optional_asset_path`、`_is_css_hex`、`_validate_story`、`_validate_node`、`_validate_choice_marks`、`_validate_step`、`_validate_investigation`、`_validate_hotspots`、`_validate_topics`、`_validate_flag_consistency`、`_hotspot_flag_writes`、`_record_flag_value`、`_validate_test`、`_test_leaves`，以及它們用到的 `_catalog_has_*`、`_is_*` 小工具與 `VALID_*` 常數。

2. **`scripts/snapshot_validator.gd`**：存檔快照的驗證。這部分需要 runner 載入後的資料（劇本、旗標允許值、目前指令），用一個參數物件傳入，不要讓它回頭讀 runner：

   ```gdscript
   static func validate(snapshot: Dictionary, context: Dictionary) -> String
   # context: {"story": ..., "catalog": ..., "allowed_flags": ..., "max_glasses": ..., "max_power": ...}
   ```

   搬過去的函式：`_validate_snapshot`、`_validate_saved_flags`、`_validate_saved_profiles`、`_validate_saved_items`、`_validate_gameplay`、`_validate_checked_hotspots`、`_validate_investigations`、`_validate_boke_snapshot`、`_validate_checkpoint`、`_validate_flag_dictionary`、`_flag_value_is_allowed`。

3. **搬移的機械步驟**：這些函式現在是實例方法，會讀 `_story`、`_asset_catalog`、`_allowed_flag_values`。搬的時候把這些改成參數。先搬不讀任何實例變數的（多數 `_validate_*` 已經把 `asset_catalog` 當參數傳），再處理讀實例變數的。

4. **`VALID_*` 常數**：`main.gd`、`flow_graph.gd`、建置器可能引用 `StoryRunner.VALID_OPS` 之類。搬走後在 runner 留別名（`const VALID_OPS = StoryValidator.VALID_OPS`），外部不用改。

5. **`_test_passes`（2822 行）留在 runner**：它是執行期判斷條件用的，不是驗證。`_validate_test` 搬走。

6. `create_validation_probe()`（230 行）要先讀懂它在做什麼再決定歸屬。

**驗證**：這是純搬移，行為不該有任何改變。錯誤訊息的文字是測試斷言的對象（測試夾具裡有故意寫壞的劇本），所以訊息字串一個字都不要改。跑 `test_ep00`、`test_choices`、`test_chapter1`、`test_chapter_flow`、存讀檔相關的幾組，再跑 `tools/bot_players.gd` 確認 know 策略仍是 1000 局 S。

---

## D2 `_validate_step` 改成欄位表

**現況**：`_validate_step`（1728–2076 行，約 350 行）是一個 `match op:`，每個分支手寫「這個欄位要存在、要是字串、要在允許值裡」。例如 `bg`：

```gdscript
"bg":
    var background_id: String = String(step.get("id", ""))
    if not _catalog_has_background(asset_catalog, background_id):
        return "%s bg id '%s' is not in asset catalog" % [prefix, background_id]
    if step.has("transition") and (typeof(step["transition"]) != TYPE_STRING or String(step["transition"]) not in VALID_BACKGROUND_TRANSITIONS):
        return "%s bg transition must be one of %s" % [prefix, ", ".join(VALID_BACKGROUND_TRANSITIONS)]
```

**做法**（在 D1 之後做，動的是 `story_validator.gd`）：

1. 每個 op 一張欄位表，一個通用函式照表檢查：

   ```gdscript
   const STEP_FIELDS: Dictionary = {
       "bg": {
           "id": {"required": true, "catalog": "backgrounds"},
           "transition": {"one_of": VALID_BACKGROUND_TRANSITIONS},
       },
       "char": {
           "id": {"required": true, "catalog": "characters"},
           "position": {"one_of": VALID_CHARACTER_POSITIONS},
           "expression": {"one_of": VALID_EXPRESSIONS},
           "transition": {"one_of": VALID_CHARACTER_TRANSITIONS},
       },
       "goto": {"target": {"required": true, "node": true}},
   }
   ```

   規則種類先只做用得到的：`required`、`type`（TYPE_STRING／TYPE_BOOL／數字）、`one_of`、`catalog`（查 catalog 的哪一類）、`node`（必須是存在的節點 id）、`range`。

2. **錯誤訊息要維持原文**。測試比對訊息字串，所以通用函式產生的訊息格式必須和現在手寫的一致。做法是先看現有訊息有幾種句型（例如 `"%s %s id '%s' is not in asset catalog"`、`"%s %s %s must be one of %s"`），通用函式照這幾種句型產生。句型對不上的欄位就留在自訂驗證裡，不要為了套表去改訊息。

3. 表格處理不了的規則（跨欄位的條件、巢狀結構如 `choice` 的 options、`boke_round`、`investigate`）保留成自訂函式，在表裡掛一個 `Callable` 或在通用檢查後用一個小的 `match` 補上。`boke_round` 已經委派給 `TsukkomiRound.validate`，維持不動。

4. **逐個 op 遷移**：一次搬一個 op 的分支到表格，跑測試，再搬下一個。簡單的（`bg`、`char`、`goto`、`sound`、`fade`、`set_flag`）先搬。預期能搬掉一半以上的行數；剩下複雜的分支留著沒關係。

5. 這張表之後可以給故事編輯器用（自動產生欄位表單、即時檢查），但不要現在就為了這個目的設計它。

**驗證**：同 D1。另外對每個搬進表格的 op，用一份故意寫錯該欄位的劇本確認錯誤訊息與搬之前逐字相同（搬之前先把訊息記下來）。

---

## D3 op 登記表

**現況**：`"boke_round"` 這個字串出現在 14 個檔：`story_runner.gd`、`main.gd`、`main_round.gd`、`main_saves.gd`、`main_qa.gd`、`main_tutorial.gd`、`flow_graph.gd`、`asset_usage.gd`、`tsukkomi_round.gd`、`tools/bot_players.gd`、`tools/shots_chapter1.gd`、`tools/text_fit_audit.gd`、`tools/story_build/story_builder.gd`、`tools/story_build/dm_source.gd`。

各處問的其實是幾個固定的問題，各自用字串清單回答：

- 這個 op 會停下來等玩家嗎？（`_drive_story` 1566 行的清單 `["say", "choice", "end", "result", "investigate", "boke_round"]`；runner 的 `advance()` 裡的 `op == "choice" or op == "end" or ...`）
- 這個 op 是 runner 內部消化、不給畫面的嗎？（`INTERNAL_OPS`）
- 這個 op 會跳到哪些節點？（`flow_graph.gd` 畫流程圖、驗證檢查目標存在）
- 這個 op 用到哪些素材？（`asset_usage.gd`）
- 存檔時要不要記額外狀態？（`main_saves.gd`）

**做法**：

1. 新增 `scripts/story_ops.gd`，只放資料與查詢函式：

   ```gdscript
   extends RefCounted
   ## 每個故事指令的性質。新增指令時在這裡加一筆，其他檔查這張表。

   const OPS: Dictionary = {
       "say":        {"waits": true},
       "choice":     {"waits": true, "blocks_advance": true},
       "boke_round": {"waits": true, "blocks_advance": true, "round": true},
       "investigate":{"waits": true},
       "end":        {"waits": true, "blocks_advance": true},
       "result":     {"waits": true, "blocks_advance": true},
       "goto":       {"internal": true},
       "set_flag":   {"internal": true},
       # ... 其餘 op 預設是「畫面演出，自動往下」
   }

   static func waits(op: String) -> bool: return OPS.get(op, {}).get("waits", false)
   static func is_internal(op: String) -> bool: return OPS.get(op, {}).get("internal", false)
   static func blocks_advance(op: String) -> bool: return OPS.get(op, {}).get("blocks_advance", false)
   ```

   `VALID_OPS` 改成 `OPS.keys()`，`INTERNAL_OPS` 改成由表推導。

2. **跳轉目標與素材**是每個 op 不同的邏輯，不適合放進純資料表。`tsukkomi_round.gd` 已經有 `targets(step)`、`flag_writes(step)`、`flag_conditions(step)` 這種靜態函式。在 `story_ops.gd` 加 `static func targets(step: Dictionary) -> Array[String]`，裡面一個 `match`，把 `flow_graph.gd` 與驗證裡各自寫的「這個 op 跳去哪」合成一份。先確認這兩處現在的邏輯是否一致；不一致的地方就是現有的 bug 或刻意的差異，要先弄清楚。

3. **畫面分派**（`_drive_story` 的 `match`）維持用 `match`：每個 op 對應一個 `_present_*`，這是它該在的地方。只把 1566 行的字串清單換成 `StoryOps.waits(op)`。

4. `tools/` 下的腳本與建置器最後改，或不改：它們不進出貨版，重複一份清單的代價很低。

**什麼時候做**：下次要新增 op 之前。現在沒有新增 op 的計畫的話，這項可以等。

**驗證**：`test_flowchart`（流程圖節點與連線數不變）、`test_ep00`、`test_chapter_flow`。

---

## D7 倒數計時移進 runner

**現況**：吐槽回合的倒數在畫面層。`main.gd:2328–2338`：

```gdscript
if _screen_mode == "tsukkomi" and not _story_busy:
    _boke_time_remaining = maxf(0.0, _boke_time_remaining - delta)
    ...
    if _boke_time_remaining <= 0.0:
        _round._on_boke_timeout()
```

逾時後才呼叫 runner 的 `timeout_boke()`。總秒數由 `main.gd:672` 的 `_timer_total()` 算（劇本的 `timer_seconds` 乘上輔助模式係數），剩餘秒數由 `main_saves.gd:442` 存進 payload。

後果：

- `tools/bot_players.gd` 只驅動 runner，量不到時間壓力。五種機器人裡沒有「想太久」的玩家，難度數據缺了一個維度。
- 「輔助模式把時間拉長」這條遊戲規則寫在畫面層的 `_timer_total`，runner 不知道。
- 剩餘秒數的存讀檔邏輯分散在 `main_round.gd`（119–121 行）與 `main_saves.gd`（442、594–599 行）。

**做法**：

1. runner 的回合狀態加剩餘秒數，並提供 `tick`：

   ```gdscript
   ## 回合倒數。回傳空字典表示還沒逾時；逾時則回傳與 timeout_boke() 相同的結果。
   func tick_boke(delta: float) -> Dictionary:
       if not _loaded or _boke_timer_left <= 0.0: return {}
       _boke_timer_left = maxf(0.0, _boke_timer_left - delta)
       return timeout_boke() if _boke_timer_left <= 0.0 else {}

   func boke_timer_left() -> float: return _boke_timer_left
   func boke_timer_total() -> float: return _boke_timer_total
   ```

   v2 回合的狀態在 `round_state`（由 `tsukkomi_round.gd` 管理，它已經有 `timer_seconds(step, state)`），把剩餘秒數放進去；舊式回合用 runner 自己的變數。先讀 `tsukkomi_round.gd` 的 `new_state`、`retry_state`、`set_line` 確認計時在哪些時機重置（換句、重試、聽下去）。

2. **輔助係數**：runner 加 `var timer_factor: float = 1.0`，由 `main.gd` 在設定改變時寫入（像 `cast` 那樣，是外殼告訴 runner 的環境值，不進存檔）。`_timer_total()` 改成讀 `_runner.boke_timer_total()`。

3. **什麼時候扣時間仍由畫面決定**：runner 不知道現在是不是在播動畫或開著選單。`main.gd` 只在可以扣的時候呼叫 `tick_boke`：

   ```gdscript
   if _screen == Screen.TSUKKOMI and not _story_busy:
       var result: Dictionary = _runner.tick_boke(delta)
       _choice_sheet.set_timer(_runner.boke_timer_left(), _runner.boke_timer_total(), false)
       if not result.is_empty(): _round.on_timeout_result(result)
   ```

4. **存檔**：剩餘秒數改由 runner 的 `snapshot()` 帶出（放在回合狀態裡），`restore()` 讀回並夾在 0 到總秒數之間。舊存檔的 payload 最外層有 `boke_timer_remaining`：`main_saves.gd` 讀檔時如果 runner 快照裡沒有這個值而 payload 有，就寫進 runner。存檔版本號要不要加一，照現有的版本規則決定；快照驗證（`_validate_boke_snapshot`）要接受這個新欄位。

5. **機器人**：`tools/bot_players.gd` 加一個參數「每次決定花幾秒」（固定值或某個分布），每次行動前呼叫 `tick_boke`。可以新增兩種策略：`slow`（知道答案但每題花 0.9 倍時限）與 `hesitant`（隨機花 0.5–1.3 倍時限）。這樣就能量「時限設多少秒，會把多少比例的正確答案變成逾時」。

**風險**：這是七項裡唯一會改存檔內容與遊戲規則位置的。放在最後做，而且做之前 D4（具型別呼叫）要先完成，否則改 runner 的介面時沒有任何靜態檢查。

**驗證**：`test_phase4_rounds_ui`、`test_phase4_ui`、`test_game_feel`（冷場原因「時間到」）；存讀檔相關測試加一組「舊格式 payload 的 `boke_timer_remaining` 讀進來後剩餘秒數正確」；`bot_players.gd` 的 know 策略在不耗時的設定下仍是 1000 局 S。
