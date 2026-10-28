# S19｜聲望、收藏與成就

狀態：**Planning Draft（文件與工作包草案）**；2026-10-26。首次交付：M5；優先層：Full Vision；相對複雜度：M（不是工期）。

2026-10-28 依單機優先決定先實作薄切片：[GDD](../../gdd/fame-collections.md)、[TDD](../../../docs/architecture/systems/fame-collections.md)、[QA](../../../production/qa/systems/fame-collections.md)。真機與跨帳號擴充尚未驗證。

## 玩家價值與責任

提供等級以外的長期目標與角色身分。

**規則與邊界**：聲望、收藏擁有、成就完成／領獎各自保存；解鎖門檻可查；獎勵事件去重。

## 文件交付清單

- **玩法／系統規格 GDD**：預定 `design/gdd/fame-collections.md`。需將上方規則展開成正常流程、狀態轉移、拒絕原因、取消／重入／死亡／離線處理；有數值時附變數、單位、安全範圍與算例。
- **Godot 技術規格 TDD**：預定 `docs/architecture/systems/fame-collections.md`。需寫 scene tree、模組責任、資料所有權、命令／事件、更新時機、存讀／網路邊界與現有程式遷移方式。
- **此系統專屬內容**：聲望等級表、收藏清單與來源；解鎖矩陣；UX：下一目標；QA：舊存檔補發。
- **QA 與證據規格**：預定 `production/qa/systems/fame-collections.md`。以本頁 AC 編號追溯測試／手測／真機證據，附內容版本與未驗證項；測試不能僅檢查檔案存在。

## 資料、介面與 Godot 實作邊界

**資料與狀態**：FameLedger；RankThreshold；CollectionEntry；AchievementDefinition／ClaimState。

**對外契約**：MetaProgression.consume(event)；查條件輸出 unlock flags；領獎透過 S12 的應用層接入。

**scene／模組**：ui/collection_window.tscn、achievement_row.tscn、fame_badge.tscn；不引用整張 HUD 來查狀態。

## 相依與整合

共通開工條件與附件規則見[文件契約](../document-contracts.md)。

- 初始契約／首版必要前置：[S01 內容定義與資料登錄](s01-content-registry.md)、[S02 權威狀態、命令與時間](s02-authority-commands-clock.md)、[S14 經驗、職業、技能成長與轉職](s14-progression-jobs.md)。
- 直接下游：無。

## 分階段 roadmap

M5 先一條聲望與少量收藏；後續才擴跨活動／帳號成就。

## 可驗收條件

- **AC-S19-01**：同成就多次符合條件只發一次獎。
- **AC-S19-02**：尚未解鎖項目顯示明確取得方向。
- **AC-S19-03**：新增成就版本對舊存檔有補算或不補算的明確政策。

## 風險與開工條件

把收藏與掉落 ledger 混在一起會阻礙可交易重複裝備。

