# Dialogic 2 能否取代 debt-commission 的 StoryRunner？評估報告

- 評估日期：2026-09-25
- 引擎：Godot 4.7.stable.official.5b4e0cb0f（headless）
- 受測 Dialogic：**2.0-alpha-20**，tag commit `e301e1bb5e62e6de22c6b7748c4372d0570bb4a7`（2026-07-21）。來源是 GitHub `dialogic-godot/dialogic`，沒用 Asset Library。main 分支 HEAD `701b67bb`（2026-08-30）已標成 2.0-Alpha-21 WIP，比 alpha-20 多 14 個 commit，**這次沒測 main**。
- 對照用 Parley：2.1.0，repo HEAD `18fd32e4`（2026-08-25），版本跟 repo 裡 `addons/parley/plugin.cfg` 相同。
- 實驗在暫存的專案副本裡進行（基準版、加 Dialogic、Dialogic 加 Parley、只加 Parley 四份），repo 沒有安裝 Dialogic。文中提到的 `results/*.log` 與 `dialogic_eval/` 測試素材都在暫存區，沒有保留進 repo；要重現就照各節寫的指令重跑。

---

## 0. 一句話結論

Dialogic 2 在 Godot 4.7 的**可行性關卡全部通過**：載入沒有錯誤，Web 可以匯出，分支 timeline 加存讀檔在 headless 能跑，匯出的 pck 在桌面 headless 也能跑（沒在瀏覽器裡測）。

所以真正要決定的是**合不合用、遷移成本多少**。這兩點證據都指向 **(B) 保留 StoryRunner，只借 Parley 做 authoring，再寫 converter**。

Dialogic 自己沒有流程圖編輯器，所以沒辦法滿足「底特律式分支圖」這個需求。本作的核心玩法（調查熱區、限時吐槽回合、檢查點）Dialogic 全都沒有，只能自己寫 custom event 或 subsystem，偏偏 alpha-20 剛好打破了 custom subsystem 的 API。存檔的穩健度和載入驗證，Dialogic 也都比現有實作弱。

---

## 1. 量測結果

### 1.1 Headless 編輯器載入

指令是 `godot --headless --path <副本> --editor --quit`，XDG 目錄都指向副本內的 `.cache/`。

| 副本 | 次數 | SCRIPT ERROR / Parse Error / Failed to load | 其他訊息 |
|---|---|---|---|
| 基準版 | 1 | 0 | 無 |
| 加 Dialogic | 3（首次 import、verbose、加 timeline 後） | **0** | 結束時有 `WARNING: 2 ObjectDB instances were leaked`，verbose 顯示是 2 個 `UndoRedo`，**只在編輯器結束時出現**，基準版沒有 |
| Dialogic 加 Parley | 2 | **0** | 結束時有 8 行 `resources still in use` / `RID ... leaked`；**只裝 Parley 的副本也有同樣 8 行**，所以是 Parley 自己的，不是兩者互相干擾 |
| 只裝 Parley | 2 | 0 | 同上 8 行 |

verbose log 有 `Loading resource: res://addons/dialogic/Editor/editor_main.tscn`，證明 Dialogic 的主面板真的載入了。
對應 log：`results/dialogic_editor_load_2_verbose.log` 第 53–64 行，以及 `results/both_editor_load_*.log`、`results/parley_editor_load_*.log`。

**副作用：Dialogic 編輯器會改寫 `project.godot`。**
- autoload 路徑被換成 `uid://ds2q0uclmolvu`。
- 多出 `[dialogic]` 區段，放 `directories/dch_directory`、`dtl_directory`、`layout/style_directory`。
- 每新增一個角色或 timeline，這些登錄表就會變。
- 程式碼證據：`addons/dialogic/Core/DialogicResourceUtil.gd:32-36`（在編輯器中呼叫 `ProjectSettings.save()`）。
- 影響：git diff 會多出雜訊，多個 agent 同時編輯時也可能衝突。

