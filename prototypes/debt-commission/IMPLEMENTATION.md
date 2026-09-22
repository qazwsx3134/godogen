# V1 直立 VN 原型：介面契約

Phase 1 範圍：依 [V1 Roadmap](../../docs/story-telling-game/ROADMAP.md) 建立 1080×1920 直立畫面框架、六層結構、對話框與懸浮按鈕，並用既有的 `data/debt_story.json` 驗證。Phase 2 起把 `bg`、`char`、`say`、`choice`、`flag`、`goto`、`item` 等 V1 指令加入 StoryRunner。

## StoryRunner 契約

`story_runner.gd` extends RefCounted，使用 preload 載入，不依賴全域 class_name。提供：

- `load_story(path: String) -> bool`：讀取與驗證 JSON，成功後 reset。
- `reset() -> void`。
- `current() -> Dictionary`：目前可呈現指令，附 `node_id`、`node_title`、`step_index`；不消耗指令。
- `advance() -> Dictionary`：完成當前指令後前進；choice／end 不可由 advance 跳過。
- `choose(option_id: String) -> bool`：只允許當前 choice 的有效選项，寫入 flags 並跳轉。
- `snapshot() -> Dictionary`、`restore(snapshot: Dictionary) -> bool`：版本、節點／步序與 flags；無效或異版存檔拒絕且不破壞現況。
- 公開 `flags: Dictionary`、`error_message: String`、`node_id: String`、`step_index: int`。

故事根資料：`id`、`version`、`title`、`entry`、`initial_flags`、`nodes`。每個 node 有 `title`、`steps`、選擇性的 `next`。

可呈現 op：

- `say`: `speaker`（shinpachi/gintoki/otose/narrator）、`text`、可選 `thought: bool`、`expression: String`。
- `choice`: `prompt`、`options: [{id,label,next,set_flags: Dictionary}]`。
- `show`/`hide`: `actor`，show 可選 `at`（舞台標記）。
- `move`: `actor`、`target`（舞台標記）、`duration`（秒）。
- `face`: `actor`、`direction`（left/right/up/down）。
- `expression`: `actor`、`value`（neutral/smile/annoyed/surprised/thinking）。
- `camera`: `target`（actor ID 或 center）、`zoom`（0.95–1.15）、`duration`。
- `wait`: `duration`；`sound`: `id`（paper/knock/step/stamp）。
- `end`: `text`。

Runner 自行消化的 op：`set_flag`（key/value）、`condition`（flag/equals/then/else）、`goto`（target）。有跳轉循環保護。若需新增 op 先回報。

字幕中的演出資訊可用 narrator say 保留，但關鍵登場、走位、表情與鏡頭要有對應指令。不可讓玩家選项只有不同台詞而丟掉後續條件回應。`question_method` 是 unset/hear_first/ledger_first；`repayment_promised` 初始 false，答應還款後設 true。

## VN 外殼（main.gd）

- 根節點 `Control` 全螢幕；`Game` 固定 1080 邏輯寬、高度等於視窗邏輯高，水平置中。子層依序：`BackgroundLayer`、`CharacterLayer`、`EffectLayer`、`DialogueLayer`、`FloatingLayer`、`PopupLayer`、`TitleScreen`。
- 對話框高度為遊戲區高度的 28%，下方是快捷列；名牌疊在對話框左上，依角色換色，旁白不顯示名牌。文字最多三行，超過時由 56 縮到 42。
- `DialogueLayer` 最底下的 `TapCatcher` 處理所有畫面手勢；對話框、立繪與標籤不攔截滑鼠。以放開判定點擊：移動超過 30 px 視為拖曳，往上 140 px 以上為上滑，按住 0.5 秒為長按。UI 隱藏時的點擊只負責恢復。
- 只處理滑鼠事件，觸控由專案設定模擬成滑鼠，確保一次觸控只觸發一次動作。
- 劇本指令：`say`／`choice`／`end` 顯示；`show`／`hide`／`expression` 改立繪；`sound`、`wait`；`move`／`face`／`camera` 沒有 VN 對應，略過。
- 存檔 schema 2：runner snapshot、各角色立繪的可見性與表情、回顧紀錄。每個穩定的 say／choice／end 自動存檔；舊 schema 1 存檔視為失效。

## 懸浮按鈕（scripts/floating_button.gd）

`setup(glyph, font)`；訊號 `tapped`、`long_pressed`（0.6 秒）、`moved`（吸邊完成）。`bounds` 是左上角允許範圍，由 main 設成對話框上方區域；放開後吸附到較近的左右邊緣。閒置 3 秒 40% 透明由 main 統一處理。

## Placeholder 立繪（scripts/placeholder_sprite.gd）

`setup(id, display_name, color, font)`、`set_expression(value)`。剪影頭肩比例固定，身體畫到節點底部；main 把立繪底部延伸到畫面底，讓下緣藏在對話框後面。

## QA

Web 網址帶 `?qa=1` 時，`window.__debtQA` 為唯讀快照：`screen`（title/story/choice/end/log/menu/busy）、`text`、`speaker`、`node_id`、`step_index`、`flags`、`text_complete`、`ui_hidden`、`auto`、`skip`、`toast`、`float_alpha`、`viewport`、`game`／`dialog`／`quickbar`／`name_plate` 矩形、`sprites`、`choices`、`controls`。測試一律透過真實 canvas 點擊操作。
