# S33 QA 與證據

2026-10-28；[GDD](../../../design/gdd/fishing.md) 是本機試調規則。

| AC | 案例／證據 | 狀態 |
|---|---|---|
| AC-S33-01 | `tests/test_fishing.gd`：停止後推進 clock 不發獎，已結算不再發獎；移動／受擊／背景取消 | 本次 headless PASS |
| AC-S33-02 | `test_fishing.gd`：背包滿時不消耗餌；完成時 1 餌換 1 產物並 checkpoint | 本次 headless PASS |
| AC-S33-03 | `test_fishing.gd` 以注入遊戲 clock 前進，不使用系統日曆 | 本次單機 headless PASS；多人服務端不在目前範圍 |

尚需 iPhone 觸控、前景／背景返回、滿包文字及長時間試玩；真實裝置時鐘變更與效能未測。
