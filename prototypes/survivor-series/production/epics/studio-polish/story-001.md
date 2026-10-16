# Story 001 — 空間索引最近目標與密度查詢

**Status**: Complete
**Type**: Logic
**Completed**: 2026-10-16
**Workflow**: minimal；既有原型改善的結案紀錄。

## 範圍與依據

使用者要求依新的 Studio 優化 debt 與 survivor，並和同 workspace 的 Claude 協作。
[遊戲摘要](../../../design/game-brief.md)與[本輪規格](../../../design/quick-specs/studio-polish-2026-10-16.md)定義範圍。

## 驗收

- [x] 規格列出的功能與隔離／邊界情況已驗證。
- [x] 同一固定負載的 before/after CPU 量測與 checksum 已保留。
- [x] 所有本遊戲 native suites 通過，最終修改的相關 suites 重跑通過。
- [x] 原生場景截圖已檢視；既有美術與可編輯場景保留。
- [x] Codex 審閱 Claude 的 Studio helper 修正與 regression test；共用工具可檢查本遊戲。

[改善報告](../../polish/studio-polish-2026-10-16.md)包含實作與量測；[smoke report](../../qa/smoke-2026-10-16.md)包含測試與限制。
本次結案限此改善範圍，真機與 Web 驗證維持報告記錄的未評估狀態。
