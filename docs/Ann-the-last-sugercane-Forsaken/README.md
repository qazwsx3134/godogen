# 安（Ann: the Last Sugarcane — Forsaken）

手機直式的《弓箭傳說》（Archero）式房間射擊。主角丟甘蔗，一路從宮廟打到天安門廣場，最後在中正紀念堂面對蔣介石。

- **可玩原型**：[`/mnt/d/repo/godot/sugarcane-tanks/`](../../../sugarcane-tanks/README.md)（2026-10-04 從 `prototypes/` 搬出 repo），Godot 4.7、GDScript。資料夾名稱是暫名時取的。
- **狀態**：第一章 15 間可以從頭玩到尾，4 組自動測試通過；還沒有真人試玩，也還沒上過實機。
- **和其他文件的關係**：這個原型原本是《宇智波斑 Survivors》（[PROJECT.md](../survivors/PROJECT.md)）取得版權前的替身，用來驗證自動攻擊、升級疊加與打擊回饋。

```bash
cd /mnt/d/repo/godot/sugarcane-tanks
G=/Applications/Godot.app/Contents/MacOS/Godot
$G --path .                                  # 玩（或用編輯器開這個資料夾按 F5）：先到開始畫面，按「開始遊戲」
$G --path . -- --room=15                     # 從第 N 間開始（第 15 間是最終 Boss）
$G --path . -- --give=front,multishot,fire   # 開局就帶這些能力
$G --path . -- --autoplay                    # 機器人自己玩（展示、錄影、測試用）
./tools/check.sh                             # 全部測試
```

操作：畫面任一處按住拖曳是浮動搖桿（平時不顯示，按下才在手指下半透明地出現，放開就消失）；放開手就自動朝最近而且看得到的敵人丟甘蔗。電腦上也可以用 WASD。`--` 後面帶任何參數（上面的 `--room`、`--give`、`--autoplay` 等）都會略過開始畫面，直接進載入畫面開始，錄影與測試才不會停在標題。

## 概念圖與目前原型的差距

| 概念圖 | 內容 |
|---|---|
| ![天安門關卡](ann1%20Large.jpeg) | 天安門廣場：坦克開砲、老鼠、背木桶的大老鼠、三個技能欄、大招按鈕、金幣 |
| ![中正紀念堂關卡](ann2%20Large.jpeg) | 中正紀念堂：大量老鼠、戴皇冠的鼠王、廚師敵人、STAGE／WAVE 標示 |
| ![Boss 戰](ann3%20Large.jpeg) | Boss 戰：光頭 Boss 放紅圈範圍攻擊、持矛老鼠、甘蔗能量條與彈藥 |

| 概念圖有 | 原型現況 |
|---|---|
| 像素風美術 | 主角、敵人、投射物、掉落物、頭像、能力圖示已換成生成的像素風圖（`assets/`，角色面朝右、左右翻面）；場地與障礙物也換成了生成圖：四個場地各貼一張 1080×1920 的背景（宮廟、天安門廣場、中正紀念堂廣場、紀念堂內，第 11–15 間），牆的碰撞照圖上的欄杆、花園、樹、建築、火盆擺，4 種障礙物（木箱、沙包牆、拒馬、石塊）只擋底座，角色可以走到它們後面被擋住（y-sort）；詳見專案 README 的「素材與來源」。還沒做：逐格動畫；場地圖比概念圖乾淨（地上沒有碎石與焦痕）|
| 大招按鈕、技能欄、甘蔗能量／彈藥 | 技能欄已做（下方中間，每個拿到的能力一格，◆ 顯示疊層）；沒有大招按鈕與甘蔗能量，只有自動攻擊，技能以「升級三選一」的被動能力呈現 |
| 金幣、STAGE／WAVE | STAGE 與金幣已做：右上 STAGE 框顯示房間數，下面是金幣（敵人掉落，只在一局內累積，結算顯示）；沒有局外成長與商店，也沒有 WAVE，一章 15 間房沒有波次 |
| 坦克開砲 | 依需求改成「預警後衝刺碾人」，不開砲 |
| 背木桶大老鼠、鼠王、持矛老鼠、廚師 | 廚師已做（原本的餐盤怪換成廚師，一樣丟三色豆）；沒有背木桶大老鼠、鼠王、持矛老鼠 |
| 一群一群的敵海（圖二） | 弓箭傳說式一間 5–8 隻；大量敵人要換架構，見下方「可共用的模組」最後一段 |

## 目前的功能

### 一章的流程

先經過兩個畫面才進到遊戲：

```
遊戲啟動 ─→ 開始畫面 ──按「開始遊戲」──→ 載入畫面（進度條）──載入完──→ main.tscn（第 1 間）
              │  └─「製作名單」──→ 製作名單面板（關閉／Esc／Back 回來）
              └─ 帶開發參數（--autoplay、--room=N …）：直接進載入畫面，不停在標題
```

遊戲本身：

