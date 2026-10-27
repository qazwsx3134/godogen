@AGENTS.md

KISS 與分層測試驗收（規劃不測／L1 單元／L2 單元＋簡易回歸／L3 手動驗收後完整測試）見 `AGENTS.md`「KISS 與分層測試驗收」，已由上一行載入。

<!-- updated: 2026-10-03 -->

## Claude Code 子 agent：用 Herdr 開 Sonnet

- 開啟前先遵守 `AGENTS.md` 的「子代理的成本門檻」：估算自行完成與委派的 API 總成本（含子代理上下文、輸入／輸出與主 session 交接、審查、整合）。若自行完成的費用 **小於委派總成本的 1.2 倍**，就留在自己的 session 做；無法合理估算時也預設自行完成。開子 agent 的目的是節省成本，此限制同樣適用 Herdr 與 Agent tool；使用者當次明確要求委派時除外。
- 要開子 agent 時，本專案授權用 `herdr` skill 在旁邊開一個 pane，跑獨立的 Claude Code session：模型 **Sonnet**，effort **max**（長時間實作、要讀大量程式碼）或 **xhigh**（範圍明確的中型工作）。主對話負責規劃、分派、整合與驗收。使用者當次指定其他模型或做法時以使用者為準。
- 啟動（先確認 `HERDR_ENV=1`；細節與等待、讀輸出的方式見 herdr skill）：

  ```bash
  herdr pane split --current --direction right --cwd "$PWD" --no-focus
  herdr agent start <名稱> --kind claude --pane <新 pane id> -- --model sonnet --effort max --permission-mode auto
  herdr agent prompt <名稱> "<派工內容>" --wait --timeout <毫秒>
  ```

  `--permission-mode` 讓子 session 不停在權限確認（狀態 `blocked`）。2026-09-29 實測：子 pane 顯示「Sonnet 5.5 with max effort」、auto mode。
- 主 session 在 auto mode 時，`agent start … --permission-mode auto` 會被分類器判為 Create Unsafe Agents 而拒絕；需要使用者先用 `/permissions` 允許 `Bash(herdr:*)`。
- 派工內容很長時，寫成檔案，`agent prompt` 只叫它讀那個檔。長任務不要用 `--wait` 卡住主 session，改在背景跑 `herdr agent wait <名稱>`。
- 不在 Herdr 裡（`HERDR_ENV` 不是 1）時改用 Agent tool，`model: sonnet`。
- 所有 Herdr agent 共用同一個工作樹：會改到同一個檔案的工作（例如 `prototypes/debt-commission/main.gd`）依序派，不要同時開。
- 回報太長、`agent read` 讀不完整時，請它把回報寫成檔案、只回傳路徑。

## 教訓紀錄（append-only；格式見 ~/claude-institution/rules/maintenance-protocol.md）

**所有原型踩過的坑統一列在 [`prototypes/LESSONS.md`](prototypes/LESSONS.md)**：開工前或遇到不合理的失敗時先查那份。新的坑從 2026-10-27 起寫在那份檔案，不再追加到下方；下方舊條目已全部收進去，保留原文。

做 Godot 原型到 itch.io 網頁版的完整做法與坑，見 skill `godot-prototype-to-itch`（原始檔在 `prototypes/godot-kit/skills/`，用 `prototypes/godot-kit/install_skills.sh` 複製安裝，不用 symlink）。

