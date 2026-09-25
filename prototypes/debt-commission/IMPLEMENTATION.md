# V1 直立 VN：劇本與畫面介面契約

依 [V1 Roadmap](../../docs/story-telling-game/ROADMAP.md)，直立外殼可載入不同 JSON 故事；`data/debt_story.json` 是已核准討債第一場的閱讀基線，`data/phase2_story.json` 與 `data/phase3_story.json` 是草莓牛奶技術片段，非正式第一章。

## StoryRunner 契約

`story_runner.gd` extends RefCounted，使用 preload 載入，不依賴全域 class_name。提供：

- `load_story(path: String) -> bool`：先讀 `data/asset_catalog.json`，再讀取與驗證 JSON；成功後 reset。失敗時保留先前載入的故事狀態。
- `get_asset_catalog() -> Dictionary`：回傳素材設定的深拷貝供 UI 使用。
- `reset() -> void`。
- `current() -> Dictionary`：目前可呈現指令，附 `node_id`、`node_title`、`step_index`；不消耗指令。
- `advance() -> Dictionary`：完成當前指令後前進；choice／end 不可由 advance 跳過。
- `choose(option_id: String) -> bool`：只允許當前可見 choice 的有效選項，寫入 flags 並跳轉；缺素材的選項不出現在 `current()` 中，也不能用 ID 強選。
- `snapshot() -> Dictionary`、`restore(snapshot: Dictionary) -> bool`：保存故事 ID／版本、穩定節點／步序、flags、items、調查與吐槽狀態；無效或異版存檔拒絕且不破壞現況。
- `inspect_hotspot(id: String) -> bool`：調查目前熱區，標記已查並取得素材；全部查完才可 `advance()`。
- `set_boke_line(index: int) -> bool`、`listen_boke_line() -> bool`：切換發言與讀取補充台詞。
- `resolve_boke(option_id: String) -> Dictionary`、`timeout_boke() -> Dictionary`：結算四種結果、眼鏡與吐槽力，回傳結果及目標節點；`retry_checkpoint() -> bool` 從 Game Over 回到回合前。
- `case_file() -> Dictionary`：`{materials: [{id,name,description}], profiles: [{id,name,profile}]}`，依取得順序列出素材與已解鎖的人物檔案，文字取自素材設定；給素材／人物檔案畫面用。
- 公開 `flags: Dictionary`、`items: Array[String]`、`profiles: Array[String]`、`gameplay: Dictionary`、`error_message: String`、`node_id: String`、`step_index: int`。

故事根資料：`id`、`version`、`title`、`entry`、`initial_flags`、`nodes`。每個 node 有 `title`、`steps`、選擇性的 `next`。

V1 可呈現 op：

- `bg`: `id` 對應 catalog 的 backgrounds。
- `char`: `id` 對應 characters，可選 `visible`、`expression`、`position`（left/center/right）；省略時依角色 catalog 預設。
- `say`: `speaker` 對應 characters 或 narrator、`text`、可選 `thought`／`expression`。
- `choice`: `prompt`、`options: [{id,label,next,set_flags?,require?}]`；`require` 是單一素材 ID，至少保留一個無條件選項。
- `end`: `text`。
- `investigate`: `id`、`prompt`、`hotspots: [{id,label,pos:[x,y],item}]`；`pos` 為場景正規化座標。
- `boke_round`: `id`、`speaker`、`lines: [{id,text,listen?}]`、`timer_seconds`、`tsukkomi.options: [{id,label,result,require?,goto,set_flags?}]`、`tsukkomi.timeout`、`game_over`。閱讀發言不限時，玩家進入吐槽選詞後才開始倒數；`require` 控制素材限定選項。

內部 op：`flag`（key/value）、`item`（id，重複取得不重複存）、`profile`（角色 id，解鎖人物檔案，重複不重複存；該角色在素材設定要有 `profile` 文字）、`condition`（flag/equals/then/else）、`goto`（target）。`bg`、`char`、`say`、`choice`、`flag`、`goto`、`item` 是新章節的主要指令；所有角色、背景、素材 ID 在載入時驗證，錯誤指出節點與步序。

