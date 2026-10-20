# luffy-marineford：魯夫・頂上戰爭（關卡制倖存者原型）

狀態：**進行中**：第 0 步視覺 spike 只剩手機實測；五幕劇本（[acts.md](../../docs/one-piece-marineford/acts.md)）的基礎系統與幕四骨架已能從頭玩到尾。設計文件見 [docs/one-piece-marineford](../../docs/one-piece-marineford/README.md)（v1.2）。

> 《航海王》是尾田榮一郎／集英社的 IP。這個原型只用來驗證手感，不公開發布、不上 itch.io、不用原作圖與原作音樂。

## 要驗證的假設

照設計文件「第一個可玩切片：C6-A 處刑台」：往前推進的感覺、兩次能力躍升、霸王色值得錄影、手機兩指操作。在那之前先過**第 0 步視覺 spike**：pokebonk.com 式畫面（2D 像素角色立在 3D 地形）在網頁版 Compatibility 渲染器上的風格、效能與構圖。

## 怎麼跑

用 Godot 4.7 開 `prototypes/luffy-marineford/project.godot`，按 F5，預設進幕四。操作：WASD／左半螢幕搖桿；空白鍵＝橡膠火箭（衝刺，沿途撞飛敵人）；二檔、霸王色各一顆按鈕。對話框點一下打完字、再點一下下一句；過場右上角可跳過。

```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot bash prototypes/godot-kit/tools/run_tests.sh prototypes/luffy-marineford banner route sprites core:60 story
```

QA 參數寫在 `--` 後面（網頁版寫成網址參數）：

| 參數 | 作用 |
|---|---|
| `cam=<preset>` | 鏡頭組：`pokebonk`、`madara`、`high`（預設）、`higher`、`steep`（`camera_rig.gd` 的 `PRESETS`） |
| `cam-height=`、`cam-back=`、`cam-ahead=`、`fov=` | 單獨改鏡頭的高度、後退距離、注視點前移、FOV |
| `density=033\|025\|020` | 佔位角色與地面的像素密度（預設 025） |
| `perf=<秒>`、`perf-warmup=<秒>` | 暖機後用牆上時間記錄幀時間，印出 PERF 行（p95、最慢、視錐內敵人數、渲染尺寸）後結束 |
| `start-z=<m>` | 從路線上的某一點開始（負值是往前，例如 `-140` 在路點 1 前） |
| `shot=<png>`、`shot-delay=<秒>` | 等幾秒後存截圖、印出構圖數字（主角在畫面的高度、魯夫在實際畫面佔幾 px、處刑台位置）後結束 |
| `act=<n>` | 玩第 n 幕（`scenes/acts/act_<n>.tscn`）；`0` 是沒有劇情的沙盒。沒指定時進幕四，但有 `perf`、`stress` 或 `shot` 時進沙盒（量測不量到標題卡與過場） |
| `skip-cutscenes` | 過場一開始就結束（測試、長跑） |
| `cutscene=<名稱>` | 暖機後直接播 `scenes/cutscenes/<名稱>.tscn`、不跑幕（配 `shot`、`shot-delay` 截過場中的某一格） |
| `learn=<id>:<級>,…` | 開局學會招式：`pistol`、`gatling`、`whip`、`bazooka`、`gigant`、`gear2`、`haki`（`data/jutsu/`） |
| `stress=<n>`、`seed=<n>`、`autoplay`、`no-hud-perf` | 同 madara-survivor |

並排比較鏡頭（macOS 要開視窗，不能 headless）：

```bash
for c in pokebonk madara high higher; do
  /Applications/Godot.app/Contents/MacOS/Godot --path prototypes/luffy-marineford --resolution 1280x720 \
    -- --cam=$c --stress=250 --seed=3 --no-hud-perf --shot=/tmp/cam-$c.png
done
```

## 鏡頭

固定朝向（往 −Z＝畫面上方），只平移不旋轉；比 pokebonk.com 的第三人稱更高、更遠，注視點放在主角前方。用四個數描述：高度、後退距離、注視點前移、FOV。

| 組 | 高度 | 後退 | 注視點前移 | FOV | 中心俯角 | 主角在畫面 | 魯夫 1.8 m（540 邏輯高、世界直立量法） |
|---|---|---|---|---|---|---|---|
| pokebonk | 4.95 | 8.09 | 0（看腳上 1 m） | 70 | 26° | 0.57 | 69 |
| madara | 9.7 | 9.66 | 0（看腳上 1 m） | 50 | 42° | 0.56（處刑台出畫） | 59 px |
| **high** | 10 | 12.3 | 9.4 | 60 | 24.7° | 0.72 | 46 px |
| higher | 13 | 16 | 12.2 | 60 | 24.7° | 0.72 | 35 px |

- 幾何限制：FOV 60 下要「處刑台留在上緣、主角在 0.72」，從鏡頭看主角腳底的俯角最多約 39°（高度／後退 ≈ 0.81）。再往下看，處刑台就出畫。
- 拉遠（巨人手槍、須佐）沿視線移動，注視點在畫面上不動（有測試）。
- 跟隨：XZ 18、Y 10（pokebonk.com）。

