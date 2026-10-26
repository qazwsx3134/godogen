# S04｜固定鏡頭、構圖與遮擋

狀態：**Planning Draft（文件與工作包草案）**；2026-10-26。首次交付：M0；優先層：MVP；相對複雜度：M（不是工期）。

## 玩家價值與責任

玩家能直接讀懂道路與戰鬥，不必旋轉鏡頭找目標。

**規則與邊界**：yaw/pitch 固定，平滑跟隨平移；首版基準縮放固定；不同 aspect 不切掉必要互動；必要前景可淡化。

## 文件交付清單

- **玩法／系統規格 GDD**：預定 `design/gdd/fixed-camera.md`。需將上方規則展開成正常流程、狀態轉移、拒絕原因、取消／重入／死亡／離線處理；有數值時附變數、單位、安全範圍與算例。
- **Godot 技術規格 TDD**：預定 `docs/architecture/systems/fixed-camera.md`。需寫 scene tree、模組責任、資料所有權、命令／事件、更新時機、存讀／網路邊界與現有程式遷移方式。
- **此系統專屬內容**：相機構圖表：地標、角色佔屏、各 aspect；遮擋規格；QA：固定 yaw/pitch 與傳送重設。
- **QA 與證據規格**：預定 `production/qa/systems/fixed-camera.md`。以本頁 AC 編號追溯測試／手測／真機證據，附內容版本與未驗證項；測試不能僅檢查檔案存在。

## 資料、介面與 Godot 實作邊界

**資料與狀態**：CameraProfile(yaw,pitch,distance,fov,follow_response)；aspect policy；occlusion mask／fade state。

**對外契約**：CameraRig.follow(target)／snap_to(target)；不提供玩家 rotate 命令；world hit test 使用同一 active camera。

**scene／模組**：scenes/camera_rig.tscn；Camera3D；需要時遮擋 ray／shape query；參數在 scene/export。

## 相依與整合

共通開工條件與附件規則見[文件契約](../document-contracts.md)。

- 初始契約／首版必要前置：[S01 內容定義與資料登錄](s01-content-registry.md)。
- 直接下游：[S03 觸控輸入與互動優先權](s03-touch-input.md)、[S21 小地圖、旅行與區域切換](s21-map-travel.md)、[S23 特效、跳字與打擊回饋](s23-combat-feedback.md)。

## 分階段 roadmap

M0 移除互動旋轉並保存構圖；M1 戰鬥視野；M2 建築遮擋與兩區域入口；M3 真機比較。

## 可驗收條件

- **AC-S04-01**：拖曳／雙指／右鍵不改 yaw 或 pitch。
- **AC-S04-02**：走到每個必要入口與 NPC 前，不需旋轉即可辨認與點選。
- **AC-S04-03**：重生／切區後不從舊區域慢慢追鏡頭。

## 風險與開工條件

固定鏡頭使關卡遮擋成為場景責任，不只是相機問題。