### 1.2 Web 匯出體積

兩個副本都用 `tools/build_web.sh` 匯出，`XDG_DATA_HOME` 指向副本內複製過來的 4.7.stable 模板。兩者都匯出成功，exit 0，錯誤 0 筆。基準版匯出耗時 8.2 秒。

| 檔案 | 基準版（bytes） | 加 Dialogic（bytes） | 差異 |
|---|---|---|---|
| `index.pck` | 12,051,572 | **13,887,940** | **+1,836,368（+15.2%）** |
| `index.pck`（gzip -9 後） | 11,752,570 | 13,120,950 | +1,368,380（+11.6%） |
| `index.wasm` | 39,509,339 | 39,509,339 | 0 |
| `index.js`、html、worklet、icon 等 | 相同 | 相同 | 0 |
| **整包下載總量** | 51,888,693 | 53,725,061 | **+3.5%** |

基準版的 pck 跟 repo 現有的 `build/web/index.pck` 完全一樣，都是 12,051,572。這個數字是只裝 Dialogic、還沒有任何 timeline 時量的；加入 `dialogic_eval/` 後重新匯出是 13,898,060。

**增量從哪來。** 用 `--export-pack Web x.zip` 匯出兩份來比對：
- 新增 902 個檔案，共 1,677,676 bytes（未壓縮）：
  - `.gdc` 共 796,217
  - `.godot/imported` 共 480,407，主要是編輯器圖示
  - `.godot/exported` 共 346,843，是轉換過的編輯器場景
  - remap、import、gdshader 共約 54K
- `uid_cache.bin` 從 810 變成 40,344；`global_script_class_cache.cfg` 從 8 變成 15,720。
- Dialogic 內建的 export plugin 只會跳過 `Editor/`、`Modules/` 底下的 `.png`（`addons/dialogic/export_plugin.gd:4-23`），所以編輯器專用的檔案也被打包進去了。
- 把 `.import` 和 `.remap` 裡的 `path=` 對回原始檔後，新增的 1,677,676 bytes 可以這樣拆：
  - **31.5%（528,446）來自 `addons/dialogic/Editor/`**
  - 約 8.1%（135,162）是各模組裡的編輯器或設定頁，這部分是**依檔名推斷**的
  - 其餘約 60% 是 runtime
- 理論上可以用 exclude_filter 排掉編輯器部分來瘦身，**但這次沒測會不會壞**。

**對照：Parley 的匯出成本。**
- Parley runtime 加 autoload 一起打包：pck 為 12,611,872（+560,300，+4.6%）。
- 照 repo 現行設定只當 authoring 工具（不加 autoload，`exclude_filter` 含 `addons/parley/*`）：pck 為 12,051,604，**只多 32 bytes**。

### 1.3 Dialogic timeline 實跑（選做項目，已完成）

測試素材在 `dc-dialogic/dialogic_eval/`：
- 兩個角色：`kenji.dch`、`gin.dch`
- 一條 `branch.dtl`，包含：
  - 3 個選項，其中一個帶 `[if {has_ledger} == true]` 條件
  - `set {question_method}`
  - `jump ending` 和 `label ending`
- `eval_runner.gd` 用 autoskip 自動推進劇情，程式選擇選項，並在選項出現時呼叫 `Dialogic.Save.save()`。

結果如下（`results/dialogic_timeline_run_3.log`）：

