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
- `snapshot() -> Dictionary`、`restore(snapshot: Dictionary) -> bool`：保存故事 ID／版本、穩定節點／步序、flags、items、調查與吐槽狀態、牌子上的字；無效或異版存檔拒絕且不破壞現況。
- `inspect_hotspot(id: String) -> bool`：調查目前地點的熱區，標記已查（每個地點分開記）並取得素材（同一素材只給一次）；第一次查時若熱區有 `goto`，跳去演出查看後台詞，演完回到調查；有 `set` 則同時寫入那些旗標（只寫第一次）。已查過的熱區再查不重播，`lines` 熱區例外：它每次點都演出，第 n 次點演出 `lines[n]`（超過就重複最後一個），次數記在 `investigations[調查 id].counts`，第一次點算已查。角色熱區（`character`）在那個角色不在 `cast` 時不能查（回 false），也不算必查。所有必查熱區（沒有 `optional: true` 的，含其他地點）查完才可 `advance()`；離開調查時回到主地點。
- `talk_topic(id: String) -> bool`：演出目前地點的一個對話話題（每個話題只播一次，`require` 的素材到手才出現）；話題節點演完回到調查。
- `move_to(place_id: String) -> bool`：移到調查的另一個地點（`home` 是調查本身）。側地點的熱區全部查完、反應演完後，自動回到主地點。
- `set_boke_line(index: int) -> bool`、`listen_boke_line() -> bool`：切換發言與讀取補充台詞。
- `resolve_boke(option_id: String) -> Dictionary`、`timeout_boke() -> Dictionary`：結算四種結果、眼鏡與吐槽力，回傳結果及目標節點；`retry_checkpoint() -> bool` 從 Game Over 回到回合前（素材、已查熱區、聊過的話題、牌子上的字都回到檢查點的狀態）。
- `placard_view() -> Dictionary`：牌子現在寫什麼：`{text, tappable, slot}`。進行中的回合停在有 `placard` 槽點、還沒接住的句子時，顯示槽點的字（只有回合畫面本身能點，反應場景裡不能）；其他時候是劇情最後一次 `placard` 指令寫的字（"" 為空白）。
- `case_file() -> Dictionary`：`{materials: [{id,name,description}], profiles: [{id,name,profile}]}`，依取得順序列出素材與已解鎖的人物檔案，文字取自素材設定；給素材／人物檔案畫面用。
- 公開 `flags: Dictionary`、`items: Array[String]`、`profiles: Array[String]`、`gameplay: Dictionary`、`checked_hotspots: Dictionary`（主地點以調查 id 為鍵，其他地點是 `<調查 id>/<地點 id>`）、`investigations: Dictionary`（`{調查 id: {place, talked, counts?}}`，`counts` 是 `{lines 熱區 id: 點擊次數}`，第一次點才出現）、`cast: Array`（目前在場的角色 id。舞台在外殼手上，外殼在問調查之前設定，不存檔；只有 `character` 熱區看它，沒設定就是沒人在場）、`placard: String`、`error_message: String`、`node_id: String`、`step_index: int`。

故事根資料：`id`、`version`、`title`、`entry`、`initial_flags`、`nodes`。每個 node 有 `title`、`steps`、選擇性的 `next`。

V1 可呈現 op：

- `bg`: `id` 對應 catalog 的 backgrounds。
- `char`: `id` 對應 characters，可選 `visible`、`expression`、`position`（left/center/right）、`enter`；省略時依角色 catalog 預設。`enter: true` 讓還沒開口的角色直接上場（例如只舉牌、不說話的伊莉莎白），不能和 `visible: false` 同時用。
- `say`: `speaker` 對應 characters 或 narrator、`text`、可選 `thought`／`expression`／`offscreen`。`offscreen: true` 是畫面外的聲音：名牌照常，說話者不上場，場上其他人的明暗不變；旁白不能用。
- `choice`: `prompt`、`options: [{id,label,next,set_flags?,require?,tone?}]`；`require` 是單一素材 ID，至少保留一個無條件選項。選填的 `perspective`（`pov`｜`director`，預設 `pov`）決定這是哪一種選項，劇本作者只標這一處，不自己組 UI：
  - **POV Choice**（`perspective` 省略或 `pov`）：玩家站在某個角色的視角，在那個人格合理的範圍內選反應（激烈吐槽／冷靜指出問題／累到懶得吐槽）。`pov`（catalog 角色 id，預設 `shinpachi`）是這句想法的主人；選項可標 `tone`（`loud`｜`calm`｜`tired`），列首多一個圓形標記。外觀是目前 UI 風格自己的選項面板。
  - **Director Choice**（`perspective: "director"`）：玩家跳出角色、變成導演，決定「接下來發生什麼」，每個選項是真分支，至少 2 個。選填 `note`（非空字串）是面板底下的註腳（例：「※製作組經費有限」）。外觀是導演專用面板，三款 UI 風格共用。
  - 不寫 `perspective`、`pov`、`note`、`tone` 的 `choice` 就是新八的 POV 選項，用目前 UI 風格自己的面板。載入時驗證，錯誤指出節點與步序：`perspective` 不是兩者之一；`pov` 不是 catalog 角色，或用在 director；`note` 用在 pov 或不是非空字串；`tone` 不是三者之一，或用在 director；director 的選項少於 2 個。這些欄位不影響存檔位置（`version` 不看它們）。
