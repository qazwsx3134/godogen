# PokeBonk 3D survivor：bundle 靜態拆解

## 範圍與判讀

本報告只讀取以下 pretty bundle，沒有向網站發出請求，也沒有連接 WebSocket：

- `/Users/peter/repo/godot/godogen/.claude/tasks/pokebonk/raw/pretty/main-B44dxb_5.js`
- `/Users/peter/repo/godot/godogen/.claude/tasks/pokebonk/raw/pretty/assets-CRegv5Cl.js`

證據行號均指向上述 pretty 檔。`main` 是遊戲邏輯與資料表；`assets` 包含 Three.js 本體、loader 與資產對照。角色、武器、敵人、被動與升級的逐筆資料分別整理在[角色表](/Users/peter/repo/godot/godogen/docs/pokebonk-3d-survivor/data/characters.md)、[武器與進化表](/Users/peter/repo/godot/godogen/docs/pokebonk-3d-survivor/data/weapons.md)、[敵人與 Boss 表](/Users/peter/repo/godot/godogen/docs/pokebonk-3d-survivor/data/enemies.md)、[被動與升級表](/Users/peter/repo/godot/godogen/docs/pokebonk-3d-survivor/data/upgrades.md)。

## 核心結論與前提校正

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

### 角色與武器

主 roster 中角色可有初始武器、屬性、基礎值覆寫、每級加值和額外跳躍；未解鎖角色由局外任務或商店條件解鎖。角色通用預設在 `Zo`，角色覆寫在 `Se`／`Zh`。逐筆條件見[角色表](/Users/peter/repo/godot/godogen/docs/pokebonk-3d-survivor/data/characters.md)。(main:3970, main:1048, main:123, main:4541)

武器各自定時自動發動，按武器類型選目標或攻擊方向；普通 survivor 流程不用玩家逐次按攻擊鍵。通用升級池改傷害、冷卻、數量、尺寸、速度、持續、穿透、擊退與連鎖；達武器等級 5 且持有對應維他命後可以進化，抽卡時會優先露出可進化項。進化武器和搭配表見[武器與進化表](/Users/peter/repo/godot/godogen/docs/pokebonk-3d-survivor/data/weapons.md)。(main:1667, main:4974, main:3558)

### 升級選單

升級選單每次提供 3 張候選卡。候選按類型權重抽取，包括已有武器升級、新武器、維他命升級、新維他命與能力卡；稀有度權重受幸運影響。初始有 3 次 reroll、2 次 banish、3 次 skip；banish 不會排除既有武器／維他命升級。完整候選權重及上限見[升級表](/Users/peter/repo/godot/godogen/docs/pokebonk-3d-survivor/data/upgrades.md)。(main:3550, main:5029, main:3558)

### XP、拾取與掉落

等級需求的底層曲線為 `floor(5 + (level - 1) × 3 + (level - 1)^1.6)`，每級再乘模式設定的 `xpCurve`；XP 獲得再乘角色 XP、全局 XP 和早期局內修正。通用拾取距離預設 4.5 m。(main:4000, main:27323, main:27428, main:3983)

XP 寶石按價值分四級顏色與尺寸；XP 和金幣用 InstancedMesh 繪製，拾取物會彈起、旋轉並在玩家進入吸取距離後被吸引。莓果、磁鐵與 Boss 寶箱另有特殊掉落邏輯；敵人普通硬幣掉落與莓果機率有各自的限制。(main:26912, main:26936, main:27000, main:30490, main:3810)

### Mega

局內地圖預先放 5 顆 Mega 石；碎片與石頭累積充能，滿格便自動觸發，沒有要求玩家手動按鍵。基礎持續 20 秒；變身時造成半徑 14 m 的範圍傷害，附 hit stop、FOV 推進、閃白、星粒子、光柱與擴散圓環。持續中再增加充能會延長時間，每次 12 秒、最長 40 秒；變身期間每秒脈衝一次。(main:3389, main:29908, main:30745, main:30761)

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
| 後處理 | composer 依序串接場景、描邊、 tilt、bloom、finish 與 copy；Bloom 參數為 strength 0.55、radius 0.3、threshold 2.4。(main:32155, main:32160) | 用 Godot WorldEnvironment 的 Glow 加上 SubViewport／Canvas shader 做描邊或色散，提供低畫質選項。 |
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
