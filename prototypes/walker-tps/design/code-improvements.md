# walker-tps 程式改善：實作方式

日期：2026-11-11。對應 [TODO.md](../TODO.md)「程式碼檢視」的 A1–A9、G1–G5、C1–C7。

來源是靜態閱讀 `scripts/` 的全部腳本與場景檔，沒有實作，也沒有跑測試。下面的程式片段是草稿，沒有執行過；行號是 2026-11-11 的版本。

## 先知道的事

- **碰撞圖層**：地形在第 1 層（值 1），玩家 `Walker` 在第 2 層（值 2），`Scout` 在第 3 層（值 4）。程式裡的遮罩 `7` 就是三層全打。
- **模型正面是 +Z**：`global_basis.z` 是機體前方。
- **既有測試會讀內部狀態**：`test_grapple_inertia.gd`、`test_combat.gd`、`tools/capture_dash_blades.gd` 直接比對 `combat.hook_state` 的字串（`"pulling"`、`"coasting"`、`"braking"`、`"cooldown"`），`test_combat.gd:170` 直接寫 `enemy.fire_wait=0`。改這些欄位時要同步改測試。
- **測試層級**：改 scout 或戰鬥屬 L2，跑 `test_combat.gd`＋`test_battlefield.gd`；改步態跑 `test_walker.gd`（要先修 `main.tscn` 的 Arena 移位，見 TODO「先處理」）。指令在 README。
- **場景修改**：新增 node 用 Godot 存檔（編輯器，或 `tools/` 裡用 SceneBuilder 的製作腳本），存完做 headless 匯入檢查。

## 建議的實作順序

```
第 1 批（一次改完 scout.gd，L2）
  A6 enum 狀態機 ─→ A1 預判 ─→ A3 受擊警覺 ─→ A2 開火後換位
  順手：C5 結算停在半空、A9 雜項

第 2 批（步態，跑 test_walker）
  G1 探地遮罩 ─→ G2 機身傾斜 ─→ G5 衝刺姿勢

第 3 批（多台敵人才有感）
  A7 感知 ─→ A4 協同 ─→ A5 搜索 ─→ A8 輕重型差異

第 4 批（結構，行為不變）
  C4 圖層常數 ─→ C3 節點查找 ─→ C2 傷害介面 ─→ C1 拆勾索
  G3、G4 視畫面問題再做
```

第 1 批先做 A6，因為 A1–A5 都要往狀態機裡加東西；現在的寫法是每幀從頭推導狀態，沒有地方放「剛開完火」「剛被打」這種記憶。

---

## 敵人 AI（`scripts/scout.gd`）

### A6 狀態機：enum＋進出條件分開

**現況**：`combat_step`（129–199 行）每幀從 `sees_player()` 重新算出 `state` 字串。距離在 `attack_range`（38 m）附近時，chase 與 aim 每幀互換，`charge` 被 181–182 行清成 0，永遠蓄不滿。

**做法**：

1. 狀態改 enum，保留一個給 HUD 顯示的名稱表。

   ```gdscript
   enum State { PATROL, CHASE, AIM, REPOSITION, SEARCH, REELED, DEAD }
   var state: State = State.PATROL
   var _state_time := 0.0   # 進入目前狀態後經過的秒數

   func _enter(next: State) -> void:
       if next == state: return
       state = next
       _state_time = 0.0
       if next != State.AIM: charge = 0.0
   ```

2. `combat_step` 拆成三段：先更新感知（`_sense`，見 A7），再依目前狀態決定要不要轉移，最後依狀態執行移動或瞄準。

   ```gdscript
   func _transition() -> void:
       var d := global_position.distance_to(player.global_position)
       match state:
           State.PATROL, State.SEARCH:
               if _sees: _enter(State.CHASE)
               elif state == State.SEARCH and _search_left <= 0.0: _enter(State.PATROL)
           State.CHASE:
               if not _sees: _enter(State.SEARCH)
               elif d < attack_range: _enter(State.AIM)
           State.AIM:
               if not _sees: _enter(State.SEARCH)
               elif d > attack_range + aim_exit_margin: _enter(State.CHASE)
           State.REPOSITION:
               if _state_time > reposition_time or agent.is_navigation_finished():
                   _enter(State.AIM if _sees else State.SEARCH)
   ```

