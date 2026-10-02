# 安

《弓箭傳說》（Archero）式的直式房間射擊原型：主角丟甘蔗，對手是老鼠、會碾人的坦克、丟三色豆的廚師，最後是蔣介石。
一路從宮廟打到天安門廣場，再到中正紀念堂。資料夾名稱 `sugarcane-tanks` 是暫名時取的。

《宇智波斑 Survivors》（[PROJECT.md](../../docs/survivors/PROJECT.md)）在拿到版權之前，先用這個與 IP 無關的替身驗證 Survivors 類的核心手感。

給其他人看的功能、架構與可共用模組整理：[docs/Ann-the-last-sugercane-Forsaken](../../docs/Ann-the-last-sugercane-Forsaken/README.md)（含概念圖與差距）。

**狀態**：進行中（第一章 10 間可以從頭玩到尾，還沒有真人試玩）

## 要驗證的假設

- 「移動就不能攻擊、停下就自動攻擊」這條規則，在手機直式上能不能兼顧走位和輸出的爽感。
- 每次升級三選一、能力可以疊加（正面＋1、連續投擲、斜向、彈射……），短短一章內能不能長出「這局的 build」。
- 三種敵人各有辨識度（老鼠衝撞、坦克預警後衝刺碾壓、廚師遠程丟豆），加上兩場打法不同的 Boss（衝刺碾壓、彈幕加紅圈範圍攻擊），能不能撐起 10 間房的節奏。
- 打擊回饋有沒有重量：閃白、傷害數字、爆炸、震屏、hit stop、分層音效。

**不驗證**敵海密度，以及 PROJECT.md 的大量敵群架構。弓箭傳說一間房只有 5–8 隻敵人，用 `CharacterBody2D` 就夠了。

## 執行

Godot 4.7（`/Applications/Godot.app`）。用編輯器開這個資料夾按 F5，或用指令執行：

```bash
G=/Applications/Godot.app/Contents/MacOS/Godot
$G --path .                                    # 正常玩
$G --path . -- --room=10                       # 直接從第 10 間（最終 Boss）開始
$G --path . -- --give=front,multishot,fire     # 開局就帶這些能力，方便試 build
$G --path . -- --autoplay                      # 機器人自己玩、自己選卡（展示與測試用）
```

`--give` 的能力 id：`front multishot diagonal side rear pierce ricochet wall_bounce attack_boost attack_speed crit fire freeze hp_boost heal`。

**操作**：在畫面任一處按住拖曳是浮動搖桿（平時看不到，按下才在手指下半透明地出現，放開就消失），放開後自動朝最近而且看得到的敵人丟甘蔗。電腦上也可以用 WASD 或方向鍵。

## 一章的流程

```
第 1–3 間 宮廟 ─→ 第 4–7 間 天安門廣場 ─→ 第 8–9 間 中正紀念堂 ─→ 第 10 間 紀念堂內
 （老鼠為主）      （坦克、廚師登場；        （全部混合）           （Boss 蔣介石）
                     第 5 間 Boss 重型坦克）

進房 → 敵人淡入（0.6 秒後才開始行動）；進入新區域時跳出地名
 → 移動閃避／停下丟甘蔗
 → 全滅：清掉子彈與豆子，經驗寶石、金幣與愛心飛向主角
 → 每升一級暫停一次：3 選 1 能力
 → 第 5、10 間是 Boss；第 5 間打完後出現天使（回血 40% 或拿一個能力）
 → 上方的門打開，走進去 → 下一間
第 10 間 Boss 倒下 → 「第一章 完成！」；主角倒下 → 結算，按「再來一次」重來
```

## 與弓箭傳說的對照

| 有做 | 沒做 |
|---|---|
| 移動時不攻擊、停下自動瞄準最近的敵人（優先挑沒被障礙物擋住的） | 裝備、天賦、體力、商店與局外成長（金幣只在一局內累積） |
| 升級 3 選 1，15 種能力可疊加，多顆甘蔗會降低單顆傷害 | 多個角色、第二章以後 |
| 房間制，清完才開門；Boss 血條；天使 | 惡魔（用生命上限換能力）、幸運轉盤、復活 |
| 子彈與豆子會被牆壁和箱子擋住；坦克衝刺前有紅線預警 | 飛行敵人（可以穿越障礙物） |
| 主角頭上有血條與數字，敵人掉經驗寶石與金幣（每點 EXP 一金，Boss 加倍），坦克被擊破掉愛心 | 存檔續玩 |

能力的效果寫在 `domain/hero_stats.gd`，卡片上的文字與可疊加的次數在 `data/abilities/*.tres`。

## 敵人

| 敵人 | 出現 | 行為 |
|---|---|---|
| 老鼠 | 第 1 間起（最早的敵人） | 快速左右搖擺衝向主角，撞到就扣血；血少，被打會被推開 |
| 坦克 | 第 2 間起 | 慢慢開向主角 → 停下亮紅線預警 → 高速衝刺，**直接碾過主角**（主角被壓扁一下，傷害比碰撞高很多）→ 衝完停頓一下，是反擊的空檔 |
| 廚師（檔名還是 `plate`） | 第 3 間起 | 保持距離、左右橫移、永遠面向主角；每隔一段時間壓低身體、跳起來，從平底鍋丟出扇形的三色豆（豌豆、玉米、紅蘿蔔） |
| 重型坦克（第 5 間 Boss） | | 輪流：長距離衝刺、連續三段衝刺（每段重新瞄準）、叫出老鼠。半血後預警變短、老鼠變多 |
| 蔣介石（第 10 間最終 Boss） | | 在上半場移動，手槍跟著主角轉；開火前身體閃一下，輪流放**紅圈**、瞄準三連發、兩波錯開的扇形、旋轉螺旋、整圈環形子彈。紅圈是第一招：一次放 4 個半透明紅圈，1 個在主角腳下、3 個隨機落在地板上；內圈從中心長滿（1.5 秒）就引爆，圈內的人受傷，Boss 放完就繼續移動。血量低於一半就**生氣**：橫幅「蔣介石 生氣了！」、身體閃一下再持續泛紅脈動、頭上冒蒸氣與怒氣符號；之後他發射的子彈變快、**碰到牆壁或障礙物會反彈**（預設 2 次，反彈後的子彈 1.5 秒內淡出消失，染成紅橘色好分辨；豆子不會反彈），休息時間縮短，紅圈變 6 個、長滿只要 1 秒 |

