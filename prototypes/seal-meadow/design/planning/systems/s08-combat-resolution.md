# S08｜普攻、命中與傷害結算

狀態：**Planning Draft（文件與工作包草案）**；2026-10-26。首次交付：M1；優先層：MVP；相對複雜度：L（不是工期）。

## 玩家價值與責任

自動普攻仍有可靠節奏、命中回饋與目標選擇價值。

**規則與邊界**：Attack windup/contact/recovery 分開；接觸時檢查存活、距離與區域；server/domain 一次結算；無連招 gauge 或輸入窗。

## 文件交付清單

- **玩法／系統規格 GDD**：預定 `design/gdd/combat-resolution.md`。需將上方規則展開成正常流程、狀態轉移、拒絕原因、取消／重入／死亡／離線處理；有數值時附變數、單位、安全範圍與算例。
- **Godot 技術規格 TDD**：預定 `docs/architecture/systems/combat-resolution.md`。需寫 scene tree、模組責任、資料所有權、命令／事件、更新時機、存讀／網路邊界與現有程式遷移方式。
- **此系統專屬內容**：GDD：普攻時序、miss／crit／減傷；公式與算例；TDD：取消 token／唯一事件；QA：低 FPS 與換目標。
- **QA 與證據規格**：預定 `production/qa/systems/combat-resolution.md`。以本頁 AC 編號追溯測試／手測／真機證據，附內容版本與未驗證項；測試不能僅檢查檔案存在。

## 資料、介面與 Godot 實作邊界

**資料與狀態**：AttackDefinition；AttackInstance(id,start,contact,target)；DamageResult(hit,crit,amount)；combat log。

**對外契約**：CombatService.start_attack／resolve_contact -> CombatEvent；演出可預播但不直接扣血；取消帶 reason。

**scene／模組**：attack 行為腳本與 actor scene 分離；受擊／跳字使用 S23；現有 await 計時需防取消後舊回呼。

## 相依與整合

共通開工條件與附件規則見[文件契約](../document-contracts.md)。

- 初始契約／首版必要前置：[S02 權威狀態、命令與時間](s02-authority-commands-clock.md)、[S06 角色移動、選取與追擊](s06-movement-targeting.md)、[S07 屬性、生命、回復與死亡](s07-stats-vitals-death.md)。
- 直接下游：[S09 主動技能與狀態效果](s09-skills-statuses.md)、[S10 怪物 AI、仇恨與生成](s10-monster-ai-spawning.md)、[S11 掉落、地上物與拾取](s11-loot-pickup.md)、[S23 特效、跳字與打擊回饋](s23-combat-feedback.md)、[S28 帳號、多人權威、AOI 與重連](s28-online-authority.md)、[S37 決鬥與 PvP 規則](s37-duels-pvp.md)。

## 分階段 roadmap

M1 一個普攻與固定數值；M2 資料化命中暴擊／裝備差異；M4 權威網路結果與回饋對齊。

## 可驗收條件

- **AC-S08-01**：一次揮擊只結算一次，即使動畫回呼與計時器同時到達。
- **AC-S08-02**：出手後死亡／換區，舊接觸回呼不造成傷害。
- **AC-S08-03**：30／60 FPS 的測試同樣時間內攻擊次數一致。

## 風險與開工條件

攻速、動畫速率與 cooldown 必須由同一份規則對齊。

