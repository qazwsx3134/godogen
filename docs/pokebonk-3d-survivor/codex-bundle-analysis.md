# PokeBonk 3D survivor：bundle 靜態拆解

## 範圍與判讀

本報告只讀取以下 pretty bundle，沒有向網站發出請求，也沒有連接 WebSocket：

- `/Users/peter/repo/godot/godogen/.claude/tasks/pokebonk/raw/pretty/main-B44dxb_5.js`
- `/Users/peter/repo/godot/godogen/.claude/tasks/pokebonk/raw/pretty/assets-CRegv5Cl.js`

證據行號均指向上述 pretty 檔。`main` 是遊戲邏輯與資料表；`assets` 包含 Three.js 本體、loader 與資產對照。角色、武器、敵人、被動與升級的逐筆資料分別整理在[角色表](/Users/peter/repo/godot/godogen/docs/pokebonk-3d-survivor/data/characters.md)、[武器與進化表](/Users/peter/repo/godot/godogen/docs/pokebonk-3d-survivor/data/weapons.md)、[敵人與 Boss 表](/Users/peter/repo/godot/godogen/docs/pokebonk-3d-survivor/data/enemies.md)、[被動與升級表](/Users/peter/repo/godot/godogen/docs/pokebonk-3d-survivor/data/upgrades.md)。

## 核心結論與前提校正

數值口徑：本文及 data 表中的 bundle 數值是出貨預設；線上實際平衡可由同源 /api/config 的 balance map 覆寫。模式、難度等範圍會決定哪一筆生效，不能將某個線上值當成所有 run 的預設。線上值引用使用存檔快照 /Users/peter/repo/godot/godogen/.claude/tasks/pokebonk/api-config.json，未在此報告重新連線請求。

- 遊戲渲染層使用 Three.js；`assets` 暴露的版本是 r170。遊戲本體採自訂 3D 移動、碰撞與空間查詢；在指定 bundle 中沒有找到 Cannon API／物理世界呼叫。(assets:34, assets:29033, main:4943, main:8869)
- 派工單提到「44 隻可玩角色」：主 roster `Se` 確有 44 筆；同檔接著把 29 筆舊角色 `Zh` 加入同一選角資料。因此文件分開列出主 roster 44 筆與舊資料 29 筆，不把兩者混成 44。(main:1048, main:1666, main:123)
- 派工單寫「5 個模式」：`Ae` 有 classic、night、cave、arena、duel、bonk 六個 ID。arena 是 Lucario 操作與訓練木偶的 action 原型；排除它後，五個 survivor／對戰流程是前三個地圖模式、duel 和 bonk。(main:2877, main:2909, main:3036, main:3058)
- bundle 搜尋到的 `Canhão`／`cannon` 是水砲進化招式或文案，沒有找到 Cannon.js 物理引擎 API；因此不能把遊戲的實際碰撞歸因於 Cannon。(main:2010, main:20203, main:8891)

## 資料目錄

| 項目 | 結果 |
|---|---|
| 角色 | 主 roster 44 筆，含屬性、初始招式、基礎覆寫、每級成長、跳躍與解鎖；另附 29 筆舊角色資料。見[角色表](/Users/peter/repo/godot/godogen/docs/pokebonk-3d-survivor/data/characters.md)。 |
| 招式／武器 | 新武器 22 筆加舊武器 29 筆，共 51 筆，含基礎傷害、冷卻、數量、穿透、擊退、行為類型、升級屬性、進化需求與效果。見[武器表](/Users/peter/repo/godot/godogen/docs/pokebonk-3d-survivor/data/weapons.md)。 |
| 敵人與 Boss | 24 筆一般敵人、18 筆 Boss，列基礎數值、出場時間／權重和 AI 行為。見[敵人表](/Users/peter/repo/godot/godogen/docs/pokebonk-3d-survivor/data/enemies.md)。 |
| 被動與升級 | 12 種維他命、32 種 Pokébola 被動、14 種能力卡，另有抽卡權重與 reroll／banish／skip 規則。見[升級表](/Users/peter/repo/godot/godogen/docs/pokebonk-3d-survivor/data/upgrades.md)。 |

