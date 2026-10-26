# S10｜怪物 AI、仇恨與生成

狀態：**Planning Draft（文件與工作包草案）**；2026-10-26。首次交付：M1；優先層：MVP；相對複雜度：L（不是工期）。

## 玩家價值與責任

怪物有可讀性格與適度反擊，讓練功路線形成節奏。

**規則與邊界**：Idle/Patrol/Alert/Chase/Attack/Return/Dead/Respawn；被動／主動；leash 與不可達退回；未定多人仇恨先保留策略介面。

## 文件交付清單

- **玩法／系統規格 GDD**：預定 `design/gdd/monster-ai-spawning.md`。需將上方規則展開成正常流程、狀態轉移、拒絕原因、取消／重入／死亡／離線處理；有數值時附變數、單位、安全範圍與算例。
- **Godot 技術規格 TDD**：預定 `docs/architecture/systems/monster-ai-spawning.md`。需寫 scene tree、模組責任、資料所有權、命令／事件、更新時機、存讀／網路邊界與現有程式遷移方式。
- **此系統專屬內容**：怪物卡：外觀、行為、數值、掉表、動畫；FSM 圖；出生／密度配置；QA：拉怪與回家。
- **QA 與證據規格**：預定 `production/qa/systems/monster-ai-spawning.md`。以本頁 AC 編號追溯測試／手測／真機證據，附內容版本與未驗證項；測試不能僅檢查檔案存在。

## 資料、介面與 Godot 實作邊界

**資料與狀態**：MonsterDefinition；SpawnDefinition(anchor,count,respawn)；AIState；ThreatEntry。

**對外契約**：MonsterBrain 發移動／攻擊命令；SpawnService 管 active entities；死亡結果由 S08 觸發，AI 不直接發掉落。

**scene／模組**：scenes/monsters/<id>.tscn；spawn markers 在區域 scene；FSM 腳本；測試可注入感知結果。

## 相依與整合

共通開工條件與附件規則見[文件契約](../document-contracts.md)。

- 初始契約／首版必要前置：[S01 內容定義與資料登錄](s01-content-registry.md)、[S05 世界場景、碰撞與導航](s05-world-navigation.md)、[S06 角色移動、選取與追擊](s06-movement-targeting.md)、[S07 屬性、生命、回復與死亡](s07-stats-vitals-death.md)、[S08 普攻、命中與傷害結算](s08-combat-resolution.md)。
- 直接下游：[S36 副本、首領與遭遇導演](s36-dungeons-bosses.md)。

## 分階段 roadmap

M1 一種被動怪與重生；M2 三種怪區分主動／反擊；M5 再加精英、群體與首領策略。

## 可驗收條件

- **AC-S10-01**：離出生區太遠或長期不可達時返回，不跨圖追殺。
- **AC-S10-02**：怪死亡一次只送一次 death result，重生用新 entity id。
- **AC-S10-03**：玩家死亡／下線後怪能清仇恨並回到正常狀態。

## 風險與開工條件

每怪每幀搜尋整張場景與重查路會在手機出尖峰。