- `end`: `text`。
- `result`: 章節結算，章節的最後一步。`title`（例如「～ 第一章 完 ～」）、`lines: {S|A|B|C: {speaker, text}}`（依評價顯示的一句）、可選 `hidden_total`（本章隱藏裝傻總數）。`chapter_result()` 回傳 `title`、`grade`、`line`、`caught`、`tries`、`perfect`、`max_combo`、`fails`、`hidden`、`hidden_total`、`glasses`、`max_glasses`、`game_overs`。評價只看剩下的眼鏡：5 副 S、4 副 A、3–2 副 B、1 副 C，每次 Game Over 降一級、最低 C（`grade_for`）。`stats` 記在 runner、不隨檢查點重試回溯，v1 與 v2 回合都會累計；眼鏡在回合之間不回滿。
- `investigate`: `id`、`prompt`、`hotspots: [{id,label,pos:[x,y],size?:[w,h],item?,goto?,optional?}]`；`pos` 是調查點中心、`size` 是大小（預設 0.12×0.12），都是背景圖寬高的比例，所以左右拖曳背景時調查點跟著圖走。熱區至少有 `item`（取得素材）、`goto`（查看後台詞的節點）或 `lines` 其中一個；`optional: true` 的熱區不擋「繼續」。可選欄位：
  - `keep_cast`（bool，預設 false）：true 時開始調查不讓角色退場（預設是全部退場），場上的人全部亮著，調查像是可點擊的場景。
  - 熱區 `character`（catalog 角色 id）：範圍是那個角色的立繪在畫面上的範圍，取代 `pos`／`size`（兩個都不能寫），只能用在 `keep_cast: true` 的調查。角色不在場時這個熱區不存在（點不到），也不算必查，所以不擋「繼續」；在場與否以外殼的 `cast` 為準。
  - 熱區 `lines`（節點 id 陣列，非空）：與 `goto` 二選一。每次點都演出（不受「已查過不重播」限制）：第 n 次點演出 `lines[n]`，超過就重複最後一個；第一次點算已查、才給素材與寫 `set`。每個節點最後 `goto` 回放調查的節點，和 `goto` 反應一樣，所以有 `lines` 的調查也必須是節點的第一步。
  - 熱區 `set`（`{旗標: 值}`）：第一次查時寫入。旗標要在 `initial_flags` 宣告，型別與全劇本其他寫入一致（納入旗標一致性檢查與存檔允許的值），之後的 `condition` 照常讀得到。
  - 以上欄位的錯誤都在載入時報出節點與步序：`lines` 與 `goto` 同時寫、`character` 用在沒有 `keep_cast` 的調查、未知的角色、`character` 又寫 `pos`、`lines` 空的或指向不存在的節點、`set` 不是旗標物件或寫了沒宣告／型別不同的旗標、`keep_cast` 不是 bool。
  - `bg`（主地點的背景）、`label`（主地點名稱，給「移動」鈕用，預設是背景的 `label`）；
  - `talk: [{id,label,goto,require?}]`：主地點的對話話題；
  - `places: [{id,bg,label?,prompt?,hotspots,talk?}]`：可以移動過去的其他地點，各有背景、熱區與話題。有 `places` 時主地點要寫 `bg`；地點 id 不能是 `home`、不能含 `/`。
  - 熱區、話題、地點 id 在整個調查裡不重複。熱區 `goto` 與話題的節點最後用 `goto`（`.dialogue` 的 `=> 節點`）跳回放調查的那個節點，所以有反應（`talk`、`places` 或熱區 `goto`）的調查必須是節點的第一步，否則載入時報錯。
- `boke_round`: `id`、`speaker`、`lines: [{id,text,listen?}]`、`timer_seconds`、`tsukkomi.options: [{id,label,result,require?,goto,set_flags?}]`、`tsukkomi.timeout`、`game_over`。閱讀發言不限時，玩家進入吐槽選詞後才開始倒數；`require` 控制素材限定選項。
- `boke_round` 加上 `mode`（`testimony`／`combo`）就是 v2 回合：每句各自的 `slot`（`options`、第四面牆 `censor` 或 `placard`、`qte`）、`listen`／`whiff`／`hint` 反應節點、`clear`、`rules`（超必殺、連擊時限與獎勵、提示門檻），單句 `speaker` 可寫合聲（`gintoki+kagura`）；欄位與規則寫在 `scripts/tsukkomi_round.gd` 開頭，完整範例是 `story_src/phase4_rounds.blocks.json`。`current()` 會附上 `current_line`（`speaker`、`caught`、`can_listen`、`can_whiff`、`listened`、`options`、`censor`、`placard`、`qte`）、`caught_line_ids`、`combo`、`timer_seconds`、`super_available`。玩家動作：`resolve_boke`、`whiff_boke`、`resolve_censor`、`resolve_placard`、`resolve_qte(tapped, offset)`、`use_super`、`set_boke_line`、`listen_boke_line`、`timeout_boke`；每個動作跳到反應節點，反應演完回到回合。
  - `placard: {text, goto, result?}`：舉牌槽點。這句是目前句子、還沒接住時，拿牌子的角色（角色 scene 裡有 `Placard` 節點的，目前是伊莉莎白）的牌子顯示 `text`；閱讀時與選詞時點牌子都算這個槽點的結果（預設 perfect）。槽點旁仍要有 `options`（選詞與逾時照常），不能和 `censor` 或 `qte` 放在同一句。
  - 選項的 `when: [{require_caught?, require?, flags?, result, goto, set_flags?}]`：條件結果。選項照常顯示；選它時，第一個條件全部成立的 case 取代選項的 `result`／`goto`（`set_flags` 沒寫就沿用選項的）。條件：`require_caught`（本回合已接住的句子 id）、`require`（持有的素材）、`flags`（`{旗標: 值}`，旗標要是故事裡有的、型別相同）；每個 case 至少一個條件。例：放棄吐槽平常 `fail`，L1、L2 都接住時 `hidden`。
