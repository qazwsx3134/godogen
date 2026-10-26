# S15｜NPC、對話與任務

狀態：**Planning Draft（文件與工作包草案）**；2026-10-26。首次交付：M2；優先層：Vertical Slice；相對複雜度：L（不是工期）。

## 玩家價值與責任

引導玩家認識世界與成長目標，回城有具體目的。

**規則與邊界**：Available/Active/Ready/Claimed；打怪／收集／互動目標；提交條件、消耗與獎勵在同一權威操作；文字使用 string ID。

## 文件交付清單

- **玩法／系統規格 GDD**：預定 `design/gdd/quests-dialogue.md`。需將上方規則展開成正常流程、狀態轉移、拒絕原因、取消／重入／死亡／離線處理；有數值時附變數、單位、安全範圍與算例。
- **Godot 技術規格 TDD**：預定 `docs/architecture/systems/quests-dialogue.md`。需寫 scene tree、模組責任、資料所有權、命令／事件、更新時機、存讀／網路邊界與現有程式遷移方式。
- **此系統專屬內容**：任務卡／對話圖／事件映射；UX：接取、追蹤、提交；資料：文字與獎勵；QA：可達性／重複領獎。
- **QA 與證據規格**：預定 `production/qa/systems/quests-dialogue.md`。以本頁 AC 編號追溯測試／手測／真機證據，附內容版本與未驗證項；測試不能僅檢查檔案存在。

## 資料、介面與 Godot 實作邊界

**資料與狀態**：QuestDefinition(prereqs,objectives,rewards)；QuestProgress；DialogueNode/Choice；NPC services。

**對外契約**：QuestService.consume(domain_event)／claim(command)；對話條件查只讀狀態；完成通知不直接生道具。

**scene／模組**：scenes/npc/npc.tscn；ui/dialogue_window.tscn、quest_tracker.tscn、quest_log.tscn；劇本格式先查現有工具。

## 相依與整合

共通開工條件與附件規則見[文件契約](../document-contracts.md)。

- 初始契約／首版必要前置：[S01 內容定義與資料登錄](s01-content-registry.md)、[S02 權威狀態、命令與時間](s02-authority-commands-clock.md)、[S12 物品、背包、貨幣與交易原語](s12-inventory-transactions.md)、[S14 經驗、職業、技能成長與轉職](s14-progression-jobs.md)。
- 直接下游：[S36 副本、首領與遭遇導演](s36-dungeons-bosses.md)、[S38 活動、每日與限時獎勵](s38-events-dailies.md)。

## 分階段 roadmap

M2 三任務串起教學與回城；M3 分支／日常前置；主線內容按章另外估量。

## 可驗收條件

- **AC-S15-01**：殺怪事件重送不重複加進度。
- **AC-S15-02**：滿包提交不扣任務物且不標已領。
- **AC-S15-03**：對話關窗／換區／重開後任務可繼續且無死路。

## 風險與開工條件

任務與背包互相查整包容易形成循環；用條件查詢與事件。

