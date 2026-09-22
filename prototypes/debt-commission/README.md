# 萬事屋吐槽 ADV（暫名）— V1 原型

Godot 4.7 手機直立視覺小說，依 [V1 Roadmap](../../docs/story-telling-game/ROADMAP.md) 與 [gintama0923](../../docs/gintama-like/new/gintama0923.md) 製作。狀態：**Phase 1 完成（直立框架與懸浮按鈕）**，Phase 2 劇本引擎待開始。

要驗證的假設：逆轉裁判式的直立 VN 版面（滿版背景、立繪、28% 對話框、可拖曳的懸浮按鈕）在手機上單手好讀、好操作，能承載之後的吐槽系統。

目前的試玩文本仍是已核准的[第一場《請幫我向你老闆討債》](../../docs/story-telling-game/stories/002-debt-commission-draft-v0.1.md)，用來測版面與操作；V1 第一章「草莓牛奶失竊事件」在 Phase 5 放入。

## 試玩與操作

啟動下方的 Web 伺服器後，開啟 <http://127.0.0.1:5193/>。

| 操作 | 效果 |
| --- | --- |
| 點畫面任一處 | 打字中顯示整句；打完進下一句 |
| 長按畫面 | 隱藏全部 UI，再點一下恢復（恢復的那一下不推進） |
| 往上滑 | 開啟對話紀錄 |
| (≡) | 點一下開選單；可拖曳，放開吸附左右邊緣 |
| (S) | 長按快速存檔並顯示「已存檔」；點一下提示長按；可拖曳 |
| 快捷列 | LOG、AUTO（自動播放）、SKIP（快轉到下一個選項）；素材在 Phase 3 |

懸浮按鈕閒置 3 秒變 40% 透明，被點到時恢復，拖曳範圍避開對話框，出現選項時也停在選項上方。Safe Area 只在 Android／iOS 原生匯出讀取；瀏覽器分頁本身已避開瀏海。每句台詞自動存檔，同一瀏覽器、同一網址重開後按「繼續」。選單的吐槽素材、人物檔案（Phase 3）與設定（Phase 5）先以停用狀態顯示。

[手機畫面預覽](docs/preview-phone.png) · [驗證紀錄](docs/VERIFICATION.md)

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
| `data/debt_story.json` | 目前的試玩劇本 |
| `IMPLEMENTATION.md` | StoryRunner 與外殼的介面契約 |

Placeholder 角色的名字、顏色與站位集中在 `main.gd` 的 `ACTORS` 表。舊劇本的 `move`／`face`／`camera` 屬於先前的俯視舞台，VN 版面略過它們；`show`／`hide`／`expression` 對應立繪。

## 驗證

```bash
# 在此 prototype 目錄執行。XDG_DATA_HOME 讓測試資料留在專案快取。
XDG_DATA_HOME="$PWD/.cache/test-data" godot --headless --path . --script res://tests/test_story.gd
XDG_DATA_HOME="$PWD/.cache/test-data" godot --headless --path . --script res://tests/test_vn_shell.gd

# 先匯出、啟動伺服器；需要已安裝 Playwright 及 Chromium 的 Node 環境。
node tools/browser_check.mjs --playwright /path/to/node_modules/@playwright/test
node tools/browser_check.mjs --smoke --playwright /path/to/node_modules/@playwright/test
```

`--url` 可指定試玩位址；`--chromium /path/to/chrome-headless-shell` 可指定 Chromium。瀏覽器檢查以真實 canvas 滑鼠與觸控操作（長按、拖曳、上滑用 CDP 觸控事件），走完兩條路線並檢查版面、手勢、懸浮按鈕、選單、AUTO／SKIP、續讀與重玩。網址帶 `?qa=1` 時才啟用唯讀的 `window.__debtQA`；一般試玩網址不啟用。

## Godot MCP

`addons/godot_mcp_toolkit/` 已啟用，編輯器開著時 AI 可以讀場景、實跑遊戲、截圖與讀 console。WSL 裡的 Claude Code 連 Windows 編輯器的設定方式見 [Roadmap 的開發工具段落](../../docs/story-telling-game/ROADMAP.md#開發工具godot-mcp-toolkit)。Web 匯出已排除此 addon。

## 發現

- 版面：28% 對話框在 390×844、360×800、320×568 都放得下三行字、兩個選項與懸浮按鈕；桌機維持 1080 寬的直式遊戲區。
- 觸控：以放開手指判定點擊，長按、拖曳、恢復 UI 的那一下都不會誤推進劇情。
- 尚待真人：Android／iOS 實機手感、按鈕大小與透明度是否合適、字級是否夠大。

## 素材來源

- 角色、背景、按鈕：Godot 繪圖與漸層製作的 placeholder。
- 音效與稀疏背景音：`tools/prepare_audio.py` 產生的原創 PCM WAV，可重建。
- 中文字型：WenQuanYi Zen Hei，隨附 `assets/fonts/COPYRIGHT.txt` 與 `LICENSE-GPL-2.txt`，包含字型嵌入例外及 M+ FONTS 授權文字。
