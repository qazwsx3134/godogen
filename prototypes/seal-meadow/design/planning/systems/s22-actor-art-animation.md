# S22｜角色美術、方向、動畫與資產管線

狀態：**Planning Draft（文件與工作包草案）**；2026-10-26。首次交付：M0；優先層：MVP；相對複雜度：L（不是工期）。

## 玩家價值與責任

建立能批量製作且在手機清楚可辨識的原創角色。

**規則與邊界**：沿用玩家 8 方向／怪物既有方向規格；腳底錨點、格距、事件幀、圖層排序統一；產生器只在製作時跑。

## 文件交付清單

- **玩法／系統規格 GDD**：預定 `design/gdd/actor-art-animation.md`。需將上方規則展開成正常流程、狀態轉移、拒絕原因、取消／重入／死亡／離線處理；有數值時附變數、單位、安全範圍與算例。
- **Godot 技術規格 TDD**：預定 `docs/architecture/systems/actor-art-animation.md`。需寫 scene tree、模組責任、資料所有權、命令／事件、更新時機、存讀／網路邊界與現有程式遷移方式。
- **此系統專屬內容**：Art Bible／角色規格卡；動作與命中事件表；atlas／壓縮預算；匯入／owner／instance 驗證。
- **QA 與證據規格**：預定 `production/qa/systems/actor-art-animation.md`。以本頁 AC 編號追溯測試／手測／真機證據，附內容版本與未驗證項；測試不能僅檢查檔案存在。

## 資料、介面與 Godot 實作邊界

**資料與狀態**：ActorVisualDefinition(sheet/layers,foot_anchor,head_height,action_events)；asset manifest；來源／授權紀錄。

**對外契約**：ActorView.play_action／face／set_appearance／set_state；讀 domain event，不算傷害；render manifest→atlas→Resource。

**scene／模組**：scenes/actors/actor.tscn；sheet .tres；tools/blender、import_sheets；沿用 godot-kit sprite3d，副本不直接改。

## 相依與整合

共通開工條件與附件規則見[文件契約](../document-contracts.md)。

- 初始契約／首版必要前置：[S01 內容定義與資料登錄](s01-content-registry.md)。
- 直接下游：[S13 裝備屬性、紙娃娃與換裝](s13-equipment-paperdoll.md)、[S17 寵物餵食、成長與進化](s17-pet-care.md)、[S23 特效、跳字與打擊回饋](s23-combat-feedback.md)、[S32 情侶、雙人互動與表情](s32-relationships-emotes.md)、[S33 釣魚與休閒採集](s33-fishing.md)、[S34 戰鬥寵物、守護者與乘坐](s34-battle-pets-guarders.md)、[S35 時裝、光環與外觀收藏](s35-cosmetics-auras.md)。

## 分階段 roadmap

M0 既有測試人可編輯呈現；M1 五動作與腳底驗證；M2 一套原創裝備；M3 手機材質與記憶體驗收。

## 可驗收條件

- **AC-S22-01**：方向／動作切換腳底偏移在規格容許範圍且有量測圖。
- **AC-S22-02**：導入資產後 scene instance 關係與節點數可重載驗證。
- **AC-S22-03**：正常啟動／測試不自動重新烘焙 atlas 或重建 scene。

## 風險與開工條件

AI 畫分層對齊不穩；先用 3D 離線渲染管線驗證；生成需另行批次選擇。

