# S34｜戰鬥寵物、守護者與乘坐

狀態：**Planning Draft（文件與工作包草案）**；2026-10-26。首次交付：M5；優先層：Full Vision；相對複雜度：L（不是工期）。

## 玩家價值與責任

擴充陪伴與移動外觀，並清楚區分戰鬥單位和養成加成。

**規則與邊界**：戰鬥寵物有自己的 AI／技能；乘坐影響速度／可施技／下坐；擁有、裝備、乘坐加成各列規則。

## 文件交付清單

- **玩法／系統規格 GDD**：預定 `design/gdd/battle-pets-guarders.md`。需將上方規則展開成正常流程、狀態轉移、拒絕原因、取消／重入／死亡／離線處理；有數值時附變數、單位、安全範圍與算例。
- **Godot 技術規格 TDD**：預定 `docs/architecture/systems/battle-pets-guarders.md`。需寫 scene tree、模組責任、資料所有權、命令／事件、更新時機、存讀／網路邊界與現有程式遷移方式。
- **此系統專屬內容**：三種類型界線與生命週期；跟隨／傳送政策；技能與乘坐表；QA：切圖／下坐／死亡。
- **QA 與證據規格**：預定 `production/qa/systems/battle-pets-guarders.md`。以本頁 AC 編號追溯測試／手測／真機證據，附內容版本與未驗證項；測試不能僅檢查檔案存在。

## 資料、介面與 Godot 實作邊界

**資料與狀態**：CompanionEntity；GuarderDefinition；MountState；FollowPolicy；modifier source IDs。

**對外契約**：CompanionController 使用既有移動／技能服務；MountCommand 只改明列的狀態與修正。

**scene／模組**：scenes/companions/、mount_visual.tscn；ui/companion_panel.tscn；不直接重用 PetCare 作戰鬥 AI。

## 相依與整合

共通開工條件與附件規則見[文件契約](../document-contracts.md)。

- 初始契約／首版必要前置：[S06 角色移動、選取與追擊](s06-movement-targeting.md)、[S07 屬性、生命、回復與死亡](s07-stats-vitals-death.md)、[S09 主動技能與狀態效果](s09-skills-statuses.md)、[S17 寵物餵食、成長與進化](s17-pet-care.md)、[S22 角色美術、方向、動畫與資產管線](s22-actor-art-animation.md)。
- 直接下游：無。

## 分階段 roadmap

M5 先一種跟隨或乘坐，後續才增加戰鬥寵物分支；若多人已啟用需權威服務擴充。

## 可驗收條件

- **AC-S34-01**：乘坐／下坐反覆操作不累加速度。
- **AC-S34-02**：切區／重生不留下前區寵物 entity。
- **AC-S34-03**：戰鬥寵物不攻擊死亡／不可達／未授權目標。

## 風險與開工條件

三類系統共用外觀但不同權威與生命週期，避免混用狀態。


## 2026-10-30 單機切片 checkpoint

已實作第 2 階解鎖乘坐與現有 entity 跟隨，範圍見 [GDD](../../gdd/battle-pets-guarders.md)、[TDD](../../../docs/architecture/systems/battle-pets-guarders.md)、[QA](../../../production/qa/systems/battle-pets-guarders.md)。AC-S34-01／02 有 L2 自動證據；AC-S34-03 未實作戰鬥 AI，真機視覺／操作仍待驗。這是 S34 部分交付。