- 演出：`shake`（`strength` small／big、`duration`）、`flash`（`color`、`duration`）、`cutin`（`text`、`speaker`）、`freeze`（`duration`）、`bgm`（`id`，空字串停止）、`se`（`id`）。`id` 對應 catalog 的 `music`／`sounds`，沒有 `path` 的先播合成佔位音。
- 漫畫吐槽 `comedy`：`{"op": "comedy", "preset": <id>, "speaker": <catalog 角色 id>, "text": <台詞>, "expression"?: <表情>}`。`preset` 只能是 `tsukkomi_impact`、`small_reaction`、`full_manga_panel`；`speaker` 必須是 catalog 角色；`text` 非空；`expression` 若有須是合法表情（預設 `tsukkomi_impact`／`full_manga_panel` 用 `shout`，`small_reaction` 用 `neutral`；catalog 沒有該角色該表情的圖就退回角色預設圖，不報錯）。驗證錯誤訊息含節點與步序，例如 `node 'comedy_open' step 4 comedy preset 'x' is not one of ...`。劇作者只選 preset，不組動畫。

內部 op：`flag`（key/value）、`item`（id，重複取得不重複存）、`profile`（角色 id，解鎖人物檔案，重複不重複存；該角色在素材設定要有 `profile` 文字）、`placard`（`text`：牌子上的字，"" 為空白；跟著存檔與回合檢查點）、`condition`（flag/equals/then/else）、`goto`（target）。`bg`、`char`、`say`、`choice`、`flag`、`goto`、`item` 是新章節的主要指令；所有角色、背景、素材 ID 在載入時驗證，錯誤指出節點與步序。

討債閱讀基線仍接受下列舊指令，以保留已核准文本與測試：

- `show`/`hide`: `actor`，show 可選 `at`（舞台標記）。
- `move`: `actor`、`target`（舞台標記）、`duration`（秒）。
- `face`: `actor`、`direction`（left/right/up/down）。
- `expression`: `actor`、`value`（neutral/smile/annoyed/surprised/thinking）。
- `camera`: `target`（actor ID 或 center）、`zoom`（0.95–1.15）、`duration`。
- `wait`: `duration`；`sound`: `id`（paper/knock/step/stamp）。
- `set_flag`（key/value）由 Runner 自行消化，與 V1 的 `flag` 同義。

Runner 對內部跳轉有循環保護。snapshot 另存 `profiles`；沒有這個欄位的舊存檔視為尚未解鎖任何人物。Phase 3 snapshot 額外保存 `gameplay`、`checked_hotspots`、`boke`、`checkpoint`、`game_over_active`；缺這些欄位的舊閱讀存檔仍可還原。`investigations` 與 `placard`（檢查點裡也有）是選填：沒有的舊存檔視為在主地點、沒聊過話題、牌子空白。`investigations[調查 id].counts` 也是選填：沒有的舊存檔視為所有 `lines` 熱區都還沒點過（從第 1 句開始）；有的話 key 必須是該調查有 `lines` 的熱區、值是 1 以上的整數，否則拒絕。檢查點整份複製 `investigations`，所以點擊次數跟著回到回合前。新增指令須同時定義資料驗證、還原與 UI 呈現。

## 素材設定

`data/asset_catalog.json` 是背景、人物與素材 ID 的唯一設定。背景含 `label`、漸層 `top`／`bottom`；人物含 `name`、`color`、預設 `slot`，可加人物檔案文字 `profile`，以及各表情的圖 `expressions: {表情id: res://…}`（說話或 `char` 帶表情時換成那張，沒有就用 `path` 那張；表情 id 見 `VALID_EXPRESSIONS` 與 [表情清單](../../docs/story-telling-game/EXPRESSIONS.md)，`tools/list_expressions.gd` 列出劇本用到、還沒有圖的表情。表情圖由 `tools/fit_expressions.gd` 從 `art_src/expressions/` 的生成原圖做出：和 `path` 那張同樣的像素比例、同一條腳底線、同一條中線，姿勢超出時畫布往兩邊與往上加大；`placeholder_sprite.gd` 依圖的大小把它擺在 `Art` 原本的位置上，所以角色 scene 的取景不用重調。表情圖用 lossy 壓縮匯入）；素材含 `name`、`description`。各項可加 `res://` 圖像 `path`，有填時載入前確認檔案存在。背景與人物沒有圖片時分別使用漸層與剪影。新增章節先在 catalog 定義 ID，再於故事 JSON 引用。背景的取景與三個通用站位（`left`／`center`／`right`，也是存檔與 `char` 可用的位置）在 `scenes/stage.tscn`：背景顯示在同名的 `Backgrounds/<id>` 框（沒有就用 `Default`）。每個角色是 `scenes/characters/<id>.tscn`，根節點是 480×1560 的站姿框（底邊是腳底線），`Art` 在框裡的位置與大小就是這個角色的取景；main 把站姿框等比縮放到站位框的高度，底邊中點對齊站位框的底邊中點。沒有 scene 的角色用預設取景（圖和框一樣高、站在底邊）；`tools/make_character_scenes.gd` 替有圖、沒 scene 的角色補建。說話的人移到最前面。

新劇本的關鍵場景與立繪變化用 `bg`／`char` 明確指定。玩家選項應保留可辨識的後續回應；討債基線的 `question_method` 是 unset/hear_first/ledger_first，`repayment_promised` 初始 false，答應還款後設 true。

## 劇本建置（story_src → data）

作者不直接改劇本 JSON，而是在編輯器寫原始檔，再建置成 `data/<名稱>_story.json`：

