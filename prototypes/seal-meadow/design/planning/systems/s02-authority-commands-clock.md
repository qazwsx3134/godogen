# S02｜權威狀態、命令與時間

狀態：**Planning Draft（文件與工作包草案）**；2026-10-26。首次交付：M0；優先層：MVP；相對複雜度：L（不是工期）。

## 玩家價值與責任

先讓單機也有單一結算入口，日後網路化不重寫傷害與物品規則。

**規則與邊界**：命令先驗證再提交；成功事件只發布一次；domain 時鐘、動畫時鐘、真實時間分開；本機權威不是多人安全保證。

## 文件交付清單

- **玩法／系統規格 GDD**：預定 `design/gdd/authority-commands-clock.md`。需將上方規則展開成正常流程、狀態轉移、拒絕原因、取消／重入／死亡／離線處理；有數值時附變數、單位、安全範圍與算例。
- **Godot 技術規格 TDD**：預定 `docs/architecture/systems/authority-commands-clock.md`。需寫 scene tree、模組責任、資料所有權、命令／事件、更新時機、存讀／網路邊界與現有程式遷移方式。
- **此系統專屬內容**：契約文件：命令結果與錯誤碼；時間規格：暫停／背景／離線；ADR（D08 後）：是否需要網路權威。
- **QA 與證據規格**：預定 `production/qa/systems/authority-commands-clock.md`。以本頁 AC 編號追溯測試／手測／真機證據，附內容版本與未驗證項；測試不能僅檢查檔案存在。

## 資料、介面與 Godot 實作邊界

**資料與狀態**：Command(id,actor_id,type,payload)；Result(code,revision,events)；GameClock；領域服務介面。

**對外契約**：GameAuthority.execute(command) -> Result；Presentation 只能請求命令／讀快照；M0 只有本機實作；網路 adapter 等 D08 決定後才設計。

**scene／模組**：scripts/domain/ 與 scripts/application/ 邊界規格；明確組裝服務，不建立全域萬用 singleton。

## 相依與整合

共通開工條件與附件規則見[文件契約](../document-contracts.md)。

- 初始契約／首版必要前置：[S01 內容定義與資料登錄](s01-content-registry.md)。
- 直接下游：[S03 觸控輸入與互動優先權](s03-touch-input.md)、[S06 角色移動、選取與追擊](s06-movement-targeting.md)、[S07 屬性、生命、回復與死亡](s07-stats-vitals-death.md)、[S08 普攻、命中與傷害結算](s08-combat-resolution.md)、[S09 主動技能與狀態效果](s09-skills-statuses.md)、[S11 掉落、地上物與拾取](s11-loot-pickup.md)、[S12 物品、背包、貨幣與交易原語](s12-inventory-transactions.md)、[S14 經驗、職業、技能成長與轉職](s14-progression-jobs.md)、[S15 NPC、對話與任務](s15-quests-dialogue.md)、[S16 NPC 商店、銀行與城鎮服務](s16-vendors-bank.md)、[S17 寵物餵食、成長與進化](s17-pet-care.md)、[S18 精煉、製作與材料消耗](s18-refine-crafting.md)、[S19 聲望、收藏與成就](s19-fame-collections.md)、[S21 小地圖、旅行與區域切換](s21-map-travel.md)、[S24 音樂、音效與環境音](s24-audio.md)、[S25 存檔、設定與手機生命週期](s25-persistence-lifecycle.md)、[S28 帳號、多人權威、AOI 與重連](s28-online-authority.md)、[S29 隊伍、聊天與好友](s29-party-chat-friends.md)、[S33 釣魚與休閒採集](s33-fishing.md)、[S38 活動、每日與限時獎勵](s38-events-dailies.md)、[S40 平衡、遙測、內容工具與營運稽核](s40-balance-telemetry-operations.md)。

## 分階段 roadmap

M0 單一結算入口＋可注入時鐘與 seed；M1 接戰鬥；M2 接交易；冪等重送、服務端執行等 D08 選定多人後再加。

## 可驗收條件

- **AC-S02-01**：所有扣血、發物、扣料都經同一結算入口；UI／動畫回呼直接改狀態的測試會失敗。
- **AC-S02-02**：固定時鐘與 seed 可重播相同戰鬥結果。
- **AC-S02-03**：暫停／背景期間 domain 時鐘不前進，返回後不補算戰鬥。

## 風險與開工條件

不要為未定規模先做通用事件框架；只定必要邊界。

