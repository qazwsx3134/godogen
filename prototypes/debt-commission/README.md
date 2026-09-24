# 萬事屋吐槽 ADV（暫名）— V1 原型

目前已完成與待辦清單見[進度紀錄](../../docs/story-telling-game/STATUS.md)。

Godot 4.7 手機直立視覺小說，依 [V1 Roadmap](../../docs/story-telling-game/ROADMAP.md) 與 [gintama0923](../../docs/gintama-like/new/gintama0923.md) 製作。狀態：**Phase 1、Phase 2 與 Phase 3 技術短循環已完成自動驗收**；第一章文本與真人手機試玩仍待完成。

要驗證的假設：直立 VN 版面（滿版背景、立繪、28% 對話框、可拖曳的懸浮按鈕）在手機上單手好讀、好操作；作者只改 JSON 就能換場景、角色、分支與素材條件。

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

[原版手機畫面](docs/preview-phone.png) · [Phase 2 手機畫面](docs/preview-phase2-phone.png) · [多欄位讀檔畫面](docs/preview-save-slots-phone.png) · [Phase 3 裝傻發言](docs/preview-phase3-boke-phone.png) · [驗證紀錄](docs/VERIFICATION.md)

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
| `scripts/placeholder_sprite.gd` | Placeholder 立繪：剪影＋角色名＋表情文字 |
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

## 發現

- 版面：28% 對話框在 390×844、360×800、320×568 都放得下三行字、兩個選項與懸浮按鈕；桌機維持 1080 寬的直式遊戲區。
- 觸控：以放開手指判定點擊，長按、拖曳、恢復 UI 的那一下都不會誤推進劇情。
- 劇本資料：不改 GDScript 即可切換背景、立繪、站位、表情與素材條件選項；兩條技術片段路線在 Web 實跑並可續讀。
- 核心短循環：調查熱區取得素材後，銀時的兩句發言可切換與聽補充；進入吐槽選詞才開始倒數。完美／普通／冷場／隱藏結果、眼鏡、力量與檢查點可由劇本資料與 UI 測試驗證。
- 尚待真人：Android／iOS 實機手感、按鈕大小與透明度是否合適、字級是否夠大。

## 素材來源

- 角色、背景、按鈕：Godot 繪圖與漸層製作的 placeholder。
- 音效與稀疏背景音：`tools/prepare_audio.py` 產生的原創 PCM WAV，可重建。
- 中文字型：WenQuanYi Zen Hei，隨附 `assets/fonts/COPYRIGHT.txt` 與 `LICENSE-GPL-2.txt`，包含字型嵌入例外及 M+ FONTS 授權文字。