討債閱讀基線仍接受下列舊指令，以保留已核准文本與測試：

- `show`/`hide`: `actor`，show 可選 `at`（舞台標記）。
- `move`: `actor`、`target`（舞台標記）、`duration`（秒）。
- `face`: `actor`、`direction`（left/right/up/down）。
- `expression`: `actor`、`value`（neutral/smile/annoyed/surprised/thinking）。
- `camera`: `target`（actor ID 或 center）、`zoom`（0.95–1.15）、`duration`。
- `wait`: `duration`；`sound`: `id`（paper/knock/step/stamp）。
- `set_flag`（key/value）由 Runner 自行消化，與 V1 的 `flag` 同義。

Runner 對內部跳轉有循環保護。snapshot 另存 `profiles`；沒有這個欄位的舊存檔視為尚未解鎖任何人物。Phase 3 snapshot 額外保存 `gameplay`、`checked_hotspots`、`boke`、`checkpoint`、`game_over_active`；缺這些欄位的舊閱讀存檔仍可還原。新增指令須同時定義資料驗證、還原與 UI 呈現。

## 素材設定

`data/asset_catalog.json` 是背景、人物與素材 ID 的唯一設定。背景含 `label`、漸層 `top`／`bottom`；人物含 `name`、`color`、預設 `slot`，可加人物檔案文字 `profile`；素材含 `name`、`description`。各項可加 `res://` 圖像 `path`，有填時載入前確認檔案存在。背景與人物沒有圖片時分別使用漸層與剪影。新增章節先在 catalog 定義 ID，再於故事 JSON 引用。

新劇本的關鍵場景與立繪變化用 `bg`／`char` 明確指定。玩家選項應保留可辨識的後續回應；討債基線的 `question_method` 是 unset/hear_first/ledger_first，`repayment_promised` 初始 false，答應還款後設 true。

## 劇本建置（story_src → data）

作者不直接改劇本 JSON，而是在編輯器寫原始檔，再建置成 `data/<名稱>_story.json`：

```bash
godot --headless --path . --script res://tools/story_build/build_story.gd -- story_src/phase4.dialogue data/phase4_story.json
godot --headless --path . --script res://tools/story_build/build_story.gd -- story_src/phase4.dialogue data/phase4_story.json --check  # 輸出過期就 exit 1
```

- **兩種原始檔，產出相同**：`.dialogue`（Dialogue Manager 的文字語法，`tools/story_build/dm_source.gd`）或 `.ds`（Parley 的節點流程圖，`tools/story_build/parley_source.gd`）。兩者的指令文法相同（Parley 的 ACTION 節點 description 就是 `.dialogue` 去掉 `do ` 的那一行），`story_src/phase4.dialogue` 與 `story_src/phase4.ds` 建出的 JSON 除了 `generated_from` 完全一致。語法對照寫在兩個 adapter 檔頭。
- **`<名稱>.blocks.json`** 放故事資訊（`id`、`title`、`note`、`initial_flags`）、節點標題，以及調查與裝傻回合的參數。熱區座標、吐槽選項與結果目標不適合在台詞編輯器裡寫，原始檔只用 `investigate("block_id")`、`boke_round("block_id")` 引用。
- **建置時檢查**：語法、說話者（catalog id 或顯示名稱，無名 = 旁白）、選項 id、到不了的節點，最後把輸出交給 `StoryRunner.load_story()` 驗證。任何無法對應的內容都報錯並指出標題或 group 與步序，不會默默略過。
- **`version` 自動產生**：取節點、步序與選項等「存檔位置依賴的結構」的雜湊。只改台詞文字時不變，舊存檔照常讀；增刪步驟或改分支就會變，舊存檔被 StoryRunner 以版本不符拒絕，而不是讀到錯位的步驟。
- 兩個外掛都會把原始檔登記進 `internationalization/locale/translations_pot_files`，供之後產生翻譯 POT，屬正常行為。