- `DIALOGIC EVAL PASSED`，exit 0。兩個角色的台詞都正確顯示（健次、阿銀）。
- 條件不成立的選項被隱藏了，只出現「1:先聽說明, 2:直接走人」。
- 路線一選「先聽說明」後，`question_method=hear_first`。
- 讀回存檔後，選項重新出現，`question_method` **還原成存檔當下的 `unset`**；改選「直接走人」後，`jump` 正確跳過中間台詞。
- **從匯出的 Web pck 在桌面 headless 跑**（`--main-pack build/web/index.pck res://dialogic_eval/eval.tscn`）：同樣 PASSED（`results/dialogic_pck_run.log`）。`.dtl` 和 `.dch` 都有進 pck。**沒有在真的瀏覽器裡測。**
- 沒驗證：立繪存讀檔。測試角色沒有 portrait，所以 `join` 實際上沒有效果，`get_joined_characters()` 一直是空的。
- 同時裝 Parley 的副本（`dc-both`）跑同一個測試，一樣 PASSED。

### 1.4 反向測試：Dialogic 怎麼處理打錯字

目的是對照 StoryRunner 在載入時做的驗證。測試檔是 `broken.dtl`，另外拆成 b0–b5 六個檔各測一種錯誤（`results/dialogic_broken_run.log`、`results/bisect_b*.log`）：

| 寫錯的內容 | Dialogic 的反應 |
|---|---|
| `kenjj:`（角色 ID 打錯） | **沒有報錯**，直接用 `kenjj` 當名字造一個臨時角色來顯示。原因在 `Modules/Text/event_text.gd:358-368` |
| `join nobody center` | **沒有報錯**，這個事件被改寫成 `join  center`，實際上什麼都不做 |
| `[bogus_cmd arg="1"]`（未知指令） | **當成一句台詞顯示出來**。所有無法辨識的行都會變成 Text 事件（`Resources/timeline.gd:210-213`） |
| `set {undefined_var} = 3` | 要等**執行到這一行**才報錯（有行號和事件編號），然後繼續往下跑 |
| `jump no_such_label` | 要等**執行到這一行**才印 `Label ... not found`（`Modules/Jump/subsystem_jump.gd:79`），然後繼續往下跑 |

另外，b1（角色 ID 打錯）這一組在 **headless 行程結束時會 abort（exit 134）**，重跑 3 次都一樣。其他五組都是 exit 0。**原因還沒查出來**，只在行程退出時發生，不影響劇情進行。

相比之下，StoryRunner 在 `load_story()` 階段就會拒絕，錯誤訊息會指出節點和步序，例如：
- `node '%s' step %d has unsupported op`（`scripts/story_runner.gd:1004-1009`）
- `path does not exist`（`scripts/story_runner.gd:899`）
- `entry node does not exist`（`scripts/story_runner.gd:947`）

### 1.5 現有 7 個測試跟 Dialogic 能否共存

兩個副本各跑一次 `tests/*.gd`：**7/7 全部 PASSED，兩邊結果一樣。** 7 份 log 都出現同一批 autoload 的啟動訊息 `[MCPRuntimeServer]`，表示 `--script` 模式下 autoload 有啟動，Dialogic 的 autoload 也有掛上去。

**不過這只能證明兩者沒有解析衝突或 class 衝突，不能證明輸入不會互相搶。**
- `input/dialogic_default_action`（Enter、滑鼠左鍵、空白鍵）只會在編輯器裡「啟用外掛」時由 `_enable_plugin` 加入（`addons/dialogic/plugin.gd:26-27, 130-150`）。副本是直接改 `project.godot` 啟用的，所以這個 action 不存在。
- 因此，Dialogic 的 `_input` 點擊推進（`Modules/Core/subsystem_input.gd:135-142`）會不會和 main.gd 的 TapCatcher 手勢（點擊、長按、上滑）搶事件，**這次沒有測到**。只要選擇保留 main.gd 又加入 Dialogic，這就是實際存在的風險。

附帶發現一個跟這次評估無關的既有問題：基準版的 `test_phase3_story.gd:211` 本來就會印一行 `SCRIPT ERROR: Invalid access to property or key 'hotspots'`，但測試還是顯示 PASSED。

---

## 2. 功能對照：StoryRunner 加 main.gd 實際做了什麼，Dialogic 有沒有對應

