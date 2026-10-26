# S13｜裝備屬性、紙娃娃與換裝

狀態：**Planning Draft（文件與工作包草案）**；2026-10-26。首次交付：M2；優先層：Vertical Slice；相對複雜度：L（不是工期）。

## 玩家價值與責任

換上新裝備時玩家能看到外觀與能力的具體變化。

**規則與邊界**：裝備欄、職業／等級需求、雙手／副手互斥、外觀覆寫與數值分開；鏡像左右手限制沿用既有素材標註。

## 文件交付清單

- **玩法／系統規格 GDD**：預定 `design/gdd/equipment-paperdoll.md`。需將上方規則展開成正常流程、狀態轉移、拒絕原因、取消／重入／死亡／離線處理；有數值時附變數、單位、安全範圍與算例。
- **Godot 技術規格 TDD**：預定 `docs/architecture/systems/equipment-paperdoll.md`。需寫 scene tree、模組責任、資料所有權、命令／事件、更新時機、存讀／網路邊界與現有程式遷移方式。
- **此系統專屬內容**：GDD：欄位與限制；紙娃娃方向／遮擋矩陣；UX：數值比較；QA：換裝與存讀。
- **QA 與證據規格**：預定 `production/qa/systems/equipment-paperdoll.md`。以本頁 AC 編號追溯測試／手測／真機證據，附內容版本與未驗證項；測試不能僅檢查檔案存在。

## 資料、介面與 Godot 實作邊界

**資料與狀態**：EquipmentSlots(instance_ids)；AppearanceLoadout；BodyRegionMask；PaperdollLayerDefinition。

**對外契約**：EquipCommand 經 InventoryTransaction 交換位置，StatService 重算一次；AppearanceResolver 輸出外觀層。

**scene／模組**：scenes/actors/actor.tscn；方向化圖層順序與同步 sheet；ui/equipment_window.tscn、item_compare.tscn。

## 相依與整合

共通開工條件與附件規則見[文件契約](../document-contracts.md)。

- 初始契約／首版必要前置：[S01 內容定義與資料登錄](s01-content-registry.md)、[S07 屬性、生命、回復與死亡](s07-stats-vitals-death.md)、[S12 物品、背包、貨幣與交易原語](s12-inventory-transactions.md)、[S14 經驗、職業、技能成長與轉職](s14-progression-jobs.md)、[S22 角色美術、方向、動畫與資產管線](s22-actor-art-animation.md)。
- 直接下游：[S18 精煉、製作與材料消耗](s18-refine-crafting.md)、[S35 時裝、光環與外觀收藏](s35-cosmetics-auras.md)。

## 分階段 roadmap

M2 一套換裝＋兩武器；M3 高階屬性與外觀覆寫；先驗手機 atlas 量再量產。

## 可驗收條件

- **AC-S13-01**：換武器後屬性只加一次，連續開關面板不累積。
- **AC-S13-02**：雙手武器與盾互斥時物品去向與滿包失敗明確。
- **AC-S13-03**：所有方向、動作都使用同一幀索引且腳底不跳。

## 風險與開工條件

預渲染換裝量會放大記憶體、方向與動作維護成本。