3. 新增 `@export var aim_exit_margin: float = 6.0`：進入瞄準是 38 m，離開要超過 44 m。
4. `REELED` 與 `DEAD` 沿用現在 135–144 行的提前 return，改成設定 enum。
5. `$Status.text`（199 行）的 `state.to_upper()` 改成 `State.keys()[state]`。

**驗證**：在 `test_combat.gd` 加一段：把 scout 放在距玩家 38 m ± 0.5 m 來回移動 2 秒，斷言 `charge` 能累積到開火（現在的程式會失敗）。原有的「追擊／視線遮擋／實際射擊傷害」斷言照跑。

### A1 射擊預判

**現況**：`shoot()` 210 行把方向設成「玩家當下位置 − 槍口」。彈速 36 m/s，在 38 m 外要飛約 1 秒；玩家走路 4 m/s 橫移就偏 4 m，機體碰撞半徑只有 1.1 m。

**做法**：解攔截時間。令 `D = 玩家位置 − 槍口`、`V = 玩家速度`、`s = 彈速`，求最小的正數 `t` 使 `|D + V·t| = s·t`：

```gdscript
## 回傳瞄準點；解不出來（目標比子彈快）就回傳目標現在的位置。
static func intercept_point(shooter: Vector3, target: Vector3, target_velocity: Vector3, shot_speed: float) -> Vector3:
    var d := target - shooter
    var a := target_velocity.length_squared() - shot_speed * shot_speed
    var b := 2.0 * d.dot(target_velocity)
    var c := d.length_squared()
    var t := -1.0
    if absf(a) < 0.0001:
        if absf(b) > 0.0001: t = -c / b
    else:
        var disc := b * b - 4.0 * a * c
        if disc >= 0.0:
            var root := sqrt(disc)
            var t1 := (-b - root) / (2.0 * a)
            var t2 := (-b + root) / (2.0 * a)
            t = minf(t1, t2) if minf(t1, t2) > 0.0 else maxf(t1, t2)
    return target + target_velocity * t if t > 0.0 else target
```

在 `shoot()` 裡：

```gdscript
var aim := intercept_point(bullet.global_position, player.global_position + Vector3.UP * 1.1, player.velocity, bullet.speed)
var lead := aim - (player.global_position + Vector3.UP * 1.1)
aim = player.global_position + Vector3.UP * 1.1 + lead * lead_accuracy   # 0 = 不預判，1 = 完美
aim += Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.4, 0.4), _rng.randf_range(-1, 1)) * aim_spread
bullet.direction = (aim - bullet.global_position).normalized()
```

- 新增 `@export var lead_accuracy: float = 0.7`、`@export var aim_spread: float = 0.6`（公尺）。這兩個就是難度旋鈕。
- 跳躍中的玩家 `velocity.y` 很大，預判會打到拋物線外。把 `player.velocity` 的 y 乘 0.3 再代入。
- 勾索衝刺 18 m/s 時 `lead_accuracy` 0.7 仍會落後，這是刻意的：衝刺是閃避手段。
- `intercept_point` 是純函式，之後可以搬進 godot-kit（見 kit 的 `docs/CODE-IMPROVEMENTS.md` K4）。

**驗證**：L1 先對 `intercept_point` 寫三個斷言：目標靜止回傳原位置；目標以 4 m/s 橫移、彈速 36、距離 36 m 時 `t` 約 1.006 秒；目標比子彈快且遠離時回傳原位置。L2 在 `test_combat.gd` 讓玩家固定 4 m/s 橫移 10 秒，斷言 `lead_accuracy=1`、`aim_spread=0` 時至少命中一次；`lead_accuracy=0` 時命中 0 次。

### A3 受擊警覺

**現況**：`apply_damage(amount)`（96 行）只扣血。視野外或背後開火，scout 繼續巡邏。

**做法**（配合 C2 的新簽名）：

```gdscript
func apply_damage(amount: float, hit_position: Vector3 = Vector3.ZERO, from_direction: Vector3 = Vector3.ZERO) -> void:
    ...
    if not dead and state in [State.PATROL, State.SEARCH]:
        # 不知道確切位置：朝子彈來的方向回推一段距離當作搜索點
        last_seen = global_position - from_direction * 25.0 if from_direction != Vector3.ZERO else player.global_position
        _search_left = search_time
        _enter(State.SEARCH)
```

近戰刀片的呼叫端傳 `from_direction = (敵人 − 玩家).normalized()`。

**驗證**：`test_combat.gd`：玩家在 scout 正後方 30 m、有視線，開一砲；斷言 scout 進入 `SEARCH` 並在 2 秒內轉向超過 90°。

