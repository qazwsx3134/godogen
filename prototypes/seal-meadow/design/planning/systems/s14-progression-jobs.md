# S14｜經驗、職業、技能成長與轉職

狀態：**Planning Draft（文件與工作包草案）**；2026-10-26。首次交付：M1；優先層：MVP；相對複雜度：L（不是工期）。

## 玩家價值與責任

短時間遊玩也有成長，長期職業有不同決策而非僅倍率差。

**規則與邊界**：經驗門檻、連升、屬性／技能點、等級上限、技能前置、洗點與轉職條件明確；先一職業。

## 文件交付清單

- **玩法／系統規格 GDD**：預定 `design/gdd/progression-jobs.md`。需將上方規則展開成正常流程、狀態轉移、拒絕原因、取消／重入／死亡／離線處理；有數值時附變數、單位、安全範圍與算例。
- **Godot 技術規格 TDD**：預定 `docs/architecture/systems/progression-jobs.md`。需寫 scene tree、模組責任、資料所有權、命令／事件、更新時機、存讀／網路邊界與現有程式遷移方式。
- **此系統專屬內容**：成長曲線表與算例；職業定位／技能前置圖；點數 UI；QA：跨多級與重置。
- **QA 與證據規格**：預定 `production/qa/systems/progression-jobs.md`。以本頁 AC 編號追溯測試／手測／真機證據，附內容版本與未驗證項；測試不能僅檢查檔案存在。

## 資料、介面與 Godot 實作邊界

**資料與狀態**：ProgressionCurve；CharacterProgress(level,xp,points,job_id)；SkillUnlockGraph；JobRequirement。

**對外契約**：ProgressionService.award_xp(source_id)；SpendPointCommand；轉職任務完成旗標由 S15 提供應用層協調。

**scene／模組**：純計算 Resource＋ui/character_window.tscn、skill_tree.tscn；不直接改角色腳本常數。

## 相依與整合

共通開工條件與附件規則見[文件契約](../document-contracts.md)。

- 初始契約／首版必要前置：[S01 內容定義與資料登錄](s01-content-registry.md)、[S02 權威狀態、命令與時間](s02-authority-commands-clock.md)、[S07 屬性、生命、回復與死亡](s07-stats-vitals-death.md)。
- 直接下游：[S13 裝備屬性、紙娃娃與換裝](s13-equipment-paperdoll.md)、[S15 NPC、對話與任務](s15-quests-dialogue.md)、[S19 聲望、收藏與成就](s19-fame-collections.md)。

## 分階段 roadmap

M1 最小 EXP／升級；M2 配點與一職業曲線；M3 一次轉職路徑；其餘職業另列內容量。

## 可驗收條件

- **AC-S14-01**：一次足夠多 EXP 可正確連升，溢出按規格保留。
- **AC-S14-02**：未達前置不能消耗技能點，重送不再扣點。
- **AC-S14-03**：洗點後有效點數與花費總量可對帳。

## 風險與開工條件

職業數量與技能內容膨脹，先驗一職業完整循環。

