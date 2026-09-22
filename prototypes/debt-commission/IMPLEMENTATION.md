# Debt Commission演出原型

本輪範圍：將 `docs/story-telling-game/stories/002-debt-commission-draft-v0.1.md` 的完整第一場製成 Godot 4.7 直式 Web 可玩原型。所有正式台詞沿用核可稿，兩條路徑皆可結束。先採自行繪製的簡化向量角色與舞台，沒有 AI 圖像生成。

## 所有權

- Runtime worker：`scripts/story_runner.gd`、`data/debt_story.json`、`tests/test_story.gd`。
- Stage worker：`scripts/story_stage.gd`、`scripts/actor_doll.gd`。
- UI worker：`main.gd`（主畫面、輸入、劇情指令協調、續讀／回顧）。
- Commander：專案／主場景設定、音效／字型、匯出、瀏覽器測試、文件、整合與最後修正。
- 各 worker 不改其他檔案、不遞迴委派。需要改共用介面先回報。

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

## Stage 契約

`story_stage.gd` extends Node2D，不依賴主場景。固定設計座標 720 × 620，由 main 根據可用舞台區整體縮放。室內為溫暖紙色、木框、榻榻米、窗戶、門、矮桌、帳本／糰子等簡化繪製。地圖角色可辨識、腳底站位、適當遮擋與深度排序。

- `reset_stage() -> void`：新八在 reader，銀時在 host，登勢隱藏。
- `perform(command: Dictionary) -> void`：awaitable；支援 show/hide/move/face/expression/camera/wait（sound 由 main 處理）。無 tween 的指令可立即返回。
- `set_speaker(actor_id: String, expression: String = "neutral") -> void`：說話者聚焦與表情。
- `snapshot() -> Dictionary`、`restore(state: Dictionary) -> void`：還原位置、可見性、表情、朝向與鏡頭，不重播動作。
- `cancel() -> void`：取消未完成 tween，restart 使用；等待者必須能返回，不能永遠等 tween.finished。
- `get_actor_state() -> Dictionary`：回傳可供驗證的位置與可見性等資料。

站位字串：`reader`（新八初始桌前）、`host`（銀時）、`door`（登勢出場）、`landlady`（登勢桌邊）、`other_side`（新八走到桌另一側）。移動到 other_side 時繞過桌子，可用自訂中繼點。Camera 調整舞台 world 子樹，不移動 UI。

`actor_doll.gd` extends Node2D，程序向量繪製（非 AI 圖），提供 `setup(id: String, as_portrait: bool = false)`、`set_expression(value: String)`、`set_facing(value: String)`、`set_speaking(value: bool)`、`set_walking(value: bool)`。世界模式約寬 80、高 125，腳底在 local (0,0)；立繪模式約寬 140、高 185，底部在 (0,0)。銀時銀白亂髮／白藍衣，新八黑髮眼鏡／藍白衣，登勢灰髮髮髻／紫衣。表情、說話及走路有輕微動態。保持 draw calls 合理。

## 驗收

1. 直式可讀，點擊先補完文字、再前進；選項／回顧不穿透；觸控與滑鼠皆可玩。
2. 兩條選擇分別進入正確回扣，皆到完整結尾；可重玩，狀態重置。
3. 登勢入場、新八繞桌走位、角色轉向、說話聚焦與至少兩種表情清楚呈現。
4. 字幕及選項是 Godot UI；Web 匯出實際在瀏覽器測試。可回顧台詞，最小本機續讀可驗證。
5. 存在對應引擎的路徑／狀態測試及瀏覽器操作證據；美術為演出用簡化造型，真人觀感仍由使用者試玩。

## Main/UI 補充

main.gd extends Control，root scene由 commander建立。介面採紙色、墨色、朱紅／木色點綴。版面為直式：頂部篇名／地點，下方室內舞台，再下方說話立繪、人物名、逐字對話與下一句／選項；回顧、音效與重新開始等功能需可操作。以 720×1280 基準；root viewport stretch expand，main 把內容區限制在720邏輯寬並置中。舞台 Node2D 720×620 可在可用區等比縮放，不扭曲角色。

字型由 commander提供 `assets/fonts/story-cjk.ttc`，原創WAV由commander提供 `assets/audio/{paper,knock,step,stamp,ambient}.wav`。UI worker應使用這些路徑；可在尚不存在時用load+fallback，避免干擾並行工作。

開場title含「開始故事」及有存檔才可點的「繼續閱讀」。第一次開始的明確點擊啟用音效。說話人英文ID映射中文，thought標為心聲。沒有自動跳過玩家選擇，正常文字第一次點擊補完、第二次前進。所有動畫等待與restart以generation token避免舊回呼重入。聲音預設輕柔且可關閉。

保存於user://，每個穩定 say／choice／end 保存 runner snapshot、stage snapshot、回顧。restore先驗證runner再載stage；進度版本不合可重新開始。回顧只呈現已看過台詞，不洩漏另一分支。

Web測試以`?qa=1`啟用唯讀`window.__debtQA`（JavaScriptBridge）。欄位：`screen`（title/story/choice/busy/end/log）、`text`、`speaker`、`node_id`、`step_index`、`flags`、`text_complete`、`viewport:{width,height}`、`actors`（stage.get_actor_state）、`choices:[{id,label,rect}]`、`controls:{begin,continue,next,log,log_close,restart,mute}`。每個rect用Control.get_global_rect()的`{x,y,width,height}`，不存在的控制可不提供。QA bridge只暴露狀態，測試透過真實canvas點擊操作，不提供修改遊戲狀態的捷徑。