### A2 開火後換位

**現況**：`aim` 狀態（171–180 行）只轉身。scout 一進入射程就站定，直到被打死。

**做法**：

1. `shoot()` 成功後呼叫 `_begin_reposition()`，不再只設 `fire_wait`。
2. 換位點先用最簡單的版本：垂直於「我→玩家」方向側移。

   ```gdscript
   func _begin_reposition() -> void:
       var to_player := (player.global_position - global_position).normalized()
       var side := to_player.cross(Vector3.UP) * (1.0 if _rng.randf() < 0.5 else -1.0)
       var want := global_position + side * _rng.randf_range(6.0, 10.0)
       agent.target_position = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, want)
       _enter(State.REPOSITION)
   ```

3. `REPOSITION` 的移動沿用現在 183–192 行的尋路段落，速度用 chase 的 2.7 m/s。新增 `@export var reposition_time: float = 2.5` 當上限。
4. 第二階段（第一版好玩再做）：改成找掩體。在自己周圍半徑 10 m 取 8 個點，貼到導航網格後，各打一條射線到玩家；選「被擋住」且離自己最近的點。到點後等 `fire_wait` 歸零再走回能看到玩家的位置。

**驗證**：`test_combat.gd`：scout 開火後 3 秒內水平位移超過 4 m；換位期間不開火。

### A7 感知：視角錐、多點、降頻

**現況**：`sees_player()`（121–127 行）360° 視野，只打一條射線到玩家腳底上方 1.3 m；`combat_step` 每幀呼叫一次，`shoot()` 再呼叫一次。

**做法**：

```gdscript
@export var view_half_angle_deg: float = 70.0
@export var close_sense_range: float = 12.0   # 這個距離內不管朝向都會察覺
var _sees := false
var _sense_wait := 0.0

func _sense(delta: float) -> void:
    _sense_wait -= delta
    if _sense_wait > 0.0: return
    _sense_wait = 0.15
    _sees = _check_sight()

func _check_sight() -> bool:
    if not is_instance_valid(player) or not player.controls_enabled: return false
    var eye := global_position + Vector3.UP * 1.6
    var to := player.global_position - global_position
    var dist := to.length()
    if dist > sight_range: return false
    # 已經在交戰就不再檢查視角，否則玩家繞到背後會立刻丟失目標
    if state in [State.PATROL, State.SEARCH] and dist > close_sense_range:
        if global_basis.z.dot(to.normalized()) < cos(deg_to_rad(view_half_angle_deg)): return false
    for height: float in [1.3, 2.6]:   # 機身中心與頂部：半掩體後露出砲塔也算看到
        var hit := get_world_3d().direct_space_state.intersect_ray(
            PhysicsRayQueryParameters3D.create(eye, player.global_position + Vector3.UP * height, 7, [get_rid()]))
        if not hit.is_empty() and hit.collider == player: return true
    return false
```

- `_ready` 裡用 `_sense_wait = _rng.randf() * 0.15` 讓各台錯開。
- `shoot()` 開頭仍直接呼叫 `_check_sight()`（不走快取），維持「隔牆不開火」。
- 3 台時效能沒有差別；這項的價值在視角錐讓「繞背」成立。

**驗證**：`test_combat.gd`：玩家站在巡邏中 scout 正後方 30 m，2 秒內 `_sees` 為 false；走到 10 m 內變 true。既有的牆擋視線斷言照跑。

### A4 協同：共用目擊資訊＋站位分配

**現況**：三台各自 `agent.target_position = player.global_position`，會走到同一點互相推擠；`NavigationAgent` 沒開 avoidance；一台看到玩家，另兩台不知道。

**做法**：

1. **共用目擊**放在 `battlefield.gd`（它已經是 `battle_session` group）：

   ```gdscript
   var contact_position := Vector3.ZERO
   var contact_time := -100.0   # match 開始後的秒數

   func report_contact(at: Vector3) -> void:
       contact_position = at
       contact_time = match_seconds - time_left
   ```

   scout 在 `_sees` 為 true 時呼叫 `report_contact`；在 `PATROL` 狀態且 `contact_time` 是最近 3 秒內、距離 80 m 內，就把 `last_seen` 設成它並進入 `SEARCH`。

