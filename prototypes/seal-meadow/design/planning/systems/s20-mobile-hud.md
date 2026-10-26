# S20｜手機 HUD、窗口與提示

狀態：**Planning Draft（文件與工作包草案）**；2026-10-26。首次交付：M0；優先層：MVP；相對複雜度：L（不是工期）。

## 玩家價值與責任

把戰鬥與整理資訊放在拇指可及、可讀的範圍。

**規則與邊界**：生命/AP、目標、技能為常駐核心；詳細聊天／寵物／背包可收合；window stack 管 modal、返回與焦點。

## 文件交付清單

- **玩法／系統規格 GDD**：預定 `design/gdd/mobile-hud.md`。需將上方規則展開成正常流程、狀態轉移、拒絕原因、取消／重入／死亡／離線處理；有數值時附變數、單位、安全範圍與算例。
- **Godot 技術規格 TDD**：預定 `docs/architecture/systems/mobile-hud.md`。需寫 scene tree、模組責任、資料所有權、命令／事件、更新時機、存讀／網路邊界與現有程式遷移方式。
- **此系統專屬內容**：UX 線框、窗口優先權、資訊密度與安全區；UI style guide；可讀性／觸控 QA 矩陣。
- **QA 與證據規格**：預定 `production/qa/systems/mobile-hud.md`。以本頁 AC 編號追溯測試／手測／真機證據，附內容版本與未驗證項；測試不能僅檢查檔案存在。

## 資料、介面與 Godot 實作邊界

**資料與狀態**：WindowState；HUD view-model；SafeAreaProfile；UI action/result；string IDs；notification priority。

**對外契約**：Views 訂閱 read model、發命令；UI 不持有權威物品；返回優先關頂層窗口，不直接退出。

**scene／模組**：ui/hud.tscn、window_shell.tscn、button/item_slot/notification scenes；Theme／Containers；靜態版面可編輯。

## 相依與整合

共通開工條件與附件規則見[文件契約](../document-contracts.md)。

- 初始契約／首版必要前置：[S01 內容定義與資料登錄](s01-content-registry.md)、[S03 觸控輸入與互動優先權](s03-touch-input.md)。
- 直接下游：[S26 新手教學、設定、無障礙與文字](s26-onboarding-accessibility.md)、[S29 隊伍、聊天與好友](s29-party-chat-friends.md)。

## 分階段 roadmap

M0 HUD shell＋一 modal；M1 血條／技能；M2 交易前各窗口；M3 所有核心窗口真機。

## 可驗收條件

- **AC-S20-01**：兩種 aspect 與安全區下主要按鈕不出界。
- **AC-S20-02**：開窗口／關窗口／按技能不穿透到世界。
- **AC-S20-03**：編輯器改一個間距與靜態文字，執行後保留。

## 風險與開工條件

先做好固定像素桌面面板再縮小會造成手機不可讀。