武器 schema 沒有各招共用的數值射程欄位，不能用單一數字比較「範圍」；資料表將其標為未找到，改記攻擊形狀與程式中的目標／判定方式。(main:103)

## 戰鬥、升級與成長

本輪補充的獨立資料：[16 組 Combo](/Users/peter/repo/godot/godogen/docs/pokebonk-3d-survivor/data/combos.md)、[天氣表](/Users/peter/repo/godot/godogen/docs/pokebonk-3d-survivor/data/weather.md)、[任務／PB 表](/Users/peter/repo/godot/godogen/docs/pokebonk-3d-survivor/data/missions.md)、[美術與 FX 實作指南](/Users/peter/repo/godot/godogen/docs/pokebonk-3d-survivor/art-and-vfx-implementation.md)。

### 角色與武器

主 roster 中角色可有初始武器、屬性、基礎值覆寫、每級加值和額外跳躍；未解鎖角色由局外任務或商店條件解鎖。角色通用預設在 `Zo`，角色覆寫在 `Se`／`Zh`。逐筆條件見[角色表](/Users/peter/repo/godot/godogen/docs/pokebonk-3d-survivor/data/characters.md)。(main:3970, main:1048, main:123, main:4541)

武器各自定時自動發動，按武器類型選目標或攻擊方向；普通 survivor 流程不用玩家逐次按攻擊鍵。通用升級池改傷害、冷卻、數量、尺寸、速度、持續、穿透、擊退與連鎖；達武器等級 5 且持有對應維他命後可以進化，抽卡時會優先露出可進化項。進化武器和搭配表見[武器與進化表](/Users/peter/repo/godot/godogen/docs/pokebonk-3d-survivor/data/weapons.md)。(main:1667, main:4974, main:3558)

### 升級選單

升級選單每次提供 3 張候選卡。候選按類型權重抽取，包括已有武器升級、新武器、維他命升級、新維他命與能力卡；稀有度權重受幸運影響。初始有 3 次 reroll、2 次 banish、3 次 skip；banish 不會排除既有武器／維他命升級。完整候選權重及上限見[升級表](/Users/peter/repo/godot/godogen/docs/pokebonk-3d-survivor/data/upgrades.md)。(main:3550, main:5029, main:3558)

### XP、拾取與掉落

等級需求的底層曲線為 `floor(5 + (level - 1) × 3 + (level - 1)^1.6)`，每級再乘模式設定的 `xpCurve`；XP 獲得再乘角色 XP、全局 XP 和早期局內修正。通用拾取距離預設 4.5 m。(main:4000, main:27323, main:27428, main:3983)

XP 寶石按價值分四級顏色與尺寸；XP 和金幣用 InstancedMesh 繪製，拾取物會彈起、旋轉並在玩家進入吸取距離後被吸引。莓果、磁鐵與 Boss 寶箱另有特殊掉落邏輯；敵人普通硬幣掉落與莓果機率有各自的限制。(main:26912, main:26936, main:27000, main:30490, main:3810)

### Mega

局內地圖預先放 5 顆 Mega 石；碎片與石頭累積充能，滿格便自動觸發，沒有要求玩家手動按鍵。基礎持續 20 秒；變身時造成半徑 14 m 的範圍傷害，附 hit stop、FOV 推進、閃白、星粒子、光柱與擴散圓環。持續中每次增加 e 份充能會延長 e×12 秒，剩餘時間上限為 20×2=40 秒。bundle 碎片 e=0.14 可延長 1.68 秒；Classic/Normal 線上快照 e=0.22 可延長 2.64 秒（main:30745-30760）；變身期間每秒脈衝一次。(main:3389, main:29908, main:30745, main:30761)

## 模式、節奏與勝利條件

