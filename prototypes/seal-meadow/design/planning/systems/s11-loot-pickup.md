# S11｜掉落、地上物與拾取

狀態：**Planning Draft（文件與工作包草案）**；2026-10-26。首次交付：M1；優先層：MVP；相對複雜度：M（不是工期）。

## 玩家價值與責任

擊殺帶來立即可辨識的獎勵，撿物不產生誤操作或重複道具。

**規則與邊界**：掉表抽取與物品生成分開；地上物有所有者／優先期／到期；拾取距離、容量與權限一次驗證。

## 文件交付清單

- **玩法／系統規格 GDD**：預定 `design/gdd/loot-pickup.md`。需將上方規則展開成正常流程、狀態轉移、拒絕原因、取消／重入／死亡／離線處理；有數值時附變數、單位、安全範圍與算例。
- **Godot 技術規格 TDD**：預定 `docs/architecture/systems/loot-pickup.md`。需寫 scene tree、模組責任、資料所有權、命令／事件、更新時機、存讀／網路邊界與現有程式遷移方式。
- **此系統專屬內容**：掉表與機率來源；拾取狀態機與權限表；UX：滿包／優先權；QA：同時拾取。
- **QA 與證據規格**：預定 `production/qa/systems/loot-pickup.md`。以本頁 AC 編號追溯測試／手測／真機證據，附內容版本與未驗證項；測試不能僅檢查檔案存在。

## 資料、介面與 Godot 實作邊界

**資料與狀態**：LootTable(weights,quantity)；LootDrop(id,item_payload,owner,unlock_at,expire_at)；pickup result。

**對外契約**：LootService.on_kill -> spawn payload；PickupCommand 交 InventoryTransaction，成功後才移除地上物。

**scene／模組**：scenes/items/loot_drop.tscn；可點區與標籤；掉表 Resource；一鍵附近拾取是後續 UX 提案。

## 相依與整合

共通開工條件與附件規則見[文件契約](../document-contracts.md)。

- 初始契約／首版必要前置：[S01 內容定義與資料登錄](s01-content-registry.md)、[S02 權威狀態、命令與時間](s02-authority-commands-clock.md)、[S05 世界場景、碰撞與導航](s05-world-navigation.md)、[S08 普攻、命中與傷害結算](s08-combat-resolution.md)、[S12 物品、背包、貨幣與交易原語](s12-inventory-transactions.md)。
- 直接下游：[S36 副本、首領與遭遇導演](s36-dungeons-bosses.md)。

## 分階段 roadmap

M1 一種掉落、點選與最小背包；M2 堆疊／稀有提示／掉表曲線；M4 多人優先權。

## 可驗收條件

- **AC-S11-01**：滿包時地上物仍存在或明確按規格分流，不吞物。
- **AC-S11-02**：兩次拾取同一 drop id 只給一次物品。
- **AC-S11-03**：優先權與到期交界用同一權威時鐘，重送不復活已拾物。

## 風險與開工條件

UI 先隱藏掉落而未確認入包會讓玩家誤以為遺失。