- 2026-10-02 | 選卡鎖與震動間隔 | 用 `Time.get_ticks_msec()`（牆上時鐘）做玩法邏輯；測試用 `--fixed-fps 60`，遊戲時間比牆上時間快很多，鎖把機器人的點擊全吞掉，十幾個不相干的測試連環失敗 | 用 `create_timer(秒, true, false, true)`（遊戲時間）或可注入的時鐘 | 影響玩法的計時一律用遊戲時間
- 2026-10-02 | 匯出版讀 `res://assets/x.ogg` | `FileAccess.file_exists` 在匯出版是 false（原檔不在 pck 裡） | `ResourceLoader.exists` 再 `load` | 資源存不存在一律問 ResourceLoader
- 2026-10-02 | 判斷子 agent 做完了沒 | 用 `herdr agent wait` 與 agent 狀態當完成訊號；狀態會閃成 idle、wait 提早回來 | 派工單指定報告檔，背景輪詢檔案出現 | 完成訊號＝報告檔，不是狀態
- 2026-10-02 | 刪暫存資料夾、停背景程序 | `rm -rf $VAR` 被 auto mode 擋；`pkill -f '字串'` 比對到自己的 shell，把自己殺掉（exit 144） | 字面路徑或新的資料夾名稱；記下 PID 再 `kill <pid>` | 刪除與殺程序都不要用會吃到變數或自己字串的寫法
- 2026-10-03 | 縮網頁版大小 | 以為大頭是引擎 | 先把 pck 按副檔名拆開：字型 8.9 MB、背景 9.8 MB 才是（21.6 → 6.8 MB），`.wasm` 39.5 MB 改不了 | 先量再縮
- 2026-10-03 | 偵測手機震動 | 只查 `typeof navigator.vibrate === 'function'`，用真的瀏覽器量才發現桌面 Chromium 也是 function | 再加 `navigator.maxTouchPoints > 0` 或 `(pointer: coarse)`，用 playwright 驗證 | 能力偵測要連裝置條件一起查，並用真瀏覽器驗證
- 2026-10-03 | 加升級特效後 balance 基準線整個平移 | 新特效的 `CPUParticles2D` 只要被建立（連 `.new()` 都算）就吃掉全域亂數（headless 小腳本實測：`seed(1)` 後第一個 `randf()` 從 0.4218 變 0.1591）；主角 scene 多 3 個粒子節點，每個 seed 的敵人繞路都變了，我先當成特效改了遊戲邏輯，二分三輪（擠壓、拿掉舊光環、加空節點全都沒事）才找到；另外 `balance_run.sh` 的 `RUN` 行有 `wall=`（牆上時間），逐位元組比對要先剝掉 | 先用幾行 headless 腳本量「建這個節點會不會動到 `randf`」；比對用 `sed -E 's/ wall=[0-9.]+//'`；基準線在加完粒子節點之後才重拍 | 加粒子節點會平移全域亂數：要 byte-identical 的 gate，基準線得在加完之後拍
- 2026-10-04 | 搬專案資料夾到 repo 外面 | `mv` 一直 `Permission denied`，`lsof` 與 /proc 都看不到誰在用——鎖在 Windows 那邊：使用者的檔案總管視窗開在子資料夾 `publishing\itch\screenshots`（Windows 不讓有東西開著的資料夾被改名） | 逐層把子資料夾改名再改回來找出被鎖的是哪個；`powershell.exe -Command "(New-Object -ComObject Shell.Application).Windows() | % LocationURL"` 列出開著的檔案總管視窗；沒被鎖的先搬走，被鎖的留著，寫一支一行指令的腳本（`.claude/tasks/sugarcane-art/finish-publishing-move.sh`）等使用者關窗 | 搬目錄前先查 Windows 的檔案總管視窗與對話框；不要替使用者關他的視窗
- 2026-10-15 | 降 survivor-series 的 draw call | 以為敵人圖散在多張貼圖才斷批次，做了圖集只省一點；`Performance.TIME_PROCESS／TIME_PHYSICS_PROCESS` 也亂跳（平均 6 ms 的跑次 physics 最大 4 秒） | 一層層 `visible=false` 量 draw call、再列出執行中實際可見的節點類型：每個 Polygon2D／Line2D／`draw_circle` 都單獨一次 draw call（胖子臭氣 4 個多邊形 ×40 隻＝160 次）；改成共用貼圖的 Sprite2D、同類放同一個 z 層後 670 → 280 | 量幀時間用牆上時間；大量重複的物件不要用多邊形畫，同類圖用同一張貼圖並放同一 z 層
- 2026-10-14 | 在 macOS 上跑 erwin-run 的測試、截圖、匯出 | 照 PROGRESS 的 WSL 指令跑：`godot` 不在 PATH、沒有 `xvfb-run`、`run_tests.sh` 沒有執行權限（permission denied） | `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot bash <腳本>`；截圖直接開視窗跑 `shots.gd`，加 `--resolution 1688x780` 看手機比例 | 換機器先確認 Godot 路徑與腳本權限，不要照抄別台的指令
- 2026-10-14 | 外部改 erwin-run 的 `.tscn` 時，使用者的 Godot 編輯器正開著同一個專案 | 沒先查就改，編輯器裡存檔會把修改蓋回去 | 改 scene 前 `ps aux | grep -i godot` 看編輯器有沒有開；有就提醒使用者重新載入、不要存舊版 | 編輯器開著時改 scene 檔要先講
- 2026-10-14 | erwin-run 的 `.gitignore` 早就寫了 `.godot/`、`build/` | 規則加在檔案提交之後，所以 257 個檔案一直被追蹤、每次都顯示已修改 | `git ls-files -ci --exclude-standard` 找出來，`git rm -r --cached` 移出版控（本機檔案保留） | 新增忽略規則後，查一次有沒有已經被追蹤的檔案
- 2026-10-14 | 推含大量圖檔與音檔的 commit 到 GitHub | `git push` 回 HTTP 400、遠端意外掛斷 | 只對那一次用 `git -c http.postBuffer=524288000 push` | 推大檔失敗先加大 postBuffer，不要改全域設定
- 2026-10-27 | 在 macOS 上用 `XDG_DATA_HOME=/tmp/...` 隔離 Godot 試跑 | 以為存檔會寫到 /tmp，結果 macOS 的 user:// 一律在 `~/Library/Application Support/Godot/app_userdata/<專案>`，正常啟動讀到作者的真實存檔，把 v1 轉成 v2 覆蓋（原檔無備份） | 試跑前先 `ls` 那個資料夾並 `cp` 存檔到 ~/.claude/backups；遊戲提供 `-- --save=<名稱>` 之類的參數改存檔路徑 | macOS 上 XDG 不隔離 user://，碰真實存檔前先備份
