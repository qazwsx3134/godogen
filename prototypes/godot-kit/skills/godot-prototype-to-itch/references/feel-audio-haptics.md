# 打擊感中樞、聲音、背景音樂、手機震動

通用技巧見 `game-feel` skill；這裡是 sugarcane-tanks 的完整實作與踩過的坑。

**共用模組（2026-10-04 抽進 godot-kit，用法見 godot-kit README）**：`sfx_bank.gd`（音效庫）、`haptics.gd`（震動規則）、`time_control.gd`（hit stop）、`camera_shake.gd`（震屏）、`music.gd`（換軌淡入淡出）、`floating_stick.gd`（浮動搖桿）、`scene_loader.gd`（載入邏輯）。下面寫的 `juice.gd`、`sfx.gd` 等是 sugarcane-tanks 怎麼用它們：三級回饋的對照表與各事件的調校留在遊戲裡，規則在模組裡。

## 回饋中樞 `game/juice.gd`

- 演員只回報「發生了什麼」（`game.juice.enemy_hit(...)`），強度由事件歸在哪一級決定。三級 small／medium／large，各自的 trauma、hit stop、粒子倍率都是 export。
- **震屏**：trauma 累加、每秒衰減，位移＝trauma²，兩條正弦疊出平滑晃動（每幀 `randf` 會嗡嗡響）。只動 `Camera2D.offset` 與很小的 roll。`shake_scale` 為 0＝完全不震（無障礙）。`flash_scale` 控制紅邊與白閃。
- **疊加上限 `stack_limit`**（1.4）：同一級事件疊起來最多是單一事件的 1.4 倍。第 15 間四個紅圈同一格引爆曾把鏡頭震到 25.9 px，加上限後 7.0 px。更大級的事件不受限。
- **hit stop** 全部走一個 `TimeControl`（唯一會改 `Engine.time_scale` 的地方），有節流（0.25 秒內不重複），Boss 死亡更長。
- **擠壓**只改 `%Sprite.scale`，每次從 `rest_scale` 重算並先 kill 前一個 tween（連續被打也不會越擠越歪）；翻面用 `%Body.scale.x`，兩者不衝突。
- 死亡：碰撞立刻關、屍體擠扁再縮小淡出、碎片顏色從那隻敵人的圖取色。
- 回饋不碰模擬：不改位置、碰撞、傷害。

## 聲音介面 `game/sfx.gd`

- 每個事件呼叫 `game.sfx.play(&"事件名")`。找聲音的順序：`assets/sfx/<事件名>.ogg`（沒有就 `.wav`）→ 內建合成音（godot-kit 的 `synth.gd`）→ 借用另一個事件的聲音（`fallback` 表）→ 靜音（不報錯）。**使用者之後丟檔案進資料夾就換聲音，不改程式。**
- 載檔用 `ResourceLoader.exists` 再 `load`（匯出版原檔不在 pck 裡）。
- **長音效**（`LONG_SOUNDS`）：Kenney 的引擎檔 `rev`、`dash` 各 5 秒，但坦克預警不到 1 秒、一間房有好幾台、Boss 還會三連衝，全疊在一起很吵。解法：切到 0.7／0.8 秒（尾端淡出 0.12 秒）、各自調音量、**同一個事件還在響時不再疊一個**；三連衝只有第一段預警播 `rev`。
- 聲音來源：Kenney（kenney.nl，CC0）的 Impact／Sci-Fi／Digital Audio／RPG Audio／Interface Sounds；沒有的（老鼠叫）保留合成音。README 的素材表要列出每個事件對應的原檔名。
- 沒聽過的混音要誠實寫在報告裡（音量 -12 dB 音樂、-6 dB 音效，戰鬥峰值接近 -1 dBFS 沒有限幅器）。

## 背景音樂 `game/music.gd`

兩個 `AudioStreamPlayer` 輪流播；換曲淡出淡入 0.8 秒；通關與死亡淡出；同一首不重來；`process_mode` Always、tween 忽略 time_scale（暫停與 hit stop 下照常）；循環在播放前用程式打開（Ogg 的 `loop`、WAV 的 `loop_mode`），所以匯入時沒設循環也會循環。Boss 房換 Boss 曲。**循環點可能有一聲輕微的喀**（沒用耳朵驗證）。

## 手機震動（haptics）

