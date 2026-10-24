# Claude review：RO 式自動戰鬥（combatant.gd／field.gd）

> **2026-10-24 結案**：`game/combatant.gd` 與舊 `field.gd` 已由 `domain/battle.gd`（純模擬）＋`game/field.gd`／`game/actor_view.gd`（呈現）取代。D1 由繞行＋卡住偵測解決（`test_battle`）；D2 由 view 每幀只決定一次動畫解決（`test_field`）；D3 結束後 view 仍更新（`test_field`）；D4 點怪追打、AI 不綁自動（`test_field`／`test_battle`）；D5 數值全部讀 tuning、重開重建 battle；D6 改用 `global_position`、WASD 用 `camera.global_basis`；D7 被打時立即重選目標（`test_battle`）。下文保留當時的分析。

2026-10-24，Claude（Opus 5.5）。這份是對 `game/combatant.gd` 與 `game/field.gd` 的靜態 review，場景還沒存好。測試寫在 `tests/test_combat_review.gd`，FAIL 訊息用的編號跟本文的 D 編號一致。

## 缺陷（依嚴重度排序）

### D1　正面撞上障礙物就卡死，`moving` 也永遠不會清掉　**高**
`combatant.gd:57-65`：推出障礙物只做「徑向推回半徑上」，沒有切向的滑行。當目的地在障礙物圓心的正後方（或近乎正後方）時，每幀算出的 `next` 都會被推回同一個接觸點，角色停在原地。
- 點地移動：`field.gd:107` 的抵達判定永遠不成立，所以 `moving` 一直是 true，狀態列一直顯示「前往指定位置」。`automatic` 的追敵與攻擊（`field.gd:110`、`:115`）被 `moving` 擋住，等於自動狩獵從此失效，玩家必須再點一次地面。
- 自動追敵：目標在石頭正後方時同樣卡住。`target` 不會被換掉（見 D7），所以會一直卡著。
- 盟友跟隨點（`player.position + offsets[i]`）落在障礙物裡、敵人回 `spawn_position` 的路被擋住，也是同一個問題。
- 建議：推回之後保留切向分量（沿切線滑行），或加卡住偵測（連續 N 幀位移小於 ε 就取消 `moving`／換目標）。最好兩個都做。

### D2　走路動畫停在第 0 格，攻擊動畫在 0.25 秒被截斷　**高（前提：`$Visual` 是 `sprite3d_actor.gd`）**
`simulate()` 每幀先呼叫 `animate()`，hit_timer 歸零時它會 `play(&"idle")`（`combatant.gd:46-47`）；接著 `walk_to()` 又 `play(&"walk")`（`:68`）。`sprite3d_actor.play()` 只要換了 anim 就把 `ticks` 歸零（`addons/proto_kit/sprite3d_actor.gd:81-84`），所以移動中的角色每幀都被重設成 walk 的第 0 格。攻擊方面，`strike` 設定 `hit_timer = 0.25`，0.25 秒後 idle 就把 attack 蓋掉；追擊中的 `walk_to` 也會在同一幀覆蓋 attack。
- 建議：由 `walk_to`／`strike` 記下「這幀有沒有動作」，在 `animate` 最後只決定一次 anim；或讓 attack 播到 `visual.finished()` 再交回 idle。
- 待確認：`build_field.gd` 存好後，看 Visual 是否真的掛 `sprite3d_actor.gd`。如果 Visual 是另一支腳本，請看它的 `play()` 會不會重設影格。

### D3　玩家倒下後畫面凍住（閃白不退、不溶解）　**中**
`field.gd:79`：一旦 `ended` 就直接 return，`animate()` 不再執行。玩家倒下那一擊把 `visual.flash` 設成 1.0（`combatant.gd:84`），之後沒有東西讓它衰減，玩家會一直停在全白，`dissolve` 也停在 0。敵人和盟友同樣停在那一幀。
- 建議：`ended` 時仍跑 `actor.animate(delta)`，只停 AI 與輸入。

### D4　手動模式下玩家不會普攻，盟衛也不參戰　**中（UX；請確認設計意圖）**
- 玩家只有在 `automatic` 時才會攻擊（`field.gd:115`）。點地移動只會走路，點敵人不會鎖定，`target` 也只在 auto 裡才會被設定。關掉 auto 時，唯一的傷害來源是 Q。
- 盾衛找目標需要 `automatic`（`field.gd:122`），所以手動時敵人追著打隊伍，盾衛只會跟在玩家旁邊。
- RO 的核心操作是點敵人就自動追打。建議：左鍵射線先檢查敵人（螢幕距離或圓柱範圍），點到就設 `target` 並追打；點到地面才移動。盾衛的參戰條件也不要綁 `automatic`。

