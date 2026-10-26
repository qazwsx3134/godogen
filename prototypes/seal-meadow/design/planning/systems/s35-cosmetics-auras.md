# S35｜時裝、光環與外觀收藏

狀態：**Planning Draft（文件與工作包草案）**；2026-10-26。首次交付：M5；優先層：Full Vision；相對複雜度：M（不是工期）。

## 玩家價值與責任

提供可展示的個性，保持小螢幕戰鬥可讀。

**規則與邊界**：外觀覆寫與裝備能力分開；光環是否加數值明列；特效縮減不影響規則；預覽不改已裝狀態。

## 文件交付清單

- **玩法／系統規格 GDD**：預定 `design/gdd/cosmetics-auras.md`。需將上方規則展開成正常流程、狀態轉移、拒絕原因、取消／重入／死亡／離線處理；有數值時附變數、單位、安全範圍與算例。
- **Godot 技術規格 TDD**：預定 `docs/architecture/systems/cosmetics-auras.md`。需寫 scene tree、模組責任、資料所有權、命令／事件、更新時機、存讀／網路邊界與現有程式遷移方式。
- **此系統專屬內容**：外觀欄位／覆寫矩陣；取得／預覽流程；VFX cap；QA：切裝與遠距離裁減。
- **QA 與證據規格**：預定 `production/qa/systems/cosmetics-auras.md`。以本頁 AC 編號追溯測試／手測／真機證據，附內容版本與未驗證項；測試不能僅檢查檔案存在。

## 資料、介面與 Godot 實作邊界

**資料與狀態**：CosmeticDefinition；OwnedCosmetics；AppearanceOverride；AuraEffectProfile；visibility tier。

**對外契約**：AppearanceService.resolve(equipment,cosmetics)；持有資格查詢不由 UI 偽造；數值光環交 StatService。

**scene／模組**：ui/wardrobe_window.tscn、preview_actor.tscn；光環附件 scene＋distance LOD。

## 相依與整合

共通開工條件與附件規則見[文件契約](../document-contracts.md)。

- 初始契約／首版必要前置：[S07 屬性、生命、回復與死亡](s07-stats-vitals-death.md)、[S13 裝備屬性、紙娃娃與換裝](s13-equipment-paperdoll.md)、[S22 角色美術、方向、動畫與資產管線](s22-actor-art-animation.md)、[S23 特效、跳字與打擊回饋](s23-combat-feedback.md)。
- 直接下游：[S39 商城、付費與權益](s39-commerce.md)。

## 分階段 roadmap

M5 時裝覆寫＋一光環；商城購入資格由 S39 後續接入。

## 可驗收條件

- **AC-S35-01**：預覽取消恢復原外觀，能力值完全不受預覽影響。
- **AC-S35-02**：關閉他人光環仍可看見必要戰鬥危險提示。
- **AC-S35-03**：無持有資格的外觀裝備命令被權威端拒絕。

## 風險與開工條件

光環過多會拉高 overdraw 並遮住怪物。

