# 安

《弓箭傳說》（Archero）式的直式房間射擊原型：主角丟甘蔗，對手是老鼠、會碾人的坦克、丟三色豆的餐盤怪，最後是蔣介石。
一路從宮廟打到天安門廣場，再到中正紀念堂。資料夾名稱 `sugarcane-tanks` 是暫名時取的。

《宇智波斑 Survivors》（[PROJECT.md](../../docs/survivors/PROJECT.md)）在拿到版權之前，先用這個與 IP 無關的替身驗證 Survivors 類的核心手感。

給其他人看的功能、架構與可共用模組整理：[docs/Ann-the-last-sugercane-Forsaken](../../docs/Ann-the-last-sugercane-Forsaken/README.md)（含概念圖與差距）。

**狀態**：進行中（第一章 10 間可以從頭玩到尾，還沒有真人試玩）

## 要驗證的假設

- 「移動就不能攻擊、停下就自動攻擊」這條規則，在手機直式上能不能兼顧走位和輸出的爽感。
- 每次升級三選一、能力可以疊加（正面＋1、連續投擲、斜向、彈射……），短短一章內能不能長出「這局的 build」。
- 三種敵人各有辨識度（老鼠衝撞、坦克預警後衝刺碾壓、餐盤怪遠程丟豆），加上兩場打法不同的 Boss（衝刺碾壓、彈幕），能不能撐起 10 間房的節奏。
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
 → 全滅：清掉子彈與豆子，經驗寶石與愛心飛向主角
 → 每升一級暫停一次：3 選 1 能力
 → 第 5、10 間是 Boss；第 5 間打完後出現天使（回血 40% 或拿一個能力）
 → 上方的門打開，走進去 → 下一間