```bash
godot --headless --path . --script res://tools/story_build/build_story.gd -- story_src/phase4.dialogue data/phase4_story.json
godot --headless --path . --script res://tools/story_build/build_story.gd -- story_src/phase4.dialogue data/phase4_story.json --check  # 輸出過期就 exit 1
```

- **兩種原始檔，產出相同**：`.dialogue`（Dialogue Manager 的文字語法，`tools/story_build/dm_source.gd`）或 `.ds`（Parley 的節點流程圖，`tools/story_build/parley_source.gd`）。兩者的指令文法相同（Parley 的 ACTION 節點 description 就是 `.dialogue` 去掉 `do ` 的那一行），`story_src/phase4.dialogue` 與 `story_src/phase4.ds` 建出的 JSON 除了 `generated_from` 完全一致。語法對照寫在兩個 adapter 檔頭。
- **`<名稱>.blocks.json`** 放故事資訊（`id`、`title`、`note`、`initial_flags`）、節點標題，以及調查與裝傻回合的參數。熱區座標、話題、地點、吐槽選項、舉牌槽點、條件結果與結果目標不適合在台詞編輯器裡寫，原始檔只用 `investigate("block_id")`、`boke_round("block_id")` 引用。
- **台詞與演出的寫法**（兩種原始檔共用，Parley 的 ACTION 就是去掉 `do ` 的那一行）：`do comedy("tsukkomi_impact", "shinpachi", "問題是你有工作的時候也在休息啊！！")`，第四個參數選填表情（`"angry"`）；`speaker` 可寫 catalog id 或顯示名稱（建置時換成 id）；`do enter("elisabeth", "neutral", "left")` 讓不說話的角色上場；`do placard("犯人是神樂")`、`do placard("")` 改寫、清掉牌子；畫面外台詞在 `.dialogue` 寫成 `定春: 汪。 [#offscreen]`，Parley 在那句 DIALOGUE 前面接一個 `offscreen()` ACTION（`.dialogue` 也可以用 `do offscreen()`），後面不是台詞就報錯。調查與回合的反應節點最後 `=> 調查或回合所在的節點`。
- **選項的種類**：在選項的提問行（旁白）前面寫 `do pov("gintoki")`（這句想法是誰的，catalog id 或顯示名稱，不寫就是新八）或 `do director("※製作組經費有限")`（導演選擇；括號裡的註腳選填，`do director()` 就沒有註腳），與 `offscreen()`、`placard()` 一樣，Parley 以 ACTION 節點表達。選項的語氣：`.dialogue` 在選項行加標籤 `- 問題是你有工作的時候也在休息啊！！ [ID:reply_loud] [#loud]`（`#loud`、`#calm`、`#tired`，至多一個）；Parley 在該選項後（與它的 `set` ACTION 一起）接一個 ACTION `tone("loud")`。兩種原始檔建出相同的 `choice`：`pov` 或 `perspective: "director"`＋`note` 寫在步驟上，`tone` 寫在選項上；沒有標記的選項不帶這些欄位。誤用都報出標題或 group 與步序，不會默默略過：標記後面不是提問、`pov` 與 `director` 同時標、未知角色、`director` 的註腳是空的、未知或多餘的 tone、導演選擇上有 tone、游離的 `tone()`。範例見 `story_src/choices.dialogue`（`tests/test_choices.gd` 另用小段 `.dialogue` 與 Parley 圖比對兩者建出的 `choice` 相同）。
- **旗標的值與條件**：`set 旗標 = 值` 與 `if 旗標 == 值` 的值可以是字串、數字或 `true`／`false`（Dialogue Manager 的語法分析把 `true`／`false` 當變數名，`dm_source.gd` 讀成布林，Parley 的 ACTION／條件節點走同一個函式）。`if` 要有 `else`，兩個分支各只有一個 `=> 標題`；只含條件的節點（例如 `ep00` 的 `s05_check`）由 runner 直接解析，不會出現在 `current()` 的 `node_id`；調查熱區的 `set`（寫旗標）只能寫在 `.blocks.json` 的熱區裡，範例是 `story_src/ep00.blocks.json`（`found_job`、`examined_strawberry_milk`）與 `ep00.dialogue` 的 `if found_job == true`。
- **建置時檢查**：語法、說話者（catalog id 或顯示名稱，無名 = 旁白）、選項 id、到不了的節點（熱區的 `goto`／`lines`、話題、選項都算連到），最後把輸出交給 `StoryRunner.load_story()` 驗證。任何無法對應的內容都報錯並指出標題或 group 與步序，不會默默略過。
- **`version` 自動產生**：取節點、步序與選項等「存檔位置依賴的結構」的雜湊。只改台詞文字時不變，舊存檔照常讀；增刪步驟或改分支就會變，舊存檔被 StoryRunner 以版本不符拒絕，而不是讀到錯位的步驟。
- 兩個外掛都會把原始檔登記進 `internationalization/locale/translations_pot_files`，供之後產生翻譯 POT，屬正常行為。

## VN 外殼（main.gd）