圖例：✅ 內建就有｜🔧 需要自己寫 custom event、subsystem 或 layout｜❌ 沒有對應，要整段自己寫
Dialogic 的原始碼行號都以 tag `2.0-alpha-20` 為準，位置是 `https://github.com/dialogic-godot/dialogic/blob/2.0-alpha-20/addons/dialogic/...`。

| # | 本作的實際能力（證據） | Dialogic 2 | Dialogic 端證據與說明 |
|---|---|---|---|
| 1 | **調查熱區**：`investigate` 指令帶正規化座標，查過打勾並取得素材，全部查完才能繼續（`story_runner.gd:226-249, 423-433`；`main.gd:1177-1307`） | ❌→🔧 | Dialogic 沒有熱區或點擊調查的事件（`Modules/` 共 27 個模組，沒有這類功能）。要自己寫三樣東西：DialogicEvent、subsystem、layout layer。擴充機制見 `Core/DialogicUtil.gd:102-117`（`dialogic/extensions_folder` 底下每個模組放一個 `index.gd`）和 `Core/index_class.gd:15, 25, 114` |
| 2 | **限時裝傻／吐槽回合**：前句、後句切換，「聽仔細」補充台詞，按下吐槽後 8 秒倒數，逾時算冷場（`story_runner.gd:252-316`；`main.gd:1309-1490`） | ❌→🔧 | Choice 模組**沒有限時選項**。唯一的計時器是 0.2 秒的防連點 `_choice_blocker`（`Modules/Choice/subsystem_choices.gd:21, 41`），不能拿來當倒數。整套回合 UI 和狀態都要自己寫 |
| 3 | **四種結果：完美、普通、失敗、隱藏**，連動眼鏡數和吐槽力；有些選項要素材才出現（`story_runner.gd:15, 401-414, 435-485`） | 🔧（部分 ✅） | 數值部分可以用 Dialogic 變數加條件（`[if ...]`）處理；需要素材的選項可以用 choice 條件。四種結果的判定和 HUD 還是要自己寫 |
| 4 | **Game Over 從檢查點重試**：回合開始前自動拍快照，失敗後 `retry_checkpoint()` 回到回合前（`story_runner.gd:318-367`；`main.gd:1492`） | 🔧 | 可以用 Save API 另存一個固定名稱的 slot（`Modules/Save/subsystem_save.gd:106`）拼出來，但要自己決定何時存、何時清 |
| 5 | **18 格手動存檔加獨立自動存檔**：3 頁各 6 格，有章節、時間、縮圖，覆寫前會確認（`scripts/save_slots.gd:6-8`；`main.gd:679-771, 1981-2143`） | 🔧 | Save 子系統有具名 slot、縮圖、`slot_info` 和 autosave 模式（`subsystem_save.gd:24-65, 294, 432, 451`），**但沒有存讀檔選單 UI**，要自己做 |
| 6 | **原子寫入**：先寫 `.tmp`，flush 後讀回驗證再 rename；另外保留 `.bak`，讀檔時依序嘗試 `.bak`、`.old`、`.tmp`（`save_slots.gd:21-32`；`addons/proto_kit/atomic_file.gd`；`main.gd:2326-2333`） | ❌ | Dialogic 用 `FileAccess.open(WRITE)` 直接覆寫，**沒有暫存檔也沒有備份**（`subsystem_save.gd:196, 201`）。另外它用 `store_var(data, true)` 和 `get_var(true)` 允許反序列化物件（`:201, :227`），Godot 文件提醒這樣做不能讀不可信的來源（https://docs.godotengine.org/en/stable/classes/class_fileaccess.html#class-fileaccess-method-get-var） |
| 7 | **舊 schema 存檔還原**：schema 3 的舊存檔會補上預設值；故事 ID 或版本不符就拒絕（`main.gd:2347-2411`；`story_runner.gd:1288-1299`） | ❌ | 兩邊存的都是位置。Dialogic 記的是 `timeline 路徑 + event_index`（`Core/DialogicGameHandler.gd:391-392`），讀檔時直接從該 index 繼續（`:438`），**不檢查版本**。StoryRunner 的位置只在單一節點內有效，還多一道版本檢查，但那道檢查要有人真的改 `version` 才會生效。alpha-20 的 release notes 也寫明這版會讓舊存檔失效（https://github.com/dialogic-godot/dialogic/releases/tag/2.0-alpha-20） |
| 8 | **載入時對照素材目錄驗證**：缺角色、缺背景、缺節點或遇到未知指令時，拒絕載入並指出節點和步序（`story_runner.gd:796-1230`，訊息格式見 `:1004-1009`） | ❌ | 見 §1.4 實測：打錯的角色被自動建立、未知指令被當成台詞、缺少的 label 和變數要等執行時才發現。Dialogic 沒有 CLI 或載入期的 linter |
| 9 | **直式手機版面**：1080 邏輯寬，對話框佔 28–30%，名牌、三行自動縮字、Safe Area（`main.gd:14, 25-31, 772-990`） | 🔧 | Dialogic 有 Style／Layout 系統和 Style Editor（`Modules/DefaultLayoutParts/Style_VN_Default` 等），可以自訂 layout 場景。預設 layout 在 1080×1920 直式畫面下長什麼樣子，**這次沒驗證** |
| 10 | **懸浮按鈕**：可拖曳、吸附左右邊、長按、閒置 40% 透明（`scripts/floating_button.gd`；`main.gd:510-526`） | ❌ | 這是遊戲外殼的 UI，跟 Dialogic 無關，要保留自寫 |
| 11 | **手勢操作**：點擊、長按隱藏 UI、上滑開紀錄（`main.gd:1714-1790`） | 🔧（有衝突風險） | Dialogic 的輸入子系統會自己處理點擊推進（`subsystem_input.gd:125-142`），要協調讓哪一方優先（見 §1.5） |
| 12 | **SKIP／AUTO**（`main.gd:1808-1848`） | ✅ | `Modules/Text/auto_skip.gd`、`auto_advance.gd`；§1.3 的測試就是用 autoskip 推進 |
| 13 | **對話紀錄（LOG）**（`main.gd:595-619, 1921-1964, 2210-2220`） | ✅ | `Modules/History/subsystem_history.gd:118-160`，搭配 `DefaultLayoutParts/Layer_History` |
| 14 | 分支、flags、條件跳轉、goto（`story_runner.gd:488-538, 607-670`） | ✅ | Choice、Condition、Variable、Jump、Label 都有，§1.3 已實測 |
| 15 | 背景、立繪、表情、站位（`bg` / `char` / `expression`） | ✅ | Background 和 Character／Portrait 模組都有。本次**沒實測**立繪存讀檔 |
| 16 | 素材（items）與素材限定選項 | 🔧 | 沒有物品欄概念，要用變數模擬 |
| 17 | QA 快照 `window.__debtQA`，含 `node_id` 和 `step_index`（`IMPLEMENTATION.md` §QA；`tools/browser_check.mjs`） | ❌ | 要重寫。Dialogic 的位置概念是 timeline 加 event_index |
| 18 | **流程圖式分支編輯**（使用者的新需求） | ❌ | alpha-20 的 `addons/dialogic` 裡完全沒有 GraphEdit，grep 結果為 0。Dialogic 的編輯器是事件清單式的 Visual Editor 加文字編輯器 |

