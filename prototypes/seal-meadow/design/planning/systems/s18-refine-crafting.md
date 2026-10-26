# S18｜精煉、製作與材料消耗

狀態：**Planning Draft（文件與工作包草案）**；2026-10-26。首次交付：M3；優先層：Vertical Slice；相對複雜度：L（不是工期）。

## 玩家價值與責任

讓材料有長期用途，同時清楚呈現投入與失敗風險。

**規則與邊界**：每階成本、成功率、失敗保留／退階／消失、保護道具與結果取樣時機都需明列；未知原作機率不補成事實。

## 文件交付清單

- **玩法／系統規格 GDD**：預定 `design/gdd/refine-crafting.md`。需將上方規則展開成正常流程、狀態轉移、拒絕原因、取消／重入／死亡／離線處理；有數值時附變數、單位、安全範圍與算例。
- **Godot 技術規格 TDD**：預定 `docs/architecture/systems/refine-crafting.md`。需寫 scene tree、模組責任、資料所有權、命令／事件、更新時機、存讀／網路邊界與現有程式遷移方式。
- **此系統專屬內容**：階梯／配方表；成功與失敗算例；期望成本模擬；UX：風險確認；QA：重送／結果落盤。
- **QA 與證據規格**：預定 `production/qa/systems/refine-crafting.md`。以本頁 AC 編號追溯測試／手測／真機證據，附內容版本與未驗證項；測試不能僅檢查檔案存在。

## 資料、介面與 Godot 實作邊界

**資料與狀態**：RefineRule；Recipe；CraftRequest(id,item_uuid,materials,protection)；ResultRecord；RNG seed policy。

**對外契約**：RefineService/CraftService 只在 Transaction commit 時消耗與改裝備；重送回同結果，不重新抽。

**scene／模組**：ui/refine_window.tscn、craft_window.tscn；kit refine_ladder 是候選邏輯，必須以本作規則測試。

## 相依與整合

共通開工條件與附件規則見[文件契約](../document-contracts.md)。

- 初始契約／首版必要前置：[S01 內容定義與資料登錄](s01-content-registry.md)、[S02 權威狀態、命令與時間](s02-authority-commands-clock.md)、[S12 物品、背包、貨幣與交易原語](s12-inventory-transactions.md)、[S13 裝備屬性、紙娃娃與換裝](s13-equipment-paperdoll.md)。
- 直接下游：無。

## 分階段 roadmap

M3 一階梯、一配方與顯示確認；M4 網路重送／DB 結算；M5 多材料與保護規則。

## 可驗收條件

- **AC-S18-01**：重複提交同 request id 不再次抽機率／扣材料。
- **AC-S18-02**：失敗後物品階級、uuid 與保護道具去向符合明列規則。
- **AC-S18-03**：模擬成本報告含退階分支，不只使用 cost/p。

## 風險與開工條件

失敗消失是產品設計決策，首切片不得默認採用。