```
第 1–3 間 ─→ 第 4–7 間             ─→ 第 8–10 間                ─→ 第 11–15 間
宮廟         天安門廣場               中正紀念堂廣場               紀念堂內
老鼠為主     坦克、廚師登場           全部混合                     全部混合、血量更高
             第 5 間 Boss 重型坦克    第 10 間 Boss 重型坦克 II    第 15 間 Boss 蔣介石

進房 → 敵人淡入 0.6 秒（進入新區域時跳出地名）→ 移動閃避／停下自動丟甘蔗
 → 全滅：清掉敵方子彈，經驗寶石、金幣與愛心飛向主角
 → 每升一級暫停一次，3 選 1 能力
 → 第 5、10、15 間是 Boss；第 5、10 間打完出現天使（回血 40% 或拿一個能力）
 → 上方的門打開，走進去 → 下一間
第 15 間 Boss 倒下 → 第一章完成；主角倒下 → 結算，按「再來一次」重來
```

每間房的場地、地名、敵人、`hp_scale` 與障礙物數量見[專案 README](../../../sugarcane-tanks/README.md) 的「15 間房」表。

### 主角與能力

主角：生命 600、攻擊 50、每 0.8 秒丟一次、移速 430。移動時不攻擊，一停下 0.12 秒內就丟出第一根。主角用手丟紫色甘蔗，畫面是 6 格的投擲動畫：移動時站姿（格 0）；下一次投擲前的最後 0.15 秒舉手蓄力（格 1→2）；甘蔗生成的那一刻出手（格 3），接著 4→5→0，共約 0.25 秒。動畫只跟著投擲節奏走，不會改變它；攻速很快或連續投擲時，每次出手都從格 3 重新開始。丟出去的甘蔗朝目標飛，飛行中自轉（每秒 2.5 圈）。

升級三選一的 15 種能力，可以疊加。甘蔗越多，每根的傷害越低：

| 類型 | 能力（id） |
|---|---|
| 投擲數量 | 正面甘蔗 +1（`front`，每層每根 −25%）、連續投擲（`multishot`，每層 −15%）、斜向（`diagonal`）、側向（`side`）、後方（`rear`） |
| 甘蔗特性 | 穿透（`pierce`，每穿一隻 −33%）、彈射（`ricochet`，最多 3 次，每次 −30%）、牆壁反彈（`wall_bounce`，2 次）、火焰（`fire`，燃燒 2 秒）、冰凍（`freeze`，減速 1.5 秒） |
| 數值 | 攻擊強化（+20%）、攻速強化（+20%）、暴擊強化（+10%，暴擊 2 倍）、生命強化（上限 +120）、急救（回 40%，受傷時才會出現） |

### 敵人

| 敵人 | 數值 | 行為 |
|---|---|---|
| 老鼠 | HP 100、移速 230、碰撞 52、EXP 3 | 第 1 間起。左右搖擺衝向主角撞人，被打會被推開 |
| 坦克 | HP 390、碰撞 35、**碾壓 150**、EXP 5 | 第 2 間起。開向主角 → 停下亮紅線 0.6 秒 → 以 1000 的速度衝刺，直接碾過主角（主角被壓扁一下）→ 停頓 0.75 秒，這是反擊的空檔 |
| 廚師（檔名 `plate`） | HP 245、豆子 65、EXP 4 | 第 3 間起。保持 380–700 的距離、左右橫移、永遠面向主角，每 1.8 秒跳一下，從平底鍋丟出扇形的豌豆、玉米、紅蘿蔔 |
| 重型坦克（第 5 間 Boss）、重型坦克 II（第 10 間 Boss） | HP 1800、2800 × 1.7（II 叫 4 隻老鼠）、碾壓 210、EXP 40 | 輪流：長距離衝刺、連續三段衝刺、叫出老鼠（叫出來的不給經驗）。半血後預警變短、老鼠變多 |
| 蔣介石（第 15 間 Boss） | HP 6000 × 2.0、子彈 82、EXP 40 | 在上半場移動，手槍跟著主角轉；開火前身體閃一下，輪流放紅圈、瞄準三連發、錯開兩波的扇形、旋轉螺旋、整圈環形。紅圈是第一招：一次 5 個（傷害 120、半徑 130），1 個在主角腳下、4 個隨機落在地板上且彼此不大幅重疊；內圈 1.5 秒長滿就引爆（爆炸、碎石、震屏、爆炸聲），主角中心在圈內才受傷；Boss 放完不等引爆，接著休息、移動。血量低於一半就**生氣**：橫幅「蔣介石 生氣了！」、身體閃一下再持續泛紅脈動、頭上冒蒸氣與怒氣符號；之後子彈變快、**碰到牆壁或障礙物會反彈**（`rage_bounces` 預設 2 次，反彈後 1.5 秒內淡出；豆子不反彈），休息時間縮短，紅圈變 7 個、長滿只要 1 秒 |