**Dialogic 內建、本作目前沒有的東西**（持平列出）：
- Glossary（`Modules/Glossary`）
- 翻譯（`Editor/Settings/CoreSettingsPages/settings_translation`）
- 配音（`Modules/Voice`）
- 文字輸入（`Modules/TextInput`）
- 立繪動畫與 Layered Portrait
- 文字特效與打字音效
- Style Editor 圖形化調整 UI

如果之後要做配音或在地化，這些就有價值。但 ROADMAP 把配音列為「V1 之後依需要再決定」（`docs/story-telling-game/ROADMAP.md:167`）。

**合計**：18 項中 ✅ 4 項（第 12–15 項），另有 1 項部分內建（第 3 項），其餘 13 項是 🔧 或 ❌。本作跟一般 VN 不一樣的地方（1–8、10、17、18）全落在 🔧 或 ❌。

---

## 3. Dialogic 和 Parley 是什麼關係？

**兩者可以裝在同一個專案**，實測結果：
- 同時啟用、兩個 autoload 都掛上時，載入 0 錯誤。
- Dialogic 的 timeline 測試一樣通過。
- 結束時的 leak 訊息是 Parley 自己本來就有的。

**但放在同一條內容管線上，三個角色會互相衝突：**

| 角色 | Dialogic | Parley | StoryRunner |
|---|---|---|---|
| 劇本格式 | `.dtl`，循序文字，用縮排表示分支 | `.ds`，JSON AST，由 `nodes` 加 `edges` 組成的圖 | `data/*.json`，節點加步序，節點之間用 goto 或 next 連 |
| 編輯器 | 事件清單加文字 | **GraphEdit 流程圖** | 無，目前手改 JSON |
| Runtime | `DialogicGameHandler` autoload | `parley_runtime.gd:25` 的 `run_dialogue()`，加自己的對話泡泡 | `story_runner.gd` 加 `main.gd` |

