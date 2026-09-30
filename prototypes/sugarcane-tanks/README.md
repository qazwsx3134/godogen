# 安

《弓箭傳說》（Archero）式的直式房間射擊原型：主角丟甘蔗，對手是老鼠、會碾人的坦克、丟三色豆的餐盤怪，最後是蔣介石。
一路從宮廟打到天安門廣場，再到中正紀念堂。資料夾名稱 `sugarcane-tanks` 是暫名時取的。

《宇智波斑 Survivors》（[PROJECT.md](../../docs/survivors/PROJECT.md)）在拿到版權之前，先用這個與 IP 無關的替身驗證 Survivors 類的核心手感。

給其他人看的功能、架構與可共用模組整理：[docs/Ann-the-last-sugercane-Forsaken](../../docs/Ann-the-last-sugercane-Forsaken/README.md)（含概念圖與差距）。

**狀態**：進行中（第一章 10 間可以從頭玩到尾，還沒有真人試玩）

## 要驗證的假設

- 「移動就不能攻擊、停下就自動攻擊」這條規則，在手機直式上能不能兼顧走位和輸出的爽感。
- 每次升級三選一、能力可以疊加（正面＋1、連續投擲、斜向、彈射……），短短一章內能不能長出「這局的 build」。
- 三種敵人各有辨識度（老鼠衝撞、坦克預警後衝刺碾壓、餐盤怪遠程丟豆），加上兩場打法不同的 Boss（衝刺碾壓、彈幕加紅圈範圍攻擊），能不能撐起 10 間房的節奏。
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

**操作**：在畫面任一處按住拖曳是浮動搖桿，放開後自動朝最近而且看得到的敵人丟甘蔗。電腦上也可以用 WASD 或方向鍵。

## 一章的流程