| 模式 | 規則與局長 |
|---|---|
| Classic | Fields 地圖；標準 Boss 預設每 90 秒一隻、共六階，最終 Lugia 在 540 秒出場。擊敗最終 Boss 後結束並結算。(main:2877, main:2994, main:2884) |
| Night | 黑夜山谷敵人與 Darkrai 終局 Boss；使用該模式 Boss 清單與同一 90 秒間隔。(main:2894, main:2994) |
| Cave | Quarry 敵人與 Groudon 終局 Boss；使用該模式 Boss 清單與同一 90 秒間隔。(main:2901, main:2994) |
| Arena | 獨立 action 原型：玩家控制 Lucario 打三段連擊、空中踢擊與訓練木偶；不是一般自動攻擊生存局。(main:2909, main:2920) |
| Duel | 兩人各打自己的敵潮；擊殺達門檻會把 alfa 菁英送去對方場地，先倒下或輸掉最終 Boss 競速者落敗。(main:3036, main:29257) |
| Bonk | 單人兩階段，每階段 540 秒、Boss 在第 300 秒出場；先打 Tyranitar、再打 Lugia，Boss 後可通過 portal，時間耗盡會進入終局 swarm。(main:3058, main:3070, main:28675) |

Classic、Night、Cave 預設 Boss 計畫是 90、180、270、360、450、540 秒；可調 Boss 數量與規則，因此這是預設節奏而不是所有自訂局的固定總長。(main:2994, main:2972)

## 敵人曲線、事件與 Boss

一般敵人的出生率隨時間按 `min(1.4 + t × 0.024, 13)` 增加；同時存活軟上限按 `min(70 + t × 0.85, 420)` 增長，再受模式、難度、合作與設定影響，並受 `maxAlive = 650` 全域上限截斷。每 60 秒生成一批群潮，數量是 `floor(22 + t × 0.14)`，出現在玩家周圍約 26 m。(main:30100, main:30112, main:3621)

普通敵人依模式清單和最早出場時間加權抽選，接近目標追擊；超遠離玩家時會重定位。Boss 有 slam、ghost、charge、serpent 四種行為：先標示落點或衝刺方向，再出招，部分招式留有地面危險區；高 tier 會追加彈幕、環形打擊、狂暴和菁英召喚。逐隻數值與出招參數見[敵人表](/Users/peter/repo/godot/godogen/docs/pokebonk-3d-survivor/data/enemies.md)。(main:26207, main:26700, main:26730, main:26751, main:26789, main:26565)

敵潮另有周期事件、菁英與掉落。菁英是 Pokémon alfa，強化 HP、傷害、尺寸與 XP，死亡掉寶箱；一般擊殺有機率掉硬幣，berry／magnet 有各自掉落機率。詳情與 boss 基礎值見[敵人表](/Users/peter/repo/godot/godogen/docs/pokebonk-3d-survivor/data/enemies.md)。(main:26235, main:30490, main:3810)

## 局外成長與儲存

局外貨幣是 PB，結算依勳章、存活時間、擊殺、Boss、勝利與模式／難度修正給予；可用於解鎖角色、武器與道具。程式中可見任務和收藏解鎖流程，沒有找到永久角色屬性升級樹。(main:3803, main:4780, main:4475, main:4541)

主要存檔使用瀏覽器 `localStorage`。核心進度 key 是 `pokebonk.meta`；設定 key 寫作 `pokebong.settings`，角色選擇 key 寫作 `pokebong_char`，模式選項在 `pokebonk_mode`。其他 key 儲存語言、小地圖、HUD、平衡設定和實驗室設定。注意 `pokebong`／`pokebonk` 拼字不一致是 bundle 實際用字。(main:4475, main:5379, main:33989, main:33996, main:22453, main:23006, main:4144, main:6698, main:32321)

## 特效與效能實作

