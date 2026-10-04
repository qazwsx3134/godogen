# 主對話 + Herdr 多 agent 的分工做法

主對話是**指揮官**：規劃、寫派工單、驗收、跟使用者說話。Herdr 裡的 Sonnet（effort max）是**實作者**。專案 `CLAUDE.md` 已授權這樣用；使用者的全域規則是「單檔小修、讀 <300 行自己做，大量、可平行、會洗掉 context 的才派」。

## 派工單（寫成檔案，`agent prompt` 只叫它去讀）

放在被 gitignore 的 `.claude/tasks/<主題>/<名稱>-brief.md`，報告寫到同資料夾的 `<名稱>-report.md`。固定結構：

1. 專案路徑、開工前要讀的檔（context 是剛清空的）
2. **目標與動機**（原話引用使用者的要求；為什麼做）
3. 規格（可驗收的具體條件、數值、節點名稱）
4. **檔案分工**：誰負責哪些檔、哪些是共用檔、哪些不能動
5. 限制（不 commit、不跑會覆蓋人工修改的產生器、刪檔用字面路徑、用哪個測試迴圈）
6. **驗收條件**（測試全過、截圖放哪、要故意弄壞一次的檢查、量測要附數字）
7. 回報格式（結論 ≤10 行、證據用 file:line、列出沒做到或沒驗證的、最後只回一行 `DONE` 或 `BLOCKED＋原因`）

加一句「做不到就直說，不要交看起來完成的半成品」。

## 同時有多個 agent 時

- **一個檔案同一時間只有一個寫手。** 做不到時用「階段」：階段一只新增檔案（審查、量測），階段二才改既有檔案，由我叫它開始。
- **共用檔**（`main.gd`、`tests/*.gd`、README）：只用小範圍 Edit，**每次改之前重新讀那一段**，不要整檔覆寫。
- 要試一個會碰共用檔的修改、而別人正在改時：`rsync -a` 一份到 scratchpad，用「精確字串替換」的 python 腳本（找不到就報錯，不會蓋掉別人的改動）先在複本上測，通過再對真的工作樹跑同一支腳本。
- 同時在跑的 agent 不要超過 3 個。
- 換新工作前先對 agent 送 `/clear`（context 超過約 80% 一定要清）；`/clear` 之後它對程式碼的記憶沒了，所以派工單要寫得完整。

## 等待與驗收

- **完成訊號是報告檔出現＋最後一行回覆**，不要信 agent 狀態：`working`／`idle` 會閃（思考間、等顧問、剛收到訊息），`herdr agent wait` 常常提早回來。背景輪詢檔案：`until [ -f <report> ]; do sleep 15; done`。
- **不要只信報告。** 驗收時自己做：在複本上重跑四組測試、自己重跑一次量測工具對數字、看它交的截圖。agent 的報告通常誠實（會寫沒驗證的），但「測試通過」和「真的對」之間常有縫。
- 用量限制（usage limit）到了，所有 agent 一起停；時間到會自動接續。派工單要能被中斷後重讀（階段、檔案分工、報告位置都寫在檔案裡）。agent 被中斷時會留交接筆記，下一棒直接讀。
- Claude Code 的評分問卷會卡在 agent 的畫面上：`herdr agent send-keys <名稱> 0`（略過），再送 `/clear`。

## Herdr 指令（已驗證）

```bash
herdr pane split --current --direction down --cwd "$PWD" --no-focus      # 取得新 pane id（JSON）
herdr agent start <名稱> --kind claude --pane <pane id> -- --model sonnet --effort max --permission-mode auto
herdr agent prompt <名稱> "請完整讀 <派工單路徑> 並照做…最後只回一行：DONE 或 BLOCKED＋原因"
herdr agent send-keys <名稱> 0         # 或 enter、esc
herdr agent read <名稱> --source visible --lines 12      # 工作中只能讀 visible
herdr agent list                                          # 看每個 agent 的狀態
```

- `agent start` 要**單獨一個指令**，跟在 `pane split` 後面同一行會得到 `agent_pane_busy`（新 shell 還沒好）。
- 權限：`Bash(herdr agent start:*)` 要先用 `/permissions` 加；一次性的核准只對那一條指令有效。
- `--permission-mode auto` 讓子 session 不停在確認。

## auto mode 的分類器會擋什麼

- `rm -rf $VAR/…`（變數可能是空字串）：用字面路徑，或建新資料夾而不是刪舊的。子 agent 也會被擋。
- `pkill -f '<字串>'` 會比對到自己的 shell 命令列、把自己殺掉（exit 144）：記下 PID 再 `kill <pid>`。
- 探測 `sudo`、掃整個檔案系統、讀憑證：會被當成「憑證探索」。需要的資訊用不需特權的方式拿。
- 建立 agent 的指令第一次會被判「不安全」：需要使用者預先允許規則。

## 教訓：派工單的壞味道

- 把「使用者之後會改」的東西寫死在 agent 的記憶裡 → 全寫進檔案（派工單、README、memory）。
- 派給 agent 的專案有 CRLF 的工作樹：提醒它 CRLF 的 `.sh` 不能直接跑（`bash\r: No such file`），改用 kit 的 `tools/run_tests.sh <專案>`（LF），或給它能直接貼的測試迴圈。
- 要求「故意弄壞一次」要具體（弄壞哪一行、預期哪一條測試失敗、怎麼還原），否則它會做成形式。
- 階段二的規則（行為不能變、用決定性工具對輸出）要在階段一的派工單就寫出來，它才會在審查時挑得動的項目。