敵人卡在箱子前面時會自動往側邊繞；後面的房間用 `hp_scale` 提高整間的血量（倍率見專案 README 的房間表）。升級所需經驗是 `4 + 2×等級`，敵人的經驗與金幣各有各的數值；清完第 1、3、8、10、12、15 間的等級是 3、5、12、14、16、19（專案 README 的「平衡」）。

### 回饋與 UI

- **打擊回饋**（`game/juice.gd`，`main.tscn` 的 `%Juice`）：事件歸成 small／medium／large 三級，各級決定震屏量、hit stop 長度與粒子數量倍率（trauma 0.25／0.45／0.85，hit stop 無／0.045／0.14 秒，粒子 ×0.6／1.0／2.2）。
  - 震屏用 trauma 模型：事件累加（同一級最多疊到單一事件的 1.4 倍，所以四個紅圈同時引爆也只是低低的震動）、每秒衰減、實際位移是 trauma 的平方，用兩條 sin 疊出平滑的晃動與微小的翻滾，不是每幀亂數；`shake_scale` 為 0 就完全不震，`flash_scale` 為 0 就不閃紅邊與白閃。
  - 命中：敵人的圖擠壓後彈回、命中點像素火花；爆擊再加 small 震屏、傷害數字 overshoot 彈出。
  - 死亡：一般敵人 medium（hit stop、依圖片取色的碎片、閃白→擠扁→縮小淡出，碰撞當下就關）；Boss large（加長的 hit stop、全畫面白閃、碎片加倍、餘震）。
  - 主角：丟甘蔗小擠壓＋手上火花（不震屏）；走路腳下冒灰塵、停下輕微擠壓；受傷 medium（碾壓 large）＋畫面四周閃紅＋HP 殘影條＋無敵時間閃爍。
  - 其他：坦克預警時圖片原地抖動、衝刺揚灰塵、撞牆 small；紅圈打到主角由受傷的 medium 負責、沒打到 small；掉落物彈出、撿到時小閃光＋HUD 數字跳一下；升級光環；開門金光＋small；Boss 登場 medium 且 Boss 條從 0 填滿。
  - 手機震動：螢幕會晃的重要時刻，手機馬達也跟著震一下（small／medium／large 是 14／38／90 ms；一般命中、丟甘蔗、撿東西不震；兩下之間至少 70 ms、每秒最多 6 下）。暫停選單有「手機震動」「畫面晃動」兩個開關，存在 `user://settings.dat`。網頁版靠 `navigator.vibrate`（Android 瀏覽器有、iPhone Safari 沒有）；itch.io 的 iframe 要帶 `allow="vibrate"` 才會震，沒有在真機上驗證，細節在專案 README 的「手機震動」。
  - 完整的事件與分級對照表在 [專案 README](../../../sugarcane-tanks/README.md) 的「打擊回饋」。
- **音效**：每個事件都會呼叫 `game.sfx.play(&"事件名")`。`assets/sfx/` 的檔名就是事件名（全部是 Kenney，CC0），換檔案不用改程式。找聲音的順序：檔案 → 內建合成音 → 借用別的事件的聲音 → 靜音。現在只有 `squeak`（老鼠叫）還是合成音，`bump` `drop` `heal` `level_up` `boss_intro` 刻意靜音；`ricochet`（彈射）與 `rage`（Boss 第一次低於一半血）是只有聲音的事件。事件名稱與檔案規則見專案 README 的「音效接口」。
- **背景音樂**（`game/music.gd`，`main.tscn` 的 `%Music`）：一般房間循環播 `battle.ogg`，Boss 房換成 `boss_battle.ogg`；換曲時舊的淡出、新的淡入，通關或死亡時淡出；音量（-12 dB）比音效（-6 dB）小聲，暫停與 hit stop 時照常運作。來源與授權（CC0）在 `assets/music/CREDITS.md`。
- **HUD**（照概念圖）：左上頭像、等級、血條與經驗條；右上 STAGE 房間數、暫停、金幣；下方中間的技能欄（每個能力一格，◆ 顯示疊層，最多顯示最近拿的 5 格）；按住時才在手指下出現的半透明浮動搖桿（平時不顯示）；Boss 房換成上方的 Boss 血條，主角血量移到下方中間；進入新區域時跳出地名；主角與敵人頭上各有血條。金幣由各敵人的 `gold_value` 決定（和經驗分開），只在一局內累積。
- **面板**：升級三選一、天使二選一、結算／再來一次。能力卡由左到右是 96 px 的能力圖示（沒有圖示的選項，例如天使的回復生命，顯示色塊）、標題與最多三行說明、疊加層數；卡片 250 px 高，文字都在外框內側。
- **開始畫面、載入畫面、製作名單**（`ui/title.tscn`、`loading.tscn`、`credits_panel.tscn`，專案的主場景是開始畫面）：
  - 開始畫面：主視覺鋪滿（像素風、最近點濾波）加上下較深的暗色漸層、金色大「安」緩動上下浮動、副標、大按鈕「開始遊戲」（預設取得焦點，Enter／空白鍵／手把 A 鍵都能開始，輕微呼吸）、次要按鈕「製作名單」、最下方的音樂與音效 credit 小字。上下各留 100 px 給瀏海與手勢列；比 9:16 更高的手機把多出來的高度留給畫面，更寬的桌面視窗左右留黑邊。
  - 主視覺還沒生成，現在是預設版面（`bg_memorial.png` 加漸層，主角站在左下）；使用者生成的 1080×1920 直式圖放進 `art_src/title_bg.png` 跑 `tools/process_art.gd`（或直接放 `assets/title_bg.png`），開始畫面發現檔案就自動換上，不用改程式。
  - 載入畫面：深色底、小「安」、金色圓角進度條、「載入中… 63%」、一句隨機小提示（只寫已經成立的事實）、同樣的 credit 小字。用 `ResourceLoader.load_threaded_request` 載入，進度條只往前、不跑在時鐘前面，最短顯示 1.2 秒（`min_show_time`，網頁版沒有執行緒時載入同步完成也一樣）；載入失敗顯示錯誤與「重試」，不會卡在 99%。
  - 製作名單：音樂（Wolfgang_《bgm》、nene《Boss Battle #2 ["8 bit"]》，CC0，OpenGameArt.org）、音效（Kenney，CC0）、字型（Noto Sans TC，SIL OFL 1.1）、引擎（Godot，MIT）。名單只寫在 `data/credits.tres` 一處，開始畫面、載入畫面與面板都讀它；面板可以用滾輪或手指捲動，「關閉」、Esc、Back 都能關，開著時底下的按鈕點不到。
  - 啟動時的 boot splash：背景色 #14141C（和載入畫面同色），圖是開始畫面拿掉按鈕的樣子（`assets/boot_splash.png`，`tools/make_splash.gd` 產生，主視覺換了要重跑）。