敵人卡在箱子前面時會自動往側邊繞。

## 主要 scene 與可以在編輯器調的地方

所有畫面與物件都是 `.tscn`，用 Godot 編輯器打開就看得到版面。

| Scene | 內容 | 常調整的地方 |
|---|---|---|
| `main.tscn` | 相機、房間容器（預覽第 1 間）、主角、投射物與特效容器、UI | Main 的 export：`rooms`（房間順序）、`abilities`（出現在卡池的能力）、`angel_heal_ratio`、`heart_heal_ratio`、`sugarcane_speed`，以及打擊特效 scene（`spark_scene` `dust_scene` `debris_scene` `gold_burst_scene` `ring_scene`）。`%Juice` 節點掛 `game/juice.gd`（回饋的分級與震屏，見「打擊回饋」）；`%Music` 節點掛 `game/music.gd`（背景音樂：`room_track`、`boss_track`、`volume_db`、`fade_time`，見「背景音樂」）；`Camera` 的 `ignore_rotation` 要保持關閉，震屏的輕微翻滾才看得到 |
| `rooms/room_01…10.tscn` | 一間房：Arena（場地圖、牆、門）、Obstacles（木箱、沙包牆、拒馬、石塊，每間 2–4 個）、Enemies、PlayerStart | **直接拖曳敵人和障礙物調整布局**（敵人與 PlayerStart 要在場地的 `walk_area` 裡、不能壓到牆，`test_scenes` 會檢查；留一條路給門）；在 Enemies 底下加或刪敵人 instance；Room 的 `boss_room`、`hp_scale`（整間敵人的血量倍率）、`area_name`（進入時跳出的地名） |
| `arena/arena_temple.tscn`、`arena_square.tscn`、`arena_memorial.tscn`、`arena_hall.tscn` | 宮廟（第 1–3 間）、天安門廣場（4–7）、中正紀念堂（8–9）、紀念堂內的 Boss 場地（10）。每個場地是一張 1080×1920 的場地圖 `Background`（`assets/bg_*.png`，剛好等於整個世界）、看不見的牆 `Walls`、出口 `%Door`。根節點 `z_index = -2`，紅圈、坦克紅線、角色都畫在它上面 | `walk_area`（可走範圍的外框；敵人、主角起點、召喚物與機器人都以它為準）；`Walls` 底下每個 `CollisionShape2D` 是一塊擋住的長方形，沿著圖上的欄杆、花園、樹、建築、火盆擺（在 2D 編輯器邊拖邊對照背景圖，往圖外多伸出去一些，才不會有縫）；`Door` 的 `position` 與 `scale` 對準圖上的門（門檻中點） |
| `arena/door.tscn` | 出口。關著：暗紅柵欄 `Bars` 加一把鎖，疊在圖上的門前面；全滅且撿完獎勵後 `door.gd` 隱藏柵欄、亮起金色光柱 `Glow` 並閃動。主角碰到門檻才進下一間 | `Glow` 的顏色與高度、`Bars` 的粗細（門的大小由場地裡的 `Door` instance 的 `scale` 決定） |
| `arena/crate.tscn`、`barrier.tscn`（沙包牆）、`hedgehog.tscn`（拒馬）、`stone_block.tscn`（石塊） | 障礙物，一張圖 `Sprite`（`crate.png`、`sandbags.png`、`hedgehog.png`、`stone_block.png`）加腳下陰影。**節點原點在底座中心**，碰撞只蓋底座（圖的下面約 30 px），圖的上半部是「高度」，主角與敵人可以走到它後面被擋住 | 底座碰撞的大小；`Sprite` 的位置（圖的下緣略低於原點） |
| `enemies/rat.tscn`、`tank.tscn`、`plate.tscn` | 老鼠、坦克、廚師。外型是 `%Body` 底下的一張圖 `Sprite`（`rat.png`、`tank.png`、`chef.png`），腳下有橢圓陰影 `Shadow`，血條在頭頂上方 | 共用 export：`max_hp`、`move_speed`、`contact_damage`、`exp_value`、`knockback`、`heart_drop_chance`、`portrait`（Boss 血條的頭像）、`corpse_time`（死後躺多久：閃白、擠扁、縮小淡出，預設 0.45 秒，Boss 兩倍；碰撞在死亡當下就關掉）；坦克的 `crush_damage`、`dash_speed`、`dash_distance`、`dash_range`、`windup_time`、`recover_time`；廚師的 `bean_scenes`、`throw_interval`、`fan_degrees`、`bean_speed`、`bean_damage`、`near_distance`／`far_distance`、`hop_height`（丟豆時跳多高），`%Muzzle` 在平底鍋的位置；老鼠的 `wobble`、`hop_speed`、`hop_height`。**面向**：圖都朝右，`%Body.scale.x` 依水平移動方向翻成 ±1（方向要夠橫，`enemy.gd` 的 `FACE_SIDE_RATIO` = 0.4，接近垂直時維持原側，不會一直翻）。調圖的位置與大小：選 `Sprite` 改 `position`（腳底的位置）、`scale`、`offset`（對齊規則見下方「素材與來源」）；碰撞圈不要為了圖而改 |
| `enemies/boss_tank.tscn`、`chiang_boss.tscn` | 兩隻 Boss | 重型坦克另有 `summon_count`、`long_dash_distance`、`quick_windup`；蔣介石有 `bullet_speed`、`bullet_damage`、`rest_time`、`telegraph_time`、`roam_area`，紅圈的 `aoe_scene`、`aoe_count`（4）、`aoe_count_enraged`（6）、`aoe_telegraph_time`（1.5）、`aoe_telegraph_time_enraged`（1.0）、`aoe_area`（隨機紅圈的圓心範圍）、`aoe_spacing`（圈與圈的圓心距離，以半徑為單位，預設 1.5），手槍（`pistol.png`）在 GunArm 底下，轉軸在握把、握在蔣介石的右手位置；它跟著主角轉，瞄向左邊時 `GunArm.scale.y` 變 -1，槍才不會倒立；`portrait` 是 Boss 血條的頭像。生氣用的 export 在「Rage (below half HP)」群組：`rage_bounces`（2，子彈反彈幾次；0 = 不反彈）、`rage_bounce_life`（1.5，第一次反彈後幾秒淡出；0 = 一直飛到撞上東西）、`rage_rest_speed`（1.6，休息計時加快的倍數；沒生氣時是 1）、`rage_bullet_tint`（反彈子彈的顏色）、`rage_tint_high`／`rage_tint_low`（身體脈動的兩個顏色）。生氣的外觀節點：`RageSteam`（頭上的蒸氣粒子）與 `RageMark`（怒氣符號，四個紅色角括號），兩個平常都是關著的，生氣的瞬間才打開；要在編輯器調位置或大小，先把 `RageMark` 的 visible 打開 |
| `effects/aoe_circle.tscn` | Boss 的紅圈：半透明圓盤 `Fill`、亮紅外框 `Ring`（外圍 `Glow` 光暈）、預警時從中心長大的內圈 `Grow`、中心的放射狀爆光 `Burst`；引爆時另外生成紅色爆炸、碎石煙塵、震屏、爆炸聲 | 顏色與粗細直接改 `Visual` 底下的各節點；export：`radius`（130，執行時外觀依它縮放）、`telegraph_time`（1.5，蔣介石依血量覆寫）、`damage`（120）。外觀畫在 130 的半徑上，改 `radius` 後要執行才看得到縮放 |
| `effects/spark.tscn`、`dust.tscn`、`debris.tscn`、`gold_burst.tscn` | 一次性的像素方塊粒子（`CPUParticles2D`，腳本 `effects/burst.gd`）：火花（命中點、丟甘蔗的手上、撿東西）、灰塵（走路、坦克衝刺、撞牆）、碎片（死亡；每顆的顏色取自那隻敵人的圖）、金光（開門）。播完自己釋放 | 外觀都在 scene 裡，直接改粒子的 `amount`、`lifetime`、`initial_velocity`、`gravity`、`scale_amount`、`color_ramp`。生成時的數量乘上分級的粒子倍率（見「打擊回饋」） |
| `effects/level_ring.tscn` | 升級時從主角身上擴散的光環與放射線（`Ring`、`Rays`），`level_ring.gd` 把它放大並淡出 | `Ring`／`Rays` 的粗細與顏色；`duration`、`final_scale` |
| `enemies/pea.tscn`、`corn.tscn`、`carrot.tscn`、`bullet.tscn` | 三色豆與子彈，各一張圖 `Sprite`（同名 png） | `spin`（豆子轉速；子彈為 0，朝飛行方向）；子彈的 `Sprite.offset` 讓彈殼（不是火焰）對在碰撞中心 |
| `player/hero.tscn` | 主角：`%Body` 底下的 `%Sprite` 是 6 格的投擲條（`hero_throw.png`，`hframes = 6`，直接設 `frame`）、`%Hand` 在出手那一格手的位置（甘蔗從這裡生成，跟著翻面）、頭上血條與數字 | `move_speed`、`stop_to_throw_delay`（停下到第一次丟的延遲）、`volley_gap`、`hurt_invulnerability`；投擲動畫的 `windup_time`（蓄力最長多久，預設 0.15 秒）、`follow_through_time`（收手多久，預設 0.25 秒）、`frame_drop`（每一格要把圖往下推幾 px，讓腳都踩在陰影上，預設 `0, 0, 0, 9, 9, 5`）。投擲動畫只跟著投擲節奏走，不會改變它：**移動時**格 0（保留身體晃動）；**站著、下一次投擲前**最後 0.15 秒（第一次丟只有 0.12 秒就用 0.12 秒）依剩餘時間走格 1→2（有目標才會舉手）；**甘蔗生成的那一刻**切到格 3，接著 4→5→0，共約 0.25 秒；攻速很快或連續投擲時，每一次出手都從格 3 重新開始。`%Sprite.scale` 沒有被動畫佔用（被碾壓時才會壓扁）。這 6 格的腳底在格子裡的高度不一樣（第 3、4、5 格比格子底邊高 9、9、5 px），所以 `frame_drop` 用「140 減去該格最低的不透明列」算出來；重新輸出 `hero_throw.png` 之後要重量 |
| `player/sugarcane.tscn` | 投出去的甘蔗：`%Visual` 底下一張圖 `Sprite`（`sugarcane_purple.png`，葉子在左）。整支 scene 朝飛行方向，`%Visual` 在飛行中自轉，像丟出去的棍子 | `spin_turns_per_second`（每秒轉幾圈，預設 2.5）；碰撞圈不變 |
| `ui/hud.tscn` | 照概念圖的 HUD。**一般房間**：左上玩家區塊 `PlayerPanel`（圓形頭像 `HeroPortrait`、`LevelLabel`、綠色 `HpBar`＋`HpLabel`、細藍 `ExpBar`）；右上 `STAGE` 框（`RoomLabel` 只放數字）、`PauseButton`，下面是金幣框（`CoinIcon`＋`CoinLabel`）；下方中間是技能欄 `AbilityChips`（每格一個 `ability_slot.tscn`）；搖桿（`Joystick`）只在手指按住時出現。**Boss 房**（`show_boss()`）：玩家區塊與技能欄隱藏，改顯示 `BossPanel`（`BossPortrait`、`BossName`、長紅條 `BossBar`），主角血量移到下方中間的 `BottomHeroPanel`（`BottomPortrait`＋5 段 `BottomHpBar`）。另有 `Banner`（地名、BOSS 來了）、`PauseOverlay`、`Fade`。**打擊回饋用的節點**：`HpGhost`／`BottomHpGhost`（HP 條後面的白色殘影條，扣血時先留在原處、約 0.35 秒後滑下去追上）、`Vignette`（受傷時閃紅的畫面四周）、`WhiteFlash`（Boss 死亡的全畫面白閃）；金幣數字、經驗條、LV 增加時會彈跳一下；Boss 條第一次出現時從 0 填滿 | `TopBar` 的邊距（`margin_top` 是 12，貼上緣）、各 Label 字級與顏色、各條的 StyleBox；`BossPanel`、`BottomHeroPanel` 在 scene 裡預設隱藏（在編輯器點眼睛圖示才看得到）；`AbilityChips` 底下的 3 格只是編輯器預覽，執行時會清掉。**圖片**：把頭像、Boss 頭像、金幣圖放進 `HeroPortrait`／`BossPortrait`／`BottomPortrait`／`CoinIcon` 的 `texture`；圖自帶框，子節點 `Frame`（金色圓框佔位）畫在圖後面，所以在編輯器裡貼上圖就直接看到圖；執行時有圖的話 `Frame` 會再自動隱藏，避免圖的透明角露出佔位框。API：`set_room`、`set_level`、`set_hp(hp, max_hp)`、`set_coins`、`set_ability(def, stacks)`、`show_boss(title, hp, max_hp, portrait = null)`、`hide_boss`、`banner` |
| `ui/ability_slot.tscn` | 技能欄的一格：`Icon`（TextureRect）、沒有圖示時的佔位 `Frame`（綠框深底）＋`Swatch`（能力顏色的方塊）＋`Initial`（標題第一個字），下方 `Pips` 用 ◆◇ 顯示疊了幾層 | `IconBox` 的大小、`Frame` 的框色；圖示放在 `data/abilities/*.tres` 的 `icon`（有圖就隱藏佔位）；點數的格數 = min(`max_stacks`, 3)。同一個能力再拿只更新同一格，最多顯示最近拿的 5 格 |
| `ui/choice_panel.tscn`＋`ui/ability_card.tscn` | 升級與天使面板、能力卡。卡片由左到右：能力圖示 `%Icon`（96 px，來自 `data/abilities/*.tres` 的 `icon`；沒有圖示的選項，例如天使的「回復生命」，改顯示 `%Swatch` 色塊）、標題與說明、疊加層數。卡片高 250 px，標題一行加最多三行說明（`Description` 的 `max_lines_visible = 3`，再長會被截掉，不會跑出框外） | 卡片高度、字級、圖示大小；面板裡的 3 張卡只是編輯器預覽，執行時會換成實際選項。說明文字裡的換行請用一般換行；`.tres` 在 Windows 換行（CRLF）下存檔時多行字串會帶 `\r`，`ability_card.gd` 會把它濾掉，否則每個換行會多出一個空行，把第二行擠到卡片邊框上 |
| `ui/joystick.tscn` | 浮動搖桿：深色底座、亮外圈、四個小箭頭、淺灰把手，整個 `Base` 半透明（`modulate` 的 alpha 0.5）。一開始不在畫面上：按畫面任一處才在手指下出現，放開就消失。編輯器裡底座照常看得到（方便調外觀），執行時 `_ready` 才把它藏起來；`Hint` 提示字節點保留但隱藏 | `radius`（手指移動多遠算推滿）、`knob_travel`（把手在底座內最遠走多少）、`dead_zone`；`Base` 的 `modulate`（整體透明度）；Base／Knob／箭頭的外觀 |
| `ui/result_panel.tscn` | 結算：標題、摘要、這一局拿到的金幣 `CoinsLabel`、「再來一次」 | 字級、顏色 |
| `pickups/exp_gem.tscn`、`heart.tscn`、`coin.tscn` | 經驗寶石、愛心、金幣，`%Visual` 底下各一張圖 `Sprite`（同名 png），飛向主角的方式相同 | `Sprite` 的位置與大小。金幣的掉落數量在 `main.gd` 的 `on_enemy_killed`：每點 `exp_value` 一金，Boss 加倍 |
| `ui/theme.tres` | 全專案字型（Noto Sans TC）、按鈕與面板樣式：深藍底 #1B2130（不透明度 0.9）＋金色邊框 #E8B84A 3px＋圓角 | 顏色、邊框粗細、圓角（升級卡、結算、暫停畫面都吃這一套） |

