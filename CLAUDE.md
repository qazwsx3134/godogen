@AGENTS.md

<!-- updated: 2026-11-11 -->

## Claude Code：用 Herdr 開子 session

- 先過 `AGENTS.md` 的「委派門檻」，不符合就留在自己的 session 做；此限制同樣適用 Herdr 與 Agent tool。使用者當次明確要求委派時照做。
- 要開時，本專案授權用 `herdr` skill 在旁邊開一個 pane，跑獨立的 Claude Code session。模型照使用者當次指定；沒指定就不帶 `--model`（沿用預設）。effort 用 **max**（長時間實作、要讀大量程式碼）或 **xhigh**（範圍明確的中型工作）。主對話負責規劃、分派、整合與驗收。
- 啟動（先確認 `HERDR_ENV=1`；細節與等待、讀輸出的方式見 herdr skill）：

  ```bash
  herdr pane split --current --direction right --cwd "$PWD" --no-focus
  herdr agent start <名稱> --kind claude --pane <新 pane id> -- --effort max --permission-mode auto
  herdr agent prompt <名稱> "<派工內容>"
  ```

  `--permission-mode` 讓子 session 不停在權限確認（狀態 `blocked`）。
- 主 session 在 auto mode 時，`agent start … --permission-mode auto` 會被分類器判為 Create Unsafe Agents 而拒絕；需要使用者先用 `/permissions` 允許 `Bash(herdr:*)`。
- 派工內容很長時，寫成檔案，`agent prompt` 只叫它讀那個檔。
- 完成訊號是派工單指定的報告檔：在背景輪詢檔案出現。`herdr agent wait` 與 agent 狀態會提早回來，不能當完成訊號。回報很長時，請它把內容寫進報告檔、只回傳路徑。
- 不在 Herdr 裡（`HERDR_ENV` 不是 1）時改用 Agent tool。
- 所有 Herdr agent 共用同一個工作樹：會改到同一個檔案的工作（例如 `prototypes/debt-commission/main.gd`）依序派，不要同時開。

## 踩過的坑

所有原型踩過的坑統一列在 [`prototypes/LESSONS.md`](prototypes/LESSONS.md)：開工前或遇到不合理的失敗時先查，新的坑也寫在那份。2026-10-02 至 10-27 原本列在本檔的 14 條都已收進去；`LESSONS.md` 裡標「CLAUDE.md ＋日期」的來源，原文在本檔 2026-11-11 之前的 git 歷史。

做 Godot 原型到 itch.io 網頁版的完整做法與坑，見 skill `godot-prototype-to-itch`（原始檔在 `prototypes/godot-kit/skills/`，用 `prototypes/godot-kit/install_skills.sh` 複製安裝，不用 symlink）。