```
第 1–3 間 宮廟 ─→ 第 4–7 間 天安門廣場 ─→ 第 8–10 間 中正紀念堂
 （老鼠為主）      （坦克、餐盤怪登場；        （全部混合；第 10 間蔣介石）
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
| 餐盤怪 | 第 3 間起 | 保持距離、左右橫移，每隔一段時間轉一圈丟出扇形的三色豆（豌豆、玉米、紅蘿蔔） |
| 重型坦克（第 5 間 Boss） | | 輪流：長距離衝刺、連續三段衝刺（每段重新瞄準）、叫出老鼠。半血後預警變短、老鼠變多 |
| 蔣介石（第 10 間最終 Boss） | | 在上半場移動，手槍跟著主角轉；開火前身體閃一下，輪流放**紅圈**、瞄準三連發、兩波錯開的扇形、旋轉螺旋、整圈環形子彈。紅圈是第一招：一次放 4 個半透明紅圈，1 個在主角腳下、3 個隨機落在地板上；內圈從中心長滿（1.5 秒）就引爆，圈內的人受傷，Boss 放完就繼續移動。半血後子彈變快，紅圈變 6 個、長滿只要 1 秒 |

敵人卡在箱子前面時會自動往側邊繞。

## 主要 scene 與可以在編輯器調的地方

所有畫面與物件都是 `.tscn`，用 Godot 編輯器打開就看得到版面。

| Scene | 內容 | 常調整的地方 |
|---|---|---|
| `main.tscn` | 相機、房間容器（預覽第 1 間）、主角、投射物與特效容器、UI | Main 的 export：`rooms`（房間順序）、`abilities`（出現在卡池的能力）、`angel_heal_ratio`、`heart_heal_ratio`、`sugarcane_speed` |
| `rooms/room_01…10.tscn` | 一間房：Arena（場地、牆、門）、Obstacles（箱子、水泥路障）、Enemies、PlayerStart | **直接拖曳敵人和箱子調整布局**；在 Enemies 底下加或刪敵人 instance；Room 的 `boss_room`、`hp_scale`（整間敵人的血量倍率）、`area_name`（進入時跳出的地名） |
| `arena/arena_temple.tscn`、`arena_square.tscn`、`arena_memorial.tscn` | 宮廟、天安門廣場、中正紀念堂三種場地 | Facade（上方建築）、Decor（柱子、燈籠、香爐、路燈、旗桿、樹）、Paving（地磚線）都是可以拖曳、改色的 Polygon2D；牆的碰撞在 Walls 底下 |
| `enemies/rat.tscn`、`tank.tscn`、`plate.tscn` | 老鼠、坦克、餐盤怪 | 共用 export：`max_hp`、`move_speed`、`contact_damage`、`exp_value`、`knockback`、`heart_drop_chance`；坦克的 `crush_damage`、`dash_speed`、`dash_distance`、`dash_range`、`windup_time`、`recover_time`；餐盤怪的 `bean_scenes`、`throw_interval`、`fan_degrees`、`bean_speed`、`bean_damage`、`near_distance`／`far_distance`。外型都在 Body 底下 |
| `enemies/boss_tank.tscn`、`chiang_boss.tscn` | 兩隻 Boss | 重型坦克另有 `summon_count`、`long_dash_distance`、`quick_windup`；蔣介石有 `bullet_speed`、`bullet_damage`、`rest_time`、`telegraph_time`、`roam_area`，紅圈的 `aoe_scene`、`aoe_count`（4）、`aoe_count_enraged`（6）、`aoe_telegraph_time`（1.5）、`aoe_telegraph_time_enraged`（1.0）、`aoe_area`（隨機紅圈的圓心範圍）、`aoe_spacing`（圈與圈的圓心距離，以半徑為單位，預設 1.5），手槍在 GunArm 底下 |
| `effects/aoe_circle.tscn` | Boss 的紅圈：半透明圓盤 `Fill`、亮紅外框 `Ring`（外圍 `Glow` 光暈）、預警時從中心長大的內圈 `Grow`、中心的放射狀爆光 `Burst`；引爆時另外生成紅色爆炸、碎石煙塵、震屏、爆炸聲 | 顏色與粗細直接改 `Visual` 底下的各節點；export：`radius`（130，執行時外觀依它縮放）、`telegraph_time`（1.5，蔣介石依血量覆寫）、`damage`（120）。外觀畫在 130 的半徑上，改 `radius` 後要執行才看得到縮放 |
| `enemies/pea.tscn`、`corn.tscn`、`carrot.tscn`、`bullet.tscn` | 三色豆與子彈 | `spin`（豆子轉速；子彈為 0，朝飛行方向） |
| `player/hero.tscn` | 主角（黑短髮、藍衣、手上的甘蔗）、頭上血條 | `move_speed`、`stop_to_throw_delay`（停下到第一次丟的延遲）、`volley_gap`、`hurt_invulnerability` |
| `player/sugarcane.tscn` | 投出去的甘蔗 | Visual 底下的外型 |
| `ui/hud.tscn` | 照概念圖的 HUD。**一般房間**：左上玩家區塊 `PlayerPanel`（圓形頭像 `HeroPortrait`、`LevelLabel`、綠色 `HpBar`＋`HpLabel`、細藍 `ExpBar`）；右上 `STAGE` 框（`RoomLabel` 只放數字）、`PauseButton`，下面是金幣框（`CoinIcon`＋`CoinLabel`）；下方中間是技能欄 `AbilityChips`（每格一個 `ability_slot.tscn`）；左下是搖桿。**Boss 房**（`show_boss()`）：玩家區塊與技能欄隱藏，改顯示 `BossPanel`（`BossPortrait`、`BossName`、長紅條 `BossBar`），主角血量移到下方中間的 `BottomHeroPanel`（`BottomPortrait`＋5 段 `BottomHpBar`）。另有 `Banner`（地名、BOSS 來了）、`PauseOverlay`、`Fade` | `TopBar` 的邊距（`margin_top` 是 12，貼上緣）、各 Label 字級與顏色、各條的 StyleBox；`BossPanel`、`BottomHeroPanel` 在 scene 裡預設隱藏（在編輯器點眼睛圖示才看得到）；`AbilityChips` 底下的 3 格只是編輯器預覽，執行時會清掉。**圖片**：把頭像、Boss 頭像、金幣圖放進 `HeroPortrait`／`BossPortrait`／`BottomPortrait`／`CoinIcon` 的 `texture`；圖自帶框，子節點 `Frame`（金色圓框佔位）畫在圖後面，所以在編輯器裡貼上圖就直接看到圖；執行時有圖的話 `Frame` 會再自動隱藏，避免圖的透明角露出佔位框。API：`set_room`、`set_level`、`set_hp(hp, max_hp)`、`set_coins`、`set_ability(def, stacks)`、`show_boss(title, hp, max_hp, portrait = null)`、`hide_boss`、`banner` |
| `ui/ability_slot.tscn` | 技能欄的一格：`Icon`（TextureRect）、沒有圖示時的佔位 `Frame`（綠框深底）＋`Swatch`（能力顏色的方塊）＋`Initial`（標題第一個字），下方 `Pips` 用 ◆◇ 顯示疊了幾層 | `IconBox` 的大小、`Frame` 的框色；圖示放在 `data/abilities/*.tres` 的 `icon`（有圖就隱藏佔位）；點數的格數 = min(`max_stacks`, 3)。同一個能力再拿只更新同一格，最多顯示最近拿的 5 格 |
| `ui/choice_panel.tscn`＋`ui/ability_card.tscn` | 升級與天使面板、能力卡 | 卡片高度、字級；面板裡的 3 張卡只是編輯器預覽，執行時會換成實際選項 |
| `ui/joystick.tscn` | 浮動搖桿：深色半透明底座、亮外圈、四個小箭頭、淺灰把手。按畫面任一處就在手指下出現，放開後回到左下角的停放位置，一直顯示；`Hint` 提示字節點保留但隱藏 | `radius`（手指移動多遠算推滿）、`knob_travel`（把手在底座內最遠走多少）、`dead_zone`；Base 的 offset 就是停放位置；Base／Knob／箭頭的外觀 |
| `ui/result_panel.tscn` | 結算：標題、摘要、這一局拿到的金幣 `CoinsLabel`、「再來一次」 | 字級、顏色 |
| `pickups/coin.tscn` | 金幣掉落物，飛向主角的方式和經驗寶石相同 | `Visual` 底下的外型（金色圓形佔位，之後換成 `assets/coin.png`）。掉落數量在 `main.gd` 的 `on_enemy_killed`：每點 `exp_value` 一金，Boss 加倍 |
| `ui/theme.tres` | 全專案字型（Noto Sans TC）、按鈕與面板樣式：深藍底 #1B2130（不透明度 0.9）＋金色邊框 #E8B84A 3px＋圓角 | 顏色、邊框粗細、圓角（升級卡、結算、暫停畫面都吃這一套） |

平衡數值（傷害、攻速、疊加懲罰、升級所需經驗）集中在 `domain/hero_stats.gd` 開頭的常數。

## 測試與錄影

```bash
tools/check.sh                                  # 規則、scene 結構、實際遊玩、編輯保留，四組全跑
tools/capture.sh /tmp/cap 600 -- --autoplay --room=5 --give=attack_boost,multishot,front
```

- `test_play` 用真的 `main.tscn`：拖曳搖桿確認會移動、移動中不會丟；機器人清完第 1 間後，用按鈕點選能力卡；確認門打開、進入第 2 間；從第 10 間開始，蔣介石一開場就放出 4 個紅圈（1 個在主角腳下、都在地板上、彼此不大幅重疊），機器人帶著紅圈仍能打倒他，確認出現「第一章 完成！」；半血後放 6 個、長滿更快；主角的中心在紅圈內引爆時受傷、剛好在圈外不受傷，機器人會在引爆前走出圈外；坦克會先預警、再衝刺碾過主角（算作碾壓傷害）；關掉無敵後主角會受傷、死亡，按「再來一次」會從第 1 間重來。HUD 方面：搖桿底座跟著手指、放開後回到停放位置且一直顯示；清完第 1 間後金幣增加、HUD 數字一致；Boss 房切換成 Boss 版面（隱藏玩家區塊與技能欄、血量移到下方），打完切回來；HUD 血量跟著扣血；結算顯示這一局的金幣，重來歸零。
- `test_scenes` 另外確認第 1 間只有老鼠、餐盤怪丟的是豌豆／玉米／紅蘿蔔、各房間屬於哪個場地、最終 Boss 是蔣介石；並直接對 `hud.tscn` 測 HUD 的數字（房間、等級、血量、金幣）、技能欄（疊層點數、同一能力只佔一格、最多 5 格、有／無圖示）與一般／Boss 版面切換。
- 錄影會開一個置頂視窗；macOS 上錄影視窗被其他視窗蓋住時會停止更新畫面，所以 `capture.sh` 加了 `--always-on-top`。
- `test_persistence` 比對執行前後所有 `.tscn`／`.tres` 的雜湊值，確認執行遊戲不會改寫 scene 檔。也確認在 scene 裡改過的文字與間距，執行時會保留。
- headless 量不到 FPS，手機效能要用實機測。

## 修改 scene

`tools/build_scenes.gd` 只用來第一次產生 scene，之後以存下來的 `.tscn` 為準，直接在編輯器改。這支工具預設不覆寫已經存在的檔案；加 `-- --force` 會全部重建，蓋掉手動做的修改，重建前先看 `git diff`。

HUD、搖桿、結算面板與 `theme.tres` 是後來用 `tools/restyle_hud.gd` 改成概念圖外觀的一次性工具（已套用，重跑會因為 `hud.tscn` 已經有 `%HpBar` 而直接退出），同時新增了 `ui/ability_slot.tscn` 與 `pickups/coin.tscn`。`build_scenes.gd` 產生的還是改版前的樣子，所以不要用 `--force` 重建這幾個檔。

## 素材與來源

- 圖像目前是 scene 裡的 Polygon2D 佔位；音效用 godot-kit 的 `synth.gd` 即時合成。
- HUD 等圖到了再放進去（現在都是空的佔位）：`ui/hud.tscn` 的 `HeroPortrait`、`BossPortrait`、`BottomPortrait`、`CoinIcon` 的 `texture`，各能力 `data/abilities/*.tres` 的 `icon`，`pickups/coin.tscn` 的 `Visual`（換成 `assets/coin.png`）。
- 換成概念圖畫風的素材：生成 prompt 與檔名在 `art_src/PROMPTS.md`；生成的圖放進 `art_src/`，再用 `tools/process_art.gd` 去背（#FF00FF）、切格、縮到遊戲尺寸，輸出到 `assets/`（`-- --self-test` 檢查去背與縮放）。`art_src/` 有 `.gdignore`，原始大圖不會被匯入。
- 蔣介石、天安門廣場、中正紀念堂都是真實人物與地點。私下試玩沒問題，公開發佈前要評估政治敏感度與肖像使用；原型裡只用簡單幾何圖形做 Q 版表現。
- 字型：`ui/fonts/NotoSansTC.ttf`，SIL OFL 1.1（`ui/fonts/OFL.txt`），從 pixel-monster 複製。
- 參考 [Whitebrim/Archero](https://github.com/Whitebrim/Archero) 與 [hafizhassanraza/Archero-Clone](https://github.com/hafizhassanraza/Archero-Clone)（都是 Unity 專案，沒有附授權），只參考行為，沒有複製程式碼：「優先瞄準看得到的最近敵人」、「全滅才開門」。兩份都沒有升級三選一的能力系統。

## 已知缺口

- 還沒上過實機。19.5:9 的畫面比例已經確認版面正確（`expand` 會把多出來的高度留在上下），但上方資訊列照概念圖貼著上緣（`TopBar` 的 `margin_top` 只有 12px），實機上會被瀏海或動態島蓋住，要依 Safe Area 往下推。
- 只有桌面的滑鼠與鍵盤測試過；觸控是靠 Godot 把觸控轉成滑鼠事件（`emulate_mouse_from_touch`）來支援。

## 發現

（真人試玩後補上）
