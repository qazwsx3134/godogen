# 萬事屋吐槽 ADV（暫名）— V1 原型

目前已完成與待辦清單見[進度紀錄](../../docs/story-telling-game/STATUS.md)。

介面提供「月下映畫／萬事屋委託簿／吐槽分鏡」三款風格，可在標題或遊戲選單切換並記住偏好。見[風格與驗證紀錄](docs/UI-REDESIGN-OPTIONS.md)及[互動比較頁](docs/ui-options/index.html)。

Godot 4.7 手機直立視覺小說，依 [V1 Roadmap](../../docs/story-telling-game/ROADMAP.md) 與 [gintama0923](../../docs/gintama-like/new/gintama0923.md) 製作。狀態：**Phase 1、Phase 2 與 Phase 3 技術短循環已完成自動驗收；Phase 4 的回合玩法（逐句槽點、第四面牆消音條與伊莉莎白的牌子、條件式放棄吐槽、連擊、QTE、超必殺、演出效果）與調查的對話／移動話題有可玩的技術試片與自動驗收**；第一章文本與真人手機試玩仍待完成。

要驗證的假設：直立 VN 版面（滿版背景、立繪、依內容高度配置的底部對話層、整合在框內的閱讀工具列）在手機上單手好讀、好操作；作者只改 JSON 就能換場景、角色、分支與素材條件。[原版、前一版與素材試版比較](docs/UI-TRIAL.md)保留實際 Web 畫面，待手機試玩決定版面。