- 根節點 `Control` 全螢幕；黑邊底色 `Letterbox` 與 `Game` 都是 `main.tscn` 裡的 node。`Game` 固定 1080 邏輯寬、高度等於視窗邏輯高，水平置中（位置與大小由 `_layout` 依視窗設定）。子層也是 `main.tscn` 裡的 node（Scene Unique Name，`main.gd` 用 `%名稱` 取得），由後到前：`BackgroundLayer`、`CharacterLayer`、`InteractionLayer`（角色熱區）、`EffectLayer`（HUD）、`DialogueLayer`、`ComedyLayer`（`comedy` 指令的漫畫吐槽疊加）、`OverlayLayer`（閃光、停格、cut-in、QTE、Game Over）、`PopupLayer`，最上面是標題畫面 scene。所有層都不攔截滑鼠，手勢一律由 `DialogueLayer` 最底下的 `TapCatcher` 在放開時判定。`main.gd` 的成員 `_game`、`_bg_layer`、`_char_layer`、`_interaction_layer`、`_fx_layer`、`_dialog_layer`、`_comedy_layer`、`_overlay_layer`、`_popup_layer` 就是這些 node；震動（`shake`）一起移動背景、立繪、`InteractionLayer`、HUD 與對話層。
- 對話框是 `scenes/ui/dialogue_box_<cinema|ledger|manga>.tscn`（腳本 `scripts/dialogue_box.gd`），換 UI 風格就換掉整個 scene。框貼齊遊戲區底部，依內容往上長；裡面依序是說話者列（記號、名字或「旁白」、章節；章節名放不下時以「…」截斷，三款的 `Chapter` 都設 `text_overrun_behavior`）、台詞、動作槽（調查的「繼續」、吐槽回合按鈕）、工具列（目錄、回顧、自動）與「續」鈕。打字時整句先排版再逐字顯示（`visible_characters`），框的高度不會跳。scene 以 390 CSS px 寬的畫面為準；更窄的手機由 main 把框從左下角等比放大 390 ÷ CSS 寬倍（`_ui_scale`），按鈕維持 48 CSS px 以上。立繪與選項改以固定的舞台底線排版（遊戲區高度 28%，沒有玩法的故事 20%），不隨台詞行數移動。
- 選項出現時，底部改由選項面板（腳本 `scripts/choice_sheet.gd`）取代對話框，選完或離開選項，對話框回來。面板有兩種 scene，由 `main.gd::_choice_sheet_scene()` 依正在顯示的選項決定（掛哪一張只在 `_swap_choice_sheet`／`_show_choice_sheet` 判斷）：
  - **POV 面板**每款風格一個：`scenes/ui/choice_sheet_<cinema|ledger|manga>.tscn`（POV 選項與限時吐槽用）：標題是劇本的 `prompt`（限時吐槽則是正在吐槽的那句台詞，POV 選項是想法語氣），每個選項一列（`choice_item_<風格>.tscn`，編號 01／壹），限時吐槽多一條倒數，最下面是「目錄」。POV 選項把 `pov` 角色（預設新八）以 `thinking` 表情聚焦、名牌是「<名字>・心聲」。有 `tone` 的列在編號後面多一個圓形標記 `%Tone`（`loud`「！」、`calm`「？」、`tired`「…」，用內附字型畫得出來的字元），列的文字從標記後開始，那一列有自己的 StyleBox 副本；沒有 `tone` 的列隱藏標記，與 scene 原樣一致。
  - **導演面板** `scenes/ui/choice_sheet_director.tscn`＋`choice_item_director.tscn`（三款風格共用，視覺上與任何一款 POV 面板一眼可分：黑底、黃黑警示條、白字）：抬頭 `%Banner`「── 導演選擇 ──」、旁白式的提問 `%Prompt`、每個選項一張場記板卡片（條紋的場記板棒、`%Index` 寫「SCENE 01」，`index_format` 控制）、底下一行註腳 `%Note`（沒有 `note` 時隱藏）、「目錄」；沿用 `Prompt`、`Choices`、`ChoicesScroll`、`Feedback`、`Menu`、`Count`、`Timer`、`CensorBar`、`Super` 這些 node 名稱，所以 `show_options`、`set_max_height`、`_fit_choice_sheet`、`_refresh_reading_ui` 照用。選項太多時卡片列改為捲動。出現時整個面板 0.25 秒內彈入（`Panel` 的縮放與透明度，面板根節點自己的縮放留給窄手機的 `_ui_scale`，彈入期間 QA 的 `screen` 回報 `busy`），並播音效 `director_clap`（catalog 的 `sounds`，目前是合成佔位音；靜音時不播）。導演選擇不把任何角色拉上場或聚焦，`_current_speaker` 為空，名牌是「旁白」，提問以旁白（非想法）語氣記進對話紀錄。條紋由 `@tool` 腳本 `scripts/stripe_bar.gd` 畫（`color_a`、`color_b`、`stripe_width`、`lean`）。
  - 兩種面板的 `Choice_%d` 命名、`choose()` 流程、略讀停在選項、長按隱藏 UI、窄手機的 `_ui_scale`、每列命中區至少 48 CSS px 都一樣。換 UI 風格時（`_mount_choice_sheet`），POV 選項在新風格的面板重建；正在顯示導演選擇則仍掛導演面板（不重播彈入與音效）。存檔只記劇本位置，從存檔還原到導演選擇外觀與還原前相同。導演面板由 `tools/make_director_scenes.gd`（`PackedScene.pack()` + `ResourceSaver.save()`）產生一次，之後 scene 是來源檔：已存在時拒絕覆蓋，需 `-- --force`，重產前先看 `git diff`。
