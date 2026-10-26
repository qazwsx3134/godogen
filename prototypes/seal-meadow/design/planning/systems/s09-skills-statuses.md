# S09｜主動技能與狀態效果

狀態：**Planning Draft（文件與工作包草案）**；2026-10-26。首次交付：M1；優先層：MVP；相對複雜度：L（不是工期）。

## 玩家價值與責任

用少量好讀的技能提供決策，而不是高頻按鍵負擔。

**規則與邊界**：首輪一技能，切片擴 2～3；明定射程、AP、冷卻、施法中斷與移動施放；buff 同源疊加／刷新規則一致。

## 文件交付清單

- **玩法／系統規格 GDD**：預定 `design/gdd/skills-statuses.md`。需將上方規則展開成正常流程、狀態轉移、拒絕原因、取消／重入／死亡／離線處理；有數值時附變數、單位、安全範圍與算例。
- **Godot 技術規格 TDD**：預定 `docs/architecture/systems/skills-statuses.md`。需寫 scene tree、模組責任、資料所有權、命令／事件、更新時機、存讀／網路邊界與現有程式遷移方式。
- **此系統專屬內容**：每技能規格卡：定位、數值、事件時間線；狀態互動表；UX：冷卻與拒絕原因；QA：中斷／疊加。
- **QA 與證據規格**：預定 `production/qa/systems/skills-statuses.md`。以本頁 AC 編號追溯測試／手測／真機證據，附內容版本與未驗證項；測試不能僅檢查檔案存在。

## 資料、介面與 Godot 實作邊界

**資料與狀態**：SkillDefinition(cost,cooldown,range,target,cast_time,effects)；SkillRuntime；StatusInstance。

**對外契約**：SkillService.try_cast(command) 驗證後交 EffectResolver；UI request 不自己扣 AP；結果碼包含原因。

**scene／模組**：ui/skill_button.tscn；skills/<id>.tscn（僅需視覺時）；actor cast 動畫與 domain 同步。

## 相依與整合

共通開工條件與附件規則見[文件契約](../document-contracts.md)。

- 初始契約／首版必要前置：[S01 內容定義與資料登錄](s01-content-registry.md)、[S02 權威狀態、命令與時間](s02-authority-commands-clock.md)、[S07 屬性、生命、回復與死亡](s07-stats-vitals-death.md)、[S08 普攻、命中與傷害結算](s08-combat-resolution.md)。
- 直接下游：[S34 戰鬥寵物、守護者與乘坐](s34-battle-pets-guarders.md)、[S36 副本、首領與遭遇導演](s36-dungeons-bosses.md)、[S37 決鬥與 PvP 規則](s37-duels-pvp.md)。

## 分階段 roadmap

M1 一個單體技能；M2 第二技能與一種 buff；M3 範圍技／控制與抗性；不增加連招系統。

## 可驗收條件

- **AC-S09-01**：AP 不足／超距離不消耗資源且顯示拒絕原因。
- **AC-S09-02**：快速點兩次只成功一次，不雙扣 AP。
- **AC-S09-03**：同一 buff 刷新後到期只移除自己的加成。

## 風險與開工條件

大量技能組合會使狀態互動矩陣迅速擴張。

