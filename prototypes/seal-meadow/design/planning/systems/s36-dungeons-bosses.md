# S36｜副本、首領與遭遇導演

狀態：**Planning Draft（文件與工作包草案）**；2026-10-26。首次交付：M5；優先層：Full Vision；相對複雜度：XL（不是工期）。

## 玩家價值與責任

在成長循環之外提供可學習、可合作的挑戰目標。

**規則與邊界**：入口條件、隊伍、instance、階段、預警、團滅重置與獎勵次數明定；固定鏡頭可看清全戰區。

## 文件交付清單

- **玩法／系統規格 GDD**：預定 `design/gdd/dungeons-bosses.md`。需將上方規則展開成正常流程、狀態轉移、拒絕原因、取消／重入／死亡／離線處理；有數值時附變數、單位、安全範圍與算例。
- **Godot 技術規格 TDD**：預定 `docs/architecture/systems/dungeons-bosses.md`。需寫 scene tree、模組責任、資料所有權、命令／事件、更新時機、存讀／網路邊界與現有程式遷移方式。
- **此系統專屬內容**：副本 layout／pacing、首領時間線與技能表、獎勵與重置、UX：團滅／預警、QA：重連／跨階段。
- **QA 與證據規格**：預定 `production/qa/systems/dungeons-bosses.md`。以本頁 AC 編號追溯測試／手測／真機證據，附內容版本與未驗證項；測試不能僅檢查檔案存在。

## 資料、介面與 Godot 實作邊界

**資料與狀態**：EncounterDefinition；BossPhaseGraph；InstanceContext；Lockout；RewardClaim；hazard areas。

**對外契約**：EncounterDirector 依事件切階段，技能走 S09；獎勵走 S11/S12；隊伍與實例成員分開驗證。

**scene／模組**：scenes/dungeons/、boss_arena.tscn、hazard_indicator.tscn；入口與安全點為實際節點。

## 相依與整合

共通開工條件與附件規則見[文件契約](../document-contracts.md)。

- 初始契約／首版必要前置：[S05 世界場景、碰撞與導航](s05-world-navigation.md)、[S09 主動技能與狀態效果](s09-skills-statuses.md)、[S10 怪物 AI、仇恨與生成](s10-monster-ai-spawning.md)、[S11 掉落、地上物與拾取](s11-loot-pickup.md)、[S15 NPC、對話與任務](s15-quests-dialogue.md)、[S28 帳號、多人權威、AOI 與重連](s28-online-authority.md)、[S29 隊伍、聊天與好友](s29-party-chat-friends.md)。
- 直接下游：無。

## 分階段 roadmap

M5 一個短副本＋一首領；再驗證可重玩與多人重連，未驗前不大量做 raid。

## 可驗收條件

- **AC-S36-01**：團滅後危險物／仇恨／計時器全部回到初態。
- **AC-S36-02**：離開再進不能重複領同一輪獎。
- **AC-S36-03**：固定視角與低特效模式都看得見預警與安全區。

## 風險與開工條件

多階段與持續技能常造成舊回呼污染下一輪。