## 架構

### 場景樹（`main.tscn`）

```
Main (Node2D, main.gd) ── 一章的流程、生成物件、機器人
├─ Camera (Camera2D)            震屏用 offset 與微小的 roll（ignore_rotation 關閉）
├─ RoomHolder                   目前的房間（編輯器裡預覽第 1 間）
│   └─ Room (room.gd)
│       ├─ Arena                場地 scene：Background（整張場地圖）/Walls（看不見的碰撞）/Door
│       ├─ Obstacles            木箱、沙包牆、拒馬、石塊（StaticBody2D，只擋底座）
│       ├─ Enemies              敵人 instance，進房前是休眠狀態
│       └─ PlayerStart
├─ Pickups                      經驗寶石、金幣、愛心
├─ Hero (hero.tscn)
├─ Shots / EnemyShots / Effects 甘蔗、敵方子彈與豆子、爆炸與傷害數字
├─ UiLayer (CanvasLayer)
│   ├─ Hud (hud.tscn)           含 Joystick
│   ├─ ChoicePanel              升級／天使（process_mode ALWAYS）
│   └─ ResultPanel
├─ TimeControl                  唯一會改 Engine.time_scale 的地方（hit stop）
├─ Sfx                          事件的音效：assets/sfx/ 的檔案 → 合成佔位音 → 靜音
├─ Music (music.gd)             背景音樂：房間曲／Boss 曲循環，換曲淡入淡出（process_mode ALWAYS）
└─ Juice (juice.gd)             打擊回饋：三級預設、trauma 震屏、擠壓、特效與 HUD 的閃爍、手機震動
```

### 流程狀態（`main.gd`）

```
FIGHT ──全滅──→ REWARD ──撿完、選完──→ DOOR ──走進門──→ TRANSITION ──→ 下一間 FIGHT
  │                  └─ 最後一間 ──→ WON
  └─ 主角 HP 0 ──→ DEAD ──再來一次──→ 重新載入 main.tscn
```

升級與天使的選擇用 `get_tree().paused`；hit stop 用 `Engine.time_scale`。兩者分開，不會互相覆蓋。

### 開始畫面與載入畫面

`main.tscn` 前面多了兩個獨立的畫面，各自是一個 scene、一支腳本，不屬於 `Main`：

```
Title (title.gd)                      專案的主場景
├─ Art · Dim · PlaceholderHero        主視覺、暗色漸層、預設主角（有 assets/title_bg.png 就換掉主視覺並藏起主角）
├─ Safe (MarginContainer, 上下 100 px)
│   └─ Column ── 標題與副標 · 彈性空白 · 開始遊戲 · 製作名單 · CreditLine
└─ CreditsPanel (credits_panel.tscn)  覆蓋層，預設隱藏；Dim 擋住所有點擊

Loading (loading.gd)                  next_scene 預設 res://main.tscn
└─ Safe ── Logo · Percent · Bar · Tip · ErrorLabel / RetryButton（失敗才出現）· CreditLine
```

