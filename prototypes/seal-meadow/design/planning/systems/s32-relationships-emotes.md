# S32｜情侶、雙人互動與表情

狀態：**Planning Draft（文件與工作包草案）**；2026-10-26。首次交付：M5；優先層：Full Vision；相對複雜度：M（不是工期）。

## 玩家價值與責任

讓角色有生活感與玩家關係，而非只有數值。

**規則與邊界**：關係邀請需雙方同意；互動距離、座位 anchors、取消／離線與解綁明定；獎勵不隱含複製原作限制。

## 文件交付清單

- **玩法／系統規格 GDD**：預定 `design/gdd/relationships-emotes.md`。需將上方規則展開成正常流程、狀態轉移、拒絕原因、取消／重入／死亡／離線處理；有數值時附變數、單位、安全範圍與算例。
- **Godot 技術規格 TDD**：預定 `docs/architecture/systems/relationships-emotes.md`。需寫 scene tree、模組責任、資料所有權、命令／事件、更新時機、存讀／網路邊界與現有程式遷移方式。
- **此系統專屬內容**：關係生命週期、同意／取消流程、雙人姿勢規格、UX／QA：斷線與互動衝突。
- **QA 與證據規格**：預定 `production/qa/systems/relationships-emotes.md`。以本頁 AC 編號追溯測試／手測／真機證據，附內容版本與未驗證項；測試不能僅檢查檔案存在。

## 資料、介面與 Godot 實作邊界

**資料與狀態**：RelationshipState；ConsentInvite；InteractionSession；EmoteDefinition；pair anchors。

**對外契約**：RelationshipService／InteractionService 管 session；ActorView 播動作；獎勵若有交 S12。

**scene／模組**：scenes/interactions/bench.tscn、emote_bubble.tscn；ui/relationship_panel.tscn。

## 相依與整合

共通開工條件與附件規則見[文件契約](../document-contracts.md)。

- 初始契約／首版必要前置：[S07 屬性、生命、回復與死亡](s07-stats-vitals-death.md)、[S22 角色美術、方向、動畫與資產管線](s22-actor-art-animation.md)、[S28 帳號、多人權威、AOI 與重連](s28-online-authority.md)、[S29 隊伍、聊天與好友](s29-party-chat-friends.md)。
- 直接下游：無。

## 分階段 roadmap

M5 單人表情＋一雙人休息；有需要才加入關係成長與獎勵。

## 可驗收條件

- **AC-S32-01**：任一方取消／離線，另一人可立刻恢復操作。
- **AC-S32-02**：未同意的玩家不被強制移動或綁關係。
- **AC-S32-03**：雙人姿勢在固定視角與各方向無嚴重錯位。

## 風險與開工條件

感情與獎勵綁定程度是產品選擇，不照搬舊版性別／天數規則。

