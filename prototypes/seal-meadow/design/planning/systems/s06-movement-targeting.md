# S06｜角色移動、選取與追擊

狀態：**Planning Draft（文件與工作包草案）**；2026-10-26。首次交付：M1；優先層：MVP；相對複雜度：L（不是工期）。

## 玩家價值與責任

一次選怪便可靠追打，走位可隨時改變戰術。

**規則與邊界**：Idle/Move/Chase 狀態；攻擊半徑與離開半徑分開；目標死亡／卸載取消；手動移動取消追擊。

## 文件交付清單

- **玩法／系統規格 GDD**：預定 `design/gdd/movement-targeting.md`。需將上方規則展開成正常流程、狀態轉移、拒絕原因、取消／重入／死亡／離線處理；有數值時附變數、單位、安全範圍與算例。
- **Godot 技術規格 TDD**：預定 `docs/architecture/systems/movement-targeting.md`。需寫 scene tree、模組責任、資料所有權、命令／事件、更新時機、存讀／網路邊界與現有程式遷移方式。
- **此系統專屬內容**：GDD：追擊／換目標／中斷表；TDD：物理更新與路徑重查；UX：選取圈；QA：狀態轉移。
- **QA 與證據規格**：預定 `production/qa/systems/movement-targeting.md`。以本頁 AC 編號追溯測試／手測／真機證據，附內容版本與未驗證項；測試不能僅檢查檔案存在。

## 資料、介面與 Godot 實作邊界

**資料與狀態**：MovementState(goal,path,target_id)；move_speed；repath thresholds；TargetSelection。

**對外契約**：MovementController 接 Move/Chase/Stop；TargetService 解析 entity id；輸出到位／路徑失敗，傷害交給 S08。

**scene／模組**：scenes/player.tscn 的 CharacterBody3D／NavigationAgent3D 或等價受控移動；不直接改 actor 貼圖。

## 相依與整合

共通開工條件與附件規則見[文件契約](../document-contracts.md)。

- 初始契約／首版必要前置：[S02 權威狀態、命令與時間](s02-authority-commands-clock.md)、[S03 觸控輸入與互動優先權](s03-touch-input.md)、[S05 世界場景、碰撞與導航](s05-world-navigation.md)。
- 直接下游：[S08 普攻、命中與傷害結算](s08-combat-resolution.md)、[S10 怪物 AI、仇恨與生成](s10-monster-ai-spawning.md)、[S34 戰鬥寵物、守護者與乘坐](s34-battle-pets-guarders.md)。

## 分階段 roadmap

M1 點地繞障礙與追怪；M2 多目標與入口取消；M4 網路位置同步接 adapter。

## 可驗收條件

- **AC-S06-01**：怪在射程邊緣移動時不每幀 Chase/Attack 抖動。
- **AC-S06-02**：手動移動後不立即返回上一目標。
- **AC-S06-03**：目標 queue_free 或跨區後無效引用不造成攻擊／崩潰。

## 風險與開工條件

移動、目標與動畫各自持有目標容易不同步。

