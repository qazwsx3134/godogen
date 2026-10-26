# S30｜玩家交易與擺攤

狀態：**Planning Draft（文件與工作包草案）**；2026-10-26。首次交付：M4；優先層：Alpha；相對複雜度：XL（不是工期）。

## 玩家價值與責任

玩家能安全交換裝備，形成城鎮市場。

**規則與邊界**：Offer/Lock/Confirm/Commit；任何修改撤銷雙方確認；背包與金幣先鎖定；超時／斷線解除或恢復已提交結果。

## 文件交付清單

- **玩法／系統規格 GDD**：預定 `design/gdd/trade-stalls.md`。需將上方規則展開成正常流程、狀態轉移、拒絕原因、取消／重入／死亡／離線處理；有數值時附變數、單位、安全範圍與算例。
- **Godot 技術規格 TDD**：預定 `docs/architecture/systems/trade-stalls.md`。需寫 scene tree、模組責任、資料所有權、命令／事件、更新時機、存讀／網路邊界與現有程式遷移方式。
- **此系統專屬內容**：雙方交易狀態機；原子提交／鎖生命週期；擺攤離線政策；UX：改價重確認；QA：競態／崩潰恢復。
- **QA 與證據規格**：預定 `production/qa/systems/trade-stalls.md`。以本頁 AC 編號追溯測試／手測／真機證據，附內容版本與未驗證項；測試不能僅檢查檔案存在。

## 資料、介面與 Godot 實作邊界

**資料與狀態**：TradeSession(revision,offers,confirmations)；ItemLock；StallListing(price,quantity)；TradeReceipt。

**對外契約**：TradeService 使用 DB atomic transaction；客戶端只傳 session revision／意圖；擺攤消耗同一物品 instance。

**scene／模組**：ui/trade_window.tscn、stall_window.tscn、listing_row.tscn；world stall marker scene。

## 相依與整合

共通開工條件與附件規則見[文件契約](../document-contracts.md)。

- 初始契約／首版必要前置：[S12 物品、背包、貨幣與交易原語](s12-inventory-transactions.md)、[S16 NPC 商店、銀行與城鎮服務](s16-vendors-bank.md)、[S28 帳號、多人權威、AOI 與重連](s28-online-authority.md)、[S29 隊伍、聊天與好友](s29-party-chat-friends.md)。
- 直接下游：無。

## 分階段 roadmap

M4 先雙人交易且通過斷線測試；M5 有限在線擺攤；離線市場另估容量與持久化。

## 可驗收條件

- **AC-S30-01**：一方修改金額後雙方舊確認全部失效。
- **AC-S30-02**：提交時 server 終止再啟動不產生半邊交易。
- **AC-S30-03**：被鎖裝備不能同時裝備、精煉、存銀行或上架另一攤。

## 風險與開工條件

防複製需要 DB／交易設計，純 UI 確認無法保證。