| 系統 | bundle 中的做法 | Godot 移植時可對照的做法 |
|---|---|---|
| Shader | 遊戲以 Three `ShaderMaterial` 建立自訂粒子／材質，並在多處使用 `onBeforeCompile` 改寫 shader。依文字形式統計，`main` 有 14 個 `new Oa(...)` 與 7 個 hook 賦值；`assets` 另有 2 個 hook。派工單的「24+7」和這個直接呼叫統計口徑不同。(main:26142, main:8039, assets:25375, assets:33376) | 用 ShaderMaterial 做自訂頂點／片段效果；把顏色、淡出、扭曲等參數放入材質 uniform，避免每個特效各自複製一套 shader。 |
| 粒子與場景特效 | 粒子系統按名稱延遲建立並重用，每種系統有 1,600 個加色或 900 個一般粒子容量；另有 decal、beam、pillar、ring、poof 等效果。(main:5766, main:5810, main:6071, main:6080, main:6120) | 用 GPUParticles3D 或固定容量粒子池；命中、蓄力預告、衝擊圈、死亡效果用可重用 scene／pool，限制同時效果數。 |
| 傷害數字與受擊 | 傷害數字是 90 個預先建立的 DOM 元件池，數字依傷害大小縮放並在 0.75–1 秒後回收；玩家受傷有短暫無敵、紅閃、粒子、震屏與 hit stop。(main:5766, main:6289, main:27474, main:30338) | 用 Label3D／CanvasLayer 數字池、材質閃白、短震屏與短暫遊戲時間縮放；讓動畫回收而非持續 new／free。 |
| 擊退與死亡 | 傷害流程分開處理 HP、擊退與受擊狀態；Boss／菁英會用較低擊退係數，死亡播放 poof／爆裂效果並生成掉落。(main:30390, main:30455, main:30501) | 傷害事件回傳擊退向量與效果類型；把死亡動畫、掉落建立和敵人回收拆成明確步驟。 |
| 後處理 | composer 依序串接場景、描邊、 tilt、bloom、finish 與 OutputPass（色調映射／輸出色彩空間）；Bloom 參數為 strength 0.55、radius 0.3、threshold 2.4。(main:32155, main:32160) | 用 Godot WorldEnvironment 的 Glow 加上 SubViewport／Canvas shader 做描邊或色散，提供低畫質選項。 |
| Instancing 與上限 | 敵人採 InstancedMesh，單型別資源池容量 640；XP 寶石 InstancedMesh 容量 900、硬幣 300；全場敵人預設最多 650。(main:26194, main:26936, main:3621) | 用 MultiMeshInstance3D 批次畫重複幾何；設定全局敵人上限與池容量，拾取物以合併價值控制數量。 |
| LOD | Three.js bundle 有 `LOD` 類別，但遊戲 bundle 未找到建立或呼叫 LOD 的使用點。(assets:19168, assets:28919) | 若目標平台需要效能餘裕，再依距離切換模型細節；不把它當作此 bundle 已採用的手法。 |

## 鏡頭、移動與輸入

鏡頭跟隨玩家約頭部高度的 75%，以角色模型的 `camDist` 和玩家可調距離決定拉遠；yaw／pitch 由滑鼠或觸控控制，pitch 限幅，鏡頭遇障礙會沿碰撞檢測結果向前推。基礎 FOV 是 65°，受擊與 Mega 等事件用 FOV punch 和 shake 增強回饋。(main:30024, main:30067, main:30072, main:30086, main:8869)

玩家以速度向量逐步追上輸入方向，而非瞬間設定位置；基礎移速是 8.5 × 角色移速，地面加速／減速分別有不同係數，上限約 2.6 倍基礎速度。dash 約 3.2 倍移速；slide 加速後受摩擦與坡度影響；跳躍速度首跳 12.5、額外跳躍 11，並有重力與特定角色滑翔。(main:27559, main:27620, main:27575, main:27641)

手機介面有可跟手移動或固定角落的虛擬搖桿、可交換左右手的按鈕配置；另一側觸控拖動旋轉鏡頭。一般 survivor 武器自動找目標；Arena 原型則以 4 m 範圍、35° 錐角找目標並允許 1.5 m 突進輔助。(main:33569, main:5418, main:5634, main:2923, main:29088)

## 碰撞、空間分割與 Cannon 判讀

