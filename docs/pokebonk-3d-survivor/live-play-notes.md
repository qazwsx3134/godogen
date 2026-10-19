# PokeBonk 實玩筆記（Claude，2026-10-16）

用 Playwright 驅動 Chromium（WebGL 開 Metal）實際玩了兩局 Classic／Casual，角色 Pikachu。只玩單人，沒進線上房間。
截圖、圖鑑文字與網路記錄都在 `.claude/tasks/pokebonk/`（已 gitignore，第三方美術不進版控）：`shots/`、`dex/`、`runtime-net.log`。
數值與規則以 `codex-bundle-analysis.md` 從程式碼拆出的為準；這份記錄畫面、流程與手感。
注意：線上數值由 `/api/config` 覆寫 bundle 預設（存於 `.claude/tasks/pokebonk/api-config.json`），所以畫面上看到的數字可能和 bundle 預設不同，見 README「線上平衡覆寫」。

## 1. 一局的流程

```
標題 ─→ 選角（招式即時示範＋數值）─→ Run Setup（模式／難度／Boss 數／Pressure／修飾器）
   └→ 載入（提示＋畫質三選一）─→ 開局
開局 ─→ 打怪撿水晶 ─→ 升級卡（暫停）─→ …
        │  第一隻 Boss 約 1:30 出現，之後擊敗後約 60 秒再來一隻（倒數常駐 HUD；
        │  bundle 預設 90 秒，線上覆寫 interval 60）
        │  波次橫幅：「WAVE 2 ZUBAT · 29 隻從四面包圍」
        │  天氣輪替（晴→暴風雪→強風→烈日），對屬性加減成
        │  Alpha 寶可夢事件：打倒得寶貝球
        └→ 打完 N 隻 Boss（6 隻約 9 分鐘，最終 Lugia）或陣亡 ─→ 結算
```

實測節奏：第一局 1:19 已 Lv9、1:41 打完第一隻 Boss（卡比獸 11.6 秒）、2:51 被第二隻 Boss（耿鬼）打倒，Lv17、904 擊殺、最大連殺 769。

## 2. 成長系統（從 UI 看到的）

| 系統 | 槽位／來源 | 備註 |
|---|---|---|
| 招式 Move | 4 格，升級卡 | 每招有傷害、冷卻、數量、大小、速度、穿透、擊退；Lv5＋指定維他命 → 進化卡保證出現 |
| 維他命 Vitamin | 4 格，升級卡 | 12 種，全域屬性（傷害、移速、護甲、HP、範圍、攻速、彈數、XP、拾取、幸運、彈速、持續）；卡上有稀有度，越稀有加越多（Common +10%、Epic +27%） |
| 特性 Ability | 3 格，升級卡（Lv3 起） | 14 種，Uncommon→Legendary，例：Speed Boost 每存活一分鐘 +5% 攻速；Sheer Force +35% 傷害但無擊退 |
| 道具 Item | 寶貝球開出 | 32 種、Common→Legendary；地圖上的球要花錢開，Boss 掉的免費；Alpha 掉的球預設也要付錢（設定 `alphaFree` 打開才免費，`main:3896`）；球越稀有道具越稀有 |
| 組合 Combo | 圖鑑列 16 組 | **不改數值**，只是在 build 湊齊 2–3 件時跳橫幅、卡上蓋章，告訴玩家「這套成形了」；升級卡會顯示「Combo 2/3 Electric Storm」引導。另有一個例外：`Tempestade Divina`（龍之波動、龍捲風、制裁光礫）同時持有會**降傷害**（2 招 85%、3 招 60%，`main:3601`），這是防疊加的削弱，不屬於這 16 組 |
| Mega | 吃 Mega 碎片填條 | 滿條當場變身：Pikachu Gigantamax「+80% 傷害、+30% 攻速、20 秒」；變身中擊殺浮出「+2.6s Mega」延長時間。這兩個數字都來自線上覆寫：Classic／Normal 的 Mega damage 0.8（bundle 預設 0.6）、碎片值 0.22（預設 0.14），0.22 × 12 秒 ≈ 2.6 秒 |

升級卡介面：3 選 1、Reroll×3、Skip（次數隨等級累積 3→8）、Banish×2–3、Q 自動選；強化卡顯示「前 → 後」數值與差額；新招式卡內嵌 3D 即時示範（假人靶場）。

