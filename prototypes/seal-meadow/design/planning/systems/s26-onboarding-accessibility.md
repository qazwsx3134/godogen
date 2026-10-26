# S26｜新手教學、設定、無障礙與文字

狀態：**Planning Draft（文件與工作包草案）**；2026-10-26。首次交付：M2；優先層：Vertical Slice；相對複雜度：M（不是工期）。

## 玩家價值與責任

新玩家不用桌面經驗，也能完成第一次戰鬥與成長。

**規則與邊界**：教學由成功操作推進；可跳過／重看；文字、圖示、聲音不單獨承載重要資訊；字級與效果設定保存。

## 文件交付清單

- **玩法／系統規格 GDD**：預定 `design/gdd/onboarding-accessibility.md`。需將上方規則展開成正常流程、狀態轉移、拒絕原因、取消／重入／死亡／離線處理；有數值時附變數、單位、安全範圍與算例。
- **Godot 技術規格 TDD**：預定 `docs/architecture/systems/onboarding-accessibility.md`。需寫 scene tree、模組責任、資料所有權、命令／事件、更新時機、存讀／網路邊界與現有程式遷移方式。
- **此系統專屬內容**：首次 5～10 分鐘 journey；教學事件矩陣；可讀性／字型／翻譯表；QA：跳過、重入與放大。
- **QA 與證據規格**：預定 `production/qa/systems/onboarding-accessibility.md`。以本頁 AC 編號追溯測試／手測／真機證據，附內容版本與未驗證項；測試不能僅檢查檔案存在。

## 資料、介面與 Godot 實作邊界

**資料與狀態**：TutorialStep(trigger,completion,skip)；AccessibilitySettings；Locale string table；font coverage report。

**對外契約**：Onboarding.consume(success_event)；SettingsCommand；文字介面使用 string ID，地區文案可替換。

**scene／模組**：ui/tutorial_hint.tscn、settings_window.tscn、confirmation_dialog.tscn；手機文字輸入／字型 fallback。

## 相依與整合

共通開工條件與附件規則見[文件契約](../document-contracts.md)。

- 初始契約／首版必要前置：[S01 內容定義與資料登錄](s01-content-registry.md)、[S03 觸控輸入與互動優先權](s03-touch-input.md)、[S20 手機 HUD、窗口與提示](s20-mobile-hud.md)、[S25 存檔、設定與手機生命週期](s25-persistence-lifecycle.md)。
- 直接下游：無。

## 分階段 roadmap

M2 三任務涵蓋點地／選怪／換裝；M3 寵物精煉提示、降低特效／文字；後期擴語言。

## 可驗收條件

- **AC-S26-01**：跳過教學不丟失任務／必要解鎖。
- **AC-S26-02**：調大文字後關閉與確認按鈕仍可點。
- **AC-S26-03**：所有首切片中文字元在匯出字型有字形，無方框。

## 風險與開工條件

把教學寫成不可跳過的大段文字會阻塞手機短遊玩。