2. **站位**：交戰中的 scout 不走向玩家本身，而是走向玩家周圍的一個點。

   ```gdscript
   ## battlefield.gd：回傳第 index 台（共 count 台）該站的位置
   func slot_for(scout: Node3D, index: int, count: int, radius: float) -> Vector3:
       var base := (scout.global_position - walker.global_position)
       base.y = 0.0
       var angle := atan2(base.x, base.z) + deg_to_rad(50.0) * (index - (count - 1) * 0.5)
       var want := walker.global_position + Vector3(sin(angle), 0.0, cos(angle)) * radius
       return NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, want)
   ```

   `index` 用「還活著且在 CHASE／AIM／REPOSITION 的 scout」依 `get_index()` 排序後的名次，每 0.45 秒（現有的 `path_wait`）重算一次。三台會展開成約 100° 的弧，玩家無法用一面牆同時擋住全部。

3. **避讓**：在 `scout.tscn` 的 `NavigationAgent` 開 `avoidance_enabled`，`radius` 設 1.4（碰撞膠囊是 0.9）。程式改成把想要的速度交給 agent，在 `velocity_computed` 訊號裡才 `move_and_slide`：

   ```gdscript
   func _ready() -> void:
       agent.velocity_computed.connect(_on_safe_velocity)

   # combat_step 末段：不直接設 velocity
   agent.velocity = Vector3(flat.x, 0.0, flat.z)

   func _on_safe_velocity(safe: Vector3) -> void:
       velocity = Vector3(safe.x, velocity.y - _gravity * get_physics_process_delta_time(), safe.z)
       move_and_slide()
   ```

   `REELED` 被拉時不經過 agent，照舊直接 `move_and_slide`。這段改動會影響所有移動，改完先跑既有的 `test_combat.gd` 確認追擊仍然成立。

**驗證**：`test_combat.gd`：三台都進入交戰後 6 秒，任兩台水平距離大於 5 m；玩家只被 Scout0 看到時，Scout1 在 3 秒內離開 `PATROL`。

### A5 搜索

**現況**：160–165 行，看不到玩家時 `memory`（4 秒）立刻開始扣，移動速度是 `speed`（1.6 m/s）。4 秒只走 6.4 m，通常還沒到最後目擊點就回去巡邏。

**做法**：

- `SEARCH` 分兩段：`_search_arrived == false` 時用 2.7 m/s 走向 `last_seen`，不計時；抵達（距離 < 2.5 m 或 `is_navigation_finished()`）後才開始扣 `_search_left`（新增 `@export var search_time: float = 5.0`）。
- 抵達後每 1.5 秒把 `rotation.y` 的目標設成一個新角度（原地左右看），配合 A7 的視角錐才看得出效果。
- 走向 `last_seen` 的路上加 12 秒上限，避免到不了的點卡住。

**驗證**：`test_combat.gd` 既有的「失去視線後搜索最後位置」斷言加強為：玩家躲到牆後，scout 抵達最後目擊點 2.5 m 內才回到 `PATROL`。

### A8 輕重型差異

**現況**：`battlefield.tscn` 的兩輕一重只在 `max_health` 與 `mass` 不同。

**做法**：把下列數值做成 `@export`，在 `battlefield.tscn` 的三個實例上覆寫。不新增腳本或子類別。

| 欄位 | 輕型建議 | 重型建議 | 現在的寫死位置 |
|---|---|---|---|
| `chase_speed` | 3.2 | 2.0 | 191 行的 `2.7` |
| `attack_range` | 30 | 45 | 已是 export |
| `lead_accuracy` | 0.5 | 0.85 | A1 新增 |
| `shot_damage` | 8 | 18 | 211 行 |
| `shot_speed` | 36 | 50 | 212 行 |
| `burst_count`／`burst_gap` | 3／0.12 秒 | 1 | 新增 |
| `windup_time` | 0.5 | 1.0 | 177 行的 `0.8` |
| `fire_cooldown` | 2.0 | 3.0 | 179 行的 `2.5` |
| `repositions` | true | false | A2 新增 |

輕型是「近距離、連發、打完就跑」，重型是「遠距離、單發重擊、不動」。玩家對輕型要靠掩體，對重型要靠橫移或繞背。

### A9 雜項

