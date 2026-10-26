# S21｜小地圖、旅行與區域切換

狀態：**Planning Draft（文件與工作包草案）**；2026-10-26。首次交付：M2；優先層：Vertical Slice；相對複雜度：M（不是工期）。

## 玩家價值與責任

在固定視角下知道自己在哪、下一個入口在哪。

**規則與邊界**：小地圖固定北向；世界座標與圖示共用轉換；跨圖由權威流程切換，不重複帶入舊怪／掉落。

## 文件交付清單

- **玩法／系統規格 GDD**：預定 `design/gdd/map-travel.md`。需將上方規則展開成正常流程、狀態轉移、拒絕原因、取消／重入／死亡／離線處理；有數值時附變數、單位、安全範圍與算例。
- **Godot 技術規格 TDD**：預定 `docs/architecture/systems/map-travel.md`。需寫 scene tree、模組責任、資料所有權、命令／事件、更新時機、存讀／網路邊界與現有程式遷移方式。
- **此系統專屬內容**：區域連接圖與傳送規則；小地圖投影公式；UX：載入／錯誤重試；QA：切區中斷。
- **QA 與證據規格**：預定 `production/qa/systems/map-travel.md`。以本頁 AC 編號追溯測試／手測／真機證據，附內容版本與未驗證項；測試不能僅檢查檔案存在。

## 資料、介面與 Godot 實作邊界

**資料與狀態**：MapDefinition(world_rect,texture,markers)；TravelRequest；ZoneTransitionState；last_safe_spawn。

**對外契約**：MapProjection.world_to_map；TravelService 驗門檻／目的地，通知 scene loader 與 save repository。

**scene／模組**：ui/minimap.tscn、world_map.tscn、loading_screen.tscn；zone portal scene；kit scene_loader 候選。

## 相依與整合

共通開工條件與附件規則見[文件契約](../document-contracts.md)。

- 初始契約／首版必要前置：[S01 內容定義與資料登錄](s01-content-registry.md)、[S02 權威狀態、命令與時間](s02-authority-commands-clock.md)、[S04 固定鏡頭、構圖與遮擋](s04-fixed-camera.md)、[S05 世界場景、碰撞與導航](s05-world-navigation.md)、[S25 存檔、設定與手機生命週期](s25-persistence-lifecycle.md)。
- 直接下游：無。

## 分階段 roadmap

M2 草原↔城鎮；M3 儲存最後安全位置與載入失敗恢復；M4 server zone transfer。

## 可驗收條件

- **AC-S21-01**：已知地標投影到預期格子，點圖轉回世界誤差在規格內。
- **AC-S21-02**：載入失敗仍可回安全場景，不丟失角色狀態。
- **AC-S21-03**：跨圖後沒有前區的目標、路徑與攻擊計時器殘留。

## 風險與開工條件

小地圖貼圖範圍與場景 bounds 不一致會讓圖示漂移。

