# S39｜商城、付費與權益

狀態：**Planning Draft（文件與工作包草案）**；2026-10-26。首次交付：M5；優先層：Full Vision；相對複雜度：XL（不是工期）。

## 玩家價值與責任

若未來採付費，提供可追溯的權益購買與恢復。

**規則與邊界**：商業模式尚未決定；未選平台不接真實付款；正式付款以可信收據驗證、去重、退款／撤銷與恢復為準。

## 文件交付清單

- **玩法／系統規格 GDD**：預定 `design/gdd/commerce.md`。需將上方規則展開成正常流程、狀態轉移、拒絕原因、取消／重入／死亡／離線處理；有數值時附變數、單位、安全範圍與算例。
- **Godot 技術規格 TDD**：預定 `docs/architecture/systems/commerce.md`。需寫 scene tree、模組責任、資料所有權、命令／事件、更新時機、存讀／網路邊界與現有程式遷移方式。
- **此系統專屬內容**：商業模式／商品範圍、付款序列／恢復／退款、平台技術 ADR、QA：sandbox／中斷；發佈要求另作查核。
- **QA 與證據規格**：預定 `production/qa/systems/commerce.md`。以本頁 AC 編號追溯測試／手測／真機證據，附內容版本與未驗證項；測試不能僅檢查檔案存在。

## 資料、介面與 Godot 實作邊界

**資料與狀態**：ProductCatalog；PlatformReceipt；PurchaseState；EntitlementLedger；RefundEvent。

**對外契約**：CommerceService 驗證平台結果後 grant entitlement；客戶端按鈕不直接發金幣／外觀；sandbox 與 live 分離。

**scene／模組**：ui/store_window.tscn、purchase_status.tscn；平台 plugin／SDK 在正式技術選型後記版本、授權、匯出限制。

## 相依與整合

共通開工條件與附件規則見[文件契約](../document-contracts.md)。

- 初始契約／首版必要前置：[S12 物品、背包、貨幣與交易原語](s12-inventory-transactions.md)、[S25 存檔、設定與手機生命週期](s25-persistence-lifecycle.md)、[S27 手機效能、測試、工具與匯出](s27-performance-build-qa.md)、[S28 帳號、多人權威、AOI 與重連](s28-online-authority.md)、[S35 時裝、光環與外觀收藏](s35-cosmetics-auras.md)。
- 直接下游：無。

## 分階段 roadmap

M5 只在確定商業模式與平台後啟動；先 mock 展示，sandbox 驗證後才評估真實接入。

## 可驗收條件

- **AC-S39-01**：同收據重送只發一次權益。
- **AC-S39-02**：付款成功但 client 被關閉，重開可恢復權益。
- **AC-S39-03**：退款／撤銷結果可對帳且不依賴本機旗標。

## 風險與開工條件

付費是條件範圍，不能把規劃視為接入／上線授權。