平衡數值（傷害、攻速、疊加懲罰、升級所需經驗）集中在 `domain/hero_stats.gd` 開頭的常數。

**前後遮擋與圖層**（3/4 視角）：`Main`、`RoomHolder`、每間房的根節點、`Obstacles`、`Enemies`、`Pickups` 都開了 `y_sort_enabled`，主角、敵人、障礙物、掉落物依節點原點的 y 座標排序。角色的原點在碰撞中心（腳在原點下方 20–30 px），障礙物的原點在底座中心，所以主角走到箱子後面時，下半身被箱子擋住，走到前面就蓋過箱子。`z_index`：場地 -2、紅圈（絕對值）-1、坦克衝刺紅線 -1，都在地板之上、角色之下；一般角色 0；`Shots`、`EnemyShots` 是 1（子彈在角色上方）；`Effects`（爆炸、傷害數字）是 2，永遠在最上面。新增會站在地上的東西，把原點放在它的腳下附近，不要改碰撞。

## 打擊回饋（game feel）

回饋全部集中在 `game/juice.gd`（`main.tscn` 的 `%Juice`）。演員只回報「發生了什麼」（`game.juice.enemy_hit(...)`），這件事有多大聲由它歸在哪一級決定，一次調整整款遊戲的比例。原則：**回饋不碰模擬**——震屏只動 `Camera2D` 的 offset 與微小的 roll，擠壓只動 `%Sprite.scale` 並一定回到原本的縮放（連續觸發也從原值重算），hit stop 只透過 `TimeControl`（唯一改 `Engine.time_scale` 的地方）。

