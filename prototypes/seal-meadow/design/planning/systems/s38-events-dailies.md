# S38｜活動、每日與限時獎勵

狀態：**Planning Draft（文件與工作包草案）**；2026-10-26。首次交付：M5；優先層：Full Vision；相對複雜度：L（不是工期）。

## 玩家價值與責任

讓內容能按版本與時間更新，玩家知道何時能領什麼。

**規則與邊界**：服務端 UTC 定義活動時間與 reset；帳號／角色 claim scope 分開；補領、延長與版本變更明列。

## 文件交付清單

- **玩法／系統規格 GDD**：預定 `design/gdd/events-dailies.md`。需將上方規則展開成正常流程、狀態轉移、拒絕原因、取消／重入／死亡／離線處理；有數值時附變數、單位、安全範圍與算例。
- **Godot 技術規格 TDD**：預定 `docs/architecture/systems/events-dailies.md`。需寫 scene tree、模組責任、資料所有權、命令／事件、更新時機、存讀／網路邊界與現有程式遷移方式。
- **此系統專屬內容**：活動日曆、每日 reset／補領／claim 規格、獎勵經濟預算、UX：時區與剩餘時間、QA：邊界。
- **QA 與證據規格**：預定 `production/qa/systems/events-dailies.md`。以本頁 AC 編號追溯測試／手測／真機證據，附內容版本與未驗證項；測試不能僅檢查檔案存在。

## 資料、介面與 Godot 實作邊界

**資料與狀態**：EventSchedule；DailyDefinition；ClaimKey(account,period,reward)；EventProgress；content version。

**對外契約**：EventService.evaluate(now)／claim(command)；發獎使用 transaction；client 日曆僅顯示。

**scene／模組**：ui/event_window.tscn、daily_row.tscn；公告資料與 gameplay rewards 分開。

## 相依與整合

共通開工條件與附件規則見[文件契約](../document-contracts.md)。

- 初始契約／首版必要前置：[S01 內容定義與資料登錄](s01-content-registry.md)、[S02 權威狀態、命令與時間](s02-authority-commands-clock.md)、[S12 物品、背包、貨幣與交易原語](s12-inventory-transactions.md)、[S15 NPC、對話與任務](s15-quests-dialogue.md)、[S25 存檔、設定與手機生命週期](s25-persistence-lifecycle.md)、[S28 帳號、多人權威、AOI 與重連](s28-online-authority.md)。
- 直接下游：無。

## 分階段 roadmap

M5 一每日與一限時活動，先小規模校驗再加季節內容。

## 可驗收條件

- **AC-S38-01**：重設前後重送同 claim 不重複領取。
- **AC-S38-02**：本機改時間不能提前開活動。
- **AC-S38-03**：活動中途修內容版本有補償／保留進度規則。

## 風險與開工條件

營運內容改表也可能改動玩家資產，需版本與稽核。

