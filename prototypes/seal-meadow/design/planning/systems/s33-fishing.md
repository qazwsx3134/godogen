# S33｜釣魚與休閒採集

狀態：**Planning Draft（文件與工作包草案）**；2026-10-26。首次交付：M5；優先層：Full Vision；相對複雜度：M（不是工期）。

2026-10-28 依單機優先決定先實作薄切片：[GDD](../../gdd/fishing.md)、[TDD](../../../docs/architecture/systems/fishing.md)、[QA](../../../production/qa/systems/fishing.md)。真機與多人權威尚未驗證。

## 玩家價值與責任

提供低強度、可整理資源的遊玩節奏。

**規則與邊界**：地點、餌、開始／等待／結果／停止；移動、受擊、滿包與背景政策明定；不把背景當可靠離線掛機。

## 文件交付清單

- **玩法／系統規格 GDD**：預定 `design/gdd/fishing.md`。需將上方規則展開成正常流程、狀態轉移、拒絕原因、取消／重入／死亡／離線處理；有數值時附變數、單位、安全範圍與算例。
- **Godot 技術規格 TDD**：預定 `docs/architecture/systems/fishing.md`。需寫 scene tree、模組責任、資料所有權、命令／事件、更新時機、存讀／網路邊界與現有程式遷移方式。
- **此系統專屬內容**：釣點／掉表／餌與期望產出；背景規則；UX：停止與滿包；QA：時鐘與重送。
- **QA 與證據規格**：預定 `production/qa/systems/fishing.md`。以本頁 AC 編號追溯測試／手測／真機證據，附內容版本與未驗證項；測試不能僅檢查檔案存在。

## 資料、介面與 Godot 實作邊界

**資料與狀態**：FishingSpot；BaitRule；CatchTable；FishingState(next_result_at,spent_bait)；harvest receipt。

**對外契約**：FishingService 依權威時鐘結算；餌與獎勵一次 Transaction；狀態事件驅動動畫。

**scene／模組**：scenes/interactions/fishing_spot.tscn；ui/fishing_panel.tscn；釣魚 actor 動作。

## 相依與整合

共通開工條件與附件規則見[文件契約](../document-contracts.md)。

- 初始契約／首版必要前置：[S02 權威狀態、命令與時間](s02-authority-commands-clock.md)、[S05 世界場景、碰撞與導航](s05-world-navigation.md)、[S12 物品、背包、貨幣與交易原語](s12-inventory-transactions.md)、[S22 角色美術、方向、動畫與資產管線](s22-actor-art-animation.md)、[S25 存檔、設定與手機生命週期](s25-persistence-lifecycle.md)。
- 直接下游：無。

## 分階段 roadmap

M5 一釣點與一餌；後續收藏魚種與區域差異。

## 可驗收條件

- **AC-S33-01**：停止後不再因舊 timer 發獎。
- **AC-S33-02**：滿包時餌與結果依明確規則回退或暫存。
- **AC-S33-03**：更改本機日曆不無限刷產出，多人由服務端決定。

## 風險與開工條件

掛機產出會影響經濟與手機電量，需共同審查。