劇情會走向《底特律：變人》、《黑鏡：潘達斯奈基》那種大量分支，所以規劃了一個可拖曳連線的故事流程圖編輯器（可做成網頁），輸出同一份劇本 JSON；規格見 [Roadmap 的 V1 之後](../../docs/story-telling-game/ROADMAP.md#v1-之後)。

預設試玩文本是已核准的[第一場《請幫我向你老闆討債》](../../docs/story-telling-game/stories/002-debt-commission-draft-v0.1.md)，用來測版面與操作。另有 Phase 2 與 Phase 3 草莓牛奶技術片段，分別檢查 JSON 與「調查 → 裝傻 → 吐槽」短循環；兩者都不是作者核准的第一章台詞。正式文本會先共同編劇與試讀。

## 試玩與操作

啟動下方的 Web 伺服器後，開啟 <http://127.0.0.1:5193/> 試玩討債閱讀基線；<http://127.0.0.1:5193/?sample=phase2> 是草莓牛奶劇本測試，<http://127.0.0.1:5193/?sample=phase3> 是可玩的調查與吐槽技術短循環，<http://127.0.0.1:5193/?sample=phase4> 是四線索調查（對話與移動話題、廚房、畫面外台詞），<http://127.0.0.1:5193/?sample=phase4_rounds> 是 Phase 4 回合試片（證言、消音條、神樂回合的伊莉莎白牌子與條件式放棄吐槽、連擊、QTE、超必殺；台詞取自第一章草稿，非核准）。<http://127.0.0.1:5193/?sample=comedy> 是漫畫吐槽疊加層技術片段（三個 preset，台詞取自 v2 EP00 草稿，非核准）。<http://127.0.0.1:5193/?sample=choices> 是兩種選項的技術片段（POV 選項：新八的想法，三個選項各帶語氣標記；導演選擇：跳出角色決定接下來發生什麼，三條分支各自結局；台詞取自 v2 EP00 的 Scene 02 與 Scene 06，非核准）。<http://127.0.0.1:5193/?sample=ep00> 是 VN Framework Prototype v0.1 的 vertical slice「EP00 今天也沒有工作的萬事屋」：一般 VN、POV 選項、漫畫吐槽層、互動調查、旗標與條件、導演選項、三個結局與存讀檔串成一集（台詞取自 v2 EP00 草稿，非核准）。各用自己的本機存檔；桌機或編輯器直接執行時，在標題點故事名稱打開「章節選擇」換故事。

| 操作 | 效果 |
| --- | --- |
| 點畫面任一處 | 打字中顯示整句；打完進下一句 |
| 長按畫面 | 隱藏全部 UI，再點一下恢復（恢復的那一下不推進） |
| 往上滑 | 開啟對話紀錄 |
| 目錄 | 開啟選單，切換風格、存讀檔、設定及其他閱讀功能 |
| 章節選擇 | 標題上的故事名稱：本篇章節依序排列，前一章結算過才開放，顯示最佳評價；試玩片段一直開放。選了就回到標題，按「開始故事」或「繼續」 |
| 設定 | 標題或目錄裡：文字速度（慢／標準／快／瞬間）、自動播放速度、背景音樂與音效音量，立刻生效並記住；目錄的「音效」開關仍可一鍵靜音 |
| 章節結算 | 章節最後：吐槽成功／出手、PERFECT、最高連擊、冷場、隱藏裝傻、剩下的眼鏡、Game Over 次數與評價（剩 5 副 S、4 副 A、3–2 副 B、1 副 C，每次 Game Over 降一級），依評價顯示一句話；「下一章」或「回標題」 |
| 推進鈕（›／續／→） | 補完當句或推進劇情 |
| 選單／標題讀檔 | 選擇指定手動欄位；讀檔頁也可選自動續讀檔 |
| 工具列 | 對話框內的目錄、回顧、自動與「續」；略讀（快轉到下一個選項）、存讀檔、吐槽素材與人物檔案收在目錄裡 |
| 調查 | 線索是背景圖上的東西，不是按鈕：左右拖曳背景找，點那樣東西就取得線索，找到的會留下淡框與勾；有查看後台詞的會先演完再回來。對話框可按「收起 ▼」縮成底部一條，「展開 ▲」叫回來；全部找到時自動展開，按「繼續」離開。調查時角色都不在畫面上 |
| 對話／移動 | 調查時對話框裡的兩排話題：「對話」點了演出那段對話，聊過的不再出現；「移動」換到另一個地點（例如廚房），那裡有自己的背景與熱區，查完會自動回到原地點，也可以按「移動」回去。各地點已查過的熱區保持打勾 |
| 裝傻發言 | ‹ › 切換句子；有補充時按「聽下去」；按「吐槽！」才進入 8 秒選詞 |
| 吐槽選詞 | 選吐槽詞；素材會解鎖完美選項，逾時算冷場；選單、紀錄及存檔欄位會暫停倒數 |
| Phase 4 證言回合 | 每句可能藏一個槽點，全部接住才結束。句數旁 ● 已接住、○ 還有槽點、· 沒有槽點；在沒有槽點的句子按「吐槽！」是揮空（冷場）；同一處失敗 3 次，神樂會提示 |
| 消音條 | 台詞裡出現發亮的黑色消音條時，點它就是吐槽：閱讀時不計時，選詞時也能點 |
| 伊莉莎白的牌子 | 牌子上出現字的那句（例如「犯人是神樂」），伊莉莎白會站到前面，直接點牌子就是吐槽：閱讀時不計時；按「吐槽！」後牌子發亮，8 秒內點也算。其他句子的牌子是空白或劇情寫的字，點了沒反應 |
| 連擊回合 | 每句講完直接進選詞，每接住一句時限縮短（8→6→5→4 秒）；吐槽力滿了會出現「超必殺！」，一次接住所有選詞句 |
| QTE | 白圈縮到黃圈時點畫面任一處；太早、太晚或沒點都算冷場 |
| Game Over | 眼鏡歸零時出現碎眼鏡畫面，可從該回合開頭重試 |
| 角色 | 開口說話才登場；說過話的人留在畫面上，說話的人在最前面、其他人在後面變暗。換背景（新場景）時全部退場，劇本也能用 `hide()` 讓人先退場 |
| 狀態列 | 左上是眼鏡（生命，掉一副就碎一副）與吐槽之力；取得的線索依序列在右邊一欄 |

對話框內提供目錄、回顧、自動與推進鈕；存檔、讀檔、略讀與素材集中在選單。Safe Area 只在 Android／iOS 原生匯出讀取；瀏覽器分頁本身已避開瀏海。讀到穩定劇本位置時寫入獨立的自動續讀檔；手動存檔有 3 頁、每頁 6 格，存入素材、背景、立繪與閱讀位置。新遊戲重設自動續讀進度，手動欄位保留。同一瀏覽器、同一網址重開後可按「繼續」或從指定欄位讀檔。選單的吐槽素材與人物檔案只在有調查或吐槽回合的故事出現。存檔也記住正在播的背景音樂。

[素材試版手機畫面](docs/preview-assets-dialogue-phone.png) · [UI 試版比較](docs/UI-TRIAL.md) · [Phase 2 手機畫面](docs/preview-phase2-phone.png) · [多欄位讀檔畫面](docs/preview-save-slots-phone.png) · [驗證紀錄](docs/VERIFICATION.md)

## 開發與 Web 匯出

此目錄是獨立的 Godot 專案，用 **Godot 4.7 stable** 開啟 `project.godot`，按 F5 試玩。設計尺寸 1080×1920（9:16），`stretch aspect=expand`：較長的手機往下延伸，桌機左右留黑邊。

```bash
cd prototypes/debt-commission
# 已安裝相符版本的 Godot Web export templates 可略過下一行。
python3 tools/fetch_web_templates.py
bash tools/build_web.sh
bash tools/serve_web.sh
```

`GODOT_BIN` 可指定 Godot 執行檔位置；`serve_web.sh` 可接受埠號，例如 `bash tools/serve_web.sh 5194`。伺服器綁定本機 `127.0.0.1`。產物為 `build/web/index.html` 及同目錄相關檔案。Compatibility renderer、單執行緒 Web 匯出。

`build_web.sh` 匯出後會修補 `index.js` 的 Emscripten IDBFS：存檔同步到 IndexedDB 的途中若檔案已被刪除（例如「重新開始」緊接在存檔之後刪掉存檔），略過那個檔案，不再報 `Failed to save IDB file system: undefined`；刪除本身會在 Godot 下一次同步時寫進 IndexedDB。換 Godot 版本後如果修補對不上，建置會直接失敗並說明原因。

## 檔案

| 檔案 | 用途 |
| --- | --- |
| `main.gd` | 直立外殼：背景、立繪、特效、對話與選項、彈出視窗；手勢、AUTO／SKIP、選單、紀錄、存讀檔、QA |
| `scripts/ui_styles.gd` | 三款介面風格與按鈕狀態 |
| `scripts/ui_stage_style.gd` | 與介面風格一致的場景色調 |
| `scenes/stage.tscn` | 舞台：各背景的取景框、左中右通用站位（編輯器裡可拖曳） |
| `scenes/comedy/tsukkomi_impact.tscn`、`small_reaction.tscn`、`full_manga_panel.tscn` | 漫畫吐槽疊加層的三個 preset（`ComedyLayer` 實例化，腳本 `scripts/comedy_preset.gd`）。根節點的 `@export` 可調：`dim_in`、`cutin_at`、`cutin_slide`、`shake_at`、`sound_at`、`burst_at`、`hold_until`、`fade_at`、`end_at`（秒）、`shake_strength`、`sound_id`、`stage_zoom`、`font_max`；`SpeedLines`（`speed_lines.gd`）調線數、顏色、中心空白；`Burst`（`burst_shape.gd`）調尖角數、填色、框線；`CutInPanel`／`Portrait` 是傾斜漫畫格與臉圖；`Text` 的字體與描邊在 scene 裡。編輯器未執行就看得到新八 `shout` 與「現在是工作時間吧！！！」 |
| `scenes/ui/choice_sheet_<cinema\|ledger\|manga>.tscn`、`choice_item_<風格>.tscn` | POV 選項與限時吐槽的選項面板（腳本 `scripts/choice_sheet.gd`）。每個 `choice_item_<風格>.tscn` 的 `%Tone` 是語氣標記（只在有 `tone` 的列顯示：位置、大小、顏色在 scene 裡）；面板根節點的 `index_numerals`、`count_format` 可調 |
| `scenes/ui/choice_sheet_director.tscn`、`choice_item_director.tscn` | 導演選擇面板（三款 UI 風格共用，腳本同上）。`%Banner` 抬頭文字、`%Note` 註腳樣式、`TopTape`／`BottomTape`／每列的 `Stick`（`scripts/stripe_bar.gd`：`color_a`、`color_b`、`stripe_width`、`lean`，編輯器裡直接看得到條紋）、`Panel` 的框線與底色、卡片列的 StyleBox（`choice_item_director.tscn`：一般／按下的邊框與底色、左邊 `content_margin_left` 留給「SCENE 01」）；根節點的 `index_format`（"SCENE %02d"）、`count_format`、`pop_seconds`（彈入秒數）、`pop_from_scale`（彈入起始縮放）可調。由 `tools/make_director_scenes.gd` 產生一次，之後 scene 是來源檔 |
| `scenes/characters/<角色>.tscn` | 每個角色的大小與取景（腳本 `scripts/placeholder_sprite.gd`，manga 風格轉黑白） |
| `scripts/story_runner.gd` | 劇本節點執行、資料檢查、條件跳轉與閱讀位置 |
| `scripts/save_slots.gd` | 手動欄位命名、暫存寫入與備份還原 |
| `data/debt_story.json` | 已核准的討債試玩文本 |
| `data/phase2_story.json` | 草莓牛奶短篇技術測試，非正式第一章 |
| `data/phase3_story.json` | 調查、銀時發言與四種吐槽結果的技術短循環，非正式第一章 |
| `data/phase4_story.json` | 四線索調查與素材限定吐槽的技術試片（`story_src/phase4.*` 建置；調查的對話話題、移動地點、查看後台詞與畫面外台詞的寫法範例） |
| `data/phase4_rounds_story.json` | Phase 4 回合試片：銀時證言、神樂證言（伊莉莎白的牌子、條件式放棄吐槽）與連擊三回合（`story_src/phase4_rounds.*` 建置；v2 回合的寫法範例） |
| `data/ep00_story.json` | EP00 vertical slice（`story_src/ep00.dialogue`＋`ep00.blocks.json` 建置；`?sample=ep00`）：六個場景、三個 POV 選項、導演選項與三個結局；`tests/test_ep00.gd` 窮舉所有路徑 |
| `data/asset_catalog.json` | 背景、人物、吐槽素材及可替換圖片的統一設定 |
| `data/stories.json` | 章節選擇裡的故事：依序的本篇（`kind: "chapter"`）與試玩片段（`"sample"`），各自的劇本與存檔路徑。新增故事加一行，不用改程式 |
| `IMPLEMENTATION.md` | StoryRunner、catalog 與外殼的介面契約 |

角色的名字、顏色與預設站位集中在 `data/asset_catalog.json`；有圖片時填入對應 `path` 即可替換背景或立繪；尚無圖片的角色透過姓名與台詞呈現。新故事用 `bg`、`char`、`say`、`choice`、`flag`、`goto`、`item`。舊劇本的 `move`／`face`／`camera` 屬於先前的俯視舞台，VN 版面略過它們；`show`／`hide`／`expression` 仍對應立繪。新增章節的欄位與驗證規則見 [介面契約](IMPLEMENTATION.md)。

## 驗證

```bash
# 在此 prototype 目錄執行。XDG_DATA_HOME 讓測試資料留在專案快取。
XDG_DATA_HOME="$PWD/.cache/test-data" godot --headless --path . --script res://tests/test_story.gd
XDG_DATA_HOME="$PWD/.cache/test-data" godot --headless --path . --script res://tests/test_vn_shell.gd
XDG_DATA_HOME="$PWD/.cache/test-data" godot --headless --path . --script res://tests/test_phase2_story.gd
XDG_DATA_HOME="$PWD/.cache/test-data" godot --headless --path . --script res://tests/test_phase2_ui.gd
XDG_DATA_HOME="$PWD/.cache/test-data" godot --headless --path . --script res://tests/test_save_slots.gd
XDG_DATA_HOME="$PWD/.cache/test-data" godot --headless --path . --script res://tests/test_phase3_story.gd
XDG_DATA_HOME="$PWD/.cache/test-data" godot --headless --path . --script res://tests/test_phase3_ui.gd
XDG_DATA_HOME="$PWD/.cache/test-data" godot --headless --path . --script res://tests/test_story_build.gd
XDG_DATA_HOME="$PWD/.cache/test-data" godot --headless --path . --script res://tests/test_story_build_parley.gd
XDG_DATA_HOME="$PWD/.cache/test-data" godot --headless --path . --script res://tests/test_phase4_ui.gd
XDG_DATA_HOME="$PWD/.cache/test-data" godot --headless --path . --script res://tests/test_story_tools.gd
XDG_DATA_HOME="$PWD/.cache/test-data" godot --headless --path . --script res://tests/test_round_v2.gd
XDG_DATA_HOME="$PWD/.cache/test-data" godot --headless --path . --script res://tests/test_phase4_rounds_story.gd
XDG_DATA_HOME="$PWD/.cache/test-data" godot --headless --path . --script res://tests/test_phase4_rounds_ui.gd
XDG_DATA_HOME="$PWD/.cache/test-data" godot --headless --path . --script res://tests/test_ui_styles.gd
XDG_DATA_HOME="$PWD/.cache/test-data" godot --headless --path . --script res://tests/test_investigation.gd
XDG_DATA_HOME="$PWD/.cache/test-data" godot --headless --path . --script res://tests/test_comedy.gd
XDG_DATA_HOME="$PWD/.cache/test-data" godot --headless --path . --script res://tests/test_choices.gd
XDG_DATA_HOME="$PWD/.cache/test-data" godot --headless --path . --script res://tests/test_ep00.gd

# 先匯出、啟動伺服器；需要已安裝 Playwright 及 Chromium 的 Node 環境。
node tools/browser_check.mjs --playwright /path/to/node_modules/@playwright/test
node tools/browser_check.mjs --smoke --playwright /path/to/node_modules/@playwright/test
node tools/browser_check.mjs --phase2 --playwright /path/to/node_modules/@playwright/test
node tools/browser_check.mjs --slots --playwright /path/to/node_modules/@playwright/test
node tools/browser_check.mjs --phase3 --playwright /path/to/node_modules/@playwright/test
node tools/browser_check.mjs --rounds --playwright /path/to/node_modules/@playwright/test
node tools/browser_check.mjs --investigate --playwright /path/to/node_modules/@playwright/test
node tools/browser_check.mjs --comedy --playwright /path/to/node_modules/@playwright/test
node tools/browser_check.mjs --choices --playwright /path/to/node_modules/@playwright/test
node tools/browser_check.mjs --ep00 --playwright /path/to/node_modules/@playwright/test
node tools/check_ui_parity.mjs --playwright /path/to/node_modules/@playwright/test
```

`--url` 可指定試玩位址；`--chromium /path/to/chrome-headless-shell` 可指定 Chromium。瀏覽器檢查以真實 canvas 滑鼠與觸控操作（長按、上滑用 CDP 觸控事件）；預設走討債兩條路線，`--phase2` 走劇本測試兩條路線，`--slots` 驗證觸控存讀檔與 18 格分頁，`--phase3` 走調查與吐槽並驗證限時選詞讀檔，`--comedy` 在漫畫吐槽片段驗證疊加層播放中、點擊快轉不推進下一句（390×844 與 320×568，截圖與報告存 `docs/`），`--ep00` 在 EP00 走兩條路線（390×844：路徑 A 選 `loud`、看漫畫吐槽層、調查裡點銀時三次與草莓牛奶、委託書、導演選第三個；路徑 B 選 `tired`、不找委託書、導演選第一個，並在調查與導演選項各存手動欄位、重新整理後讀檔回到同一個事件），320×568 再跑路徑 A 到調查為止，截圖存 `docs/preview-ep00-*.png`、報告存 `docs/ep00-browser-report.json`；`--choices` 在兩種選項片段驗證 POV 選項（語氣標記、選了接對應的反應與旗標）、導演選擇（導演面板、註腳、卡片至少 48 CSS px、舞台不變、從目錄換 UI 風格仍是導演面板、選一張卡走到結局與旗標；390×844 與 320×568，截圖與報告存 `docs/`），`--rounds` 在回合試片用觸控點消音條、伊莉莎白的牌子（閱讀時與 320×568 的選詞面板旁，檢查牌子至少 48 CSS px 且沒被選項面板蓋住）、超必殺與 QTE，並在 320×568 檢查回合操作列；`--investigate` 在四線索試片用觸控點對話與移動話題（390×844 與 320×568）、到廚房查冰箱（畫面外台詞）再回到客廳；`check_ui_parity.mjs` 在 390×844 與 320×568 下對照三款風格的 HTML 樣稿，檢查每個可點元件至少 48 CSS px、都在畫面內且互不重疊。網址帶 `?qa=1` 時才啟用唯讀的 `window.__debtQA`；一般試玩網址不啟用。

## Godot MCP

`addons/godot_mcp_toolkit/` 已啟用，編輯器開著時 AI 可以讀場景、實跑遊戲、截圖與讀 console。WSL 裡的 Claude Code 連 Windows 編輯器的設定方式見 [Roadmap 的開發工具段落](../../docs/story-telling-game/ROADMAP.md#開發工具godot-mcp-toolkit)。Web 匯出已排除此 addon。

## 劇本與解謎編輯工具（只當編輯器用）

**不寫程式的人改劇情，請看 [編劇指南](docs/AUTHORING.md)**：在 Parley 流程圖寫劇情，從選單「專案 → 工具 → 劇本：建置並試玩」就能直接玩，不用打指令。這個選單由 `addons/story_tools/` 提供；`characters/`、`facts/`、`actions/` 是 Parley 的角色與狀態清單，角色由 `tools/story_build/make_parley_stores.gd` 依素材設定產生（新增角色後重跑一次）。

`addons/parley/` 是 [Parley](https://github.com/bisterix-studio/parley)（MIT），裝來試做 [Roadmap](../../docs/story-telling-game/ROADMAP.md#v1-之後) 的故事流程圖編輯器：在 Godot 編輯器底部的 Parley 面板拖曳節點、拉線連分支，存成 JSON 格式的 `.ds` 檔。版本釘在 commit `42f78c79e41da08b804c159ee616188afed76342`（`plugin.cfg` 寫 2.1.0，Asset Library 標 2.2.0，以 commit 為準）。

- **只當編輯器用。** 遊戲仍由 `StoryRunner` 讀 `data/*.json`；Web 匯出已排除 `addons/parley/*`。
- **plugin 直接登記在 `project.godot`，不要在 Project Settings 裡關掉再打開。** 從介面啟用時，Parley 與 Dialogue Manager 都會加一個 runtime autoload，而 Web 匯出排除了它們的檔案，匯出版會因找不到 autoload 而壞掉。`tools/build_web.sh` 偵測到這兩個 autoload（路徑或 uid）會直接停止匯出。
- **Parley 的角色、事實、動作清單已建好**，放在 `characters/`、`facts/`、`actions/`，編輯器打開時會自動登記進 `project.godot` 的 `[parley]` 區段。清單檔的 UID 不能變，`.ds` 檔裡的說話者就是靠它對應；要重建請用 `make_parley_stores.gd`，它會保留原本的 UID。
- **為什麼不換成 Dialogic 2：** 評估見 [docs/DIALOGIC-EVALUATION.md](docs/DIALOGIC-EVALUATION.md)。結論是保留 StoryRunner，Parley 只負責編寫：Dialogic 沒有流程圖編輯器，調查熱區、限時吐槽、檢查點都要自己寫；存檔不是原子寫入、會默默錯位；打錯的角色與指令要到執行時才發現。換過去會影響全部 7 個測試檔。
- **寫好的劇本怎麼進遊戲**：`tools/story_build/build_story.gd` 把 Parley 的 `.ds` 或 Dialogue Manager 的 `.dialogue` 建置成 `data/*.json`，兩種格式可以混用，產出相同。用法、語法與存檔版本規則見 [介面契約的「劇本建置」](IMPLEMENTATION.md#劇本建置story_src--data)；`story_src/phase4.*` 是同一段故事的兩種寫法，可以對照著看。
- **Parley 的圖怎麼畫**：一個 group 框是一個劇情節點（group 名稱就是節點 id）；框內從第一個節點往下連。ACTION 節點的 description 寫指令（例如 `char("kagura", "smile", "left")`、`set asked = "kagura"`），選項節點的 translation key 當選項 id。裝傻回合結束後的走向寫在 `story_src/*.blocks.json`，圖上的回合節點不接線。

同一套做法（登記在 `project.godot`、排除於 Web 匯出）另外裝了兩個工具：

- **[Dialogue Manager](https://github.com/nathanhoad/godot_dialogue_manager)** v4.1.0（commit `a719088`，MIT，需 Godot 4.6+）：在 `.dialogue` 檔用類似劇本的文字語法寫分支對話，編輯器有語法高亮、搜尋與試跑。它和 Parley 都是劇本的編寫格式；**寫 converter 之前要先選定一種**（Parley 的 `.ds` 流程圖，或 DM 的 `.dialogue` 文字），遊戲端仍由 `StoryRunner` 執行。
- **[Puzzle Dependencies](https://github.com/nathanhoad/godot_puzzle_dependencies)** v3.0.1（commit `875a62f`，MIT）：畫冒險遊戲的[解謎依賴圖](https://www.grumpygamer.com/puzzle_dependency_charts)，規劃「拿到哪個素材才能解開哪個調查或吐槽」，可匯出 Graphviz。節點是可分類上色的文字卡片加箭頭，沒有條件運算，是解謎規劃工具，也可當流程圖編輯器的 UI 參考。
  - **圖表存在 `project.godot` 的 `[puzzle_dependencies]` 區段**，每次編輯都會改寫 `project.godot`。多人或多個 session 同時編輯時要注意衝突。
  - **不要按面板裡的更新按鈕**：它會從 GitHub 下載最新版覆寫 `addons/puzzle_dependencies/`，蓋掉固定的版本。
- headless 驗證過 Godot 4.7 能載入、既有測試與 Web 匯出不受影響；**面板本身要在有畫面的編輯器打開確認**。headless 編輯器結束時會多出幾行 `leaked at exit` 訊息，來自 Parley 的編輯器 UI，不影響遊戲。

## Scene 轉換進度

畫面原本全在 `main.gd` 執行時建立，編輯器裡看不到。依 repo 根目錄 `CLAUDE.md` 的原則，改到哪個畫面就轉成 `scenes/ui/` 裡的 scene，版面交給 node 與 Container，程式只負責填資料和行為。

| 畫面 | 狀態 | Scene |
|---|---|---|
| 舞台（背景取景、角色站位） | ✅ 已轉換 | `scenes/stage.tscn`（見下方「舞台」） |
| 角色立繪 | ✅ 已轉換 | `scenes/characters/<角色>.tscn`（腳本 `scripts/placeholder_sprite.gd`），`tools/make_character_scenes.gd` 補建 |
| 素材／人物檔案 | ✅ 已轉換 | `scenes/ui/case_file_panel.tscn`，卡片 `case_file_card.tscn` |
| 標題畫面 | ✅ 已轉換 | `scenes/ui/title_screen_cinema.tscn`、`title_screen_ledger.tscn`、`title_screen_manga.tscn`（腳本 `scripts/title_screen.gd`） |
| 章節選擇、設定、章節結算 | ✅ 已轉換 | `scenes/ui/chapter_select.tscn`（每列 `chapter_row.tscn`）、`settings_panel.tscn`、`chapter_result.tscn`（三款共用） |
| 素材圖片 | ✅ 已轉換 | `scenes/ui/item_picture.tscn`：catalog 有 `path` 就顯示圖，沒有就畫名稱第一個字的色卡；線索欄、素材卡與素材詳細都用它 |
| 對話框與工具列 | ✅ 已轉換 | `scenes/ui/dialogue_box_cinema.tscn`、`dialogue_box_ledger.tscn`、`dialogue_box_manga.tscn`（腳本 `scripts/dialogue_box.gd`） |
| 目錄 | ✅ 已轉換 | `scenes/ui/menu_panel_cinema.tscn`、`menu_panel_ledger.tscn`、`menu_panel_manga.tscn`（腳本 `scripts/menu_panel.gd`），每列是 `menu_row_<風格>.tscn` |
| 對話紀錄 | 待轉換 | |
| 存讀檔欄位 | 待轉換 | |
| 吐槽回合的操作列與消音條 | ✅ 已轉換 | 在三款對話框 scene 的 Actions 裡（‹ ›、句數、聽下去、吐槽！、`CensorBar`）；選項面板另有 `CensorBar` 與 `Super`；顯示什麼由 `scripts/round_view.gd` 決定 |
| QTE、cut-in、Game Over | ✅ 已轉換 | `scenes/ui/qte_ring.tscn`、`cutin.tscn`、`game_over.tscn`（三款共用） |
| 選項面板 | ✅ 已轉換 | POV 選項與限時吐槽：`scenes/ui/choice_sheet_cinema.tscn`、`choice_sheet_ledger.tscn`、`choice_sheet_manga.tscn`（腳本 `scripts/choice_sheet.gd`），每列是 `choice_item_<風格>.tscn`（`%Tone` 語氣標記）；導演選擇：`scenes/ui/choice_sheet_director.tscn`（三款共用），每列是 `choice_item_director.tscn` |
| 眼鏡／吐槽之力 HUD、線索欄 | ✅ 已轉換 | `scenes/ui/round_hud.tscn`（三款共用，`set_style` 換色），眼鏡 `glasses_icon.tscn`、線索 `clue_chip.tscn` |
| 調查點、收起後的調查列 | ✅ 已轉換 | `scenes/ui/hotspot.tscn`（依劇本放在背景圖上）、`scenes/ui/investigate_bar.tscn`；「收起」鈕在三款對話框 scene 的 `InvestigationRow` |
| 調查的對話／移動話題 | ✅ 已轉換 | 三款對話框 scene 的 `InvestigationTopics`（`TalkRow`／`MoveRow`，標籤與間距在 scene 裡），每個話題是 `scenes/ui/investigate_topic.tscn`（大小與字級在這裡，顏色跟著該款的「聽下去」） |
| 伊莉莎白的牌子 | ✅ 已轉換 | `scenes/characters/elisabeth.tscn` 的 `Placard`（對齊圖上白牌子的框，可拖曳、縮放、旋轉）、`Text`（字級與顏色）、`Glow`（選詞時的光框樣式）；牌子上的字由劇本決定 |
| 漫畫吐槽疊加層 | ✅ 已轉換 | `scenes/comedy/*.tscn`（三個 preset，三款 UI 風格共用；`ComedyLayer` 在 `main.tscn`） |
| 結尾按鈕 | 待轉換（做成小 item scene） | |

**舞台**：打開 `scenes/stage.tscn`。

- **站位（站哪裡）**：`StageArea` 底下的 `left`／`center`／`right` 是三個通用站位，任何角色都能站，由劇本 `char(角色, 表情, 位置)` 決定誰站哪裡（沒寫位置時用 catalog 的 `slot`）。主角通常站 `left`。框的底邊是腳底線、中線是角色的中心；框的高度是標準身高，三個站位一樣高。框裡的虛線剪影只在編輯器顯示，點剪影會選到整個框。站位只有這三個名字，劇本和存檔都認這三個；要多一個位置得改程式（`scripts/story_runner.gd` 的 `VALID_CHARACTER_POSITIONS`）。
- **角色（多大、圖怎麼擺）**：每個角色一個 `scenes/characters/<角色>.tscn`。橘色框是站姿框，和站位框同一個大小；拖曳、縮放裡面的 `Art`，就決定這個角色不論站哪個位置的大小與位置（例如神樂的傘很大，她的 `Art` 比框大 1.13 倍）。框本身不用動。畫面上的大小是「站位高度 × 角色自己的比例」。
- **說話的人會移到最前面**，其他人變暗；站位靠得很近時，沒說話的人可能被擋住。
- **背景取景**：`Backgrounds` 底下每個 node 對應 catalog 的一個背景 id（`yorozuya_exterior` 就是萬事屋大樓），圖等比填滿框、置中裁切。把框拉得比畫面大，就能選要露出哪一段，例如左邊拉出去，畫面就往右偏。圖以 `data/asset_catalog.json` 為準，這裡的圖只是預覽。沒有自己 node 的背景（或只有漸層色的）用 `Default`。編輯器裡一次只顯示一張：在場景樹點眼睛圖示切換要調的背景；存檔時哪張開著都沒關係，遊戲會自己顯示當下的背景。
- `StageArea` 的底邊、`DialogueGuide`（對話框示意）由程式處理，已鎖定，不用調。
- 新角色：先在 `data/asset_catalog.json` 登記圖片，再跑 `godot --headless --path . --script res://tools/make_character_scenes.gd`，會替還沒有 scene 的角色建一個（已經有的不會動）。
- 編輯器的畫框是 1080×1920，手機（390×844）的遊戲區是 1080×2337，比較長：站位跟著對話框走，一樣準；背景的裁切在手機上會不同，調完用手機尺寸跑一次確認。
- 標題畫面的大樓是另一張：`scenes/ui/title_screen_<風格>.tscn` 的 `Background`，三款各一份，一樣用拉框取景。

**在編輯器裡調整**：雙擊 `scenes/ui/*.tscn` 打開，左邊場景樹點選 node，右邊屬性面板改位置、大小、字級、間距；Container 的間距在 Theme Overrides 裡。對話框、選項面板、目錄與標題畫面各三款 scene（導演選擇面板一份，三款共用）的配色、字級與框線都存在 scene 裡（框線由 `scripts/ui_ornament.gd` 繪製，編輯器裡也畫得出來），看到的就是遊戲裡的樣子；其他畫面（對話紀錄、存讀檔欄位、結尾按鈕）的顏色與框線仍是執行時依 UI 風格（A／B／C）套上，編輯器裡是 Godot 預設灰色。之後可以把三種風格做成 Theme 資源，讓編輯器也顯示真實配色。

## 發現

- 版面：原版 28% 對話框在 390×844、360×800、320×568 都放得下三行字、兩個選項與懸浮按鈕。底部全寬、無邊框對話層的素材試版也通過主線、Phase 3 四選項與存讀檔 Web 觸控檢查；桌機維持 1080 寬的直式遊戲區。採用哪一版仍待真人手機試玩。
- 觸控：以放開手指判定點擊，長按、拖曳、恢復 UI 的那一下都不會誤推進劇情。
- 劇本資料：不改 GDScript 即可切換背景、立繪、站位、表情與素材條件選項；兩條技術片段路線在 Web 實跑並可續讀。
- 核心短循環：調查熱區取得素材後，銀時的兩句發言可切換與聽補充；進入吐槽選詞才開始倒數。完美／普通／冷場／隱藏結果、眼鏡、吐槽之力與檢查點可由劇本資料與 UI 測試驗證。
- 尚待真人：Android／iOS 實機手感、按鈕大小與透明度是否合適、字級是否夠大。

## 素材來源

- 背景與立繪：使用者加入 `assets/image/` 的 PNG（外觀、客廳、廚房 `kitchen.png`；新八、銀時、神樂、登勢、定春、伊莉莎白），在 `data/asset_catalog.json` 登記。站位的虛線剪影是 `assets/editor/stand_in.svg`，只在編輯器顯示。每個角色要畫哪些表情（生氣、慌張、緊張……）見 [表情清單](../../docs/story-telling-game/EXPRESSIONS.md)；表情圖登記在角色的 `expressions`，還沒有的先用原本那張。
- 音效與稀疏背景音：`tools/prepare_audio.py` 產生的原創 PCM WAV，可重建。
- 中文字型：WenQuanYi Zen Hei，隨附 `assets/fonts/COPYRIGHT.txt` 與 `LICENSE-GPL-2.txt`，包含字型嵌入例外及 M+ FONTS 授權文字。
