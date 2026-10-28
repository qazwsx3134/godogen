# S35 衣櫥 QA 與證據

2026-10-29；目前為單機薄切片，規則見 [GDD](../../../design/gdd/cosmetics-auras.md)。

| AC | 案例／證據 | 狀態 |
|---|---|---|
| AC-S35-01 | `tests/test_wardrobe.gd`：鎖定選項仍可預覽、關閉／切其他視窗還原、存檔排除預覽、預覽與套用不改裝備／攻擊／生命 | 本次 headless PASS；桌面模擬截圖 `/tmp/seal-wardrobe-shots/` |
| AC-S35-02 | 他人光環開關與戰鬥危險提示 | 多人不在本次範圍，未驗證；單機裝飾光環不改戰鬥判定 |
| AC-S35-03 | `test_wardrobe.gd`：未解鎖及未知 id 的直接套用被拒絕；無效存檔回退備份或停止覆寫 | 本次 headless PASS |
| 保存與可編輯 | `test_wardrobe.gd`：v5→v6、v5 讀取器拒絕新版、解鎖後套用重啟保留、兩種畫面比例、編輯文字／間距保留；寫入保護另由一般 newer 存檔測試和舊版程式路徑佐證 | 本次 headless PASS；未實際啟動舊版遊戲做寫入端對端，iPhone Safari 未驗 |

五個隔離變異（資格、取消、數值、版本保護、預覽存檔）均由測試抓到。`/tmp/godot-tests.wtxsbV/` 是 7 組 L2 回歸；故意載入損壞存檔的 warning 是預期案例。844×390 Chromium 的 v5→v6、預覽不保存、套用與重開通過，報告 `/tmp/seal-web-wardrobe-20261029/report.json`，0 瀏覽器錯誤。iPhone 觸控、背景／冷啟動、戰鬥中遮擋與效能仍待驗證。