地圖碰撞器、敵人鄰居查詢和其他局部查詢用 `Bc` 空間雜湊；世界格寬 6 m、敵人群組用 3 m 格。碰撞是水平圓形半徑與高度檢查，再將玩家推出重疊圓；敵人之間用鄰近查詢分離。玩家重力、跳躍與地面高度也是遊戲程式自行積分。指定 bundle 沒有 Cannon world、Body 或 shape API 使用。(main:4943, main:8366, main:8869, main:8891, main:27641, main:26207)

## 連線架構（僅靜態閱讀）

遊戲以 `wss://<host>/api/ws` 連線；本次未開啟任何 socket。合作模式 host 負責敵潮、Boss、敵人快照與結算事件；客戶端傳玩家狀態、build 與傷害請求。敵人快照是二進位位置／朝向／HP 等資料，host 約 12 Hz 廣播；角色狀態約 15 Hz、build 約每 0.5 秒送一次。(main:27717, main:27845, main:27846, main:28010, main:28248, main:28413, main:28418)

```text
┌──────────────┐   玩家狀態／build／傷害請求   ┌──────────────┐
│ 客戶端 A     │ ───────────────────────────→ │              │
│              │ ←── 敵人快照／meta／事件 ─── │    Host      │
└──────────────┘                              │ 敵潮與 Boss  │
                                               │ 權威／結算   │
┌──────────────┐   玩家狀態／build／傷害請求   │              │
│ 客戶端 B     │ ───────────────────────────→ │              │
│              │ ←── 敵人快照／meta／事件 ─── │              │
└──────────────┘                              └──────────────┘
```

Duel 是另一套競賽邏輯：雙方各自跑敵潮，依擊殺門檻送 alfa 到對手場地，並交換雙方狀態與勝負事件。(main:29257, main:3036)

## 模型、貼圖與音效

模型表使用 `/models/swsh/{dex}.glb`，個別角色另有 Gmax 路徑、fallback dex、模型高度與鏡頭距離；Three loader 另提供 `/models/pokemon/{dex}.glb` 通用 GLB 路徑，並把 Draco decoder 指向 `/draco/`。貼圖表引用 `/models/swsh/tex/{id}.png`，還包含 UV、wrap 與材質替換設定。素材來源／授權無法從這兩份 bundle 確認。(main:16250, main:16433, assets:33268, assets:33272, assets:33337)

`assets` 包含 Three.js 的 AudioContext、AudioListener、AudioLoader、Audio 與 PositionalAudio 實作；但在 `main` 內沒有找到遊戲呼叫這些 API 或遊戲音效資源路徑，實際遊戲音效管線因此標為未找到。(assets:26098, assets:26226, assets:28780, assets:29023)

## 對 Godot 版最值得抄的 10 件事

1. 用固定容量的粒子池與延遲建立系統管理命中特效，並按系統種類設定上限。(main:5810)
2. 把傷害數字、拾取物、敵人分別做物件池或 MultiMesh，另設全局硬上限。(main:5766, main:26936, main:3621)
3. 以獨立空間雜湊支援敵人鄰居查詢、環境碰撞和鏡頭遮擋測試。(main:4943, main:8869)
4. 將 Boss 攻擊拆成「預告、延遲、命中、收招」階段，讓玩家能讀懂危險區。(main:26700, main:26751)
5. 以 90 秒 Boss 節拍和漸增敵潮率構成短局節奏，再把最後 Boss 作為明確終點。(main:2994, main:30100)
6. 升級池用權重、類別上限和可進化項優先規則，讓三選一卡片兼具新構築與成長感。(main:3550, main:4974, main:5029)
7. 以獨立的充能／變身狀態統一模型替換、傷害脈衝、粒子、FOV 與 hit stop。(main:30745, main:30761)
8. 移動使用速度加速、慣性、衝刺、滑行與跳躍互動，而不是每幀直接改角色位置。(main:27559, main:27620)
9. 手機搖桿提供浮動／固定、左右手交換與獨立鏡頭拖動設定。(main:5418, main:5634, main:33569)
10. 多人敵潮由 host 權威模擬，以量化二進位快照傳輸敵人，而把玩家狀態和傷害請求分開同步。(main:28248, main:28413, main:28418)

## 遠端平衡（/api/config）

