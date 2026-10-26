# S12｜物品、背包、貨幣與交易原語

狀態：**Planning Draft（文件與工作包草案）**；2026-10-26。首次交付：M0；優先層：MVP；相對複雜度：L（不是工期）。

## 玩家價值與責任

讓所有物品增減有一致規則，支撐裝備、掉落、商店與長期經濟。

**規則與邊界**：唯一裝備有 instance ID；可堆疊物依定義上限；整數數量與貨幣不得負值；跨容器操作全成或全不成。

## 文件交付清單

- **玩法／系統規格 GDD**：預定 `design/gdd/inventory-transactions.md`。需將上方規則展開成正常流程、狀態轉移、拒絕原因、取消／重入／死亡／離線處理；有數值時附變數、單位、安全範圍與算例。
- **Godot 技術規格 TDD**：預定 `docs/architecture/systems/inventory-transactions.md`。需寫 scene tree、模組責任、資料所有權、命令／事件、更新時機、存讀／網路邊界與現有程式遷移方式。
- **此系統專屬內容**：資料字典：堆疊／綁定／鎖定／容量；交易原語與錯誤碼；UX：選取、拆堆、比較；QA：溢位／回滾。
- **QA 與證據規格**：預定 `production/qa/systems/inventory-transactions.md`。以本頁 AC 編號追溯測試／手測／真機證據，附內容版本與未驗證項；測試不能僅檢查檔案存在。

## 資料、介面與 Godot 實作邊界

**資料與狀態**：ItemDefinition；ItemInstance(uuid,definition_id,rolls,refine,bind)；InventoryState；CurrencyLedger；revision。

**對外契約**：InventoryTransaction.validate/commit，回 Delta；業務服務提出變更集合，不直接改 UI slot；持久化由 repository 接管。

**scene／模組**：純 domain model；ui/item_slot.tscn 是展示；容器服務不依賴 HUD／場景節點。

## 相依與整合

共通開工條件與附件規則見[文件契約](../document-contracts.md)。

- 初始契約／首版必要前置：[S01 內容定義與資料登錄](s01-content-registry.md)、[S02 權威狀態、命令與時間](s02-authority-commands-clock.md)。
- 直接下游：[S11 掉落、地上物與拾取](s11-loot-pickup.md)、[S13 裝備屬性、紙娃娃與換裝](s13-equipment-paperdoll.md)、[S15 NPC、對話與任務](s15-quests-dialogue.md)、[S16 NPC 商店、銀行與城鎮服務](s16-vendors-bank.md)、[S17 寵物餵食、成長與進化](s17-pet-care.md)、[S18 精煉、製作與材料消耗](s18-refine-crafting.md)、[S28 帳號、多人權威、AOI 與重連](s28-online-authority.md)、[S30 玩家交易與擺攤](s30-trade-stalls.md)、[S31 公會與公會資源](s31-guilds.md)、[S33 釣魚與休閒採集](s33-fishing.md)、[S38 活動、每日與限時獎勵](s38-events-dailies.md)、[S39 商城、付費與權益](s39-commerce.md)。

## 分階段 roadmap

M0 最小 add/remove／模擬存檔；M1 最小背包 UI；M2 裝備／買賣／精煉共用；M4 DB 原子提交。

## 可驗收條件

- **AC-S12-01**：扣材料後空間不足的失敗操作不留半套變更。
- **AC-S12-02**：同裝備 uuid 不同時存在背包與倉庫。
- **AC-S12-03**：貨幣不足、非法負數、版本衝突均拒絕且不改狀態。

## 風險與開工條件

這是經濟瓶頸，應先定義再讓各功能各寫一套扣料。