局外：BP（Battle Points）幣，結算 +41 BP；任務 22 個，完成解鎖招式／角色（例：「Horde grinder」解鎖 Kowtow Cleave）；73 隻角色中 14 隻預設可用，其餘用 BP（200–800）或任務解鎖。

## 3. 模式與難度（Run Setup）

- 預設組：Casual／Hard／Challenge／No Pressure／Custom。
- 模式：
  - **Classic**：晴天草原。
  - **Grim Night**：淹水夜谷，鬼與惡系，最終 Boss 為 Darkrai。
  - **Quarry**：黃昏礦場，敵人慢但耐打、打得重，最終 Boss 為 Groudon。
  - **Boss Mode**：原型模式，操作 Lucario，有三段連擊、空中踢與架勢條。
  - **1v1 Duel**：線上模式。
  - **Bonk**：分關，有神殿、商人、微波爐，Boss 後出現傳送門，時間到則進入最終蜂群。
- Difficulty：Normal／Hard（Hard 時 Boss 使用原作招式）。Boss 數可選 3／6／9／12／15。
- **Pressure**（Off／Light／Normal／Strong）：只有 build 遠超曲線時才加壓，屬於動態難度。
- 修飾器可複選：Fast Horde、More Alphas、No Berries、Swarm、Brutal Bosses、Glass Pokémon。
- 開關：
  - **Restricted**：只出本屬性招式，+25% 傷害。
  - **Random Bosses**：隨機抽 Boss，並決定哪一隻是最終 Boss。
  - **Adaptive**：隨傷害成長加強敵群，+25% BP。

## 4. 畫面與特效（看到的＋設定選單揭露的）

- **鏡頭**：第三人稱背後、偏低，看得到遠方地平線；可調距離。移動 WASD、Shift 衝刺、Space 跳（角色有跳躍次數，Pikachu 1 次）。
- **風格**：低多邊形場景＋原作寶可夢模型＋**卡通描邊**；高草叢（可關）、漂浮花粉與螢火蟲、黃金時刻調色、移軸模糊、暗角、bloom。全都在設定裡有滑桿 → 後處理是一條可調的堆疊。
- **打擊感**：設定有 Hit-stop、Camera Shake、Screen Flash、Impact Distortion（截圖看到受擊時 RGB 色差）、Effect Strength 五個獨立滑桿。
- **數字**：一般傷害藍白小字；爆擊是金色「CRIT 50」加大字；Mega 期間出現浮字「+2.6s Mega」。設定可選全部／只顯示爆擊／不顯示。
- **掉落**：
  - XP 是大顆、旋轉的藍色低多邊形水晶。
  - 金幣是黃色圓片。
  - 道具位置在天空打一道彩色光柱。
  - Boss 掉落是巨大 3D 寶貝球，靠近按 E 開。
- **死亡**：深灰煙團（smoke 貼圖）＋碎片。
- **HUD**：
  - 左上：頭像、HP／EXP、Mega 條。
  - 中上：計時器、波次、模式標籤、天氣卡（顯示對哪些屬性加減成）、Next Boss 倒數。
  - 右上：金幣、擊殺數、大字 Combo 連殺數、小地圖（標出寶貝球位置）。
  - 下方：4 招式格（等級與進度條），以及 Abilities／Vitamins／Items 三排格子。
  - HUD 可在設定裡編輯位置。
- **可讀性**：「Always see my Pokémon」會在草、特效與閃光之上把自己的角色描邊畫出來。
- **效能選項**：陰影 Off／Low／High、解析度 Light／Normal／Sharp、地面特效上限、**自動降解析度**、FPS 計數器。載入畫面直接請玩家選畫質。

## 5. 美術（從截圖看到的）

程式碼層的做法（toon、描邊、草、水、天空、霧）寫在 `art-and-vfx-implementation.md`；這一節只記畫面給人的印象與版面規則。

- **整體調性**：
  - 高飽和的亮綠草原，配上暖黃的黃昏霧。
  - 遠景是一排排深綠松樹，加上灰色低多邊形石頭與圓胖灌木。
  - 湖岸是一圈淺沙，水面淡藍，邊緣有一圈白色泡沫。
  - 場景是平面著色的低多邊形，角色是原作模型加上 toon 著色與黑色描邊。兩者的細緻度不同，但被描邊與調色統一。