線上 config 由 Bg() 以同源 fetch /api/config 取得，啟動流程將回應的 balance 傳給 le.applyServer（main:29557-29563、34201-34203）。applyServer 先以 gr() 驗證每個值為有限數字、key 符合 parser 且 ID 已註冊；全域值寫入參數 shipped slot，範圍值寫入 Gt map；若至少一個鍵套用，接著排序範圍並重算註冊參數（main:7659-7668、7798-7801）。key parser Kc 接受 @scope|分類.子類.鍵，scope 經 Jc/il 驗證與正規化（main:7552-7618）。生效值先取全域值，再疊符合當局 context 的範圍值；Wi 依 scope 特異性排序，較多限定條件的值後套用並優先（main:7635-7657）。

排序分數 ed(scope) = 每個維度加 1000，再加該維度位元權重；維度順序為 m,d,h,r,b,p（main:7591、7622）。同樣有兩個限定時，m+d 得分 2003，m+h 得分 2005，所以標準敵潮的 @m:classic,h:std 值會在 @m:classic,d:normal 後套用。這是同時匹配兩種範圍的結果，不是只按難度決定 XP。實際 run context 包含 h:std 或 h:adapt（main:29852-29857）。

scope 維度：m 模式、d Classic 難度 normal/hard、h 標準／adaptive horde、r:off/on（Golpes 自由／Restrito）、b Boss 數、p solo/online 玩家狀態。h 的允許值是 std/adapt，代表 horde style，不是任意文字標籤（main:7554-7590）。例如 @m:classic,d:normal|Geral.Inimigos.enemyDmg 可覆寫全域 Geral.Inimigos.enemyDmg，且只在 Classic/Normal context 命中。

已存 api-config.json 快照含 211 個 balance keys：136 個全域、75 個範圍鍵；它是提供的線上資料快照，不代表本報告重新取得的即時狀態。快照主要分類為 Geral 120、Cartas 7、Itens 6、Golpes 74、Inimigos 1、Megaeclima 2、Vitaminas 1。下表將 bundle 預設與該快照的線上值分欄；effective 值指未啟用本機平衡調參時的 matching run context（main:7635-7647）：

| 設定 | bundle 預設 | 線上覆寫（快照） | 範圍／解讀 |
|---|---:|---:|---|
| Geral.Jogador.xpCurve | 1 | 全域 3；Classic/Normal 1；Classic/標準敵潮 2；Classic/Hard/Adaptive 3 | Classic/Normal/標準敵潮實際為 2；Normal/Adaptive 為 1；Hard/標準為 2；Hard/Adaptive 為 3。相同限定數的 scope 仍有排序，見下文（main:7622、7640-7657、29852-29857）。 |
| Geral.Chegadadoschefes.interval | 90 秒 | 全域 60 秒 | 共用 Boss timing 控制值；mode plan 仍可能給出明確 Boss at 時間，不可因此推斷每種模式都統一每 60 秒刷新 Boss（main:2993-2996、29959-29963、7016）。 |
| Geral.Inimigos.enemyDmg | 1.0 | 全域 1.5；Classic/Normal 0.72 | scope 值在匹配 run 覆寫全域。實際傷害還乘時間、威脅、horde、事件、合作等倍率（main:6703、30001-30013）。 |
| Geral.Inimigos.spawnRate | 1.1 | 全域 1.25；Classic/Normal 1.8 | 影響每秒生成率，與波次群潮分開計算（main:6705、30092-30103）。 |
| Megaeclima.MegaEvolução.damage | +60% | Classic/Normal +80% | bundle 的 Ee.buffs.damage=0.6；線上值是 +0.8（main:3389-3397；快照同名 balance key）。 |
| Megaeclima.MegaEvolução.shardValue | 0.14／碎片條 | Classic/Normal 0.22 | 每碎片充能比例，不是傷害倍率（main:3389-3397）。 |
| Golpes.ChoquedoTrovão.damage | 27.2 | 全域 28.8 | 招式資料本體 main:1676-1687；bundle 的具體攻擊係數可由同名線上鍵取代。 |
| Inimigos.Rattata.hp | 10 | 全域 10.2 | 直接覆寫敵人資料 HP 欄；敵人基礎值 main:2558。 |

