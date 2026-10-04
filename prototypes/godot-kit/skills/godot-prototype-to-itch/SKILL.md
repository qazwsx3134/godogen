---
name: godot-prototype-to-itch
description: 把 Godot 4.7 的 2D 手機直式原型一路做到 itch.io 網頁版的實戰手冊（來自《安》sugarcane-tanks）：AI 生圖素材接進遊戲、headless 測試與機器人平衡量測、打擊感音效與手機震動、網頁匯出瘦身與用瀏覽器驗證、用 Herdr 多 agent 分工。開新的 Godot 原型、準備上架 itch.io、要縮小網頁版、或「編輯器裡正常但匯出版／手機有問題」時先讀。
---

# Godot 原型 → itch.io 網頁版（實戰手冊）

來源：sugarcane-tanks（原在 `prototypes/`，2026-10-04 起是 `/mnt/d/repo/godot/sugarcane-tanks`；Archero 式房間射擊，15 間房，2026-09 至 10 月）。這裡只收**未來還會再遇到**的做法與坑，每條都是實際跑過、量過的；沒驗證過的明講。共用程式放在 `prototypes/godot-kit/`。

## 何時用

- 新開 Godot 原型，目標是手機／網頁：先看「一條龍流程」與「最常踩的坑」。
- 要上架 itch.io：看 `references/web-release.md`，再用 `itch-publish`（butler 的上傳部分）。
- 素材由使用者自己用生圖工具產生：看 `references/art-pipeline.md`。
- 派 Herdr agent 做事：看 `references/agent-workflow.md`。

**不要用在**：Steam 上架（`steam-publish`）、純規劃階段（走 repo 的 `/brainstorm` 流程）。

## 一條龍流程

```
想法 → 素材 → 場景＋程式 → 測試＋量測 → 打擊感 → 瘦身 → 網頁匯出 → 瀏覽器驗證 → itch.io
 │       │        │            │           │       │        │          │            │
 │   PROMPTS.md  .tscn 為主   test_kit    juice.gd  字型子集  Web 範本     playwright   butler push
 │   process_art  腳本管行為   balance_run  sfx/haptics 有損貼圖  不開執行緒    SwiftShader  （使用者登入）
 └── 每一步都先寫「驗收條件」，做完用證據關掉（測試輸出、截圖、量測表）
```

## 核心做法

1. **素材**：生圖一律用純洋紅 `#FF00FF` 背景（不要「透明」、不要綠色）；角色朝右、不畫地面影子；場地背景只畫空的地板，障礙物另外做。`tools/process_art.gd` 去背、切格、縮到遊戲內尺寸，執行時不縮放。→ `references/art-pipeline.md`
2. **場景與程式**：畫面是 `.tscn`，行為在腳本；翻面用 `%Body.scale.x`，擠壓與震動只動 `%Sprite` 與相機 offset，**回饋不碰模擬**。大改 scene 用一次性 headless 腳本存檔（`PackedScene.pack()`），不手寫 `.tscn`，也不重跑會覆蓋人工修改的產生器。
3. **測試**：沿用 `godot-kit` 的 `test_kit.gd`，四組套件（rules／scenes／play／persistence）加嚴格 log 迴圈；**每個新測試都故意弄壞一次**確認抓得到。`--fixed-fps` 下遊戲時間比牆上時間快很多，別用牆上時鐘做會影響玩法的邏輯。→ `references/testing-and-balance.md`
4. **平衡**：寫一支決定性的機器人量測工具（`tools/balance_run.sh god|real`），用「每間房結算等級」的目標表調經驗與難度；它同時是純重構的回歸測試（前後輸出必須逐字相同）。
5. **打擊感**：所有回饋走一個中樞（`game/juice.gd`）：三級（small／medium／large）、trauma 平方震屏加疊加上限、單一 `TimeControl` 管 hit stop；每個事件呼叫 `sfx.play(&"事件名")`，使用者之後丟 `事件名.ogg` 就換聲音。長音效要截斷並限制同時一個。→ `references/feel-audio-haptics.md`
6. **瘦身**（網頁版 pck 21.6 MB → 6.8 MB；之後加了開始畫面與 boot splash 是 7.65 MB）：字型裁成靜態 Bold 子集、大背景改有損 WebP（`.import` 的 `compress/mode=1`、品質 0.9）、WAV 轉 Ogg。`.wasm` 約 39.5 MB 是引擎本體，改不了。→ `references/web-release.md`
7. **匯出與驗證**：Web 預設關掉 Thread Support；用 headless Chromium（SwiftShader）真的把匯出版開起來（桌面與手機兩種裝置，點開始鈕走完標題→載入→遊戲），檢查 console 錯誤、截圖、`navigator` 能力。**編輯器裡過的測試不等於匯出版沒問題。** 現成工具都在 `godogen/prototypes/godot-kit/tools/web/`：`build_web.sh <專案>`（匯入→匯出→補 IDBFS 補丁→印 pck 組成→出 zip，約 15 秒，範本第一次自動抓）、`web_probe.mjs`、`pck_size.py`、`fetch_web_templates.py`、`patch_idbfs.py`，每支有 `--self-test`；專案要有 `export_presets.cfg` 的 `Web` preset（抄 sugarcane-tanks 的）。其他共用工具：`tools/run_tests.sh`（嚴格 log 檢查的測試執行）、`tools/capture.sh`（錄影）、`tools/subset_font.py`（字型子集）。用法見 godot-kit README 的「tools/」一節。
8. **多 agent**：主對話寫派工單、驗收；Herdr Sonnet 實作。一份檔案同一時間只有一個寫手；完成訊號是**報告檔出現**，不是 agent 的狀態。→ `references/agent-workflow.md`