- **資料來源會互搶。** 如果 Parley 負責編寫、Dialogic 負責執行，就得把 `.ds` 轉成 `.dtl`，也就是把圖壓成線性，再用 label 和 jump 重建分支。這樣 `.dtl` 會變成產出物，不能手改，Dialogic 自己的編輯器也就用不上了。
- **轉檔會讓舊存檔讀到錯的地方，而且不會報錯。** Dialogic 存的是整條 timeline 的 `event_index`（`DialogicGameHandler.gd:391, 438`）。converter 每重新產生一次 `.dtl`，只要前面多一行，後面的 index 就全部位移。舊存檔會從錯的事件繼續，**Dialogic 不會拒絕**。
- StoryRunner 其實也是存位置（節點 ID 加節點內的步序），但它多了兩層保護：
  - 位置只在單一節點內有效，改動影響不到其他節點。
  - 有版本檢查，版本不符就拒絕（`story_runner.gd:1298-1299`）。

  不過，如果同一版本下改了某個節點，StoryRunner 一樣會默默錯位。所以兩者差在影響範圍和有沒有檢查，不是一個會錯位、一個不會。要讓版本檢查真正生效，得由 converter 在結構改動時自動調高 `version`。
- **擴充成本會重複付兩次。** 調查和吐槽回合，在 Parley 裡要用 Action 節點帶參數（`models/action_node_ast.gd:20-30`：`action_type`、`action_script_ref`、`values`），到了 Dialogic 又要寫 custom event 和 subsystem 來執行。alpha-20 剛打破 custom subsystem 的 API（見上方 release notes 連結），之後還可能再變。
- **Parley 也有自己的 runtime。** 所以擺在桌上的其實是三個 runtime，必須**只挑一種編寫格式和一個 runtime**。

**結論：「Parley 負責編寫、Dialogic 負責執行」是三方案裡最差的組合。** 兩邊的成本都要付，還多一個會讓存檔錯位的轉檔層。repo 現在的設定是 Parley 只當編輯器外掛：不加 autoload，`export_presets.cfg` 的 `exclude_filter` 已含 `addons/parley/*`（實測 pck 只多 32 bytes）。這已經是方案 (B) 的樣子，跟 ROADMAP 第 166 行「編輯器輸出 StoryRunner 已在讀的劇本 JSON，遊戲端不必跟著改」一致。

---

