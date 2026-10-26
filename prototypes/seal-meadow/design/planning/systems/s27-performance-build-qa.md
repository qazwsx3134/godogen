# S27｜手機效能、測試、工具與匯出

狀態：**Planning Draft（文件與工作包草案）**；2026-10-26。首次交付：M0；優先層：MVP；相對複雜度：L（不是工期）。

## 玩家價值與責任

每個里程碑都有可重跑建置與真機證據，效能問題提早發現。

**規則與邊界**：桌面／headless 與真機證據分開；固定負載場景；記錄機型／OS／renderer／版本；匯出平台未定前不宣稱全平台通過。

## 文件交付清單

- **玩法／系統規格 GDD**：預定 `design/gdd/performance-build-qa.md`。需將上方規則展開成正常流程、狀態轉移、拒絕原因、取消／重入／死亡／離線處理；有數值時附變數、單位、安全範圍與算例。
- **Godot 技術規格 TDD**：預定 `docs/architecture/systems/performance-build-qa.md`。需寫 scene tree、模組責任、資料所有權、命令／事件、更新時機、存讀／網路邊界與現有程式遷移方式。
- **此系統專屬內容**：目標機矩陣、效能預算／量測 protocol、測試策略、匯出流程、release checklist、授權清單。
- **QA 與證據規格**：預定 `production/qa/systems/performance-build-qa.md`。以本頁 AC 編號追溯測試／手測／真機證據，附內容版本與未驗證項；測試不能僅檢查檔案存在。

## 資料、介面與 Godot 實作邊界

**資料與狀態**：BuildManifest；DeviceProfile；FrameTimeCapture；TestReport；content/scene/import budget。

**對外契約**：工具執行內容驗證、domain／scene／UI 檢查、匯出與量測；不得啟動時重建美術或覆寫 scene。

**scene／模組**：tests/、tools/、export_presets.cfg（平台決定後）；代表性壓力 scene；godot-kit 工具先評估。

## 相依與整合

共通開工條件與附件規則見[文件契約](../document-contracts.md)。

- 初始契約／首版必要前置：[S01 內容定義與資料登錄](s01-content-registry.md)。
- 直接下游：[S28 帳號、多人權威、AOI 與重連](s28-online-authority.md)、[S39 商城、付費與權益](s39-commerce.md)、[S40 平衡、遙測、內容工具與營運稽核](s40-balance-telemetry-operations.md)。

## 分階段 roadmap

M0 可重跑原型與基準量測；M1 smoke；M2 完整循環；M3 20～30 分鐘持續測試；每新增平台重驗。

## 可驗收條件

- **AC-S27-01**：同 commit＋素材版本能重建同內容的可玩包並記錄 hash。
- **AC-S27-02**：真機測試附機型與 P50/P95/P99，無硬體則標未驗證。
- **AC-S27-03**：正常開編輯器／執行不重建來源 scene，修改間距後能保留。

## 風險與開工條件

未定最低機型時不給假 RAM／下載上限；先量再定。

