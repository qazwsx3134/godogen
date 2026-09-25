# 萬事屋吐槽 ADV（暫名）— V1 原型

目前已完成與待辦清單見[進度紀錄](../../docs/story-telling-game/STATUS.md)。

Godot 4.7 手機直立視覺小說，依 [V1 Roadmap](../../docs/story-telling-game/ROADMAP.md) 與 [gintama0923](../../docs/gintama-like/new/gintama0923.md) 製作。狀態：**Phase 1、Phase 2 與 Phase 3 技術短循環已完成自動驗收**；第一章文本與真人手機試玩仍待完成。

要驗證的假設：直立 VN 版面（滿版背景、立繪、底部半透明對話層、可拖曳的懸浮按鈕）在手機上單手好讀、好操作；作者只改 JSON 就能換場景、角色、分支與素材條件。[原版、前一版與素材試版比較](docs/UI-TRIAL.md)保留實際 Web 畫面，待手機試玩決定版面。

劇情會走向《底特律：變人》、《黑鏡：潘達斯奈基》那種大量分支，所以規劃了一個可拖曳連線的故事流程圖編輯器（可做成網頁），輸出同一份劇本 JSON；規格見 [Roadmap 的 V1 之後](../../docs/story-telling-game/ROADMAP.md#v1-之後)。

預設試玩文本是已核准的[第一場《請幫我向你老闆討債》](../../docs/story-telling-game/stories/002-debt-commission-draft-v0.1.md)，用來測版面與操作。另有 Phase 2 與 Phase 3 草莓牛奶技術片段，分別檢查 JSON 與「調查 → 裝傻 → 吐槽」短循環；兩者都不是作者核准的第一章台詞。正式文本會先共同編劇與試讀。

## 試玩與操作

啟動下方的 Web 伺服器後，開啟 <http://127.0.0.1:5193/> 試玩討債閱讀基線；<http://127.0.0.1:5193/?sample=phase2> 是草莓牛奶劇本測試，<http://127.0.0.1:5193/?sample=phase3> 是可玩的調查與吐槽技術短循環。三者各用自己的本機存檔。

| 操作 | 效果 |
| --- | --- |
| 點畫面任一處 | 打字中顯示整句；打完進下一句 |
| 長按畫面 | 隱藏全部 UI，再點一下恢復（恢復的那一下不推進） |
| 往上滑 | 開啟對話紀錄 |
| (≡) | 點一下開選單；可拖曳，放開吸附左右邊緣 |
| (S) | 點一下開啟手動存檔欄位；可拖曳 |
| 選單／標題讀檔 | 選擇指定手動欄位；讀檔頁也可選自動續讀檔 |
| 快捷列 | LOG、AUTO（自動播放）、SKIP（快轉到下一個選項）；素材檔案在 Phase 4 |
| Phase 3 調查 | 點場景中的線索；查過會打勾，全部查完才能繼續 |
| Phase 3 裝傻發言 | 前句／後句切換；有補充台詞時可按「聽仔細」；按「吐槽！」才進入 8 秒選詞 |
| Phase 3 吐槽選詞 | 選吐槽詞；素材會解鎖完美選項，逾時算冷場；選單、紀錄及存檔欄位會暫停倒數 |

懸浮按鈕閒置 3 秒變 40% 透明，被點到時恢復，拖曳範圍避開對話框，出現選項時也停在選項上方。Safe Area 只在 Android／iOS 原生匯出讀取；瀏覽器分頁本身已避開瀏海。讀到穩定劇本位置時寫入獨立的自動續讀檔；手動存檔有 3 頁、每頁 6 格，存入素材、背景、立繪與閱讀位置。新遊戲重設自動續讀進度，手動欄位保留。同一瀏覽器、同一網址重開後可按「繼續」或從指定欄位讀檔。選單的吐槽素材、人物檔案（Phase 4）與設定（Phase 5）先以停用狀態顯示。

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

## 檔案

| 檔案 | 用途 |
| --- | --- |
| `main.gd` | 六層直立外殼：背景 → 立繪 → 特效 → 對話框 → 懸浮按鈕 → 彈出視窗；手勢、AUTO／SKIP、選單、紀錄、存讀檔、QA |
| `scripts/floating_button.gd` | 圓形懸浮按鈕：點擊、長按、拖曳吸邊 |
| `scripts/placeholder_sprite.gd` | 角色立繪：銀時圖片的深色剪影與其他角色佔位圖 |
| `scripts/story_runner.gd` | 劇本節點執行、資料檢查、條件跳轉與閱讀位置 |
| `scripts/save_slots.gd` | 手動欄位命名、暫存寫入與備份還原 |
| `data/debt_story.json` | 已核准的討債試玩文本 |
| `data/phase2_story.json` | 草莓牛奶短篇技術測試，非正式第一章 |
| `data/phase3_story.json` | 調查、銀時發言與四種吐槽結果的技術短循環，非正式第一章 |
| `data/asset_catalog.json` | 背景、人物、吐槽素材及可替換圖片的統一設定 |
| `IMPLEMENTATION.md` | StoryRunner、catalog 與外殼的介面契約 |

Placeholder 角色的名字、顏色與預設站位集中在 `data/asset_catalog.json`；有圖片時填入對應 `path` 即可替換背景或立繪。新故事用 `bg`、`char`、`say`、`choice`、`flag`、`goto`、`item`。舊劇本的 `move`／`face`／`camera` 屬於先前的俯視舞台，VN 版面略過它們；`show`／`hide`／`expression` 仍對應立繪。新增章節的欄位與驗證規則見 [介面契約](IMPLEMENTATION.md)。

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

# 先匯出、啟動伺服器；需要已安裝 Playwright 及 Chromium 的 Node 環境。
node tools/browser_check.mjs --playwright /path/to/node_modules/@playwright/test
node tools/browser_check.mjs --smoke --playwright /path/to/node_modules/@playwright/test
node tools/browser_check.mjs --phase2 --playwright /path/to/node_modules/@playwright/test
node tools/browser_check.mjs --slots --playwright /path/to/node_modules/@playwright/test
node tools/browser_check.mjs --phase3 --playwright /path/to/node_modules/@playwright/test
```

`--url` 可指定試玩位址；`--chromium /path/to/chrome-headless-shell` 可指定 Chromium。瀏覽器檢查以真實 canvas 滑鼠與觸控操作（長按、拖曳、上滑用 CDP 觸控事件）；預設走討債兩條路線，`--phase2` 走劇本測試兩條路線，`--slots` 驗證觸控存讀檔與 18 格分頁，`--phase3` 走調查與吐槽並驗證限時選詞讀檔。網址帶 `?qa=1` 時才啟用唯讀的 `window.__debtQA`；一般試玩網址不啟用。

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

## 發現

- 版面：原版 28% 對話框在 390×844、360×800、320×568 都放得下三行字、兩個選項與懸浮按鈕。底部全寬、無邊框對話層的素材試版也通過主線、Phase 3 四選項與存讀檔 Web 觸控檢查；桌機維持 1080 寬的直式遊戲區。採用哪一版仍待真人手機試玩。
- 觸控：以放開手指判定點擊，長按、拖曳、恢復 UI 的那一下都不會誤推進劇情。
- 劇本資料：不改 GDScript 即可切換背景、立繪、站位、表情與素材條件選項；兩條技術片段路線在 Web 實跑並可續讀。
- 核心短循環：調查熱區取得素材後，銀時的兩句發言可切換與聽補充；進入吐槽選詞才開始倒數。完美／普通／冷場／隱藏結果、眼鏡、力量與檢查點可由劇本資料與 UI 測試驗證。
- 尚待真人：Android／iOS 實機手感、按鈕大小與透明度是否合適、字級是否夠大。

## 素材來源

- 店面、客廳與銀時：使用者加入 `assets/image/` 的三張 PNG；銀時透過 shader 顯示為深藍灰剪影，圖片原檔保留。廚房與其他角色、按鈕由 Godot 繪圖與漸層製作佔位圖。
- 音效與稀疏背景音：`tools/prepare_audio.py` 產生的原創 PCM WAV，可重建。
- 中文字型：WenQuanYi Zen Hei，隨附 `assets/fonts/COPYRIGHT.txt` 與 `LICENSE-GPL-2.txt`，包含字型嵌入例外及 M+ FONTS 授權文字。