- **巡邏點**：`_pick_target()`（92–94 行）算完後用 `NavigationServer3D.map_get_closest_point` 貼到導航網格；`combat_enabled` 為 false 的遊蕩模式沒有導航圖時保持原樣。
- **死亡**：`apply_damage` 的死亡分支加 `set_physics_process(false)`，並在那之前把 `$Status`、`$Warning`、`$HitFlash` 設成不可見（現在靠每幀執行 `combat_step` 的前幾行去關）。
- **遊蕩模式**：`_physics_process` 61–90 行是 `main.tscn` 展示用的舊行為。搬到 `scripts/scout_wander.gd` 並讓 `main.tscn` 的 12 台改掛它，或確認不再需要後刪除；`scout.gd` 只留戰鬥。

---

## 步態與 IK（`scripts/walker_gait.gd`）

### G1 探地射線只打地形

**現況**：`_ground()`（239–243 行）的查詢沒設遮罩，會打到所有圖層；只排除自己。腳的落點可能落在活著的 scout 膠囊頂端。

**做法**：

```gdscript
const GROUND_MASK := 1
...
var query := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p + Vector3.DOWN * 3.0, GROUND_MASK)
```

同時讓 `_ground` 回傳法線，給 G2 用：把回傳型別改成 `Dictionary`（`position`、`normal`），或另加一個 `_ground_normal(p)`。選後者改動最少。

**驗證**：`test_walker.gd` 加一段：在 walker 前方 2 m 放一台 scout，往前走 3 秒，斷言所有 `leg.plant.y` 與地面高度差小於 0.05 m。

### G2 機身與腳掌跟著地形

**現況**：Hull 只有上下位移（136 行），腳掌固定與機身平行（140 行）。地形有起伏時，機身水平地「浮」過去，腳掌角度與地面不合。

**做法**：

1. 腳的索引順序是 `LEG_NAMES = ["FL","BR","FR","BL"]`。用四個接地點（`contact(leg)`）算出前後與左右兩個向量，叉積得到地面法線：

   ```gdscript
   func _ground_plane_normal() -> Vector3:
       var fl := contact(legs[0]); var br := contact(legs[1])
       var fr := contact(legs[2]); var bl := contact(legs[3])
       var fore := (fl + fr) * 0.5 - (bl + br) * 0.5
       var side := (fr + br) * 0.5 - (fl + bl) * 0.5
       var n := fore.cross(side).normalized()
       return n if n.y > 0.0 else -n
   ```

2. 轉到模型的局部空間後取俯仰與側傾，限制角度並平滑：

   ```gdscript
   @export var tilt_max_deg: float = 12.0
   @export var tilt_rate: float = 6.0
   var _tilt := Vector2.ZERO   # x = 俯仰, y = 側傾（弧度）

   var n := _model.global_basis.inverse() * _ground_plane_normal()
   var limit := deg_to_rad(tilt_max_deg)
   var want := Vector2(clampf(atan2(n.z, n.y), -limit, limit), clampf(-atan2(n.x, n.y), -limit, limit))
   _tilt = _tilt.lerp(want, 1.0 - exp(-tilt_rate * delta))
   _hull.rotation.x = _tilt.x
   _hull.rotation.z = _tilt.y
   ```

   正負號要在編輯器裡對著坡道確認一次（上坡時車頭應該抬起）。空中（`airborne`）時把 `want` 設成零。

3. 這段要放在 136 行設定 `_hull.position` 之後、138 行的 IK 迴圈之前。IK 用的是 `_hull.global_transform.affine_inverse()`，Hull 傾斜後髖部位置會自動跟著變，不用改 `_solve`。

4. 腳掌：140 行改成依落點法線傾斜，同樣限制角度。

   ```gdscript
   var up := _ground_normal(leg.plant) if leg.t < 0.0 else _model.global_basis.y
   up = _model.global_basis.y.slerp(up, 0.8)
   var fwd := _model.global_basis.z
   var right := up.cross(fwd).normalized()
   leg.foot.global_basis = Basis(right, up, right.cross(up))
   ```

   `SOLE` 補償（139 行的 `_model.global_basis.y * SOLE`）在坡度 12° 內誤差約 2%，先不改。

5. 砲塔是 Hull 的子節點，`walker_combat.gd` 的 `update_aim` 用 `to_local` 計算，Hull 傾斜後仍然正確。

**驗證**：`test_walker.gd` 的坡道段加斷言：在坡道上穩定行走時 `_hull.rotation.x` 的絕對值大於 3°；平地上小於 1°；既有的「著地腳誤差小於 1 mm」仍成立（腳掌傾斜不該移動接地點）。再用 `tools/capture.gd` 截坡道畫面目視。

### G5 勾索衝刺時的腿

