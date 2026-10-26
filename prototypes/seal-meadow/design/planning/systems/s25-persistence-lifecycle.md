# S25｜存檔、設定與手機生命週期

狀態：**Planning Draft（文件與工作包草案）**；2026-10-26。首次交付：M0；優先層：MVP；相對複雜度：L（不是工期）。

## 玩家價值與責任

玩家切到背景或被系統終止後，已完成的成長不遺失。

**規則與邊界**：定義狀態版本與 migration；原子寫入／備份；核心操作後 checkpoint；不只等正常退出；多人進度不信任本機存檔。

## 文件交付清單

- **玩法／系統規格 GDD**：預定 `design/gdd/persistence-lifecycle.md`。需將上方規則展開成正常流程、狀態轉移、拒絕原因、取消／重入／死亡／離線處理；有數值時附變數、單位、安全範圍與算例。
- **Godot 技術規格 TDD**：預定 `docs/architecture/systems/persistence-lifecycle.md`。需寫 scene tree、模組責任、資料所有權、命令／事件、更新時機、存讀／網路邊界與現有程式遷移方式。
- **此系統專屬內容**：存檔 schema／遷移表／恢復流程；背景與單機離線時鐘政策；QA：強制終止、損壞、舊版。
- **QA 與證據規格**：預定 `production/qa/systems/persistence-lifecycle.md`。以本頁 AC 編號追溯測試／手測／真機證據，附內容版本與未驗證項；測試不能僅檢查檔案存在。

## 資料、介面與 Godot 實作邊界

**資料與狀態**：SaveEnvelope(version,revision,checksum,payload)；Settings；LifecycleState；Repository interface；各系統片段。

**對外契約**：SaveRepository.load/commit(snapshot)；LifecycleCoordinator flush／pause local；不硬依賴每個 feature class。

**scene／模組**：設定窗口與讀檔錯誤 scene；kit atomic_file 作寫入原語；Web 若採用需實機驗持久化。

## 相依與整合

共通開工條件與附件規則見[文件契約](../document-contracts.md)。

- 初始契約／首版必要前置：[S01 內容定義與資料登錄](s01-content-registry.md)、[S02 權威狀態、命令與時間](s02-authority-commands-clock.md)。
- 直接下游：[S17 寵物餵食、成長與進化](s17-pet-care.md)、[S21 小地圖、旅行與區域切換](s21-map-travel.md)、[S26 新手教學、設定、無障礙與文字](s26-onboarding-accessibility.md)、[S28 帳號、多人權威、AOI 與重連](s28-online-authority.md)、[S33 釣魚與休閒採集](s33-fishing.md)、[S38 活動、每日與限時獎勵](s38-events-dailies.md)、[S39 商城、付費與權益](s39-commerce.md)。

## 分階段 roadmap

M0 設定與最小角色狀態；M1 XP／物品；M2 任務；M3 寵物／精煉與背景；M4 遠端 repository。

## 可驗收條件

- **AC-S25-01**：寫入中終止後能回到最近一筆完整存檔。
- **AC-S25-02**：壞主檔與有效備份有明確恢復，不默默清空。
- **AC-S25-03**：背景回前景沒有卡住輸入／聲音／舊攻擊回呼。

## 風險與開工條件

非同步保存完成前顯示成功會誤導玩家；每平台耐久性需驗證。