## 場景

| scene | 內容 | 可在編輯器調整 |
|---|---|---|
| `scenes/route.tscn` | C6 灰盒路線：高度場地形、閃電橋、處刑台、海軍本部、包圍壁、6 艘軍艦、路點（路點 1、卡普、處刑台） | 地標的位置大小與材質顏色；`Route` 根節點的路寬、橋、終點（改了地形數字要重跑產生器，只重建 mesh） |
| `scenes/ult_banner.tscn` | 大招全寬斜向橫幅（HUD 裡的 `UltBanner`） | 傾斜角、色帶 StyleBox、頭像框、字級；根節點的三段時長、白閃、Safe Insets |
| `scenes/fist_streak.tscn` | 橡膠手槍拳影（3 條手臂輪流用） | 停留時間、肩高、手臂寬；`shaders/fist_streak.gdshader` 的顏色 |
| `scenes/main.tscn` | 一局：Route、玩家、大軍、鏡頭、HUD、StoryUi | `CameraRig` 的 View 群組（高度、後退、注視點前移、FOV）、WorldEnvironment 的霧與天空色；`Main` 的 Story（預設幕）、Rocket、Hormone 群組 |
| `scenes/story_ui.tscn` | 劇情層：對話框（頭像、名字、台詞、▼）、遊戲中字幕、toast 欄、幕標題卡、過場黑邊、跳過鈕 | 各元件的位置大小、StyleBox、字級；根節點的打字速度、字幕停留、toast 停留、標題停留 |
| `scenes/toast_item.tscn` | 三國無雙式側邊通知（頭像＋名字＋一句話） | 色帶、頭像框、字級；滑入時間 |
| `scenes/cast_actor.tscn` | 一名角色（sprite＋腳下影子），`character` 決定用哪張圖 | `character`、`anim`、`facing`、影子比例 |
| `scenes/blocker.tscn` | 擋路角色（卡普、克比）：被魯夫打中 `hits_needed` 下後飛走 | 要打幾下、碰撞半徑、被打與飛走的動畫、飛多遠 |
| `scenes/acts/act_4.tscn` | 幕四：根節點 `Act`（幕號、標題、起點、方向、開局招式、同伴），底下是觸發點（`ActTrigger`，Z 位置＝在路線哪裡觸發、`goal_name`＝目標列名稱），每個觸發點底下依序是劇情步驟（`Beat`：台詞、字幕、toast、橫幅、標題、過場、呼叫、等待、過關） | 觸發點位置、步驟的順序與文字、頭像、顏色；`Reference` 是編輯器裡對位用的路線（執行時刪掉） |
| `scenes/cutscenes/act4_*.tscn` | 幕四的三段過場（荷爾蒙、行刑、金色拳頭）：`Shot` 鏡頭、`Anim` 動畫（鏡頭移動、角色動作、方法軌叫台詞與震動）、角色 | 在動畫編輯器改鏡頭關鍵格、台詞時間與內容；角色位置 |

- `tools/build_route.gd` 產生 `route.tscn` 與 `assets/route/terrain.res`，地形與可走範圍出自同一個 `scripts/route.gd` 的高度函式。在編輯器改了 `Route` 根節點的路寬、橋段等數字後重跑：產生器讀 `route.tscn` 裡的設定重建地形 mesh，scene 本身不覆蓋。**橋面（`Bridge` 節點）要自己在編輯器對齊**；尺寸或位置對不上時產生器會警告並印出應設的值。
- 地形 `shaders/terrain.gdshader`：toon 分層明暗、世界座標 40 px/m 量化，依坡度與高度分成廣場石板、懸崖岩層、平台霜面、海溝冰面。地標 `shaders/toon_solid.gdshader`。

## 現況