**現況**：衝刺到 18 m/s 時機體仍在地面，`_walk` 照常執行；`current_step_time()` 在 6.5 m/s 就到下限 0.17 秒，腳一步最多跨約 1.1 m，跟不上每 0.17 秒 3 m 的位移，169 行的安全抬腳每幀觸發。

**做法**：加一個「滑行」姿勢，重用空中姿勢的機制。

```gdscript
var skid := false   # walker_player 每幀設定：combat.has_dash_momentum()

# _physics_process 裡，取代 `if airborne:` 的判斷
if airborne or skid:
    _air_pose(delta, skid)
else:
    lifted = _walk(delta, vel)
```

- `_air_pose` 多一個參數：滑行時目標改成 `Vector3(home_local.x * 1.1, home_local.y + 0.05, home_local.z * 1.2)`（四腳外張、略離地），不用 `tuck`。
- `skid` 由 true 變 false 的那一幀呼叫 `replant()`，並把 `_sink` 設成 0.2 做一個剎車下沉。
- 進入滑行時要像 `_take_off()` 一樣先把 `air_local` 設成目前的接地點，否則腳會瞬移。
- `walker_player.gd` 在 `combat.step(delta)` 之後加一行 `gait.skid = combat != null and combat.has_dash_momentum()`。

**驗證**：`test_grapple_inertia.gd` 加斷言：衝刺期間 `gait.stepped` 訊號觸發次數為 0；剎車結束後 0.5 秒內四腳 `t < 0`（都已落地）。

### G3 膝蓋朝向約束

**現況**：`_solve`（230 行）用 `Quaternion(reach_dir, to.normalized())`，是兩個方向之間的最短旋轉，繞「髖→踝」軸的扭轉角度沒有約束。目標點經過髖部正下方、或急速橫移時，膝蓋可能朝內或翻面。

**先確認有沒有這個問題**：用 `tools/capture.gd` 拍急停、原地轉身、橫移衝刺三種情況。畫面看不出膝蓋亂轉就不做。

**做法**：在最短旋轉之後補一個繞目標方向的扭轉，讓旋轉後的鉸鏈軸盡量貼近靜止時的鉸鏈軸。

```gdscript
var dir := to.normalized()
var q := Quaternion(reach_dir, dir)
var hinge_now := (q * leg.hinge).slide(dir)
var hinge_want := leg.hinge.slide(dir)
if hinge_now.length() > 0.01 and hinge_want.length() > 0.01:
    q = Quaternion(dir, hinge_now.normalized().signed_angle_to(hinge_want.normalized(), dir)) * q
leg.thigh.quaternion = q
```

### G4 膝角改閉式解

**現況**：222–227 行用 4 次牛頓法加數值微分求膝角。腿接近伸直時 `df` 趨近 0，靠 225 行的中斷與 ±1.4 的 clamp 擋住。

**做法**：把 `knee_rel`（記為 k）與 `ankle_rel`（記為 a）各拆成平行與垂直於鉸鏈軸的分量。繞鉸鏈轉 φ 之後，髖到踝的距離平方是：

```
d² = |k|² + |a|² + 2·(k∥·a∥) + 2·|k⊥|·|a⊥|·cos(φ + φ0)
```

其中 φ0 是 k⊥ 到 a⊥ 繞鉸鏈軸的有號角度。所以：

```gdscript
# setup() 裡每條腿算一次
leg.c0 = leg.knee_rel.length_squared() + leg.ankle_rel.length_squared() \
    + 2.0 * leg.knee_rel.project(leg.hinge).dot(leg.ankle_rel.project(leg.hinge))
var kp := leg.knee_rel.slide(leg.hinge)
var ap := leg.ankle_rel.slide(leg.hinge)
leg.c1 = 2.0 * kp.length() * ap.length()
leg.phi0 = kp.signed_angle_to(ap, leg.hinge)
leg.bend_sign = 1.0   # 用靜止姿勢代回去確認是 +1 還是 -1

# _solve() 裡
var phi := clampf(leg.bend_sign * acos(clampf((d * d - leg.c0) / leg.c1, -1.0, 1.0)) - leg.phi0, -1.4, 1.4)
```

`setup()` 時把靜止姿勢（φ = 0）代回 `_span` 驗算，兩者差超過 1 mm 就 `push_error`。優先度低：現在的牛頓法在測試裡是收斂的，換掉只是省每幀 32 次向量旋轉並去掉不穩定點。

---

