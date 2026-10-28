# seal-meadow 唯讀獨立審查（2026-10-29）

## 結論

對 `master` 的 `180149a9` 以後、目前未提交的 seal-meadow 變更，**沒有發現可重現且需要修正的行為缺陷**。本次是唯讀程式與證據審查；未修改專案、未重跑 Godot 或瀏覽器測試，也未將既有測試結果當成本次新驗證。

## 審查範圍與判斷依據

- 檢查 `git status --short -- Progress.md prototypes/seal-meadow`，包含未追蹤的 S35 GDD/TDD/QA、`scripts/cosmetics.gd`、衣櫥 scene/腳本、精煉列 scene 與 `tests/test_wardrobe.gd`；對照 `git diff HEAD` 的主流程、HUD、玩家、傳送門、存檔驗證及 scene 修改。
- 精煉：背包「物品／精煉」切換與關窗均清除確認狀態；第二次點擊才呼叫 `Refine.attempt()`，裝備 UID 在確認時再次核對。既有 `test_m3.gd` 涵蓋切頁取消及兩次點擊；Web 報告記錄觸控精煉與保存。
- 戰鬥／互動：揮砍只從實際命中且仍存活的怪中選最近者，保留有效既有目標及移動優先；傳送門外環由 `_portal_goal` setter 統一清除與啟用，改點、鍵盤移動、施法、選怪和抵達均有清除路徑。`test_review_interactions.gd` 覆蓋主要中斷與選怪情境。
- 衣櫥：預覽只改顯示層，取消與切窗會還原；套用先同時核對兩個資格，保存資料只含已套用選項。換裝數值仍由裝備與寵物計算。衣櫥是 HUD 中實際的子 scene，文字與間距保存在可編輯 scene；`test_wardrobe.gd` 包含 scene 編輯後重新打包／載入驗證。
- 存檔：v5→v6 補預設外觀；驗證拒絕超過 12 格背包、未知或未持有外觀。主檔 payload 無效時會嘗試有效備份；第一次新寫入前先將有效備份恢復成主檔，避免備份被壞主檔覆蓋；沒有備份時停止寫入。較新版本在 `SaveSlots.restore()` 及 `main.save_game()` 路徑會阻止舊版遊戲覆寫。`test_m3_hardening.gd`、`test_wardrobe.gd` 有對應案例。
- 檢視 `/tmp/seal-web-wardrobe-20261029/wardrobe.png`：844×390 模擬畫面可見衣櫥選項、角色預覽、關閉與套用；全畫面遮罩在視窗開啟時攔截其後的遊戲操作，符合模態視窗行為，未見新增按鈕遮住必要操作。

## 證據限制與交接

- 既有 L2 七組通過的紀錄在 `/tmp/godot-tests.wtxsbV/`；既有 12 項 Chromium 結果在 `/tmp/seal-web-wardrobe-20261029/report.json`。本次沒有獨立執行它們，因此只確認測試內容及報告宣稱大致對應程式路徑，未獨立證實環境中的通過結果。
- `tests/test_wardrobe.gd:37` 以 `SaveSlots.restore(SAVE, 5)` 的 `newer` 結果表述「舊版不覆寫」。這一斷言本身只驗證讀取拒絕；實際阻止寫入還依賴舊版 `main.gd` 的 `save_blocked_reason`。靜態路徑存在，但此項測試名稱比單一斷言的證明範圍更廣，後續若強化測試可直接啟動舊版程式做端到端驗證。
- iPhone 17 Safari 的真實觸控、安全區、背景／強制終止後的 IndexedDB 恢復、FPS、20～30 分鐘發熱，以及真人試玩仍未驗證。桌面 Godot 與 Chromium 模擬不構成這些項目的通過證據。
- `build/seal-meadow-mobile-web.zip` 僅是本地候選，未上傳；`build/web/` 是舊版。此次未檢查或更動其他原型，也未 stage、commit、push。