按「開始遊戲」→ `change_scene_to_file("res://ui/loading.tscn")` → 載入畫面載完 `change_scene_to_packed(main.tscn)`。「再來一次」是 `main.gd` 重新載入 `main.tscn`，不會回到這兩個畫面。三個畫面的 credit 文字都讀 `data/credits.tres`（`data/credits_def.gd` 定義三個欄位）。`title.gd` 在 `_ready` 檢查命令列：`--` 後面有任何參數就自己呼叫 `_start()`，所以 `tools/capture.sh`、錄影與手動測試不用按按鈕。

`tools/apply_screens.gd` 是產生這三個 scene 與 `credits.tres` 的一次性工具（已套用）；腳本與 `ui/dim_gradient.gdshader` 是手寫的。

### 敵人的繼承關係

```
enemy.gd   HP、碰撞傷害、燃燒／冰凍、淡入登場、擊退、卡住繞路、投射物
├─ rat.gd          衝撞
├─ plate.gd        廚師：遠程丟豆（bean_scenes 可在編輯器換）
├─ chiang_boss.gd  彈幕＋紅圈 Boss（紅圈是 effects/aoe_circle.tscn，放在 EnemyShots 底下）
└─ tank.gd         接近 → 預警 → 衝刺碾壓 → 停頓
    └─ boss_tank.gd  覆寫 begin_attack／after_dash，做出連續衝刺與召喚
```

### 腳本分工

| 檔案 | 行數 | 負責 |
|---|---|---|
| `main.gd` | 639 | 房間載入、瞄準（最近而且看得到的敵人）、生成甘蔗／子彈／掉落物／特效、獎勵流程、Boss 血條、`floor_free()`（圓形放得下的地面，召喚物與機器人用；召喚物找離出生點最近、不碰牆、主角與其他敵人的空位）、機器人（會預測子彈位置往最安全的方向閃、閃坦克衝刺線、走出紅圈、被牆逼住時停下來丟、目標被牆擋住時走過去、用 A* 繞過障礙走到門） |
| `domain/hero_stats.gd` | 126 | 純邏輯：能力疊加換算成投擲方式與傷害、經驗曲線、抽卡。不需要場景樹就能測 |
| `player/hero.gd`、`sugarcane.gd` | 175、72 | 移動與停下投擲、投擲動畫（依投擲節奏選 `%Sprite` 的格子）；甘蔗每步用射線檢查牆壁（反彈要用到法線），用 Area2D 打敵人，圖片在飛行中自轉 |
| `enemies/*.gd` | 19–171 | 見上面的繼承關係 |
| `enemies/bean.gd` | 56 | 敵方投射物（豆子會旋轉，子彈朝飛行方向）；`bounces` > 0 時碰到牆壁或障礙物會用射線法線反彈（生氣後的蔣介石設定），`bounce_life` > 0 時第一次反彈後淡出消失 |
| `effects/aoe_circle.gd` | 47 | Boss 的紅圈：預警時內圈從中心長大，長滿引爆（中心在圈內才受傷，播爆炸／煙塵／震屏／音效），然後淡出釋放。計時綁在節點的 tween 上，主角死亡或清房時會跟子彈一起停住、被清掉。`is_aoe()` 讓機器人認得它 |
| `rooms/room.gd`、`arena/door.gd`、`arena/arena.gd` | 34、30、7 | 喚醒敵人、存活清單、中途加入敵人；門的上鎖與開啟；場地的 `walk_area`（可走範圍的外框，敵人起點、召喚、機器人都以它為準） |
| `ui/*.gd` | 13–132 | HUD（版面切換、技能欄）、浮動搖桿、技能欄的一格、選擇面板與卡片、結算 |
| `game/juice.gd` | 405 | 打擊回饋的中樞：三級預設、trauma 震屏、擠壓彈回、手機震動（`haptic()` 的間隔、每秒上限、弱不打斷強）、各事件（命中、死亡、受傷、撿取、升級……）疊哪些回饋與發哪個音效名 |
| `game/settings.gd` | 35 | 玩家的兩個開關（手機震動、畫面晃動）存在 `user://settings.dat`，用 `AtomicFile` 寫入；檔案不存在或壞了就回預設（都開） |
| `game/time_control.gd`、`sfx.gd` | 32、117 | hit stop 節流（可強制、可加長）；事件音效：找 `assets/sfx/` 的檔案、合成音、借用、靜音，加上播放聲道池 |
| `game/music.gd` | 85 | 背景音樂：兩個 `AudioStreamPlayer` 輪流播，換曲淡入淡出（Tween 忽略 `time_scale`），播放前打開循環 |
| `effects/burst.gd`、`level_ring.gd` | 23、13 | 一次性的像素粒子（數量、方向、顏色在生成時決定）；升級光環 |
| `ui/title.gd`、`loading.gd`、`credits_panel.gd` | 87、111、38 | 開始畫面（命令列有參數就自動開始、發現 `assets/title_bg.png` 就換主視覺、浮動與呼吸動畫、開啟製作名單時停用底下的按鈕）；載入畫面（`load_threaded_request`、只往前的進度條、`min_show_time`、失敗與重試）；製作名單面板（Esc／Back／按鈕關閉、`closed` signal） |
| `data/ability_def.gd` ＋ `data/abilities/*.tres` | | 卡片的標題、說明、顏色、可疊加次數 |
| `data/credits_def.gd` ＋ `data/credits.tres` | 9 | 三個畫面共用的製作名單：`music_line`、`sfx_line`（短版）、`full_bbcode`（面板） |
| `tools/build_scenes.gd` | 1110 | 一次性產生所有 scene 的工具（見下） |