## 戰鬥與架構

### C5 結算時停在半空（bug）

**現況**：`walker_player.gd` 62–64 行，`controls_enabled` 為 false 時把 `velocity` 清成零就 return，不跑重力也不 `move_and_slide`。跳躍中擊毀最後一台，機體會懸在空中；步態也停在空中姿勢。

**做法**：

```gdscript
if not controls_enabled:
    velocity = Vector3(0.0, velocity.y - _gravity * delta, 0.0)
    move_and_slide()
    return
```

**驗證**：`test_combat.gd`：玩家跳到最高點時呼叫 `battlefield.finish("victory")`，1.5 秒後斷言 `is_on_floor()`。

### C4 碰撞圖層命名

**做法**：`project.godot` 的 `[layer_names]` 設 `3d_physics/layer_1="terrain"`、`layer_2="player"`、`layer_3="enemy"`。新增一個只放常數的 `scripts/layers.gd`：

```gdscript
const TERRAIN := 1
const PLAYER := 2
const ENEMY := 4
const SOLID := TERRAIN | PLAYER | ENEMY
```

把四處的 `7`（`scout.gd:126`、`walker_combat.gd:74`、`combat_projectile.gd:16`，以及 A7 新增的射線）換成 `Layers.SOLID`，G1 用 `Layers.TERRAIN`。

### C3 節點查找集中

**現況與做法**：

| 現在的寫法 | 出現位置 | 改成 |
|---|---|---|
| `get_tree().get_first_node_in_group("battle_session")` 再 `get_node("Projectiles")` | `scout.gd` 110、152、204 行；`walker_combat.gd` 131–133 行 | `battlefield.gd` 加 `func spawn(node: Node3D, at: Vector3)`；沒有 session 時的後備邏輯只留在一個靜態函式裡 |
| `body.get_parent().get_node_or_null("Enemies")` | `auto_blades.gd` 24 行 | `scout.tscn` 根節點加 group `enemies`，改用 `get_tree().get_nodes_in_group("enemies")` |
| `walker.get_node("Combat/MuzzleFlash")`、`get_node("Gait")`、`get_node("CameraRig")` | `battlefield.gd` 41、64–68 行 | `walker_player.gd` 加 `func halt()`（結算用）與 `func teleport(to: Vector3)`（越界用），battlefield 只呼叫這兩個 |
| `find_child("Turret")`、`"Cannon"`、`"Muzzle"` | `walker_combat.gd` 38–40 行 | 模型是匯入的 GLB 子場景，不能用 `%`；保留 `find_child`，但在 `_ready` 加 `assert(turret and cannon and muzzle)`，改名時立刻報錯 |
| `get_node("Launch%d" % side)`、`Cable%d`、`Pin%d` | `walker_combat.gd` 6 處 | `_ready` 時存成三個長度 2 的陣列 |

### C2 傷害介面帶命中資訊

**做法**：所有 `apply_damage` 改成同一個簽名，後兩個參數有預設值，舊呼叫不會壞：

```gdscript
func apply_damage(amount: float, hit_position: Vector3 = Vector3.ZERO, from_direction: Vector3 = Vector3.ZERO) -> void
```

- `combat_projectile.gd` 21 行：`body.apply_damage(damage, hit.position, direction)`。
- `auto_blades.gd` 53 行：`enemy.apply_damage(damage, enemy.global_position + Vector3.UP, (enemy.global_position - body.global_position).normalized())`。
- `walker_player.gd` 與 `walker_combat.gd` 的轉發照傳。

有了命中方向，最便宜的弱點規則是背面加成，不需要新的碰撞形狀：

```gdscript
# scout.gd apply_damage 開頭
if from_direction != Vector3.ZERO and from_direction.dot(global_basis.z) > 0.5:   # 子彈方向與機體朝向同向 = 從背後打
    amount *= rear_multiplier   # @export，建議 2.0
```

這讓勾索繞背與 A7 的視角錐一起形成一個完整的打法。玩家受擊方向也可以用來在 HUD 顯示來襲方位。

### C1 勾索拆成獨立 node

**現況**：`walker_combat.gd` 287 行裡，144–287 行（一半）是勾索。狀態是字串，`["flying","pulling","coasting","braking"]` 在 94、145、167 行各出現一次。

**做法**（純搬移，行為不變）：

