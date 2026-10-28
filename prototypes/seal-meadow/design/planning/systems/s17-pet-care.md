# S17｜寵物餵食、成長與進化

狀態：**Planning Draft（文件與工作包草案）**；2026-10-26。首次交付：M3；優先層：Vertical Slice；相對複雜度：L（不是工期）。

2026-10-28 已有單機原型切片與現行規格：[GDD](../../gdd/pet-care.md)、[TDD](../../../docs/architecture/systems/pet-care.md)、[QA](../../../production/qa/systems/pet-care.md)。D09 仍為暫定，真機與真人平衡尚未驗收。

## 玩家價值與責任

寵物提供陪伴與雜物用途，形成可預期的養成目標。

**規則與邊界**：飢餓、食物、經驗、進化材料／機率、裝卸與區域暫停分開；是否餓死／離線下降是待定風險，不能照搬舊 Wiki。

## 文件交付清單

- **玩法／系統規格 GDD**：預定 `design/gdd/pet-care.md`。需將上方規則展開成正常流程、狀態轉移、拒絕原因、取消／重入／死亡／離線處理；有數值時附變數、單位、安全範圍與算例。
- **Godot 技術規格 TDD**：預定 `docs/architecture/systems/pet-care.md`。需寫 scene tree、模組責任、資料所有權、命令／事件、更新時機、存讀／網路邊界與現有程式遷移方式。
- **此系統專屬內容**：GDD：照護與失敗後果；公式：餵食／飢餓／進化；UX：材料與風險預覽；QA：背景／卸裝。
- **QA 與證據規格**：預定 `production/qa/systems/pet-care.md`。以本頁 AC 編號追溯測試／手測／真機證據，附內容版本與未驗證項；測試不能僅檢查檔案存在。

## 資料、介面與 Godot 實作邊界

**資料與狀態**：PetDefinition；PetState(stage,level,xp,hunger,last_tick)；FoodRule；EvolutionRecipe；modifier source。

**對外契約**：PetService.tick(context)／FeedCommand／EvolveCommand；材料交 Transaction；輸出外觀與屬性變更。

**scene／模組**：scenes/pets/pet_visual.tscn；ui/pet_panel.tscn、feed_window.tscn；pet_care 只作規則來源評估，不直接採全部預設。

## 相依與整合

共通開工條件與附件規則見[文件契約](../document-contracts.md)。

- 初始契約／首版必要前置：[S01 內容定義與資料登錄](s01-content-registry.md)、[S02 權威狀態、命令與時間](s02-authority-commands-clock.md)、[S07 屬性、生命、回復與死亡](s07-stats-vitals-death.md)、[S12 物品、背包、貨幣與交易原語](s12-inventory-transactions.md)、[S22 角色美術、方向、動畫與資產管線](s22-actor-art-animation.md)、[S25 存檔、設定與手機生命週期](s25-persistence-lifecycle.md)。
- 直接下游：[S34 戰鬥寵物、守護者與乘坐](s34-battle-pets-guarders.md)。

## 分階段 roadmap

M3 一寵物、餵食、一次進化與存讀；M5 稀有分支；不以稀有機率充當已知原作數據。

## 可驗收條件

- **AC-S17-01**：同份食物只扣一次，失敗交易不加寵物 EXP。
- **AC-S17-02**：進城、背景與離線時間按規格一致，改本機時間不能無界獲利。
- **AC-S17-03**：裝卸不重複疊屬性，進化結果可保存重開。

## 風險與開工條件

手機背景／離線養成若沿用每幀 delta，狀態會與真實時間脫節。