## VN 外殼（main.gd）

- 根節點 `Control` 全螢幕；`Game` 固定 1080 邏輯寬、高度等於視窗邏輯高，水平置中。子層依序：`BackgroundLayer`、`CharacterLayer`、`EffectLayer`、`DialogueLayer`、`FloatingLayer`、`PopupLayer`、`TitleScreen`。
- 對話框高度為遊戲區高度的 28%，下方是快捷列；名牌疊在對話框左上，依角色換色，旁白不顯示名牌。文字最多三行，超過時由 56 縮到 42。
- `DialogueLayer` 最底下的 `TapCatcher` 處理所有畫面手勢；對話框、立繪與標籤不攔截滑鼠。以放開判定點擊：移動超過 30 px 視為拖曳，往上 140 px 以上為上滑，按住 0.5 秒為長按。UI 隱藏時的點擊只負責恢復。
- 只處理滑鼠事件，觸控由專案設定模擬成滑鼠，確保一次觸控只觸發一次動作。
- 劇本指令：`bg` 切換背景、`char` 控制立繪與站位，`say`／`choice`／`end` 顯示；舊故事的 `show`／`hide`／`expression` 仍改立繪，`sound`／`wait` 仍執行，`move`／`face`／`camera` 無 VN 對應而略過。
- `story_path` 與 `save_path` 可在場景設定；Web `?sample=phase2` 與 `?sample=phase3` 各開啟固定技術片段及獨立存檔命名空間。
- `save_path` 是自動續讀檔；同一命名空間另有 18 個手動欄位（3 頁 × 6 格）。(S) 與選單「存檔」開啟欄位，選單與標題「讀檔」可指定欄位或自動檔；覆寫有確認。新遊戲只重設自動進度。
- 存檔 schema 3：runner snapshot、當前背景、各角色立繪的可見性／表情／站位、回顧紀錄；手動欄位另有章節、時間與小型場景縮圖。穩定的 say／choice／end／investigate／boke_round 寫入自動檔，手動欄位只在玩家選定後寫入。吐槽回合另存 `boke_ui_screen`，選詞階段才存 `boke_timer_remaining`；舊的有倒數但無畫面欄位的存檔會還原到選詞階段。讀檔先驗證劇本 ID／版本與狀態；寫入採暫存檔及備份，避免覆寫中斷破壞原有欄位。

## 懸浮按鈕（scripts/floating_button.gd）

`setup(glyph, font)`；訊號 `tapped`、`long_pressed`（0.6 秒）、`moved`（吸邊完成）。`bounds` 是左上角允許範圍，由 main 設成對話框上方區域；放開後吸附到較近的左右邊緣。閒置 3 秒 40% 透明由 main 統一處理。

## Placeholder 立繪（scripts/placeholder_sprite.gd）

`setup(id, display_name, color, font)`、`set_expression(value)`、`set_art(texture)`。剪影頭肩比例固定，身體畫到節點底部；main 把立繪底部延伸到畫面底，讓下緣藏在對話框後面。catalog 有角色圖片時改顯示圖片。

## QA

Web 網址帶 `?qa=1` 時，`window.__debtQA` 為唯讀快照：`screen`（title/story/choice/end/investigate/boke_round/tsukkomi/log/menu/save_slots/load_slots/slot_confirm/busy）、`text`、`speaker`、`node_id`、`step_index`、`flags`、`items`、`background`、`text_complete`、`ui_hidden`、`auto`、`skip`、`toast`、`float_alpha`、`viewport`、`game`／`dialog`／`quickbar`／`name_plate` 矩形、`sprites`（含站位）、`choices`、`slot_page`、當頁 `slots`（欄位號、佔用狀態、章節、時間、矩形）、`phase3`（眼鏡與吐槽力、素材、熱區、發言索引與已聽狀態、倒數、檢查點、結果）、`controls`。測試一律透過真實 canvas 點擊操作。
