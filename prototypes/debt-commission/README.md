# 請幫我向你老闆討債

Godot 4.7 直式互動故事原型，演出[已確認的完整第一場](../../docs/story-telling-game/stories/002-debt-commission-draft-v0.1.md)。新八接下登勢的委託，追討的對象正是銀時；玩家選擇問話方式，銀時會在後段記住並反用這個選擇。

## 試玩與操作

啟動下方的 Web 伺服器後，開啟 <http://127.0.0.1:5193/>。

- 按「開始故事」。對話第一次點擊補完文字，下一次前進。
- 選項等待玩家決定；兩條路徑各有回應與後段回扣。
- 「回顧」查看已讀台詞；可關閉音效、重新開始。
- 閱讀點自動存檔。使用同一瀏覽器、同一網址重開後，按「繼續閱讀」。

畫面包含簡化向量角色、說話立繪、表情、登場、繞桌走位、鏡頭及輕音效。這一場以取得「明日洗碗抵部分房租」的承諾收束。

[手機畫面預覽](docs/preview-phone.png) · [實際驗證紀錄](docs/VERIFICATION.md) · [後續 Roadmap](../../docs/story-telling-game/ROADMAP.md)

## 開發與 Web 匯出

此目錄是獨立的 Godot 專案，可用 **Godot 4.7 stable** 開啟 `project.godot`，按 F5 試演。

```bash
cd prototypes/debt-commission
# 已安裝相符版本的 Godot Web export templates 可略過下一行。
python3 tools/fetch_web_templates.py
bash tools/build_web.sh
bash tools/serve_web.sh
```

`GODOT_BIN` 可指定 Godot 執行檔位置；`serve_web.sh` 可接受埠號，例如 `bash tools/serve_web.sh 5194`。伺服器綁定本機 `127.0.0.1`。

下載工具從 Godot 官方發布的範本包擷取兩個單執行緒 Web 範本，逐檔檢查 ZIP CRC，放在本目錄 `.cache/`。匯出工具優先使用這份快取；沒有快取時使用 Godot 已安裝的範本。產物為 `build/web/index.html` 及同目錄相關檔案，需一同放在 HTTP 伺服器上。

引擎與範本鎖定 4.7 stable；Compatibility renderer、單執行緒 Web 匯出。技術依據：[Godot Web 匯出文件](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)。

## 劇本與演出

| 檔案 | 用途 |
| --- | --- |
| `data/debt_story.json` | 正式台詞、選項、旗標與演出指令 |
| `scripts/story_runner.gd` | 節點執行、資料檢查、條件跳轉與閱讀位置 |
| `scripts/story_stage.gd` | 萬事屋舞台、角色站位、走位與鏡頭 |
| `scripts/actor_doll.gd` | SD 角色和對話立繪、表情與動態 |
| `main.gd` | 直式介面、文字、輸入、音效、回顧與存讀檔 |
| `IMPLEMENTATION.md` | 本次實作範圍與介面契約 |

改台詞或選項請修改 JSON，保留節點 ID 和既有旗標含義；改變結構或閱讀步序時更新故事 `version`，使舊進度不會跳到錯誤台詞。作者原稿仍保留在 `docs/story-telling-game/stories/`，修改內容時同步更新原稿。

## 驗證

```bash
# 在此 prototype 目錄執行。XDG_DATA_HOME 讓測試資料留在專案快取。
XDG_DATA_HOME="$PWD/.cache/test-data" godot --headless --path . --script res://tests/test_story.gd
XDG_DATA_HOME="$PWD/.cache/test-data" godot --headless --path . --script res://tests/test_stage.gd

# 先匯出、啟動伺服器；需要已安裝 Playwright 及 Chromium 的 Node 環境。
node tools/browser_check.mjs --playwright /path/to/node_modules/@playwright/test
# 只重跑直接點擊對話、音效、回顧、重玩與正常網址的觸控檢查：
node tools/browser_check.mjs --smoke --playwright /path/to/node_modules/@playwright/test
```

`--url` 可指定試玩位址；`--chromium /path/to/chrome-headless-shell` 可指定已安裝的 Chromium 執行檔。省略時使用 Playwright 預設版本。

瀏覽器驗證透過真實 canvas 點擊／觸控操作，涵蓋兩條完整路線、逐字顯示、選項等待、回顧、重新整理續讀、人物位置還原與重新開始；包含桌機、390×844 手機觸控模擬和 320×568 縮放檢查。以上已通過；[驗證紀錄](docs/VERIFICATION.md) 附具體範圍與報告。重跑會產生 `test-results/browser-report.json`、`smoke-report.json` 和截圖。

網址帶 `?qa=1` 時才啟用唯讀 `window.__debtQA`，提供狀態與控制項座標供上述驗證使用。一般試玩網址不啟用此介面。

手機瀏覽器的實機閱讀、聲音感受與喜劇節奏仍須由玩家試玩確認；桌機的觸控模擬不代表 Android／iOS 實機已通過。

## 素材來源

- 角色、室內、圖示：本原型以 Godot 繪圖與 SVG 製作的簡化素材。
- 音效與稀疏背景音：`tools/prepare_audio.py` 產生的原創 PCM WAV，可重建。
- 中文字型：WenQuanYi Zen Hei，隨附 `assets/fonts/COPYRIGHT.txt` 與 `LICENSE-GPL-2.txt`，包含字型嵌入例外及 M+ FONTS 授權文字。