線上 Mega damage=0.8 時，部分 UI 靜態提示仍寫 +60%，而動態公告讀當前配置；移植時應共用同一設定來源產生數值，避免提示與實際係數脫節（main:30828-30834）。Cartas、Itens、Vitaminas 的直接覆寫逐項比較見[升級表的線上覆寫對照](/Users/peter/repo/godot/godogen/docs/pokebonk-3d-survivor/data/upgrades.md)。快照沒有角色專屬、Pokébola 價格或天氣類別的 balance keys；共用傷害、XP 與 enemy 乘數仍會間接改變這些玩法的有效結果。

## 本輪補充的遊戲系統

### Pressure 與 Adaptive

Pressure 是能力效果：半徑 7m 內敵人移速 -35%，移動程式將敵速再乘 0.65（main:3535-3538、26439-26443）。Adaptive Horde 從 run 120 秒後開始，約每 2 秒評估一次最近 10 個玩家 HP 樣本；light／normal／strong profile 可設附近敵人目標、horde 上限與成長速率。normal 的近敵目標 2、horde cap 2.5、每次 creep 0.02；strong 近敵目標 4、cap 4、creep 0.035。Boss 戰中停止一般評估，並以受傷、附近敵人數與威脅命中調節 horde（main:3719-3742、4071-4105）。這是動態威脅修正，與 /api/config 的 h:adapt 範圍值分開。

### 狀態異常

| 狀態 | bundle 預設與處理 | Boss／菁英 |
|---|---|---|
| 靜電麻痺／暈眩 | Static 基礎 20% 命中機率，另乘 effectMult；設定 stunT=1 秒（main:3400-3406、30372-30375）。 | 排除 Boss，沒有排除菁英。 |
| 燃燒 | 同一武器實例每 0.5 秒造成 dps×0.5；該實例重複點燃取時間與 DPS 最大值。可傳染時找 3.4m 內一隻，時間／DPS 乘 0.8（main:8933-8935、8954-8983、9008-9021）。 | 此處 ignite／tick 未見 Boss／菁英專屬減半。不同武器實例各有 burns map，不能推論所有來源的燃燒互斥。 |
| 減速 | 普通敵人／菁英移速乘 0.45；一般 dealDamage 收到 slow 會設 slowT=2 秒。Pressure 另乘 0.65（main:26439-26443、30394）。 | Boss 的 bossMove 減速係數為 0.6（main:26505-26511），不是普通敵人的 0.45。 |
| 冰招「凍結」 | 基礎 Ice Beam 命中 slow=真；進化每 2.6 秒在半徑 8×size 範圍施加 stun 1.5 秒、slowT=3 秒（main:14105-14166）。Icicle Crash 主落點 stun 0.45 秒；進化碎裂延遲 0.18 秒、stun 1.3 秒（main:15440-15470）。 | 共用 aoe／cone／zone 的 stun 排除 Boss；上述慢速效果仍可設在 Boss 上。 |
| 共用抗性 | 未找到獨立跨招式 freeze enum 或固定凍結時長；冰招以既有 stunT／slowT 表達控制。 | 通用暈眩對 Boss 有免疫條件；未找到 Boss／菁英統一抗性減半規則（main:8995-8997、9073-9101）。 |

### Bonk 物件與經濟

Bonk 兩階段各 540 秒，Boss 在第 300 秒；Fields/Tyranitar 為第一階段，Noite Sombria/Lugia 為第二階段，後段敵方 HP 階段倍率 2.4、傷害 1.7（main:3058-3075、28611-28618）。場上有 4 個 charge shrine：半徑 3.4m 內累積 4 秒，離開時以一半速率退回充能（main:28700-28715）。2 個 challenge shrine 會召喚非最終、非本階段目標的隨機 Boss，HP scale=當局 hpScale×0.6；擊敗後出免費 Pokébola（main:28747-28754、28784-28790）。2 個 cursed shrine 每次給幸運 stat +0.10、XP stat +0.12、reroll +1，代價是敵方 HP 倍率乘 (1+詛咒數×0.15)、spawn 倍率乘 (1+詛咒數×0.12)（main:28611-28618、28791-28802）。charge shrine 的獎勵由十種本局永久 buff 抽三張，稀有度依幸運抽選（main:3082-3093、28807-28836）。