### 設計原則

- **畫面都是 scene**：每個畫面、房間、敵人、子彈、UI 元件都是 `.tscn`，編輯器打開就看得到。房間布局是在 scene 裡拖曳敵人和箱子，不寫在程式裡。
- **數值放 export 與 resource**：敵人數值在各自 scene 根節點的 export，能力在 `.tres`，主角的平衡常數集中在 `hero_stats.gd` 開頭。
- **Main 是唯一的中樞**：敵人、甘蔗、子彈要生成東西或回報事件時，都呼叫 `game.spawn_*`／`game.on_*`，不互相找節點。
- **產生器只用一次**：`tools/build_scenes.gd` 用 `PackedScene.pack()` ＋ `ResourceSaver.save()` 產生 scene，並檢查 owner 與 pack 前後節點數；子 scene 一律以 instance 引用。存下來的 `.tscn` 就是原始檔，執行與測試都不會重建。工具預設不覆寫既有檔案，加 `--force` 才會，覆寫前先看 diff。
- **前後遮擋與圖層**：`Main`、`RoomHolder`、每間房的根節點、`Obstacles`、`Enemies`、`Pickups` 都開 `y_sort_enabled`，依節點原點的 y 排序（角色原點在碰撞中心，障礙物原點在底座中心，碰撞只蓋底座，圖的上半部是高度）。`z_index`：場地 -2、紅圈與坦克紅線 -1（在地板上、角色下），角色 0，`Shots`／`EnemyShots` 1，`Effects`（爆炸、傷害數字）2。
- **碰撞層**：1 = world（牆、箱子），2 = player，3 = enemy。甘蔗只偵測 enemy，敵方投射物只偵測 player，兩者都用射線檢查 world；坦克衝刺時暫時拿掉 player 碰撞，才能輾過去。

## 可共用的模組

### 已經在用的 godot-kit 模組

| 模組 | 在這裡的用法 |
|---|---|
| `test_kit.gd` | 4 組測試都繼承它；`_drag`／`_mouse` 用來測浮動搖桿，`_press` 用來點能力卡與「再來一次」 |
| `font_check.gd` | `test_scenes` 檢查「遊戲寫的每個字，裁切過的字型都有字形」 |
| `synth.gd` | `game/sfx.gd` 用它合成 13 種佔位音效；現在只有 `squeak` 還在用，其餘都被 `assets/sfx/` 的同名檔案蓋過去，檔案拿掉就退回它們 |
| `sfx_bank.gd` | `game/sfx.gd` 繼承它：依事件名找檔案、合成音、借用、輪流用 voice、長音效截斷 |
| `haptics.gd`、`camera_shake.gd` | `game/juice.gd` 委派給它們：手機震動的規則與震屏 |
| `time_control.gd` | `main.tscn` 的 `%TimeControl` 直接掛它：hit stop |
| `music.gd` | `game/music.gd` 繼承它，只加房間曲與 Boss 曲兩個 export |
| `floating_stick.gd` | `ui/joystick.tscn` 直接掛它：浮動搖桿 |
| `scene_loader.gd` | `ui/loading.gd` 用它做執行緒載入、進度與失敗重試 |
| `atomic_file.gd` | `game/settings.gd` 用它存 `user://settings.dat`（暫停選單的兩個開關） |
| `scene_builder.gd` | 還沒用到：一次性產生器是它抽出來之前寫的，已套用，不回頭改 |

這些模組都是從這個原型抽出去的；工具（字型子集、網頁匯出、測試執行、錄影）在 kit 的 `tools/`。同步方式：`prototypes/godot-kit/sync.sh /mnt/d/repo/godot/sugarcane-tanks`（專案已搬出 repo）。`addons/proto_kit/` 是副本，不要直接改。

### 這個原型裡還沒抽出來的部分

上面表格裡的模組已經抽進 godot-kit；下面這些仍留在原型裡（godot-kit 原本的收錄規則是「至少兩個原型真的在用」）。等第二個專案需要時，再照 [godot-kit README](../../prototypes/godot-kit/README.md) 的「維護」流程抽出來。