### D5　`restart_run` 把攻擊力寫死成 18.0　**中**
`field.gd:316`：生命值有 `spawn_health` 可以還原，攻擊力卻寫死。場景裡把玩家的 `attack_power` export 改成別的值，重開後就會跟場景不一致；調數值的人在編輯器裡改了也看不出效果（違反「版面／數值交給 scene」）。
- 建議：在 `_ready` 存下 `spawn_attack`，`restore()` 或 `restart_run` 用它來還原。

### D6　座標空間的假設（靜態檢查場景時要確認）　**中**
所有距離都用 `position`（local），例如 `field.gd:113`、`:145`、`:172` 與 `combatant.gd:59`、`:77`。這只有在 `%Player`／`%Guardian`／`%Healer`、`%Enemies` 的子節點、`%Obstacles` 的子節點共用同一個座標系時才正確，也就是 `Enemies`、`Obstacles` 容器的 transform 必須是 identity，且三名隊員都直接掛在同一個父節點下。
- 另外 `pointer`／`target_marker` 也用 local `position`，它們的父節點同樣要符合上面的條件。
- `order_move` 的障礙物距離是 3D（`field.gd:228`），`walk_to` 則是平面距離；障礙物節點的 y 不是 0 時兩邊會不一致。
- WASD 用 `camera.basis`（local）。Camera 若掛在有旋轉的 rig 底下，方向會錯，應改用 `global_basis`。

### D7　自動狩獵一鎖定目標就不換　**低～中**
`target` 只在死亡時清掉（`field.gd:90`）。搜尋半徑 30 幾乎涵蓋全圖，所以玩家會穿過正在打自己的近敵，走向遠處的目標；目標被石頭擋住時則永遠卡著（D1）。
- 建議：自己被攻擊、或目標距離明顯比最近敵人遠（例如超過 2 倍）時重選目標。

## 次要／待確認意圖

- 盾衛、補師倒下後，在 `restart_run` 前都不會復活；`party_label` 只顯示 `0/…`，沒有寫「倒下」。如果這是設計，至少要顯示倒下狀態。
- 補師治療沒有距離限制，隔著全圖也補得到；浮字一律顯示 `+12`，不反映實際補了多少。
- 敵人的 bob 寫在 `walk_to` 裡（`combatant.gd:72`），停下後 `visual.position.y` 停在最後一個 sin 值，最多會浮空或陷地 0.06。
- 敵人在 spawn 點原地 `restore()`，如果玩家站在那裡，就會貼臉復活並立刻開打。
- 在同一個 physics 幀裡，自動喝水排在敵人攻擊與死亡判定之後（`field.gd:155-159`），多隻敵人同幀爆發時，40% 的門檻來不及救。這是可接受的取捨，只是要知道有這回事。
- `use_skill` 打的是攻擊範圍內最近的敵人，不是目前鎖定的 `target`。
- 文件不一致：`production/session-state/active.md` 寫「角色永久死亡，帳號保留部分傳承」為已確認，而 Codex 的說明是「死亡規則使用者未回答」，請跟使用者確認並修正其中一邊。

## 測試現況

見 `tests/test_combat_review.gd`。因為 `field.gd` preload 了還不存在的 `scenes/floating_text.tscn`，目前只能測 `combatant.gd`：在測試裡手組節點，Visual 用 stub 記錄 `play()` 的呼叫順序。D1、D2 的紅燈是缺陷證據，不是測試本身寫錯。場景存好後再補 field 層的實測（D3、D4、D6、D7）。

### 第一輪實跑（2026-10-24，Godot 4.7 headless）

`COMBAT REVIEW FAILED: 3`，沒有 SCRIPT ERROR。strike（命中、冷卻、射程、歸零、打已倒下的目標）、restore，以及 D1 的對照組（斜向接近時能滑過石頭）都通過。三個紅燈都符合預期：
- D1：正面走向石頭後方的目標，10 秒後停在 `(-1, 0, 0)`，也就是接觸點。
- D2：連續走 30 幀，walk 的 ticks 仍然是 1.0，代表動畫每幀被重設。
- bob：停下 30 幀後，`visual.position.y` 仍是 0.055。