### 三級預設（在 `%Juice` 的 Inspector 調）

| 級 | trauma（震屏量） | hit stop | 粒子數量倍率 |
|---|---|---|---|
| small | 0.25 | 無 | ×0.6 |
| medium | 0.45 | 0.045 秒 | ×1.0 |
| large | 0.85 | 0.14 秒 | ×2.2 |

震屏用 trauma 模型：事件**累加** trauma（上限 1），每秒衰減 `decay`（1.5），實際位移是 trauma 的平方，所以小事件幾乎不動、大事件才明顯，而且一定自己停下來。同一級的事件互相疊加有上限：最多疊到單一事件的 `stack_limit` 倍（1.4），所以四個紅圈同一格引爆、連續爆擊只會低低地震（small 疊到 0.35、medium 疊到 0.63），不會變成 large 的大震；更大的事件疊上去仍然加上自己那一份（最多到 1）。位移用兩條不同頻率的 sin（`frequency` 約 8 Hz）疊出平滑的晃動，不是每幀亂數。位移最大 `max_offset`（40×30 px），翻滾最大 `max_roll`（0.02 弧度）。hit stop 沿用 `TimeControl` 的節流（0.25 秒內不重複），Boss 死亡可以強制並加長。

無障礙：`shake_scale`（0–1，鏡頭實際移動量的倍率，0＝完全不震屏）、`flash_scale`（0–1，0＝不閃紅邊與白閃）。沒有做設定畫面，在 Inspector 或腳本裡改。