- 規則集中在 `juice.gd` 的 `haptic(tier)`：玩家開關與 `haptic_scale` 為 0 → 不做；兩下之間至少 70 ms、每秒最多 6 次；較弱的脈衝不打斷還沒結束的較強的；**更大級的脈衝穿過間隔與上限**（被爆擊打死的 Boss 同一格先 small 再 large，不然 Boss 死亡永遠少一個大震）。
- 三級：14 ms／0.35、38 ms／0.65、90 ms／1.0（Android 原生才有強度；網頁版只有長度）。<10 ms 很多手機感覺不到，>150 ms 變成嗡嗡聲。
- **只在螢幕會晃的重要時刻震**：爆擊、敵人死亡（small）、受傷／被碾（medium／large）、倒下（large＋餘震）、Boss 登場／生氣／死亡（large＋餘震）、升級（small 兩下）、開門、坦克撞牆。一般命中、丟甘蔗、腳步、撿東西不震。整章平均約 450 次脈衝、戰鬥中每秒 1.6 次。
- 偵測與限制見 `web-release.md` 第 5 節。設定（`haptics`、`screen_shake`）存 `user://settings.dat`，用 `AtomicFile`；暫停選單有兩個開關，桌面與 iPhone 隱藏震動開關。
- **沒有真機驗證過**；手感（14／38／90 ms）是照文件定的，沒調過。

## 升級節奏與選卡

- 連續升級會連續彈面板，下一張出現在手指剛點過的位置：選卡鎖 `pick_delay`（0.35 秒，卡片從暗到亮），用遊戲時間 timer。
- 經驗曲線 `exp_to_next(L) = 4 + 2L`，老鼠 3、廚師 4、坦克 5、Boss 40；第 1 間就升兩級，通關約 Lv19，能力池（不含回血的 33 層）不會抽乾。
- 敵人強度與經驗是「一起調」的：升級快了 4–5 級之後，中後段房間靠基礎數值壓不起來，要用每間房的 `hp_scale`（第 10–14 間 1.7／1.9／2.1／2.6／3.0、Boss 15 間 2.0）。

## 升級光效（獎勵爆發）的做法

使用者說「太醜太廉價」的是舊版：Line2D 畫的平面光環加放射線。換成 `effects/level_up_fx.tscn`（sugarcane-tanks）之後的原則：

- **掛在主角底下、跟著主角**：節點原點放腳底，夾在 `Shadow` 與 `Body` 之間，所以地上的光環與光柱畫在主角後面；星光與字放在 `z_index` 高於特效層的 `Air` 底下。放進 `Effects` 容器的話會整個蓋在主角身上。
- **淺色地板用一般混合加深色外緣**：金色加亮（additive）在淺灰石板上會洗成白色。只有光柱最內層的白核心與閃光用加亮。
- **像素風光環不用 PNG**：`GradientTexture2D` 放射狀、`Gradient.interpolation_mode = CONSTANT`（每圈一個平色）、貼圖寬高不同就得到橢圓（`96×48`）、`texture_filter = NEAREST`。光柱是往上變窄的 `Polygon2D` 梯形加縱向漸層貼圖（UV 用貼圖像素）。只有星星（13×13，帶深色外框才看得到）是一張小 PNG。
- **節奏**：光環用 `TRANS_EXPO` ease-out 展開、第二圈晚一拍；光柱衝上去再變細淡出；閃光一開始最亮、四分之一秒內消失；字用 `TRANS_BACK` 彈出（把字包在 `Node2D` 裡縮放，樞紐才在字的中央，不用調 `pivot_offset`）。
- **閃光要吃無障礙設定**：`play(level, flash)`，`juice.flash_scale` 傳進去，0 就沒有閃光。
- **面板會暫停遊戲**：升級面板在撿完最後一顆經驗球的下一格就開，特效 `process_mode = ALWAYS` 才不會凍在面板後面。
- **預覽用 SubViewport 排版圖，不用錄影**：非 headless 跑一支 SceneTree 腳本，把真的主角 scene 放在真的地板圖上，固定 fps 下每格 = 1/60 秒，挑幾格 `get_image()` 拼成一張圖；再縮到 0.4 倍看手機上的大小——2–3 px 的細線在那個大小會消失，粗的色塊才看得到。
- **加粒子節點會平移全域亂數**（`CPUParticles2D` 一建立就消耗）：見 `testing-and-balance.md`。