- 目錄是 `scenes/ui/menu_panel_<風格>.tscn`（腳本 `scripts/menu_panel.gd`，每列 `menu_row_<風格>.tscn`）：暗幕上置中的面板，標題與 ×，依序是回到故事、儲存進度、讀取存檔、吐槽素材與人物檔案（只在有玩法的故事）、故事回顧、略讀（只從台詞開啟時可用）、三款風格、音效、回標題。畫面太矮時清單可以捲動。點暗幕、× 或回到故事都會關閉。
- 標題畫面是 `scenes/ui/title_screen_<風格>.tscn`（腳本 `scripts/title_screen.gd`）：故事外觀照片加上該風格的色調，底部卡片放目前的故事（點一下開章節選擇）、遊戲名、開始故事、繼續、讀取存檔與設定、三款風格。
- 故事清單是 `data/stories.json`（`stories_path`）：`{id, kind: chapter|sample, path, save}`，依序。`?sample=<id>` 與記住的選擇都用 `id`（例如漫畫吐槽層技術片段是 `?sample=comedy`，兩種選項的技術片段是 `?sample=choices`）。章節選擇 `scenes/ui/chapter_select.tscn`：本篇依序、前一章有結算紀錄才開放，試玩片段一直開放。結算紀錄在 `progress_path`（預設 `user://progress.cfg`，`[cleared] <id> = 最佳評價`）。`result` 步驟顯示 `scenes/ui/chapter_result.tscn` 並記錄評價；「下一章」是清單裡的下一個本篇。
- 設定 `scenes/ui/settings_panel.tscn`（標題或目錄開啟，從目錄開時目錄留在底下）：`scripts/settings.gd` 的四項，各是選項索引，存在 `settings_path`（預設 `user://settings.cfg`）。預設值等於原本的速度與音量；「瞬間」整句直接顯示；音量改變時背景音樂重播（Web 的 Sample 模式不吃播放中的音量變化）；目錄的「音效」靜音蓋過音量。
- 章節選擇與設定是全螢幕面板，窄手機時和其他面板一樣依 `_panel_scale` 等比放大，按鈕維持 48 CSS px 以上。
- 換 UI 風格時，對話框、選項面板（導演面板三款共用，不換）、目錄與標題畫面都換成該風格的 scene，畫面上的狀態原樣帶過去。背景照片套 `scripts/ui_stage_style.gd` 的色調，C 分鏡的立繪另轉黑白。這些 scene 都以 390 CSS px 寬的畫面為準，更窄的手機由 main 等比放大（`_ui_scale`）。
- 吐槽回合：Phase 3 與 v2 回合共用對話框 Actions 裡的操作列（‹ ›、句數與接住標記、聽下去、吐槽！）和消音條，顯示什麼由 `scripts/round_view.gd` 決定。證言回合按「吐槽！」依該句打開選詞、開始 QTE 或揮空；連擊回合每句直接打開選詞（時限依連擊縮短）或 QTE。QTE 是 `scenes/ui/qte_ring.tscn`：以 `Time.get_ticks_usec` 計時，點一下回報與「縮到剛好」的時間差，過了 `late_after` 沒點就回報太晚。選詞時選項面板另外顯示消音條，以及吐槽力滿時的「超必殺！」；面板比畫面可用高度還高時，選項列改為捲動。v2 的聽下去直接演出 runner 跳去的節點。
- 登場：角色開口才上場（`_focus_speaker`，合聲的每個人都算），在自己的站位；已在場的人留著、變暗，說話的人移到最前面。`char` 只設定站位與表情，`visible: false`（`hide`）才讓人退場；換到不同背景時與開始調查時全部退場（`keep_cast: true` 的調查不退場，全部亮著）。
- 調查：對話框的 `InvestigationTopics` 有「對話」與「移動」兩排（沒有項目的那排隱藏），每個話題或地點是 `scenes/ui/investigate_topic.tscn`，樣式照該款對話框的「聽下去」鈕；點話題演出它的節點、演完回到調查（背景拖到哪裡就回到哪裡），點地點換成那個地點的背景、熱區與話題。熱區有查看後台詞時，點到就演出、演完回到調查。「繼續」在任何地點都能按，離開時換回主地點的背景。調查點是 `scenes/ui/hotspot.tscn`，放在當前背景框裡一層蓋住整張圖的節點上（依 `pos`／`size` 用 anchor 定位），找到前不顯示。角色熱區（`character`）改放在 `InteractionLayer`：範圍是該角色立繪（`placeholder_sprite.gd::art_rect()`，剪到遊戲區內）在畫面上的範圍，視窗改變時跟著立繪重排，角色不在場就不建。點擊判定時，疊在一起的熱區物件勝過角色（角色熱區是整張立繪，不能把物件蓋住）、物件取面積小的，兩個角色取在前面（`CharacterLayer` 較後面）的；已查過的熱區不再回應，`lines` 熱區例外，每次點都演出。調查期間背景框撐開成整張圖（等比蓋滿框、置中），拖曳畫面左右平移、不會超出圖的邊，離開調查時還原框的位置。點擊在放開時判定：拖過的不算，點在對話框上的不算，命中區至少 48 CSS px。對話框的 `InvestigationRow` 有「收起」，收起後改顯示 `scenes/ui/investigate_bar.tscn`（進度與「展開」）；最後一個線索找到時自動展開。
- HUD 是 `scenes/ui/round_hud.tscn`（眼鏡圖示 `glasses_icon.tscn`、吐槽之力、連擊、倒數；面板下方右側是線索欄，每個線索一個 `clue_chip.tscn`）；Game Over 是 `scenes/ui/game_over.tscn`（碎眼鏡、結尾文字、檢查點重試、回標題），取代一般結尾按鈕。
- **ComedyLayer**（`main.tscn` 的 `Game/ComedyLayer`，腳本 `scripts/comedy_layer.gd`，`DialogueLayer` 之上、`OverlayLayer` 之下，平常隱藏）：`play(step) -> float`（回傳 preset 長度）、`fast_forward()`、`stop()`、`is_active()`、`qa_state()`。每個 preset 是 `scenes/comedy/<preset>.tscn`，根節點掛 `scripts/comedy_preset.gd`，時間軸與效果是根節點的 `@export`（秒）：`tsukkomi_impact` 0.00 舞台變暗、0.05 speaker 顏藝 cut-in 從左緣滑入、0.10 震動 big、0.12 音效 `comedy_don`、0.15 爆炸框大字（紅黑混排）彈出並讓 `BackgroundLayer`／`CharacterLayer` zoom 1.0→1.05、0.90 停住、1.20 淡出、1.35 結束，蓋住立繪與對話框；`small_reaction` 不遮對話框，小爆炸框掛在 speaker 立繪頭部上方（speaker 不在場就在對話框上緣中間），音效 `comedy_pop`、不震動、約 0.9 秒；`full_manga_panel` 白底漫畫大格＋速度線＋大張 cut-in＋大字，震動 big、`comedy_don`、約 1.8 秒。三款 UI 風格共用同一套外觀。
  - 震動與音效走 `StageEffects`（`add_shake_layer` 讓預設的 preset 跟著舞台震動；新音效 `comedy_don`、`comedy_pop` 在 catalog 的 `sounds`，有合成佔位音）。zoom 用 `scale` 動 `BackgroundLayer`、`CharacterLayer`（`pivot_offset` 設在中心），播放前記下兩層的 `scale` 與 `pivot_offset`，`stop()` 一律還原。
  - 劇情等 preset 播完才前進（`main.gd` 的 `comedy` 分派在 await 後檢查 `generation`）。ComedyLayer 內所有 node 的 `mouse_filter` 都是 IGNORE，點擊由 `DialogueLayer` 底下的 `TapCatcher` 接：播放中的一次點擊（含按下時 preset 在播、放開時已結束的那一下，以及 `ui_accept`／續）只呼叫 `fast_forward()`，≤0.15 秒淡出結束，不推進劇情，下一句照常打字、完整顯示。
  - 略讀（`skip`）時不建 preset、不等，開啟略讀時正在播的 preset 立刻快轉；自動播放照常等。台詞不論播或略過都記進對話紀錄（說話者是 `speaker`）。存檔不記 comedy：讀檔、還原、檢查點重試時，若目前步驟停在 `comedy` 會直接跳過，已播過的不會重播。
  - 回標題、讀欄位、換 UI 風格、重新開始、Game Over 重試（`_cancel_generation`、`_render_restored_current`、`_apply_ui_style`）都呼叫 `stop()`：ComedyLayer 清空並隱藏、舞台層 `scale`／`position`／`pivot_offset` 還原、沒有殘留 tween。大字依爆炸框內的空間縮到放得下（`comedy_preset.gd::_fit_text`，用 label 自己量內容高度），窄螢幕（320 CSS px）也不超出遊戲區；整層用 `_fit_full_area` 跟 `_ui_scale` 放大。
  - 場景由 `tools/make_comedy_scenes.gd`（`PackedScene.pack()` + `ResourceSaver.save()`）產生一次，之後 scene 是來源檔：已存在時拒絕覆蓋，需 `-- --force`，重產前先看 `git diff`。`speed_lines.gd`、`burst_shape.gd` 是 `@tool` 繪圖，編輯器裡直接看得到速度線與鋸齒爆炸框。
