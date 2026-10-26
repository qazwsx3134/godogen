# S28｜帳號、多人權威、AOI 與重連

狀態：**Planning Draft（文件與工作包草案）**；2026-10-26。首次交付：M4；優先層：Alpha；相對複雜度：XL（不是工期）。

## 玩家價值與責任

多人看見一致的世界，角色進度與物品由伺服器保護。

**規則與邊界**：登入／角色與 session；權威移動／戰鬥／交易；AOI；命令序號與去重；超時／重連／跨圖恢復；不承諾千人同屏。

## 文件交付清單

- **玩法／系統規格 GDD**：預定 `design/gdd/online-authority.md`。需將上方規則展開成正常流程、狀態轉移、拒絕原因、取消／重入／死亡／離線處理；有數值時附變數、單位、安全範圍與算例。
- **Godot 技術規格 TDD**：預定 `docs/architecture/systems/online-authority.md`。需寫 scene tree、模組責任、資料所有權、命令／事件、更新時機、存讀／網路邊界與現有程式遷移方式。
- **此系統專屬內容**：拓樸 ADR、協定／channel 表、權威清單、DB schema、AOI／插值、重連／跨圖流程、負載與威脅測試。
- **QA 與證據規格**：預定 `production/qa/systems/online-authority.md`。以本頁 AC 編號追溯測試／手測／真機證據，附內容版本與未驗證項；測試不能僅檢查檔案存在。

## 資料、介面與 Godot 實作邊界

**資料與狀態**：Session、CharacterId、EntitySnapshot、AOISet、CommandAck、ServerClockOffset；DB revision。

**對外契約**：Authority adapter→map server；repository→DB；scene replication 屬呈現層；原生／Web transport 依平台選。

**scene／模組**：headless server project／server role 啟動；client network coordinator；network status UI；協定不直接依賴內部 node path。

## 相依與整合

共通開工條件與附件規則見[文件契約](../document-contracts.md)。

- 初始契約／首版必要前置：[S02 權威狀態、命令與時間](s02-authority-commands-clock.md)、[S05 世界場景、碰撞與導航](s05-world-navigation.md)、[S07 屬性、生命、回復與死亡](s07-stats-vitals-death.md)、[S08 普攻、命中與傷害結算](s08-combat-resolution.md)、[S12 物品、背包、貨幣與交易原語](s12-inventory-transactions.md)、[S25 存檔、設定與手機生命週期](s25-persistence-lifecycle.md)、[S27 手機效能、測試、工具與匯出](s27-performance-build-qa.md)。
- 直接下游：[S29 隊伍、聊天與好友](s29-party-chat-friends.md)、[S30 玩家交易與擺攤](s30-trade-stalls.md)、[S31 公會與公會資源](s31-guilds.md)、[S32 情侶、雙人互動與表情](s32-relationships-emotes.md)、[S36 副本、首領與遭遇導演](s36-dungeons-bosses.md)、[S37 決鬥與 PvP 規則](s37-duels-pvp.md)、[S38 活動、每日與限時獎勵](s38-events-dailies.md)、[S39 商城、付費與權益](s39-commerce.md)。

## 分階段 roadmap

M0 先保留邊界；M2 前做雙 client 技術風險試驗；M4 正式登入／權威地圖／DB；再擴容量。

## 可驗收條件

- **AC-S28-01**：兩 client 同時拾物只有一人成功且重連不複製。
- **AC-S28-02**：偽造速度／傷害／金額被拒絕，客戶端不能寫最終結果。
- **AC-S28-03**：延遲、掉包、重連下權威狀態收斂，tick P95 有量測。

## 風險與開工條件

網路是高返工風險，技術試驗提早但完整實作後置；容量要壓測。

