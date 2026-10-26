# S07｜屬性、生命、回復與死亡

狀態：**Planning Draft（文件與工作包草案）**；2026-10-26。首次交付：M1；優先層：MVP；相對複雜度：M（不是工期）。

## 玩家價值與責任

讓傷害、成長與生存規則可理解且可測。

**規則與邊界**：base＋equipment＋buff 分層計算；HP/AP clamp；死亡只觸發一次；休息與脫戰回復需與受擊中斷規則一起定義。

## 文件交付清單

- **玩法／系統規格 GDD**：預定 `design/gdd/stats-vitals-death.md`。需將上方規則展開成正常流程、狀態轉移、拒絕原因、取消／重入／死亡／離線處理；有數值時附變數、單位、安全範圍與算例。
- **Godot 技術規格 TDD**：預定 `docs/architecture/systems/stats-vitals-death.md`。需寫 scene tree、模組責任、資料所有權、命令／事件、更新時機、存讀／網路邊界與現有程式遷移方式。
- **此系統專屬內容**：GDD：屬性、回復、死亡懲罰；公式：取整／上限／順序；TDD：modifier 生命週期；QA：死亡競態。
- **QA 與證據規格**：預定 `production/qa/systems/stats-vitals-death.md`。以本頁 AC 編號追溯測試／手測／真機證據，附內容版本與未驗證項；測試不能僅檢查檔案存在。

## 資料、介面與 Godot 實作邊界

**資料與狀態**：StatBlock；Modifier(source_id,stack_rule)；Vitals(hp,ap)；LifeState；RespawnPolicy。

**對外契約**：StatService.rebuild(inputs)；Vitals.apply_delta(event_id)；死亡事件通知 AI／任務，UI 只讀。

**scene／模組**：角色 scene 掛 HealthComponent／StatBinding；sleep 動畫由狀態事件驅動。

## 相依與整合

共通開工條件與附件規則見[文件契約](../document-contracts.md)。

- 初始契約／首版必要前置：[S01 內容定義與資料登錄](s01-content-registry.md)、[S02 權威狀態、命令與時間](s02-authority-commands-clock.md)。
- 直接下游：[S08 普攻、命中與傷害結算](s08-combat-resolution.md)、[S09 主動技能與狀態效果](s09-skills-statuses.md)、[S10 怪物 AI、仇恨與生成](s10-monster-ai-spawning.md)、[S13 裝備屬性、紙娃娃與換裝](s13-equipment-paperdoll.md)、[S14 經驗、職業、技能成長與轉職](s14-progression-jobs.md)、[S17 寵物餵食、成長與進化](s17-pet-care.md)、[S28 帳號、多人權威、AOI 與重連](s28-online-authority.md)、[S32 情侶、雙人互動與表情](s32-relationships-emotes.md)、[S34 戰鬥寵物、守護者與乘坐](s34-battle-pets-guarders.md)、[S35 時裝、光環與外觀收藏](s35-cosmetics-auras.md)、[S37 決鬥與 PvP 規則](s37-duels-pvp.md)。

## 分階段 roadmap

M1 HP、受擊、死亡／重生與測試回復；M2 AP、睡覺與裝備修正；M3 決定正式死亡成本。

## 可驗收條件

- **AC-S07-01**：連續兩筆致命事件只掉獎／死亡通知一次。
- **AC-S07-02**：卸下加血裝備後 HP 不超新 max，政策明確。
- **AC-S07-03**：移除 buff 後數值還原，不累積重複 modifier。

## 風險與開工條件

原型自動回血不自動成為正式生存平衡。

