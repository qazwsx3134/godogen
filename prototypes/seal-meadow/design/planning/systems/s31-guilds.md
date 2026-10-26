# S31｜公會與公會資源

狀態：**Planning Draft（文件與工作包草案）**；2026-10-26。首次交付：M5；優先層：Full Vision；相對複雜度：L（不是工期）。

## 玩家價值與責任

建立長期團體身分、共同目標與合作資源。

**規則與邊界**：建會成本、職級權限、邀請、退出／解散、公告；公會銀行與獎勵另列權限與稽核規則。

## 文件交付清單

- **玩法／系統規格 GDD**：預定 `design/gdd/guilds.md`。需將上方規則展開成正常流程、狀態轉移、拒絕原因、取消／重入／死亡／離線處理；有數值時附變數、單位、安全範圍與算例。
- **Godot 技術規格 TDD**：預定 `docs/architecture/systems/guilds.md`。需寫 scene tree、模組責任、資料所有權、命令／事件、更新時機、存讀／網路邊界與現有程式遷移方式。
- **此系統專屬內容**：公會規則、權限矩陣、銀行／捐獻 ledger、UX：職級與公告；QA：降權與同時操作。
- **QA 與證據規格**：預定 `production/qa/systems/guilds.md`。以本頁 AC 編號追溯測試／手測／真機證據，附內容版本與未驗證項；測試不能僅檢查檔案存在。

## 資料、介面與 Godot 實作邊界

**資料與狀態**：GuildState；RolePermission；GuildBankLedger；AuditEvent；membership revision。

**對外契約**：GuildService 檢查角色權限，任何取物／花費經 Transaction；公會聊天用既有頻道能力。

**scene／模組**：ui/guild_window.tscn、member_row.tscn、guild_bank.tscn；公會名牌資料由服務端提供。

## 相依與整合

共通開工條件與附件規則見[文件契約](../document-contracts.md)。

- 初始契約／首版必要前置：[S12 物品、背包、貨幣與交易原語](s12-inventory-transactions.md)、[S28 帳號、多人權威、AOI 與重連](s28-online-authority.md)、[S29 隊伍、聊天與好友](s29-party-chat-friends.md)。
- 直接下游：無。

## 分階段 roadmap

M5 建會／成員／公告；之後銀行、共同目標與公會玩法。

## 可驗收條件

- **AC-S31-01**：被降權後已開面板不能繼續取物。
- **AC-S31-02**：會長離線／移交／解散不留下無 owner 狀態。
- **AC-S31-03**：公會存取可對帳，失敗不增減物資。

## 風險與開工條件

公會戰與城戰屬內容與網路規模擴充，不因有公會就默認全做。