### 各事件用哪一級

| 事件 | 音效名 | 級 | 畫面回饋 |
|---|---|---|---|
| 主角丟甘蔗 | `throw` | small，**不震屏** | 主角 `%Sprite` 小擠壓伸展、手上冒火花 |
| 主角走路 | `step` | — | 每走 95 px（`hero.gd` 的 `step_spacing`）腳下冒一點灰塵 |
| 主角停下 | — | — | `%Sprite` 輕微擠壓 |
| 甘蔗命中敵人 | `hit` | — | 敵人 `%Sprite` 擠壓後彈回（`TRANS_BACK`）、命中點的像素火花 |
| 爆擊 | `crit` | small | 火花加倍變金色、傷害數字 overshoot 彈出（普通傷害數字也會彈出） |
| 一般敵人死亡 | `enemy_die` | medium | hit stop、閃白後擠扁、縮小淡出；依那隻敵人的圖取色的碎片；掉落物 overshoot 彈出 |
| Boss 死亡 | `boss_die` | large | hit stop 加長（×1.6）並強制、全畫面白閃、碎片加倍、之後三次逐次變弱的餘震 |
| 主角受傷 | `hurt` | medium | 畫面四周閃紅、HP 殘影條、無敵時間（0.5 秒）主角閃爍 |
| 坦克碾壓主角 | `crush` | large | 同上，但紅邊更強 |
| 主角死亡 | `hero_die` | large | 爆炸 |
| 坦克預警 | `rev` | — | 坦克的圖原地抖動，越接近衝刺越大（只動圖片，身體不動） |
| 坦克衝刺 | `dash` | — | 身後揚灰塵 |
| 衝刺撞牆停下 | `bump` | small | 灰塵 |
| 紅圈引爆 | `aoe_blast` | 打到主角：由 `hurt` 的 medium 負責；沒打到：small | 爆炸、煙塵 |
| 召喚小怪、Boss 的環形子彈 | `squeak`、`gun` | small | — |
| 掉落物出現 | `drop` | — | 圖片從 0 彈出（overshoot） |
| 撿經驗寶石 | `pickup` | — | 小閃光、經驗條跳一下 |
| 撿金幣 | `coin` | — | 小閃光、金幣數字與圖示跳一下 |
| 撿愛心 | `heal` | — | 紅色小閃光 |
| 升級（等級增加的那一刻） | `level_up` | — | 主角身上一圈放射光環、LV 跳一下 |
| 升級面板打開 | `level` | — | — |
| 開門 | `door` | small | 門口金光爆 |
| Boss 登場 | `boss_intro` | medium | Boss 條從 0 填滿 |
| 甘蔗彈向下一隻敵人、在牆上彈開 | `ricochet` | — | —（只有聲音） |
| Boss 血量第一次低於一半（`enraged()` 變成 true） | `rage` | — | —（只有聲音） |
| 廚師丟豆 | `toss` | — | 廚師壓低、跳起（`plate.gd`） |

### 音效接口

**每個事件都會呼叫 `game.sfx.play(&"事件名")`**（上表的「音效名」欄；沒有音效名的列不發聲）。找聲音的順序（`game/sfx.gd`）：

1. `res://assets/sfx/<事件名>.ogg`，沒有就 `<事件名>.wav`——**檔名就是事件名，換檔案不用改程式**。剛放進去、編輯器還沒匯入的檔案也讀得到（直接從硬碟讀）。檔案是啟動時才找，新放的檔案要重新執行遊戲；測試或除錯時 `sfx.refresh()` 可以讓它重找。
2. 內建的合成佔位音（godot-kit 的 `synth.gd`）：`throw` `hit` `crit` `gun` `toss` `rev` `dash` `squeak` `boom` `hurt` `pickup` `level` `door`。除了 `squeak`，每一個都有同名的檔案蓋過去；檔案拿掉就退回合成音。
3. 借用別的事件的聲音（`sfx.gd` 的 `fallback`）：`enemy_die`、`boss_die`、`hero_die`、`aoe_blast` 借 `boom`，`crush` 借 `hurt`，`coin` 借 `pickup`。
4. 都沒有：靜音，不報錯。

目前每個音效名的聲音（`test_play` 逐項檢查：每個事件都找得到檔案，或在刻意保留的清單裡；資料夾裡的每個檔案都有事件在播）：

| 音效名 | 聲音 | 備註 |
|---|---|---|
| `throw` `hit` `crit` `crush` `hurt` `hero_die` `boss_die` `aoe_blast` `gun` `toss` `rev` `dash` `step` `pickup` `coin` `level` `door` `ricochet` `rage` | `assets/sfx/<音效名>.ogg`（Kenney） | 檔名＝音效名 |
| `enemy_die` | `assets/sfx/enemy_die.ogg`（使用者自選） | `art_src/enemy_die_kenney.ogg` 是另一個版本，不會被匯入 |
| `squeak` | 合成音 | 刻意保留：Kenney 的音效裡沒有老鼠叫 |
| `bump` `drop` `heal` `level_up` `boss_intro` | 靜音 | 刻意沒有聲音；放進同名的檔案就會響 |
| `boom` | `assets/sfx/boom.ogg`（Kenney） | 沒有事件直接播它：借用它的四個事件都有自己的檔案了，它是那些檔案不見時的後備 |