## 最常踩的坑（一行一條）

- **匯出後讀不到檔案**：`FileAccess.file_exists("res://x.ogg")` 在匯出版是 false（只剩匯入後的版本）。用 `ResourceLoader.exists` 再 `load`。
- **桌面瀏覽器也有 `navigator.vibrate`**：只用 `typeof` 偵測，電腦上會誤判成可震動。要再加 `navigator.maxTouchPoints > 0` 或 `(pointer: coarse)`。iPhone Safari 沒有這個 API。
- **`--write-movie` 無視 `--resolution`**，畫面大小永遠是專案視窗設定；想看寬螢幕要自己用 SubViewport 或改視窗 override。
- **字型有保留名稱**時改過的版本要檢查名稱表（Noto Sans TC 的保留名稱是 `Source`，字型本身沒用到，可以裁切）。裁完要跑「遊戲寫的每個字都有字形」的測試。
- **`.tres` 在 Windows 換行下存的多行字串帶 `\r`**，`Label` 會多一個空行把文字擠出框。顯示前濾掉 `\r`。
- **連續升級面板會出現在手指剛點過的位置**：加短暫的選卡鎖（0.35 秒，用遊戲時間 timer）。
- **工作樹的 `.sh` 可能是 CRLF**（`bash\r: No such file`）。直接用迴圈跑測試，或用 LF 寫新腳本。
- **手機上用區網 `http://192.168.x.x` 測試，遊戲根本不會啟動**：引擎要求安全環境（HTTPS 或 localhost）。上傳 itch.io 的 Draft 頁面用手機開，或 `adb reverse` 後開 `http://localhost:8000`。
- **Godot 遇到 SCRIPT ERROR 仍可能 exit 0**：測試一定要 grep log。
- **匯出模式要維持「Export all resources」**：用名字在執行時找的檔案（丟 `事件名.ogg` 換聲音、`title_bg.png`）沒有 scene 引用，改成只匯出 scene 與相依資源它們就默默消失。boot splash 的匯入版是多餘的，用 `exclude_filter` 排除（原檔照樣打包）。→ `references/web-release.md`
- **主場景的 `_ready()` 裡換場景會留下舊場景**（要 `call_deferred`），而且 headless 測試看不到；載入畫面只在狀態是 LOADED 時才換場景。→ `references/testing-and-balance.md`
- **GitHub 下載很慢時**（這台 WSL 約 36 KB/s），Godot 範本是 zip，用 HTTP Range 只抓 `web_nothreads_release.zip`（13.6 MB，不是 1.28 GB）。kit 的 `tools/web/fetch_web_templates.py` 已有現成工具（debt-commission 那份是舊版）。
- **Windows 上的 Godot 編輯器用自己的範本資料夾**（`%APPDATA%\Godot\export_templates\4.7.stable`），在 WSL 裝範本對它沒用。

## References

- `references/web-release.md`：匯出設定、範本、大小表、瀏覽器驗證、itch.io 頁面設定
- `references/agent-workflow.md`：派工單範本、檔案分工、等待與驗收、Herdr 指令、auto mode 會擋什麼
- `references/testing-and-balance.md`：測試迴圈、時間域陷阱、變異檢查、機器人量測
- `references/art-pipeline.md`：洋紅去背、切格、動畫條、prompt 規則、匯入設定
- `references/feel-audio-haptics.md`：回饋中樞、事件→聲音、長音效、BGM、手機震動規則

## 相關

- `itch-publish`：`butler push` 與頁面設定（建頁面、登入只有使用者能做）
- `godot-export`：一般的匯出預設與 CLI
- `game-feel`：回饋技巧的通用說明（本手冊是它的一個完整實作）
- 共用模組：`prototypes/godot-kit/README.md`（`synth.gd`、`atomic_file.gd`、`test_kit.gd`）與其「下一批值得抽出來的」一節（字型子集、網頁匯出工具組、場景產生器函式、手機震動、音效播放、虛擬搖桿、素材處理）
