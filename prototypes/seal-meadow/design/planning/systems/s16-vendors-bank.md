# S16｜NPC 商店、銀行與城鎮服務

狀態：**Planning Draft（文件與工作包草案）**；2026-10-26。首次交付：M2；優先層：Vertical Slice；相對複雜度：M（不是工期）。

## 玩家價值與責任

提供補給、資源回收與出城前整理。

**規則與邊界**：NPC 目錄決定售價／回收價；購買數量、綁定物與回購規則明定；存取驗容量、鎖與權限。

## 文件交付清單

- **玩法／系統規格 GDD**：預定 `design/gdd/vendors-bank.md`。需將上方規則展開成正常流程、狀態轉移、拒絕原因、取消／重入／死亡／離線處理；有數值時附變數、單位、安全範圍與算例。
- **Godot 技術規格 TDD**：預定 `docs/architecture/systems/vendors-bank.md`。需寫 scene tree、模組責任、資料所有權、命令／事件、更新時機、存讀／網路邊界與現有程式遷移方式。
- **此系統專屬內容**：價格與容量表；購買／出售／存取流程；UX：數量與比較；QA：滿包／變價／重複操作。
- **QA 與證據規格**：預定 `production/qa/systems/vendors-bank.md`。以本頁 AC 編號追溯測試／手測／真機證據，附內容版本與未驗證項；測試不能僅檢查檔案存在。

## 資料、介面與 Godot 實作邊界

**資料與狀態**：VendorCatalog；PriceRule；BankContainer；Buy/Sell/Deposit/Withdraw command。

**對外契約**：ShopService 依服務端／本機權威價格產生 Transaction；銀行是同原語的容器轉移。

**scene／模組**：ui/vendor_window.tscn、bank_window.tscn；共用 item_slot 與數量選擇 scene；NPC 僅開服務入口。

## 相依與整合

共通開工條件與附件規則見[文件契約](../document-contracts.md)。

- 初始契約／首版必要前置：[S01 內容定義與資料登錄](s01-content-registry.md)、[S02 權威狀態、命令與時間](s02-authority-commands-clock.md)、[S12 物品、背包、貨幣與交易原語](s12-inventory-transactions.md)。
- 直接下游：[S30 玩家交易與擺攤](s30-trade-stalls.md)。

## 分階段 roadmap

M2 商店、賣雜物與有限銀行；M3 回購或服務擴充；M4 角色／帳號倉庫權限。

## 可驗收條件

- **AC-S16-01**：購買時錢不足或包滿，金幣與物品皆不變。
- **AC-S16-02**：存取後全容器 uuid 守恆。
- **AC-S16-03**：確認前價格改變需重確認，不按舊 UI 價格提交。

## 風險與開工條件

商店是貨幣水龍頭／回收口，價格需與掉落平衡共同審查。