- **鏡頭構圖**：
  - 主角在畫面下 1/3、略偏中央。
  - 鏡頭高度約在主角頭頂，所以前景的草葉會擋住部分畫面。
  - 這樣有臨場感，但敵人在草裡比較難看清楚，所以才需要「Always see my Pokémon」與敵人頭上的數字。
- **UI 視覺語言**：
  - 黑底面板配黃色粗字（Chakra Petch 斜體粗體），色塊與按鈕都切斜角。
  - 每個按鈕與面板下方都有一塊錯位的紅色或藍色硬陰影，像貼紙疊在一起。
  - 標題頁背景是黃色放射線（sunburst），主角站在寶貝球紋樣的圓台上。
- **升級卡**：
  - 卡頂插圖區用放射線網點背景，顏色依類別區分：招式按屬性色，維他命是藍，特性是綠或黃。
  - 道具與維他命圖示是像素風（pixelated）。
  - 卡底是米白紙色（`--paper`），數值框是黑底黃字。
  - 稀有度用一條彩色細帶加上文字。
- **橫幅與數字**：「LEVEL UP!」「WAVE 2 ZUBAT」「MEGA PIKACHU GIGANTAMAX」都是斜體大字，配黑色底塊與黃色描邊，從畫面中上方滑入。
- **HUD**：
  - 半透明深色托盤（`--tray`）。
  - 等級與數值用像素字 Silkscreen，名稱用 Chakra Petch。
  - 右上角的連殺數用超大的粉紫色字，數字越大越顯眼。
- **鎖定角色**：灰階剪影，加上斜向「TRANCADO」（已鎖定）字樣，以及價格或「MISSION」標籤。

## 6. 素材管線（執行時網路記錄）

- 模型：`/models/pokemon/*.glb`、`/models/swsh/*.glb`（載入器配置了 Draco decoder，執行時也真的載了 `draco_decoder.wasm`，表示至少部分模型是 Draco 壓縮；沒有逐檔確認），`/models/props/`（寶貝球、樹果、Mega 標記、Gmax 特效），`/models/mega/gmax-25.glb`。
- VFX 貼圖：`/vfx/` 下 40 張，例如 `circle_02`、`smoke_01–08`、`spark_05`、`star_06`、`trace_07`、`twirl_01–03`、`slash_01–04`、`scorch_01–03`、`magic_03`、`flare_01`、`light_03`、`dirt_01`。檔名與 **Kenney Particle Pack（CC0）** 的命名一致，但來源與授權沒有證實；Godot 版若要用，直接從 Kenney 官方下載，不要拿這裡的檔案。
- UI 圖示：`/sprites/items/`、`/sprites/types/`、`/sprites/home/`；第一局沒有任何音檔請求，`main` 也沒有任何 WebAudio 呼叫（`AudioContext`、`createOscillator`、`new Audio` 都是 0 次），客戶端看起來沒有音效。
- 後端：
  - `/api/config`：公告、維護開關，以及 **211 個平衡覆寫鍵**，可依模式、難度分開設定。
  - `/api/runs/start` 加週期性 `/api/runs/tick`：客戶端回報局的開始與進度（`main:29699`）。伺服器怎麼驗證、防不防竄改，從客戶端看不出來。
  - `/api/t/stream`（EventSource）加 `/api/t/ping`：遙測與即時資料。
  - `/api/votes`：每週投票加角色。

## 7. 實玩疑點與程式碼對照結果

- 兩局都在第一隻 Boss 時剩 2/90 HP：程式碼只有兩種保命——**Hard** 難度滿血時單擊傷害有上限（`main:27444`）與 Focus Sash 道具（`main:27481`）。這兩局是 Normal 也沒道具，所以只是 Boss 傷害剛好。
- 玩家受傷回饋（`main:27470`）：0.4 秒無敵、紅字傷害數字、震屏 0.2、紅色粒子、hit-stop 0.05 秒。
- Skip 會把該級換成 `round(5 + level × 2)` 金幣（見 `data/upgrades.md`）。
- Mega 碎片來源：Boss 每隻 2 顆、地圖預放 5 顆 Mega 石；變身中再充能延長，每次 12 秒、最多 40 秒（Codex 報告「Mega」節）。線上 Classic／Normal 的碎片值是 0.22，所以一顆碎片延長約 2.6 秒，與畫面一致。
