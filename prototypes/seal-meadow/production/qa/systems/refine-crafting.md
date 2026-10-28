# S18 QA 與證據

2026-10-28；基準為工作區現行實作，真機尚未驗證。規則見 [GDD](../../../design/gdd/refine-crafting.md)。

| AC | 案例與證據 | 狀態 |
|---|---|---|
| AC-S18-01 | `tests/test_m3_hardening.gd`：重啟後重送相同序號回相同結果，不再扣石；較舊序號拒絕 | 本次 headless PASS |
| AC-S18-02 | `tests/test_m3.gd`：成功／失敗等級和材料；`test_m3_hardening.gd`：同款實例獨立及 v4 遷移 | 本次 headless PASS；目前不提供保護道具 |
| AC-S18-03 | `tools/m3_economy.gd`：固定 seed、10,000 次；現行保級與假設退階對照，理論驗算見 [經濟報告](../m3-economy.md) | 模擬 PASS；真人經濟未驗 |
| 分頁與場景 | `test_m3.gd`：物品／精煉切換、兩次確認、切頁取消、字級空間、按鈕尺寸及編輯後保留；桌面模擬橫向截圖 | headless 與 844×390 桌面模擬 PASS；iPhone 尚未驗 |

真機需確認點按目標、關窗不誤觸、材料數與失敗提示可讀，以及結算前／後切背景和強制終止的存讀。不得以固定 seed 或 Chromium 模擬替代真機結果。