授權與來源見「素材與來源」的音效表。

### 背景音樂

`%Music`（`game/music.gd`）：一般房間播 `assets/music/battle.ogg`，Boss 房播 `assets/music/boss_battle.wav`，兩首都循環。換房間時：同一首不會重來（第 1 間走到第 2 間，音樂不中斷）；要換成另一首（進 Boss 房）就舊的淡出、新的淡入，約 0.8 秒；通關或主角死亡時淡出到靜音；「再來一次」從房間曲重新開始。

- Inspector：`room_track`、`boss_track`（換歌：把別的音檔拖到這兩格）、`volume_db`（-12 dB；音效是 -6 dB，音樂比較小聲）、`fade_time`（0.8 秒）。循環由 `music.gd` 在播放前打開（OGG 的 `loop`、WAV 的 `loop_mode` 與 `loop_end`），所以換上沒設循環的檔案也會循環。
- 暫停（升級面板、暫停選單）時音樂照放，淡入淡出不受 hit stop 的慢動作影響：`Music` 節點的 `process_mode` 是 Always，淡入淡出的 Tween 忽略 `Engine.time_scale`。兩個 `AudioStreamPlayer`（`TrackA`、`TrackB`）輪流播，走 Master 匯流排。
- `boss_battle.wav` 是 10 MB 的 WAV（Godot 匯入時預設壓成 QOA，約 2 MB）。檔案的首尾取樣值不連續（尾端有淡出與兩格靜音），循環點可能聽得到一聲輕微的喀；沒有用耳朵驗證過。

## 測試與錄影

```bash
tools/check.sh                                  # 規則、scene 結構、實際遊玩、編輯保留，四組全跑
tools/capture.sh /tmp/cap 600 -- --autoplay --room=5 --give=attack_boost,multishot,front
```

- `test_play` 用真的 `main.tscn`：拖曳搖桿確認會移動、移動中不會丟（投擲動畫另列一條，見下）；機器人清完第 1 間後，確認升級面板每張卡都有能力圖示、標題／說明／層數都在卡片外框內 16 px 以內，再用按鈕點選能力卡；確認門打開、進入第 2 間；從第 10 間開始，蔣介石一開場就放出 4 個紅圈（1 個在主角腳下、都在地板上、彼此不大幅重疊），機器人帶著紅圈仍能打倒他，確認出現「第一章 完成！」；半血後放 6 個、長滿更快；血量低於一半時蔣介石生氣（橫幅、蒸氣、怒氣符號、身體泛紅），生氣前的子彈碰到牆就消失，生氣後的子彈碰牆反彈並在反彈後淡出，豆子不反彈；機器人會預測子彈的位置，站著不安全時往最安全的方向走一步（一顆正面飛來的子彈，站著不動會被打到，機器人會閃開）；主角的中心在紅圈內引爆時受傷、剛好在圈外不受傷，機器人會在引爆前走出圈外；坦克會先預警、再衝刺碾過主角（算作碾壓傷害）；關掉無敵後主角會受傷、死亡，按「再來一次」會從第 1 間重來。HUD 方面：搖桿一開始不在畫面上、按下的瞬間在手指下出現（半透明，alpha 0.5）、換個地方按就出現在那裡、放開就消失（遊戲暫停時放開也一樣）；清完第 1 間後金幣增加、HUD 數字一致；Boss 房切換成 Boss 版面（隱藏玩家區塊與技能欄、血量移到下方），打完切回來；HUD 血量跟著扣血；結算顯示這一局的金幣，重來歸零。
- 打擊回饋的測試（`test_play` 的 `_game_feel`，另有 `test_scenes`）：trauma 會累加、上限 1、衰減到 0，之後相機的 offset 與 roll 回到 0；震屏是平滑的（以 240 Hz 手動步進，相鄰取樣不會跳很遠）；`shake_scale = 0` 時完全不收集 trauma、相機不動；同一級事件疊加有上限（十個 small 只疊到 0.35，medium 疊上去還是會加，再疊 small 不變）；三級的 trauma／hit stop／粒子倍率遞增；對同一隻敵人連打 10 次後 1 秒，`%Sprite.scale` 回到原值；殺死敵人當下碰撞就關掉、躺平後被釋放、特效自己消失；hit stop 之後 `Engine.time_scale` 回到 1，短時間內第二次被節流、強制的不會；放一個測試用的 `assets/sfx/zz_feel_test.wav`（測完刪掉，資料夾裡其他檔案測試都不動）確認 `sfx` 改播它、刪掉後退回合成音；每個事件都找得到 `assets/sfx/` 的檔案（`squeak` 與五個刻意靜音的除外）、資料夾裡每個檔案都有事件在播、借用與靜音的規則（用測試自己編的事件名）；`ricochet` 在彈向下一隻敵人時播、`rage` 在 Boss 第一次低於一半血時播且只播一次；各事件的音效名都有發出（`step` `hit` `crit` `enemy_die` `hurt` `crush` `aoe_blast` `level_up` `boss_intro` `coin`）；紅邊、HP 殘影條、無敵閃爍、數字彈跳、Boss 條從 0 填滿。
- 背景音樂的測試（`test_play` 的 `_music`）：房間曲與 Boss 曲是 `assets/music/` 的那兩個檔案、音量比音效小、`Music` 節點在暫停時照常運作、換曲時兩首同時淡入淡出再只剩新的、同一首再要一次不重來、兩首都循環、暫停中仍在播而且淡入繼續、`time_scale` 0.05 時淡入仍照真實時間走、`stop()` 淡出到靜音；Boss 房播 Boss 曲、通關與死亡淡出、重來從房間曲開始。
- 投擲動畫的測試（`test_play`、`test_scenes`）：`hero.tscn` 的 `%Sprite.hframes == 6`；移動中是格 0；站著時第一次投擲前看得到格 1 或 2、蓄力不超過約 0.15 秒；甘蔗生成的那一刻（`%Shots` 加入新節點時）是格 3；約 0.3 秒後回到格 0；剛丟完就移動會立刻回到格 0；丟出去的甘蔗會自轉；連續投擲＋攻速滿級時，每一次出手都從格 3 重新開始，沒有任何一格卡超過 0.2 秒。
- `test_scenes` 另外確認 15 個能力的升級卡都顯示自己的圖示、說明跟標題與層數都在框內（含 16 px 內距；`\r\n` 不會多出空行；很長的說明最多三行、不會跑出框；沒有圖示的天使選項改顯示色塊）、蔣介石的 `RageSteam`／`RageMark` 在 scene 裡且平常關著、`rage_bounces` 在 1–2、子彈與豆子預設不反彈、每個角色、投射物、掉落物 scene 都有貼圖不是空的 `Sprite`、15 個能力都有圖示、敵人依移動方向翻面（接近垂直不翻）、蔣介石與巨型坦克有頭像、手槍是圖且槍口跟著轉；第 1 間只有老鼠、廚師丟的是豌豆／玉米／紅蘿蔔、各房間屬於哪個場地（第 10 間是紀念堂內的 `arena_hall`）、每個場地的背景圖貼滿整個世界、牆足夠多、障礙物只擋底座，每間房 2–4 個障礙物都站在地上、敵人與主角起點在 `walk_area` 裡且不壓到牆、最終 Boss 是蔣介石；並直接對 `hud.tscn` 測 HUD 的數字（房間、等級、血量、金幣）、技能欄（疊層點數、同一能力只佔一格、最多 5 格、有／無圖示）與一般／Boss 版面切換。
- 錄影會開一個置頂視窗；macOS 上錄影視窗被其他視窗蓋住時會停止更新畫面，所以 `capture.sh` 加了 `--always-on-top`。
- `test_persistence` 比對執行前後所有 `.tscn`／`.tres` 的雜湊值，確認執行遊戲不會改寫 scene 檔。也確認在 scene 裡改過的文字與間距，執行時會保留。
- headless 量不到 FPS，手機效能要用實機測。