- 演出指令交給 `scripts/stage_effects.gd`：震動只移動舞台各層（`Game` 的位置由版面決定），閃光與停格灰屏放在 `OverlayLayer`，cut-in 是 `scenes/ui/cutin.tscn`。它們都不攔截點擊；只有 `freeze` 讓劇情等待，略讀時不等。存檔以選填欄位 `bgm` 記住正在播的音樂。
- 舉牌：角色 scene 裡的 `Placard`（伊莉莎白的在 `scenes/characters/elisabeth.tscn`：框對齊圖上的白牌子、可旋轉，底下 `Text` 是字、`Glow` 是提示光框）顯示 `placard_view()` 的字。牌子能點時（`tappable`），拿牌子的人站到說話者前面、不變暗；選詞時 `Glow` 一明一暗，選項面板的最大高度停在牌子下緣，選項改捲動。點擊由 `TapCatcher` 在放開時判定：命中區是牌子外框的矩形、每邊至少 48 CSS px，扣掉被對話框或選項面板蓋住的部分。
- 登場：`enter` 讓角色在自己的站位上場並亮著；`offscreen` 的台詞不呼叫 `_focus_speaker`。
- `DialogueLayer` 最底下的 `TapCatcher` 處理所有畫面手勢；對話框、立繪與標籤不攔截滑鼠。以放開判定點擊：移動超過 30 px 視為拖曳，往上 140 px 以上為上滑，按住 0.5 秒為長按。UI 隱藏時的點擊只負責恢復。
- 只處理滑鼠事件，觸控由專案設定模擬成滑鼠，確保一次觸控只觸發一次動作。
- 劇本指令：`bg` 切換背景、`char` 控制立繪與站位，`say`／`choice`／`end` 顯示；舊故事的 `show`／`hide`／`expression` 仍改立繪，`sound`／`wait` 仍執行，`move`／`face`／`camera` 無 VN 對應而略過；演出指令見上。
- `story_path` 與 `save_path` 可在場景設定；Web `?sample=phase2` 與 `?sample=phase3` 各開啟固定技術片段及獨立存檔命名空間。
- `save_path` 是自動續讀檔；同一命名空間另有 18 個手動欄位（3 頁 × 6 格）。目錄的「儲存進度」開啟欄位，目錄與標題的「讀取存檔」可指定欄位或自動檔；覆寫有確認。新遊戲只重設自動進度。
- 存檔 schema 3：runner snapshot、當前背景、各角色立繪的可見性／表情／站位、回顧紀錄；手動欄位另有章節、時間與小型場景縮圖。穩定的 say／choice／end／investigate／boke_round 寫入自動檔，手動欄位只在玩家選定後寫入。吐槽回合另存 `boke_ui_screen`，選詞階段才存 `boke_timer_remaining`；舊的有倒數但無畫面欄位的存檔會還原到選詞階段。讀檔先驗證劇本 ID／版本與狀態；寫入採暫存檔及備份，避免覆寫中斷破壞原有欄位。

