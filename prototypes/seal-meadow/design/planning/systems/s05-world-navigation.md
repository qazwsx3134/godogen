# S05｜世界場景、碰撞與導航

狀態：**Planning Draft（文件與工作包草案）**；2026-10-26。首次交付：M0；優先層：MVP；相對複雜度：L（不是工期）。

## 玩家價值與責任

提供可編輯、可走通的草原與城鎮，而不是只看起來可走的地表。

**規則與邊界**：視覺地形、碰撞與可行走面分層；導航初始化後才查路；入口與重生點有 ID；不可達目標有明確結果。

## 文件交付清單

- **玩法／系統規格 GDD**：預定 `design/gdd/world-navigation.md`。需將上方規則展開成正常流程、狀態轉移、拒絕原因、取消／重入／死亡／離線處理；有數值時附變數、單位、安全範圍與算例。
- **Godot 技術規格 TDD**：預定 `docs/architecture/systems/world-navigation.md`。需寫 scene tree、模組責任、資料所有權、命令／事件、更新時機、存讀／網路邊界與現有程式遷移方式。
- **此系統專屬內容**：關卡文件：路線、視線、障礙、入口；TDD：地形與導航契約；資料：區域／spawn；QA：通路地圖。
- **QA 與證據規格**：預定 `production/qa/systems/world-navigation.md`。以本頁 AC 編號追溯測試／手測／真機證據，附內容版本與未驗證項；測試不能僅檢查檔案存在。

## 資料、介面與 Godot 實作邊界

**資料與狀態**：ZoneDefinition(id,scene,spawn_ids,bounds)；navigation layers；collision mask 表；SpawnAnchor。

**對外契約**：WorldQuery.find_path／sample_walkable／can_interact 提供查詢；地圖不負責發獎或扣血。

**scene／模組**：scenes/zones/meadow.tscn、town.tscn；NavigationRegion3D；簡化 collision；現有高度函式需與導航高度一致。

## 相依與整合

共通開工條件與附件規則見[文件契約](../document-contracts.md)。

- 初始契約／首版必要前置：[S01 內容定義與資料登錄](s01-content-registry.md)。
- 直接下游：[S06 角色移動、選取與追擊](s06-movement-targeting.md)、[S10 怪物 AI、仇恨與生成](s10-monster-ai-spawning.md)、[S11 掉落、地上物與拾取](s11-loot-pickup.md)、[S21 小地圖、旅行與區域切換](s21-map-travel.md)、[S28 帳號、多人權威、AOI 與重連](s28-online-authority.md)、[S33 釣魚與休閒採集](s33-fishing.md)、[S36 副本、首領與遭遇導演](s36-dungeons-bosses.md)。

## 分階段 roadmap

M0 一塊導航灰盒與一障礙；M1 草原可玩路線；M2 城鎮與入口；後續分區載入。

## 可驗收條件

- **AC-S05-01**：點障礙後方能繞行，不能直穿。
- **AC-S05-02**：點孤島／界外點回不可達或最近可達點，規則一致。
- **AC-S05-03**：scene 在編輯器有地形、障礙與出生點，啟動不重建來源 scene。

## 風險與開工條件

原型圓形推開不等同完整導航，需保留轉換測試。

