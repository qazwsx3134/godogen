# S03｜觸控輸入與互動優先權

狀態：**Planning Draft（文件與工作包草案）**；2026-10-26。首次交付：M0；優先層：MVP；相對複雜度：L（不是工期）。

## 玩家價值與責任

讓玩家點的對象與角色做出的動作一致，能純觸控完成核心操作。

**規則與邊界**：UI→互動物／目標→地面；touch index 獨立；抬指／取消清理指標；不接旋轉手勢、連招、強制雙指操作。

## 文件交付清單

- **玩法／系統規格 GDD**：預定 `design/gdd/touch-input.md`。需將上方規則展開成正常流程、狀態轉移、拒絕原因、取消／重入／死亡／離線處理；有數值時附變數、單位、安全範圍與算例。
- **Godot 技術規格 TDD**：預定 `docs/architecture/systems/touch-input.md`。需寫 scene tree、模組責任、資料所有權、命令／事件、更新時機、存讀／網路邊界與現有程式遷移方式。
- **此系統專屬內容**：UX：單指、多指、UI 穿透、密集目標與取消；TDD：輸入路由；QA：觸控操作矩陣。
- **QA 與證據規格**：預定 `production/qa/systems/touch-input.md`。以本頁 AC 編號追溯測試／手測／真機證據，附內容版本與未驗證項；測試不能僅檢查檔案存在。

## 資料、介面與 Godot 實作邊界

**資料與狀態**：PointerState(index,start,current,captured_by)；InputIntent；hit target；tap／drag 閾值與縮放規則。

**對外契約**：InputRouter 產生 MoveIntent/SelectTargetIntent/UseSkillIntent；UI consume 後不派發 world intent。

**scene／模組**：ui/touch_overlay.tscn；點選回饋 scene；腳本使用 _unhandled_input 或明確 consume，避免多套重複派發。

## 相依與整合

共通開工條件與附件規則見[文件契約](../document-contracts.md)。

- 初始契約／首版必要前置：[S02 權威狀態、命令與時間](s02-authority-commands-clock.md)、[S04 固定鏡頭、構圖與遮擋](s04-fixed-camera.md)。
- 直接下游：[S06 角色移動、選取與追擊](s06-movement-targeting.md)、[S20 手機 HUD、窗口與提示](s20-mobile-hud.md)、[S26 新手教學、設定、無障礙與文字](s26-onboarding-accessibility.md)。

## 分階段 roadmap

M0 點地與點 UI；M1 選怪＋技能雙觸控；M2 背包與軟鍵盤；搖桿僅在真機結果需要時提案。

## 可驗收條件

- **AC-S03-01**：關閉背包的同一次觸控不使角色移動。
- **AC-S03-02**：一指按技能、另一指移動不互相覆蓋 capture。
- **AC-S03-03**：背景切換中途取消觸控，回前景不留下按住狀態。

## 風險與開工條件

桌面滑鼠模擬成功無法證明多指與系統手勢可用。

