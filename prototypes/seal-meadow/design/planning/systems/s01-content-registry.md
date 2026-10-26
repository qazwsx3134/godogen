# S01｜內容定義與資料登錄

狀態：**Planning Draft（文件與工作包草案）**；2026-10-26。首次交付：M0；優先層：MVP；相對複雜度：M（不是工期）。

## 玩家價值與責任

讓怪物、物品、技能與任務使用可驗證的穩定 ID，內容製作不靠散落腳本常數。

**規則與邊界**：定義表不可在遊戲中直接改寫；ID 發布後不得重用；引用失效時回報錯誤並阻擋有問題的內容包進入可發佈建置。

## 文件交付清單

- **玩法／系統規格 GDD**：預定 `design/gdd/content-registry.md`。需將上方規則展開成正常流程、狀態轉移、拒絕原因、取消／重入／死亡／離線處理；有數值時附變數、單位、安全範圍與算例。
- **Godot 技術規格 TDD**：預定 `docs/architecture/systems/content-registry.md`。需寫 scene tree、模組責任、資料所有權、命令／事件、更新時機、存讀／網路邊界與現有程式遷移方式。
- **此系統專屬內容**：資料字典：ID 命名、型別、必填／預設、版本；內容引用規格：怪物→掉表→物品→圖示；QA：重複與失效引用。
- **QA 與證據規格**：預定 `production/qa/systems/content-registry.md`。以本頁 AC 編號追溯測試／手測／真機證據，附內容版本與未驗證項；測試不能僅檢查檔案存在。

## 資料、介面與 Godot 實作邊界

**資料與狀態**：ContentManifest(version, ids, asset_refs)；各類 Definition Resource；驗證報告(source_path, field, error_code)。

**對外契約**：ContentCatalog.lookup(kind,id) 提供唯讀定義；validate_manifest() 輸出結構化問題；不提供角色進度。

**scene／模組**：resources/definitions/；tools/validate_content.gd；編輯器／headless 工具，不建立遊戲畫面。

## 相依與整合

共通開工條件與附件規則見[文件契約](../document-contracts.md)。

- 初始契約／首版必要前置：無。
- 直接下游：[S02 權威狀態、命令與時間](s02-authority-commands-clock.md)、[S04 固定鏡頭、構圖與遮擋](s04-fixed-camera.md)、[S05 世界場景、碰撞與導航](s05-world-navigation.md)、[S07 屬性、生命、回復與死亡](s07-stats-vitals-death.md)、[S09 主動技能與狀態效果](s09-skills-statuses.md)、[S10 怪物 AI、仇恨與生成](s10-monster-ai-spawning.md)、[S11 掉落、地上物與拾取](s11-loot-pickup.md)、[S12 物品、背包、貨幣與交易原語](s12-inventory-transactions.md)、[S13 裝備屬性、紙娃娃與換裝](s13-equipment-paperdoll.md)、[S14 經驗、職業、技能成長與轉職](s14-progression-jobs.md)、[S15 NPC、對話與任務](s15-quests-dialogue.md)、[S16 NPC 商店、銀行與城鎮服務](s16-vendors-bank.md)、[S17 寵物餵食、成長與進化](s17-pet-care.md)、[S18 精煉、製作與材料消耗](s18-refine-crafting.md)、[S19 聲望、收藏與成就](s19-fame-collections.md)、[S20 手機 HUD、窗口與提示](s20-mobile-hud.md)、[S21 小地圖、旅行與區域切換](s21-map-travel.md)、[S22 角色美術、方向、動畫與資產管線](s22-actor-art-animation.md)、[S24 音樂、音效與環境音](s24-audio.md)、[S25 存檔、設定與手機生命週期](s25-persistence-lifecycle.md)、[S26 新手教學、設定、無障礙與文字](s26-onboarding-accessibility.md)、[S27 手機效能、測試、工具與匯出](s27-performance-build-qa.md)、[S38 活動、每日與限時獎勵](s38-events-dailies.md)、[S40 平衡、遙測、內容工具與營運稽核](s40-balance-telemetry-operations.md)。

## 分階段 roadmap

M0 先匯入一種怪、一件物品、一技能並查詢；M2 擴全部定義；後續加入內容版本相容性檢查。

## 可驗收條件

- **AC-S01-01**：兩筆相同 ID 必須回報兩個來源，不能默默取後者。
- **AC-S01-02**：未知物品／技能／圖示引用有欄位路徑與錯誤碼。
- **AC-S01-03**：兩角色引用同 Definition 時，改一人的狀態不改另一人數值。

## 風險與開工條件

把 Resource 當成可變狀態會污染所有實例。