## 4. 建議：選 (B) 保留 StoryRunner，Parley 負責編寫，再寫 `.ds` → StoryRunner JSON 的 converter

### 理由（依影響大小排序）
1. **流程圖需求只有 Parley 能滿足**，Dialogic 沒有圖形編輯器（§2 第 18 項）。所以換成 Dialogic 並不會少掉 Parley 或 converter 這一段。
2. **本作的核心玩法 Dialogic 都沒有**：熱區、限時吐槽、四種結果、檢查點。換過去的話，最難的部分還是要自己寫，只是改成依賴 alpha 版的 custom subsystem API，而這套 API 在 alpha-20 剛改過。
3. **存檔穩健度會退步**：Dialogic 不是原子寫入、沒有 `.bak`，位置用整條 timeline 的 index，也不檢查版本（§2 第 6、7 項）。StoryRunner 同樣存位置，但只在單一節點內有效，而且有版本檢查。本作在 Web 上把存檔寫進 IndexedDB，現有的原子寫入和回退鏈都是驗收過的。
4. **編寫錯誤要到執行時才會發現**（§1.4 實測）。分支一多（底特律等級），這會變成主要的除錯成本；StoryRunner 在載入時就會拒絕。
5. **遷移成本高，而且現有測試資產大多作廢**（見下一節）。
6. Web 體積增加 1.84 MB（pck +15%、整包 +3.5%）本身可以接受，**不是決定性因素**。

### (B) 要付的成本（不要低估）
- **converter 要寫的東西**：
  - Parley 的 `START / DIALOGUE / DIALOGUE_OPTION / CONDITION / MATCH / ACTION / JUMP / END` 對應到 StoryRunner 的 `entry / say / choice / condition / flag・item / goto / end`。
  - 把連續的 DIALOGUE 串合併成一個 StoryRunner 節點的步序。
  - 從 Parley 的 node id 產生**穩定的**節點 ID。
- **兩個玩法指令 Parley 沒有對應節點**：`investigate` 和 `boke_round`。只能用 Action 節點的 `values` 帶 JSON 參數，編寫體驗會比較差。另一個做法是讓 converter 只處理分支骨架，這兩種指令保留在另一份 JSON，由 converter 合併。
- **可達性檢查**：StoryRunner 目前不檢查哪些節點到不了（ROADMAP 第 166 行），要由 converter 或編輯器補上。
- **版本政策**：StoryRunner 遇到不同版本的存檔會拒絕。converter 必須在結構改動時自動調高 `version`，否則同版本下的節點改動會讓舊存檔默默錯位；但每調一次，舊存檔就全部失效。要不要另外做存檔遷移，得另外決定。
- **Parley 的 autoload 要一直擋在外面（未驗證的風險）**：只多 32 bytes 的前提是 `project.godot` 裡沒有 Parley autoload。但只要有人在編輯器 UI 重新啟用 Parley，`parley_plugin.gd:254` 就會把 autoload 加回來。如果那時 `addons/parley/*` 仍在 exclude 名單裡，匯出的遊戲就會引用一個不存在的 autoload 腳本。建議在 build 或 CI 加一道檢查。
- **不用動的部分**：遊戲端 0 行，現有 370 個 expect、7 個測試檔都不受影響。要新增的是 converter 測試：把 `.ds` 轉出來後丟給 `StoryRunner.load_story()`，順便重用它的驗證。

### 什麼情況值得回頭考慮 (A)
遊戲轉成一般立繪 VN，砍掉熱區和吐槽回合或讓它們變得很少，同時確定要配音和多語系，而且編劇希望用 Dialogic 的 GUI 自己寫。在那之前，比較划算的做法是參考 Dialogic 的 History 和 Glossary 設計，而不是整套換掉。

