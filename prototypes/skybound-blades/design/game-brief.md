# Game Brief: 浮空劍域（Skybound Blades，暫名）

**One-sentence pitch:** 帶著兩名 AI 夥伴，在浮空塔中自動狩獵、修練劍技與整備，決定何時押上這一代冒險者的性命挑戰守層者。

第一個交付物是 [RO 戰鬥切片](ro-slice.md)，之後依 [機制開發順序](mechanism-plan.md)接上遠征閉環；系統盤點見 [MMORPG 機制研究](../../../docs/research/echoes-of-aincrad-mmorpg-systems-2026-10-24.md)。

## Core loop

接取目標與選路線 → 狩獵累積角色／武器技能與素材 → 回城補給、鍛造、存入倉庫 → 帶 AI 隊伍挑戰下一層。

## Player goal & fail state — what “working” looks like

首版通過 3 層、3 名守層者；隊長 HP 歸零即永久死亡並結束本次遠征。下一代保留地圖知識、已解鎖傳送點、城鎮倉庫與傳承手記，重新培養角色。

## MVP — what must exist to be the game

1. 城鎮、狩獵區與守層者的遠征流程、結果與區域進度；RO 式 HD 2.5D 戰鬥畫面。
2. 角色等級、3 種武器流派、技能熟練度與技能格配置。
3. 戰利品、換裝比較、定向強化、補給與自動補血／撤退規則。
4. 主線、討伐與收集任務，含追蹤、回報及不可重領的獎勵。
5. 隊長＋2 名 AI：護衛／援護戰術、隊伍對話與戰鬥紀錄。
6. 永久死亡、冒險紀錄、城鎮倉庫、下一代傳承與安全存檔。
7. 安全離線委託、回歸結算、橫向自適應 UI 與省電帳本視圖。

## Out of scope — not building this

首版無真人連線、全球聊天、PvP、拍賣、玩家交易、公會、付費系統；角色圖層換裝、全部 100 層與自由旋轉鏡頭列為擴充。視覺仍可呈現不同武器，先使用完整角色圖集切換。

## Build order

1. RO 戰鬥切片：一個狩獵區、隊長＋2 AI、點敵人追打與自動狩獵、升級與補藥；死亡只結束本輪、不存檔。
2. 以決定性結算驗證任務、成長、消耗、物品及死亡傳承，接成單層完整循環（狩獵／補血／撤退／死亡）。
3. 裝備技能、任務與 2 名 AI；證明配裝可改變戰果。
4. 倉庫、傳承、離線與復原；驗證死亡不能重複結算。
5. 擴至 3 層與 3 Boss，再做數值與美術驗收。

---

**Who it's for / what they feel:** 喜歡農裝、農等級與技能，也希望每次攻塔的準備與撤退都有份量的玩家。

**Art & audio direction:** RO 式 HD 2.5D：低多邊形 3D 地圖、固定俯角鏡頭，3～3.5 頭身 HD 角色用 godot-kit sprite3d billboard；Web 桌機與手機橫向。

**Reference game:** Snored Art Online 的農怪／技能／樓層循環、Sword Art Online 的攻塔與死亡張力、RO 的 2D 角色＋3D 場景語彙；本作採單機 AI 隊伍與原創世界內容。