| 模組 | 檔案 | 通用程度 | 抽出前要做的事 | 可能的使用者 |
|---|---|---|---|---|
| N 選 1 暫停面板 | `ui/choice_panel.gd`＋`ability_card.gd` 與兩個 scene | 高。`open(title, subtitle, options)` 之後 `await chosen`；打開後 `pick_delay` 秒內點擊無效，防止連續升級時連點選到沒看過的卡 | 卡片外觀改成用 theme 控制 | 升級、獎勵、事件選擇 |
| 能力疊加與抽卡 | `domain/hero_stats.gd` | 中。「疊層、多顆投射物降傷、未滿層才進卡池、條件卡」的寫法可以沿用，能力內容是這款遊戲專用 | 拆成通用的疊層與抽卡，加上遊戲專用的效果表 | 斑 Survivors 的升級三選一 |
| 敵人基底 | `enemies/enemy.gd` | 中。HP、燃燒／冰凍、淡入登場、擊退、卡住繞路、碰撞傷害都是通用的 | 依賴 `game.show_damage`／`on_enemy_killed` 等介面，要寫成文件或改用 signal | 少量敵人的房間制原型 |
| 載入畫面（畫面本身） | `ui/loading.gd`＋`loading.tscn` | 高。載入邏輯已抽成 kit 的 `scene_loader.gd`；剩下的是畫面：`next_scene` 與 `min_show_time` 是 export，提示、製作名單與文字是這款遊戲的 | 把 credit 與小提示拆成可選的 export | 所有要載入大 scene 的原型 |
| 製作名單 | `ui/credits_panel.gd`＋`data/credits_def.gd` | 高。一份 Resource 餵多個畫面，面板會捲動、擋住底下的輸入、Esc／Back 關閉 | 無 | 所有要放 CC0／OFL 來源名單的原型（itch.io 網頁版尤其需要） |
| 射線步進投射物 | `player/sugarcane.gd`、`enemies/bean.gd` | 高。高速時不會穿牆，反彈用得到法線。核心只有 8 行 `intersect_ray`，其餘是這款遊戲的碰撞規則，所以沒有抽成模組 | 無 | 任何射擊原型 |

### 轉到《宇智波斑 Survivors》時能帶走什麼

- **可以直接帶走**：godot-kit 裡的浮動搖桿、hit stop、音效庫、震動、震屏、音樂、載入邏輯與測試腳本；N 選 1 面板（還在這個原型裡）。能力疊加的規則可以參考，但內容要重寫。
- **不能直接帶走**：一隻敵人一個 `CharacterBody2D` 的寫法。這裡一間房最多 8 隻，所以沒問題；Survivors 要同時有好幾百隻，要改成 [PROJECT.md](../survivors/PROJECT.md)「敵群架構」寫的資料陣列＋空間格＋MultiMesh。

## 怎麼擴充

- **新增敵人**：寫一支 `extends "res://enemies/enemy.gd"` 的腳本，覆寫 `think(delta)`；需要特殊碰撞傷害就再覆寫 `current_contact_damage()`／`is_crushing()`。外型放在 `%Body` 底下，另外要有 `%HpBar`、`%ContactArea`；遠程敵人加 `%Muzzle`。可以複製 `rat.tscn` 改，或在 `build_scenes.gd` 加一個產生函式。
- **新增或調整房間**：在編輯器開 `rooms/room_XX.tscn`，把敵人 scene 拖進 `Enemies`、把箱子拖進 `Obstacles`；在 `main.tscn` 的 `rooms` 陣列加入新房間。Room 的 `boss_room`、`hp_scale`、`area_name` 在 Inspector 設定。
- **新增能力**：在 `data/abilities/` 加一個 `.tres`（`id`、`title`、`description`、`color`、`max_stacks`），把效果寫進 `domain/hero_stats.gd`，再加進 `main.tscn` 的 `abilities`；`tests/test_scenes.gd` 的 `HANDLED_IDS` 也要加上。
- **新增場地**：生成一張 1080×1920 的場地圖放進 `assets/`；複製一個 `arena/arena_*.tscn`，把 `%Background` 的 `texture` 換成新圖，在 2D 編輯器裡重擺 `Walls` 底下的碰撞長方形（照圖上的牆、欄杆、花園、建築，往圖外多伸出去一些），調整 `walk_area`，把 `%Door` 的位置與 `scale` 對準圖上的門，根節點的 `z_index` 維持 -2；再讓房間的 `Arena` 改成用它，`tests/test_scenes.gd` 的 `stage_files` 補上對應。

## 測試與驗證