### (C) 其他組合，都不建議
- **C1：Parley 編寫 + Dialogic 執行**：§3 已說明，是最差的組合。
- **C2：只拆 Dialogic 的部分模組來用**：它的子系統都綁在 `DialogicGameHandler` autoload 上（`Core/DialogicGameHandler.gd:448-495`），拆不乾淨。
- **C3：直接用 Parley 的 runtime 取代 StoryRunner**：一樣沒有熱區和吐槽回合，而且**本次沒評估**它的存檔和 Web 行為。

---

## 5. 遷移工作量估算

數字來自 grep 或逐檔計數；expect 數是 `_expect` 或 `expect(` 的 grep 次數。

| 項目 | (A) 換成 Dialogic | (B) 保留加 converter |
|---|---|---|
| `scripts/story_runner.gd`（1,613 行） | 整份汰換，但調查、吐槽、檢查點、驗證約 900 行以上的邏輯要改寫成 Dialogic custom event 和 subsystem，外加一個 `.dtl` linter | 不改 |
| `main.gd`（2,733 行，`_runner` 被引用 50 處，共用 14 個 API） | 對話框、選項、名牌、打字機效果、AUTO/SKIP/LOG 改成 Dialogic layout；存讀檔改接 Save API，同時自己補回原子寫入和版本檢查；手勢和 Dialogic 輸入要協調；調查和吐槽的 UI 接 custom subsystem。**實際上等於重寫大半** | 不改 |
| `scripts/save_slots.gd`、`floating_button.gd`、`placeholder_sprite.gd` | 懸浮按鈕保留；save_slots 要改接 Dialogic 的狀態；立繪要改成 Dialogic portrait scene | 不改 |
| 劇本資料：3 份 JSON，共 20 個節點、141 個步序 | 全部轉成 `.dtl` 和 `.dch`。討債基線的 `camera / move / face` 共 14 步，Dialogic 沒有直接對應 | 不改；新內容改在 Parley 寫 |
| 故事測試：`test_story`、`test_phase2_story`、`test_phase3_story`，共 204 個 expect，直接呼叫 StoryRunner API | **全部重寫**，要改成對 Dialogic 訊號的非同步測試 | 不改 |
| UI 與存檔測試：`test_vn_shell`、`test_phase2_ui`、`test_phase3_ui`、`test_save_slots`，共 166 個 expect，透過 `main.tscn` 並讀取內部欄位 | **大部分重寫** | 不改 |
| `tools/browser_check.mjs`（685 行，讀 `__debtQA` 的 `node_id` 和 `step_index`，共 10 處） | QA 快照的欄位定義要重新設計，腳本也要跟著改 | 不改 |
| 新增項目 | custom 模組和 `.dtl` linter | Parley → JSON converter、可達性檢查、converter 測試 |
| **受影響的現有測試** | **7/7 個檔、370 個 expect，加上瀏覽器 QA** | **0** |

量級判斷：(A) 相當於重做 Phase 1 到 Phase 3 的技術實作和驗收；(B) 是新增一個獨立工具（converter），風險可以隔離。這次**沒有**估人天，因為 converter 的規模取決於 Parley 節點怎麼對應 `investigate` 和 `boke_round`，這件事還沒定。

---

## 6. 沒做或查不到的部分

- 沒在真的瀏覽器（Android Chrome、iOS Safari）跑 Dialogic；只在桌面 headless 用 `--main-pack` 跑過 Web 匯出的 pck。
- 沒驗證立繪存讀檔（測試角色沒有 portrait）。
- 沒測 Dialogic 的點擊推進和 main.gd 手勢會不會互相搶（`dialogic_default_action` 沒建立）。
- 沒測排除 `addons/dialogic/Editor/*` 後，體積能省多少、會不會壞。
- b1 在退出時 abort（exit 134，3/3 可重現），原因不明。
- 沒測 Dialogic main 分支（alpha-21 WIP）。
- Parley 的 runtime、存檔和 Web 行為都沒評估（本次只量了匯出體積和能否共存）。
- 沒估人天。
