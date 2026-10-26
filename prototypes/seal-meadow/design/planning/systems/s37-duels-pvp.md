# S37｜決鬥與 PvP 規則

狀態：**Planning Draft（文件與工作包草案）**；2026-10-26。首次交付：M5；優先層：Full Vision；相對複雜度：L（不是工期）。

## 玩家價值與責任

以雙方同意的對戰測試職業互動，不破壞 PvE 生存與經濟。

**規則與邊界**：邀請、接受、倒數、範圍、勝敗／離線；PvP 倍率、控制遞減與死亡後果獨立於 PvE。

## 文件交付清單

- **玩法／系統規格 GDD**：預定 `design/gdd/duels-pvp.md`。需將上方規則展開成正常流程、狀態轉移、拒絕原因、取消／重入／死亡／離線處理；有數值時附變數、單位、安全範圍與算例。
- **Godot 技術規格 TDD**：預定 `docs/architecture/systems/duels-pvp.md`。需寫 scene tree、模組責任、資料所有權、命令／事件、更新時機、存讀／網路邊界與現有程式遷移方式。
- **此系統專屬內容**：同意與結束狀態機、PvP 平衡表、技能互動矩陣、UX／QA：離線與越界。
- **QA 與證據規格**：預定 `production/qa/systems/duels-pvp.md`。以本頁 AC 編號追溯測試／手測／真機證據，附內容版本與未驗證項；測試不能僅檢查檔案存在。

## 資料、介面與 Godot 實作邊界

**資料與狀態**：DuelSession；PvPRuleSet；Consent；Boundary；Result／cooldown。

**對外契約**：DuelService 將規則 context 注入 CombatService；不得另複製一套不一致傷害。

**scene／模組**：ui/duel_prompt.tscn、duel_result.tscn；duel boundary scene／marker。

## 相依與整合

共通開工條件與附件規則見[文件契約](../document-contracts.md)。

- 初始契約／首版必要前置：[S07 屬性、生命、回復與死亡](s07-stats-vitals-death.md)、[S08 普攻、命中與傷害結算](s08-combat-resolution.md)、[S09 主動技能與狀態效果](s09-skills-statuses.md)、[S28 帳號、多人權威、AOI 與重連](s28-online-authority.md)、[S29 隊伍、聊天與好友](s29-party-chat-friends.md)。
- 直接下游：無。

## 分階段 roadmap

M5 先 1v1 無排位／下注；後續競技場另定內容與配對範圍。

## 可驗收條件

- **AC-S37-01**：未同意者不承受 PvP 傷害。
- **AC-S37-02**：決鬥死亡不套 PvE 掉落／經驗懲罰。
- **AC-S37-03**：一方斷線或越界結果唯一，兩 client 顯示一致。

## 風險與開工條件

手機延遲與職業平衡使 PvP 風險高，排在 PvE 循環之後。