1. 新增 `scripts/grapple.gd` 與 `scenes/grapple.tscn`：把 `Launch0/1`、`Cable0/1`、`Pin0/1` 六個 node 從 `walker_combat.tscn` 移過去，做成 `Combat` 的子場景，和 `AutoBlades` 並列。用 SceneBuilder 的製作腳本搬，保留 node 的 transform 與材質。
2. 搬過去的函式：`launch_hooks`、`cancel_hook`、`clear_cables`、`has_dash_momentum`、`begin_coasting`、`begin_braking`、`update_inertia`、`update_hooks`，以及相關的 export 與變數。`walker_combat.step()` 只留一行 `grapple.step(delta, aim_point)`。
3. 狀態改 enum，並提供一個判斷取代重複的清單：

   ```gdscript
   enum Hook { READY, FLYING, PULLING, COASTING, BRAKING, COOLDOWN }
   var hook: Hook = Hook.READY
   func is_active() -> bool: return hook in [Hook.FLYING, Hook.PULLING, Hook.COASTING, Hook.BRAKING]
   ```

4. **測試相容**：`test_grapple_inertia.gd`、`test_combat.gd`、`capture_dash_blades.gd` 讀 `combat.hook_state` 字串。在 `walker_combat.gd` 留一個唯讀屬性轉接，測試不用改：

   ```gdscript
   var hook_state: String:
       get: return Grapple.Hook.keys()[grapple.hook].to_lower()
   ```

   `test_grapple_inertia.gd:87` 有一行直接寫入 `combat.hook_state="ready"`，要改成呼叫 `grapple.cancel_hook()` 或直接設 enum。
5. `combat_hud.gd` 讀的 `hook_message`、`cooldown_left` 同樣用屬性轉接，或改成讀 `combat.grapple`。
6. 血量留在 `walker_combat.gd`：它只有十行，拆出去沒有好處。

**驗證**：搬移前後各跑一次 `test_grapple_inertia.gd`、`test_auto_blades.gd`、`test_combat.gd`，數字（越位距離 8.85 m、峰值 18 m/s）應該完全相同。

### C6 開火輸入

**現況**：`walker_combat.gd` 90–92 行。

```gdscript
if Input.is_action_pressed("fire") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or Input.is_action_pressed("fire") and DisplayServer.is_touchscreen_available():
    try_fire()
if Input.get_joy_axis(0,JOY_AXIS_TRIGGER_RIGHT)>0.6: try_fire()
```

- 觸控螢幕筆電上 `is_touchscreen_available()` 為 true，滑鼠沒鎖定時點任何地方（包括 DEPLOY 按鈕）都會開火。
- 手把扳機已經在 50–54 行綁進 `fire` action，92 行又直接讀 0 號手把的軸，等於兩條路。

**做法**：由輸入來源決定，而不是由裝置能力決定。FIRE 觸控鍵的狀態在 `combat_hud.gd`：36–47 行用 `fire_finger` 記住按著 FIRE 的手指編號（−1 表示沒按），失焦時清掉。讓 `walker_combat.gd` 直接問它：

```gdscript
# combat_hud.gd
func fire_held() -> bool: return fire_finger >= 0

# walker_combat.gd step()
var from_touch: bool = _hud != null and _hud.fire_held()
var from_pointer := Input.is_action_pressed("fire") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
var from_pad := Input.get_action_strength("fire") > 0.6 and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
if from_touch or from_pointer or from_pad: try_fire()
```

`_hud` 在 `_ready` 用 group 取得（給 `combat_hud.tscn` 根節點加 group `combat_hud`），沒有 HUD 的測試場景為 null。刪掉 92 行。動手前先讀 `combat_hud.gd` 36–47 行，確認 FIRE 鍵按下時是否也送出 `fire` action：如果有，`from_pointer` 那一行在觸控時不會成立（滑鼠沒鎖定），所以仍需要 `from_touch`；如果沒有，現在觸控開火靠的就是 `is_touchscreen_available()` 那個條件。

### C7 索釘索引

**現況**：`walker_combat.gd` 260 行 `pins.find(pin)`。`Array.find` 對 Dictionary 是比內容；兩支索釘的內容完全相同時（例如兩支都在發射瞬間被同一點擋住）都會回傳 0，第二支會用到第一支的發射點。

**做法**：把 259–264 行的迴圈改成用索引走 `pins`，只處理 `anchored` 的：

```gdscript
for side: int in pins.size():
    if not pins[side].anchored: continue
    var obstruction := ray(_launch[side].global_position, pins[side].position)
    ...
```