| 測試 | 內容 |
|---|---|
| `test_rules` | 能力疊加、降傷倍率、經驗曲線、抽卡規則（滿層與急救的條件）；手機震動的規則（間隔、每秒上限、弱不打斷強、大級穿過間隔，手動撥時鐘、不睡）；設定檔的讀寫（壞檔回預設） |
| `test_scenes` | 每個 scene 都有腳本會找的節點；每個角色／投射物／掉落物都有貼圖不是空的 `Sprite`、15 個能力都有圖示；敵人依移動方向翻面；第 1 間只有老鼠；廚師丟三色豆；有 15 間房、各房間屬於哪個場地與地名；Boss 房（第 5、10、15 間）、第 10 間的重型坦克 II 與第 15 間的最終 Boss；第 11–14 間的敵人組成與離起點 700 px 以上；房間不覆寫敵人的經驗值，且把各間房的經驗加起來，清完第 1、3、5、8、10、12、15 間的等級大約落在目標（3、5、8、12、14、16、19–22）上下一級以內，最後一間要在 19–22（重型坦克叫出來的老鼠不給經驗，所以這條曲線固定）；HUD 的數字、技能欄（疊層點數、同一能力一格、最多 5 格、有／無圖示）與一般／Boss 版面切換；開始畫面、載入畫面、製作名單面板的節點齊全，`credits.tres` 與三個畫面上實際顯示的文字都含 `Wolfgang_`、`nene`、`Kenney`、`Noto Sans TC`、`Godot` 與完整的 `Boss Battle #2 ["8 bit"]`，在 540×960、1080×1920、1080×2340 與 1600×900 的視窗裡每個按鈕與文字都在畫面內、按鈕離上下緣至少 90 px，長文字能用滾輪捲動 |
| `test_play` | 用真的 `main.tscn`：打擊回饋（trauma 衰減到 0 且相機回到靜止、`shake_scale = 0` 不震、連打 10 次後擠壓回到原值、擊殺當下關碰撞並躺平釋放、hit stop 之後時間回到 1、放進 `assets/sfx/` 的測試檔會被播放、各事件發出對應的音效名且找得到音效檔、同級震屏疊加有上限）；背景音樂（換曲淡入淡出、暫停與 hit stop 下照常、Boss 房換 Boss 曲、通關與死亡淡出）；搖桿會移動、移動中不丟、移動中是站姿（格 0）；投擲前看得到舉手（格 1 或 2）、甘蔗生成的那一刻是格 3、約 0.3 秒後回到格 0、丟出去的甘蔗會自轉；連續投擲＋攻速滿級時每次出手都從格 3 重新開始、沒有卡住；清房 → 點能力卡 → 開門 → 進下一間；第 10 間的 Boss（重型坦克 II）打倒後出現天使、開門、進第 11 間，不是通關；清房時主角站在門口也會直接過關；Boss 在牆邊叫出的老鼠不會被擠進牆裡；坦克預警後衝刺碾壓；蔣介石開場放 5 個紅圈（半血後 7 個）；紅圈內引爆會受傷、圈外不會，機器人會走出圈外；帶著紅圈打倒蔣介石通關；搖桿一開始不在畫面上、按下才在手指下出現（半透明）、放開就消失；清房後金幣增加、HUD 數字一致；Boss 房切換 HUD 版面；HUD 血量跟著扣血；受傷 → 死亡（結算顯示金幣）→ 重來歸零；手機震動（各事件震預期那一級、一般命中與丟甘蔗不震、爆擊擊殺 Boss 的 large 不被吃掉）與暫停選單的兩個開關（存檔的選擇開局就套用、翻開關即套用即存檔、重來讀回）；開始畫面 → 載入畫面（進度條到 100%、只往前）→ 第 1 間，連按兩次開始只載入一次，有命令列參數時略過標題，`min_show_time` 有效，載入失敗顯示錯誤與重試且重試載得進去，`assets/title_bg.png` 會換掉預設主視覺，製作名單面板開／關（按鈕、Esc、Back）且擋住底下的按鈕 |
| `test_persistence` | 玩過之後所有 `.tscn`／`.tres` 的雜湊值不變；在 scene 裡改過的文字與間距，執行時會保留；玩一局不會寫設定檔 |

示範影片（由 `tools/capture.sh` 產生，放在已被 gitignore 的 `build/`）：`temple-room1-to-2.mp4`、`square-tanks-plates.mp4`、`memorial-final-boss.mp4`。

## 已知缺口與下一步

- **美術**：角色、敵人、投射物、掉落物、頭像與能力圖示已經是像素風生成圖；場地與障礙物也是生成圖，已經接上。主角有 6 格的投擲動畫；其他角色還是程式做的動畫（跳起、翻面、彈跳），沒有逐格動畫。開始畫面的主視覺還沒生成，現在是預設版面；圖放進 `assets/title_bg.png` 就自動換上。
- **概念圖裡還沒做的**：大招按鈕與甘蔗能量、背木桶大老鼠、鼠王、持矛老鼠、WAVE 標示、金幣的商店與局外成長。
- **實機**：還沒上過手機。上方資訊列離頂端只有 12px（照概念圖貼上緣），會被瀏海或動態島蓋住，要依 Safe Area 往下推；手機效能也要實測。
- **題材**：蔣介石、天安門廣場、中正紀念堂都是真實的人物與地點。公開發佈前要評估政治敏感度與肖像使用。
- **參考資料**：[Whitebrim/Archero](https://github.com/Whitebrim/Archero)、[hafizhassanraza/Archero-Clone](https://github.com/hafizhassanraza/Archero-Clone)。兩個都是 Unity 專案、沒有附授權，只參考行為，沒有複製程式碼。
