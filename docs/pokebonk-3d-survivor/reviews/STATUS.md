# 互相 review 進度（2026-10-16）

使用者在 Codex pane 指示「先把目前的研究跟還沒 review 完的紀錄起來／告一段落」，所以停在第 2 輪。

| 輪次 | 內容 | 狀態 |
|---|---|---|
| 1 | Claude 實玩＋Codex 拆 bundle → README、live-play-notes、codex-bundle-analysis、data/ | 完成（data 表經 verifier 抽查 PASS） |
| 2a | Claude 審 Codex → `claude-review-of-codex.md` | 完成 |
| 2b | Codex 審 Claude → `codex-review-of-claude.md` | **checkpoint**：事實錯誤與缺口已列，未整理成最終版，沒有 `CODEX_REVIEW_DONE` |
| 3a | Claude 依 Codex 審查修 README／live-play-notes；加美術觀察與「線上平衡覆寫」 | 完成 |
| 3b | Codex 依 Claude 審查修自己的文件＋新增 `art-and-vfx-implementation.md`、`data/combos.md`、`weather.md`、`missions.md`＋遠端平衡一節 | 完成（`CODEX_FIX_DONE`）；送 verifier 抽驗 |

## 仍未找到（兩邊都標了）

- 草葉與角色的碰撞或踩踏互動。
- 跨招式通用的凍結時長與抗性，以及 Boss／菁英的抗性規則。
- Boss 危險區的殘留時間與統一色表。
- 近戰斬擊弧的共用幾何與生命週期。
- 升級卡的轉場動畫時長。
- **缺動態證據**：目前沒有逐格錄影，Boss 預告、命中、Mega 的時序只有程式碼可以佐證。要補的話，下一步是用 Playwright 錄 Boss 戰與 Mega 的影片。