## 修改 scene

`tools/build_scenes.gd` 只用來第一次產生 scene，之後以存下來的 `.tscn` 為準，直接在編輯器改。這支工具預設不覆寫已經存在的檔案；加 `-- --force` 會全部重建，蓋掉手動做的修改，重建前先看 `git diff`。

HUD、搖桿、結算面板與 `theme.tres` 是後來用 `tools/restyle_hud.gd` 改成概念圖外觀的一次性工具（已套用，重跑會因為 `hud.tscn` 已經有 `%HpBar` 而直接退出），同時新增了 `ui/ability_slot.tscn` 與 `pickups/coin.tscn`。`build_scenes.gd` 產生的還是改版前的樣子，所以不要用 `--force` 重建這幾個檔。

打擊回饋同理：`tools/apply_game_feel.gd` 是一次性工具（已套用，重跑會因為 `hud.tscn` 已有 `%HpGhost` 而退出），它產生五個特效 scene（`effects/spark`、`dust`、`debris`、`gold_burst`、`level_ring`），並在 `hud.tscn` 加殘影條、紅邊與白閃。`-- --effects` 只重做五個特效 scene（會蓋掉你在編輯器裡對它們做的修改）。`main.tscn` 的 `%Juice`、特效 scene 的 export、相機 `ignore_rotation` 是之後用文字小改的。

場地與障礙物同理：`tools/apply_arena_art.gd` 是一次性工具（已套用，重跑會因為 `arena/arena_hall.tscn` 已存在而退出；`-- --force` 才會重做），它重做了 `arena/door.tscn`、四個障礙物 scene、四個場地、十間房的布局與 `main.tscn` 的 y-sort，並把紅圈 scene 的 `z_index` 設成 -1。四個場地的牆、門的位置與每間房的障礙物都寫在它開頭的 `ARENAS`／`OBSTACLES`／`ROOMS` 表裡，當作這次怎麼量出來的紀錄；之後以存下來的 `.tscn` 為準。`build_scenes.gd --force` 會把場地和房間還原成舊的幾何圖形版，同樣不要用。

### 新增場地

1. 把場地圖（1080×1920，剛好等於整個世界）放進 `assets/`。
2. 在編輯器複製一個 `arena/arena_*.tscn` 存成新檔，把 `%Background` 的 `texture` 換成新圖（`centered` 保持關閉、位置 0,0）。
3. 重擺 `Walls` 底下的碰撞長方形：沿著圖上的欄杆、花園、樹、建築、火盆，往圖外多伸出去一些才不會有縫；圖中可走的地板就是活動範圍，把外框填進根節點的 `walk_area`。
4. 把 `%Door` 的 `position`（門檻中點）與 `scale` 對準圖上的門。
5. 根節點的 `z_index` 維持 -2，紅圈、坦克紅線與角色才會畫在地板之上。
6. 讓要用這個場地的 `rooms/room_XX.tscn` 的 `Arena` 指向新 scene，再依 `walk_area` 與牆調整那間房的敵人、`PlayerStart` 與障礙物。
7. 在 `tests/test_scenes.gd` 的 `stage_files` 補上這間房對應的場地檔名，並把新場地加進「每個場地」的檢查清單（`Background`、`walk_area`、牆數）。

## 素材與來源