## 角色立繪（scripts/placeholder_sprite.gd）

`scenes/characters/<id>.tscn` 的根腳本：`setup(id, display_name, color, font)`、`set_expression(value)`、`set_art(texture)`（把 catalog 的圖放進 scene 的 `Art`，沒有 `Art` 時建預設的）、`set_ui_style(style_id)`（manga 轉黑白）。`REFERENCE_SIZE` 是站姿框大小。

## QA

Web 網址帶 `?qa=1` 時，`window.__debtQA` 為唯讀快照：`screen`（title/story/choice/end/result/investigate/boke_round/tsukkomi/log/menu/save_slots/load_slots/slot_confirm/chapter_select/settings/busy）、`result`（結算時的 `chapter_result()`）、`settings`、`text`（打字中的部分）、`full_text`、`speaker`、`node_id`、`step_index`、`flags`、`items`、`background`、`text_complete`、`ui_hidden`、`auto`、`skip`、`toast`、`viewport`、`game`／`dialog`／`quickbar`／`name_plate`／`choice_sheet` 矩形（看不見的留空）、`sprites`（含站位）、`choices`、`choice`（`choice` 步驟的選項顯示時是 `{perspective, pov, note, sheet, tones}`：步驟要求的種類、POV 是誰（導演選擇為空字串）、導演註腳（沒有為空字串）、實際掛上的面板（`director` 或目前的風格 id）、每個選項的語氣（沒有為空字串）；沒有選項、限時吐槽時是空物件）、`slot_page`、當頁 `slots`（欄位號、佔用狀態、章節、時間、矩形）、`phase3`（眼鏡與吐槽力、素材、調查點（`screen_rect` 是命中區，`rect` 只在點得到時才有；角色熱區的 `rect` 只取立繪在對話框上方那一段）、`pan`（`offset`／`min`／`max`）、`investigate_collapsed`、發言索引與已聽狀態、倒數、檢查點、結果；v2 回合另有 `round`：`mode`、`combo`、`caught`、`super_available`、`censor`、`placard`、`qte_active`；調查另有 `investigation`：`place`、`place_label`、`talk`、`moves`、`complete`、`progress`）、`placard`（`text`、`glowing`、`holder_visible`、`tappable`）、`comedy`（`active`、`preset`；播放中另有 `burst`、`text` 兩個矩形與 `text_fits`）、`controls`。快照在該幀排版完成、繪製之前才寫出，目錄彈出與導演面板彈入的動畫期間 `screen` 回報 `busy`，測試讀到的座標一定是最終位置。`controls` 只列玩家當下點得到的：看得見、沒停用、沒被捲出或裁出畫面（目錄在矮螢幕上捲到下方的列不列）；目錄開著時只列目錄裡的控制項（`menu_resume`、`menu_<列>`、`menu_style_<風格>`、`menu_close`），`menu_dim` 是面板左側暗幕的一條。調查有 `investigate_collapse`、`investigate_expand`、`investigate_continue`、每個話題 `talk_<話題 id>`、每個地點 `move_<地點 id>`（主地點是 `move_home`）；結算有 `result_next`、`result_title`；章節選擇有 `chapter_<id>`、`chapter_close`；設定有 `setting_<項目>_<索引>`、`settings_close`，標題的 `title_settings`；章節選擇或設定開著時只列它自己的控制項；回合相關的控制項有 `boke_previous`、`boke_next`、`boke_listen`、`boke_tsukkomi`、`censor`（閱讀時對話框裡的，選詞時選項面板裡的）、`placard`（牌子點得到的部分，至少 48 CSS px 高才列）、`super`、`qte`（整個畫面）、`game_over_retry`、`game_over_title`。測試一律透過真實 canvas 點擊操作。


## B 超必殺演出（2026-10-06）

- 回合的 `rules.super_label` 是選詞面板上的超必殺文字（非空字串）；省略時沿用「超必殺！」。切換 UI 風格與存讀檔皆從目前回合取得文字。
- `beam` 是非阻塞演出：JSON `{ "op": "beam", "duration": 0.8 }`，Dialogue Manager／Parley action 寫 `beam()` 或 `beam(0.8)`；duration 可為 0.05–5 秒。略讀不播，所有 node 都忽略滑鼠，不消耗劇情點擊。
- `scenes/ui/beam.tscn` 的 `Strip` anchors／offsets 決定光束位置與厚度；`Aura`、`Light`、`Core` 決定色彩，`shaders/beam.gdshader` 可調脈動速度與邊緣柔化。根 node 的 `reveal_seconds` 決定展開時間。動畫只改 scale／modulate，場景位置不被改寫。
- HUD 的眼鏡在力量達到 `max_power` 時出現金色氣焰；發動後力量歸零並消失。從未滿到全滿只播一次「吐槽之力全滿！」cut-in 與 `power_up`，讀檔恢復全滿僅恢復氣焰。
- `power_up` 使用獨立音效播放器，不會被同一步的反應音打斷；`beam`／`power_up` 同樣遵守靜音及音效音量。catalog `sounds.<id>.path` 可替換合成佔位音。
- `phase4_rounds` 試片保留原有三個選詞槽點＋QTE，用來驗證超必殺只接住剩餘選詞槽點，QTE 仍要手動完成。正式第一章 C1–C4＋C5 的轉稿列在 TODO 的 E。
