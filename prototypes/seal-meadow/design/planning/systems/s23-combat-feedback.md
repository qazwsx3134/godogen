# S23｜特效、跳字與打擊回饋

狀態：**Planning Draft（文件與工作包草案）**；2026-10-26。首次交付：M1；優先層：MVP；相對複雜度：M（不是工期）。

## 玩家價值與責任

不用連招也能看清普攻、技能、暴擊與升級的差別。

**規則與邊界**：命中事件唯一；特效不決定傷害；普通／暴擊／精英分強度；手機透明覆蓋與名牌有上限；震動可關。

## 文件交付清單

- **玩法／系統規格 GDD**：預定 `design/gdd/combat-feedback.md`。需將上方規則展開成正常流程、狀態轉移、拒絕原因、取消／重入／死亡／離線處理；有數值時附變數、單位、安全範圍與算例。
- **Godot 技術規格 TDD**：預定 `docs/architecture/systems/combat-feedback.md`。需寫 scene tree、模組責任、資料所有權、命令／事件、更新時機、存讀／網路邊界與現有程式遷移方式。
- **此系統專屬內容**：VFX event sheet／時間線／優先表；shader 與 renderer 降級規格；QA：30 FPS、過載、靜音。
- **QA 與證據規格**：預定 `production/qa/systems/combat-feedback.md`。以本頁 AC 編號追溯測試／手測／真機證據，附內容版本與未驗證項；測試不能僅檢查檔案存在。

## 資料、介面與 Godot 實作邊界

**資料與狀態**：FeedbackProfile；CombatEvent view payload；effect priority、duration、pool size；accessibility flags。

**對外契約**：FeedbackPresenter.consume(event) -> VFX/SFX/haptic requests；丟棄遠端低優先效果不丟戰鬥結果。

**scene／模組**：scenes/fx/hit_spark.tscn、slash_arc.tscn、level_up.tscn、floating_number.tscn；Compatibility 可用幾何。

## 相依與整合

共通開工條件與附件規則見[文件契約](../document-contracts.md)。

- 初始契約／首版必要前置：[S04 固定鏡頭、構圖與遮擋](s04-fixed-camera.md)、[S08 普攻、命中與傷害結算](s08-combat-resolution.md)、[S22 角色美術、方向、動畫與資產管線](s22-actor-art-animation.md)。
- 直接下游：[S35 時裝、光環與外觀收藏](s35-cosmetics-auras.md)。

## 分階段 roadmap

M1 普攻／受擊／暴擊／升級；M2 技能套件；M3 同屏限額、池化與關閉震動。

## 可驗收條件

- **AC-S23-01**：接觸、跳字與音效依同一 event id 對齊。
- **AC-S23-02**：特效池滿只降低演出，不吞傷害或卡住技能。
- **AC-S23-03**：玩家關掉震動／降低特效後仍可分辨命中與範圍危險。

## 風險與開工條件

全域 hit stop 不適合直接暫停未來多人權威時鐘。