- 音效與音樂是現成的授權素材，不是生成的（表在下面）。音效檔放 `assets/sfx/`，檔名就是事件名（見「音效接口」，`assets/sfx/README.md` 說明規則）；音樂放 `assets/music/`（見「背景音樂」）。
- 角色、投射物、掉落物、能力圖示與頭像都已換成 `assets/` 裡的生成圖（像素風；角色一律面朝右，所以左右用 `scale.x` 翻面）；只有 `squeak` 還是用 godot-kit 的 `synth.gd` 合成的音效。換掉其中一張圖：直接覆蓋 `assets/` 的同名 png（尺寸就是遊戲內的顯示尺寸，要同尺寸才不用調 `Sprite`），或在 scene 裡改 `Sprite` 的 `texture`。
- 圖片怎麼對齊角色：`Sprite` 置中，`position` 是腳底（圖的底邊貼著陰影），`offset` 把圖的腳點對到 x = 0，所以改 `scale` 是繞著腳底縮放。圖比碰撞圈大，所以縮小了：主角 1.0、老鼠 0.85、廚師 0.9、坦克／巨型坦克／蔣介石 0.75（可調整範圍 ±25%，碰撞圈不動）。
- 素材表（名稱、遊戲內尺寸、用在哪）：

  | 素材 | 尺寸 | 用在 |
  |---|---|---|
  | `assets/hero_throw.png` | 954×141（6 格，每格 159×141，腳底在格子底邊） | `player/hero.tscn` 的 `%Sprite`（`hframes = 6`） |
  | `assets/hero.png` | 85×120 | 沒有用到（它的姿勢就是 `hero_throw.png` 的格 0） |
  | `assets/rat.png` | 110×77 | `enemies/rat.tscn` |
  | `assets/tank.png` | 210×164 | `enemies/tank.tscn` |
  | `assets/boss_tank.png` | 320×258 | `enemies/boss_tank.tscn` |
  | `assets/chef.png` | 140×127 | `enemies/plate.tscn`（廚師） |
  | `assets/chiang.png` | 220×300 | `enemies/chiang_boss.tscn` |
  | `assets/pistol.png` | 72×53 | 蔣介石的 `GunArm/Pistol` |
  | `assets/sugarcane_purple.png` | 90×26 | `player/sugarcane.tscn`（丟出去的紫甘蔗） |
  | `assets/sugarcane_shot.png` | 80×45 | 沒有用到（舊的綠色甘蔗彈） |
  | `assets/bullet.png` | 50×18 | `enemies/bullet.tscn` |
  | `assets/pea.png`、`corn.png`、`carrot.png` | 30×30、40×33、46×31 | 同名 scene（廚師丟的豆子） |
  | `assets/exp_gem.png`、`heart.png`、`coin.png` | 26×40、44×40、34×36 | `pickups/` 同名 scene；`coin.png` 也是 HUD 的 `CoinIcon` |
  | `assets/portrait_hero.png` | 150×146 | HUD 的 `HeroPortrait`、`BottomPortrait` |
  | `assets/portrait_chiang.png`、`portrait_boss_tank.png` | 150×146、150×148 | 兩隻 Boss 的 `portrait`（Boss 血條） |
  | `assets/icon_<id>.png`（15 個） | 約 96×94 | 對應的 `data/abilities/<id>.tres` 的 `icon` |
  | `assets/bg_temple.png`、`bg_square.png`、`bg_memorial.png`、`bg_hall.png` | 1080×1920（等於整個世界） | `arena/arena_temple.tscn`、`arena_square.tscn`、`arena_memorial.tscn`、`arena_hall.tscn` 的 `Background` |
  | `assets/crate.png`、`sandbags.png`、`hedgehog.png`、`stone_block.png` | 74×110、250×103、97×110、93×110 | `arena/crate.tscn`、`barrier.tscn`、`hedgehog.tscn`、`stone_block.tscn` 的 `Sprite` |

  接上的方式是一次性工具 `tools/apply_actor_art.gd`（已套用，重跑會因為 `hero.tscn` 已經有 `%Sprite` 而退出）。

- 音效與音樂（檔名、用途、來源、授權）：

  | 檔案 | 用途 | 來源 | 授權 |
  |---|---|---|---|
  | `assets/sfx/<音效名>.ogg`，共 20 個：`aoe_blast` `boom` `boss_die` `coin` `crit` `crush` `dash` `door` `gun` `hero_die` `hit` `hurt` `level` `pickup` `rage` `rev` `ricochet` `step` `throw` `toss` | 同名事件的音效（見「音效接口」） | Kenney（www.kenney.nl）；個別檔案出自 Kenney 的哪個音效包沒有逐一記錄 | CC0（資料夾裡的 `KENNEY_LICENSE.txt` 是 Impact Sounds 1.0 的授權檔） |
  | `assets/sfx/enemy_die.ogg` | `enemy_die`（一般敵人死亡） | 使用者自己挑的；來源沒有記錄 | 沒有記錄，公開發佈前要補 |
  | `assets/music/battle.ogg` | 一般房間的背景音樂（循環，26.6 秒） | 作者 Wolfgang_ 的「bgm」（8-bit chiptune，2017-12-20） | CC0（`assets/music/CREDITS.md`） |
  | `assets/music/boss_battle.wav` | Boss 房的背景音樂（循環，59.6 秒，10 MB） | 作者 nene 的「Boss Battle #2 ["8 bit"]」（2016-09-05） | CC0（`assets/music/CREDITS.md`） |
- 換成概念圖畫風的素材：生成 prompt 與檔名在 `art_src/PROMPTS.md`；生成的圖放進 `art_src/`，再用 `tools/process_art.gd` 去背（#FF00FF）、切格、縮到遊戲尺寸，輸出到 `assets/`（`-- --self-test` 檢查去背與縮放）。`art_src/` 有 `.gdignore`，原始大圖不會被匯入。
- 蔣介石、天安門廣場、中正紀念堂都是真實人物與地點。私下試玩沒問題，公開發佈前要評估政治敏感度與肖像使用（蔣介石現在是寫實風的生成圖，風險比原本的幾何圖形高）。
- 字型：`ui/fonts/NotoSansTC.ttf`，SIL OFL 1.1（`ui/fonts/OFL.txt`），從 pixel-monster 複製。
- 參考 [Whitebrim/Archero](https://github.com/Whitebrim/Archero) 與 [hafizhassanraza/Archero-Clone](https://github.com/hafizhassanraza/Archero-Clone)（都是 Unity 專案，沒有附授權），只參考行為，沒有複製程式碼：「優先瞄準看得到的最近敵人」、「全滅才開門」。兩份都沒有升級三選一的能力系統。

## 已知缺口

- 還沒上過實機。19.5:9 的畫面比例已經確認版面正確（`expand` 會把多出來的高度留在上下），但上方資訊列照概念圖貼著上緣（`TopBar` 的 `margin_top` 只有 12px），實機上會被瀏海或動態島蓋住，要依 Safe Area 往下推。
- 只有桌面的滑鼠與鍵盤測試過；觸控是靠 Godot 把觸控轉成滑鼠事件（`emulate_mouse_from_touch`）來支援。

## 發現

（真人試玩後補上）