Meowth 商人展示 3 項，稀有度基價 25／40／70／120／200；價格 = round(該稀有度基價 × (1+time/600) × (1+stage×0.5))，reroll = round(15×(1+time/600))（main:3079、28838-28845、28850-28883）。微波爐每階段 2 台；價格 round(45×1.7^已使用次數×(1+time/900))，可複製一個已持有 item（main:3080、28887-28928）。非最終 Boss 倒下後開 portal 供進下一階段；計時耗盡進終局 swarm（main:28931-28948、3081）。

### Pokébola 價格

Bundle 初始普通球公式 round(12×1.32^opened + 4×opened)，前五次 12／20／29／40／52；不同稀有度再乘 [1、1.6、2.5、4、6.5]。另有錢包門檻倍率 0／0／0.08／0.18／0.35，實際價格取公式價與稀有度錢包比例計算值的較高者。每 40 秒出現一顆，地圖上限 22，最多顯示 3 個 item 選項；拒絕付款退款係數 0.5。稀有度基礎權重 60／25／10／4／1，並受 luck 調整（main:3875-3895、7495-7514、1034-1046、27080-27085）。付款可依稀有度消耗維他命等級、reroll／banish／skip 或詛咒，見 main:7516-7546。api-config.json 快照沒有 Pokébola 價格鍵。

### 評級、PB 與任務

勝利取 Boss medal 平均分：至少 0.85 為 S+，否則 S；失敗按 450／270／120 秒分 A／B／C，未達 120 為 D（main:22582-22589）。PB 基底由 medal 3／2／1、存活每分鐘 3、每 100 擊殺 1（上限 30）、每 Boss 6、勝利 40 或 Duel 勝 25、bonus PB 組成；結算乘數為 Bonk 時 1.3、否則 1.0，再加 restricted +0.25、adaptive +0.25、風險 modifier 總和、每位額外玩家 +0.05，四捨五入並追加任務 PB（main:3803、4540、4794-4831）。22 個任務完整條件與解鎖獎勵見[任務資料表](/Users/peter/repo/godot/godogen/docs/pokebonk-3d-survivor/data/missions.md)（main:4562-4718）。

### 平衡實驗室

F2 Balanceamento 與 F4 Laboratório 是開發工具入口（main:23967）。Balanceamento 將註冊分類／子類／鍵顯示為滑桿，並附使用現值換算生成、傷害或 XP 公式的說明；y() 收集註冊 key、label、範圍、step 與預設值（main:6724-6739、6756-6768、17654-17682）。Laboratório 的測試局不進歷史、排行榜或永久進度（main:26081-26089）；UI 顯示 run／player／build／敵人／scenario／account 類別（main:32321-32339）。

### 合作人數修正

合作 scale = 1 + 每位額外玩家 × 各項係數（main:3620、28050-28055）。它用於敵人生命、傷害、生怪、場上 cap、elite 出現、horde wave 與 Boss 出招速度（main:3602-3618、26686、29987-30013、30104-30125、30196）。每多一名玩家：一般敵 HP +60%、Boss HP +85%（取代一般敵 HP 的合作倍率，非兩者相乘；main:30252-30264）、spawn +30%、存活上限 +8%（乘數最多 1.5，即最多 +50%）、敵人傷害 +7%、移速 +2%、horde +20%、elite 生成速度 +25%、Boss 攻擊速度 +6%。隊友復活需站旁 3 秒、距離 2.8m，復活 HP 40%；升級選卡時受到傷害乘 0.5，遠距 XP 範圍參數為 22m（main:3602-3618、28371-28388、27441、30436）。Duel 不應直接套用為多人合作；PB 的額外玩家加成另見前節。
