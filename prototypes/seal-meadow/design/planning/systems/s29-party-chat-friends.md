# S29｜隊伍、聊天與好友

狀態：**Planning Draft（文件與工作包草案）**；2026-10-26。首次交付：M4；優先層：Alpha；相對複雜度：L（不是工期）。

## 玩家價值與責任

提供一起練功、互相聯絡的最小社交體驗。

**規則與邊界**：隊伍邀請／接受／離開／隊長；XP／掉落分配另列 policy；聊天頻道、長度／頻率、封鎖與好友雙向政策。

## 文件交付清單

- **玩法／系統規格 GDD**：預定 `design/gdd/party-chat-friends.md`。需將上方規則展開成正常流程、狀態轉移、拒絕原因、取消／重入／死亡／離線處理；有數值時附變數、單位、安全範圍與算例。
- **Godot 技術規格 TDD**：預定 `docs/architecture/systems/party-chat-friends.md`。需寫 scene tree、模組責任、資料所有權、命令／事件、更新時機、存讀／網路邊界與現有程式遷移方式。
- **此系統專屬內容**：社交狀態機、分配政策、頻道與邀請矩陣；UX：通知／鍵盤；QA：離線、隊長退出、限流。
- **QA 與證據規格**：預定 `production/qa/systems/party-chat-friends.md`。以本頁 AC 編號追溯測試／手測／真機證據，附內容版本與未驗證項；測試不能僅檢查檔案存在。

## 資料、介面與 Godot 實作邊界

**資料與狀態**：PartyState；Invite(expires_at)；ChatMessage(id,channel,sender)；FriendRelation；mute/block state。

**對外契約**：PartyService／ChatService／FriendService 檢查權限；UI subscribe roster；分配透過 S11/S14 應用層 policy。

**scene／模組**：ui/party_panel.tscn、chat_window.tscn、friend_list.tscn；角色頭上資訊只讀成員模型。

## 相依與整合

共通開工條件與附件規則見[文件契約](../document-contracts.md)。

- 初始契約／首版必要前置：[S02 權威狀態、命令與時間](s02-authority-commands-clock.md)、[S20 手機 HUD、窗口與提示](s20-mobile-hud.md)、[S28 帳號、多人權威、AOI 與重連](s28-online-authority.md)。
- 直接下游：[S30 玩家交易與擺攤](s30-trade-stalls.md)、[S31 公會與公會資源](s31-guilds.md)、[S32 情侶、雙人互動與表情](s32-relationships-emotes.md)、[S36 副本、首領與遭遇導演](s36-dungeons-bosses.md)、[S37 決鬥與 PvP 規則](s37-duels-pvp.md)。

## 分階段 roadmap

M4 兩人隊伍＋區域／隊伍聊天；M5 好友、分配與封鎖；公會是 S31。

## 可驗收條件

- **AC-S29-01**：過期邀請／重複接受不造成幽靈成員。
- **AC-S29-02**：聊天開鍵盤時角色不誤走，關閉後輸入狀態恢復。
- **AC-S29-03**：隊長下線與隊伍解散有一致客戶端結果。

## 風險與開工條件

隊伍共享獎勵必須和原子發獎及權限一起驗證。

