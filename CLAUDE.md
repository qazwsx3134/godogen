@AGENTS.md

<!-- updated: 2026-09-29 -->

## Claude Code 子 agent：用 Herdr 開 Sonnet

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