- 從 madara-survivor 複製（不含 `art_src`），渲染器改成 Compatibility。敵人資料（`data/enemies`）與升級被動還是斑的。
- **招式**（`scripts/jutsu.gd`，數字依設計文件「魯夫的招式」，未調手感）：手槍（直線、Lv4 貫穿 3）、機關槍（扇形連打）、鞭（360° 掃腿）、火箭砲（推成一道牆）、巨人手槍（定時砸地）、二檔（按鈕：全招式 ×1.6、移動加快、冒蒸氣）、霸王色（`ultimate.gd`：一般兵昏倒算擊殺、不回意志值；精英震退 4 m）、橡膠火箭（衝刺鍵，沿途撞飛）、荷爾蒙（每幕一次致命傷改成剩一半血）。招式也打得到劇情的擋路角色（`jutsu.targets`）。
- **劇情系統**（`act.gd`、`act_trigger.gd`、`beat.gd`、`story_ui.gd`、`cutscene.gd`）：抵達觸發點就依序跑劇情步驟；對話、標題卡、過場會停住遊戲時鐘，字幕與 toast 不會。過場借用遊戲鏡頭（描邊與後處理照常），結束時 0.6 秒滑回追蹤鏡頭。
- **幕四骨架**（`act=4`，預設）：伊萬科夫打荷爾蒙 → 廣場推進 → 克比擋路（打 2 下） → 行刑過場 → 霸王色 → 白鬍子 toast → 橋升起（之前過不去） → 卡普對話與擋路（打 8 下） → 金色拳頭過場 → 過關。開局套裝：手槍 3、機關槍 3、二檔 1、巨人手槍 1。
- **角色**：Codex 用程式畫的佔位魯夫、海兵、中將（玩家白色、中將金色的身分描邊）（`tools/make_placeholder_sprites.py`，三種密度各一份圖集在 `assets/sprites/density_*/`）。玩家與大軍都依鏡頭相對方向選 8 方向（5 列畫、3 列鏡像），用 kit 的 `Sprite3DSheet`（`scripts/sprite_set.gd` 載入）。
- **畫面**：像素天空（`pixel_sky`，7 階、4 px Bayer）、地形 toon、深度描邊（`pixel_outline`，全畫面 quad 排在透明佇列最前）、調色與暗角（`grade`，HUD 下面的 CanvasLayer 讀 screen texture）、Environment 的 Glow 與距離霧。
- **路線**：敵人從前方 55 m 生成、散佈在整條路寬；落後玩家 25 m 以上的敵人移到前方（後面不留東西）；玩家與大軍被路線邊界擋住。頂端目標列顯示下一個路點與剩餘距離。

## 量測（2026-10-20，250 隻，`perf=10`，暖機 10 秒，視窗 1280×720，3D 以 1280×720 渲染）

| 平台 | 靜止 p95／最慢 | 沿路前進 | 群體受擊（第 11 秒放大招） |
|---|---|---|---|
| 本機 macOS（M1 Pro、Compatibility） | 7.4／17 ms | 7.3／12 ms | 14.5／25 ms |
| 網頁 Chromium 153（ANGLE Metal、硬體 WebGL、DPR 1） | 9.3／10 ms | 9.3／12 ms | 9.3～9.4／12 ms（2 次） |

- 指令：靜止 `stress=250&seed=3&perf=10`；前進加 `autoplay`；群體受擊加 `autoplay&ult-at=11&learn=haki`（大招要先學會：`ult-at` 只把支配值設滿；施放時印 `ULT fired`，量測要看到這行才算數）。
- 兩邊都受螢幕垂直同步限制（本機 120～145 Hz、網頁 120 Hz），平均幀時間就是刷新間隔。
- **開局預熱**（`_begin_warm_up`）：前 3 幀不推進遊戲，把隱藏的效果節點移到鏡頭前、各種特效池各發一次，螢幕壓暗。網頁版大招第一次施放的最慢一幀：沒預熱 62／62／67／87 ms；第一版預熱 13／16／29／31 ms；Codex 第三輪指出特效池樣本沒在預熱期間畫到，修正後 12／12 ms。網頁沒有 shader 快取，第一次畫到的材質當場編譯；預熱把這筆成本移到開局。`no-warmup` 可關掉對照。
- 開局第一秒內本來就有 430～950 ms 的長幀（引擎啟動），量測一定要暖機。
- macOS 視窗被蓋住時 Godot 會停止更新（量測卡住、CPU 1%），量測與截圖要加 `--always-on-top`。同一台機器不要同時開瀏覽器或別的 Godot。
- 手機還沒量（要使用者的手機）。

## 三種像素密度（`density=033|025|020`）

`high` 鏡頭、720p 渲染下，1.8 m 的魯夫在畫面上約 73 px（`shot` 沿 billboard 方向量、換成實際像素）：0.025（素材 72 px）接近 1:1；0.020（90 px）被縮小、邊緣變糊；0.033（55 px）被放大、像素最清楚。地面與地標的像素密度跟著角色一起切換。對照圖 `.claude/tasks/luffy-spike/density_compare.png`。手機的渲染解析度不同，要在手機上選。

## 第 0 步還沒做的

- [x] 使用者選鏡頭組：`high`（2026-10-20，已是預設）
- [x] 像素天空；地形 toon（手動方向光，不用場景燈）
- [x] 後處理：像素描邊（深度）、tint／ToonGrade、暗角；Glow
- [x] 佔位魯夫與海兵（8 方向），三種像素密度在選定鏡頭下比較
- [x] HUD 目標列
- [x] 網頁匯出；桌機原生與網頁三情境量 p95
- [x] Codex 審查 spike 程式（P1×3、P2×7），已修正，見 `docs/one-piece-marineford/reviews/claude-response-spike-code.md`
- [x] 透明拳影（`scenes/fist_streak.tscn`：體術出拳時伸長的手臂與拳頭，疊在描邊上不被抹掉）
- [x] 全寬斜向橫幅（Codex 製作：`scenes/ult_banner.tscn`，`hud.show_banner(標題, 副標, 顏色, 頭像)`；放大招時顯示「霸王色霸氣」）
- [x] 大招第一次施放的卡頓：開局 shader 預熱（網頁最慢一幀 62～87 → 12 ms）
- [ ] 使用者手機：三情境 p95、三種密度、兩指操作