第 10 間 Boss 倒下 → 「第一章 完成！」；主角倒下 → 結算，按「再來一次」重來
```

## 與弓箭傳說的對照

| 有做 | 沒做 |
|---|---|
| 移動時不攻擊、停下自動瞄準最近的敵人（優先挑沒被障礙物擋住的） | 裝備、天賦、體力、金幣與商店 |
| 升級 3 選 1，15 種能力可疊加，多顆甘蔗會降低單顆傷害 | 多個角色、第二章以後 |
| 房間制，清完才開門；Boss 血條；天使 | 惡魔（用生命上限換能力）、幸運轉盤、復活 |
| 子彈與豆子會被牆壁和箱子擋住；坦克衝刺前有紅線預警 | 飛行敵人（可以穿越障礙物） |
| 主角頭上有血條與數字，坦克被擊破掉愛心 | 存檔續玩 |

能力的效果寫在 `domain/hero_stats.gd`，卡片上的文字與可疊加的次數在 `data/abilities/*.tres`。

## 敵人

| 敵人 | 出現 | 行為 |
|---|---|---|
| 老鼠 | 第 1 間起（最早的敵人） | 快速左右搖擺衝向主角，撞到就扣血；血少，被打會被推開 |
| 坦克 | 第 2 間起 | 慢慢開向主角 → 停下亮紅線預警 → 高速衝刺，**直接碾過主角**（主角被壓扁一下，傷害比碰撞高很多）→ 衝完停頓一下，是反擊的空檔 |
| 餐盤怪 | 第 3 間起 | 保持距離、左右橫移，每隔一段時間轉一圈丟出扇形的三色豆（豌豆、玉米、紅蘿蔔） |
| 重型坦克（第 5 間 Boss） | | 輪流：長距離衝刺、連續三段衝刺（每段重新瞄準）、叫出老鼠。半血後預警變短、老鼠變多 |
| 蔣介石（第 10 間最終 Boss） | | 在上半場移動，手槍跟著主角轉；開火前身體閃一下，輪流放瞄準三連發、兩波錯開的扇形、旋轉螺旋、整圈環形子彈。半血後子彈變快 |

敵人卡在箱子前面時會自動往側邊繞。

## 主要 scene 與可以在編輯器調的地方

所有畫面與物件都是 `.tscn`，用 Godot 編輯器打開就看得到版面。

| Scene | 內容 | 常調整的地方 |
|---|---|---|
| `main.tscn` | 相機、房間容器（預覽第 1 間）、主角、投射物與特效容器、UI | Main 的 export：`rooms`（房間順序）、`abilities`（出現在卡池的能力）、`angel_heal_ratio`、`heart_heal_ratio`、`sugarcane_speed` |
| `rooms/room_01…10.tscn` | 一間房：Arena（場地、牆、門）、Obstacles（箱子、水泥路障）、Enemies、PlayerStart | **直接拖曳敵人和箱子調整布局**；在 Enemies 底下加或刪敵人 instance；Room 的 `boss_room`、`hp_scale`（整間敵人的血量倍率）、`area_name`（進入時跳出的地名） |
| `arena/arena_temple.tscn`、`arena_square.tscn`、`arena_memorial.tscn` | 宮廟、天安門廣場、中正紀念堂三種場地 | Facade（上方建築）、Decor（柱子、燈籠、香爐、路燈、旗桿、樹）、Paving（地磚線）都是可以拖曳、改色的 Polygon2D；牆的碰撞在 Walls 底下 |
| `enemies/rat.tscn`、`tank.tscn`、`plate.tscn` | 老鼠、坦克、餐盤怪 | 共用 export：`max_hp`、`move_speed`、`contact_damage`、`exp_value`、`knockback`、`heart_drop_chance`；坦克的 `crush_damage`、`dash_speed`、`dash_distance`、`dash_range`、`windup_time`、`recover_time`；餐盤怪的 `bean_scenes`、`throw_interval`、`fan_degrees`、`bean_speed`、`bean_damage`、`near_distance`／`far_distance`。外型都在 Body 底下 |
| `enemies/boss_tank.tscn`、`chiang_boss.tscn` | 兩隻 Boss | 重型坦克另有 `summon_count`、`long_dash_distance`、`quick_windup`；蔣介石有 `bullet_speed`、`bullet_damage`、`rest_time`、`telegraph_time`、`roam_area`，手槍在 GunArm 底下 |
| `enemies/pea.tscn`、`corn.tscn`、`carrot.tscn`、`bullet.tscn` | 三色豆與子彈 | `spin`（豆子轉速；子彈為 0，朝飛行方向） |
| `player/hero.tscn` | 主角（黑短髮、藍衣、手上的甘蔗）、頭上血條 | `move_speed`、`stop_to_throw_delay`（停下到第一次丟的延遲）、`volley_gap`、`hurt_invulnerability` |
| `player/sugarcane.tscn` | 投出去的甘蔗 | Visual 底下的外型 |
| `ui/hud.tscn` | 上方資訊列、經驗條、能力標籤、Boss 血條、暫停、橫幅字 | TopBar 的邊距、各 Label 字級、ExpBar 顏色 |
| `ui/choice_panel.tscn`＋`ui/ability_card.tscn` | 升級與天使面板、能力卡 | 卡片高度、字級；面板裡的 3 張卡只是編輯器預覽，執行時會換成實際選項 |
| `ui/joystick.tscn` | 浮動搖桿與底部提示字 | `radius`、`dead_zone`、Base／Knob 外觀 |
| `ui/theme.tres` | 全專案字型（Noto Sans TC）與按鈕樣式 | |

平衡數值（傷害、攻速、疊加懲罰、升級所需經驗）集中在 `domain/hero_stats.gd` 開頭的常數。

## 測試與錄影

```bash
tools/check.sh                                  # 規則、scene 結構、實際遊玩、編輯保留，四組全跑
tools/capture.sh /tmp/cap 600 -- --autoplay --room=5 --give=attack_boost,multishot,front
```

- `test_play` 用真的 `main.tscn`：拖曳搖桿確認會移動、移動中不會丟；機器人清完第 1 間後，用按鈕點選能力卡；確認門打開、進入第 2 間；從第 10 間開始打倒蔣介石，確認出現「第一章 完成！」；坦克會先預警、再衝刺碾過主角（算作碾壓傷害）；關掉無敵後主角會受傷、死亡，按「再來一次」會從第 1 間重來。
- `test_scenes` 另外確認第 1 間只有老鼠、餐盤怪丟的是豌豆／玉米／紅蘿蔔、各房間屬於哪個場地、最終 Boss 是蔣介石。
- 錄影會開一個置頂視窗；macOS 上錄影視窗被其他視窗蓋住時會停止更新畫面，所以 `capture.sh` 加了 `--always-on-top`。
- `test_persistence` 比對執行前後所有 `.tscn`／`.tres` 的雜湊值，確認執行遊戲不會改寫 scene 檔。也確認在 scene 裡改過的文字與間距，執行時會保留。
- headless 量不到 FPS，手機效能要用實機測。

## 修改 scene

`tools/build_scenes.gd` 只用來第一次產生 scene，之後以存下來的 `.tscn` 為準，直接在編輯器改。這支工具預設不覆寫已經存在的檔案；加 `-- --force` 會全部重建，蓋掉手動做的修改，重建前先看 `git diff`。

## 素材與來源

- 圖像全部是 scene 裡的 Polygon2D 佔位，沒有付費生成；音效用 godot-kit 的 `synth.gd` 即時合成。
- 蔣介石、天安門廣場、中正紀念堂都是真實人物與地點。私下試玩沒問題，公開發佈前要評估政治敏感度與肖像使用；原型裡只用簡單幾何圖形做 Q 版表現。
- 字型：`ui/fonts/NotoSansTC.ttf`，SIL OFL 1.1（`ui/fonts/OFL.txt`），從 pixel-monster 複製。
- 參考 [Whitebrim/Archero](https://github.com/Whitebrim/Archero) 與 [hafizhassanraza/Archero-Clone](https://github.com/hafizhassanraza/Archero-Clone)（都是 Unity 專案，沒有附授權），只參考行為，沒有複製程式碼：「優先瞄準看得到的最近敵人」、「全滅才開門」。兩份都沒有升級三選一的能力系統。

## 已知缺口

- 還沒上過實機。19.5:9 的畫面比例已經確認版面正確（`expand` 會把多出來的高度留在上下），但上方資訊列只離頂端 60px，實機上會被瀏海或動態島蓋住，要依 Safe Area 往下推。
- 只有桌面的滑鼠與鍵盤測試過；觸控是靠 Godot 把觸控轉成滑鼠事件（`emulate_mouse_from_touch`）來支援。

## 發現

（真人試玩後補上）
