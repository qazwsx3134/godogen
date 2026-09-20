extends Node2D
class_name Playfield

## 盤面物理。它只負責一件事：**始動口入賞率**——同樣的球數能買到幾次抽選。
##
## 抽選在球落入始動口的瞬間就定案（ADR 0002），所以球往哪彈不影響結果。滾輪與捷徑通道
## 也不例外：它們讓球**更容易到達始動口**，改變的是同樣的球數買到幾次抽選，不是同一次
## 抽選更容易中。這個區別是整台機器的地基——通道「中獎機率比較大」講的是前者。
##
## 拓樸（真機）：發射控制在機台右下角，但球是從**盤面左下角**進打出軌道的。軌道沿左緣
## 爬上去，在左上角把球甩進釘子場。力道決定球從那裡往右飛多遠：
##   力道小 → 落在中央偏左的釘子場 → 風車 → 誘導釘 → 始動口        （左打）
##   力道大 → 飛過釘子場落到右側路線 → 電チュー與大入賞口              （右打）
## 所以「左打／右打」字面成立，而 slider 的方向和名字同向：拉越大，球越右。

signal start_pocket_hit
signal big_pocket_hit
signal warped                       # 球進了捷徑通道（給演出用的小回饋）

const BALL_RADIUS := 10.0
const NAIL_RADIUS := 5.0
## 釘子排距。縫寬 = pitch − 2×NAIL_RADIUS 要明顯大於球徑，球才穿得過去而不是被篩住。
const NAIL_PITCH := 58.0

## 打出軌道是**導引通道，不是自由落體的舞台**：球在裡面沿著軌道被帶上去，出口才交還
## 給物理。理由是可校準性——若讓球靠初速自己爬，出口速度是 `sqrt(v0² − 2gh)`，
## 兩項都是 3×10⁶ 等級而有用的餘量只有幾百，是典型的災難性抵消：力道掃描量出來會是
## 非單調的退化值（而那正是第一版的症狀），而且「力道 ±10% 內都接近 12 発/轉」這個
## 寬容度在數學上做不到。直接給出口速度就落在想要的範圍裡，也讓力道→落點是線性的。
##
## 出口速度 0→1 對應的力道。低力道＝出口慢＝落在中央偏左的釘子場（左打）；
## 高力道＝飛過釘子場落到右側路線（右打）。方向同向：拉越大，球越右。
const EXIT_SPEED := Vector2(120.0, 780.0)
## 球在軌道裡爬升的速度。純粹是觀感——它和瞄準無關，只決定爬上去要多久。
const RAIL_TRANSIT := Vector2(1100.0, 1900.0)

## 左撇子設定：整個盤面鏡射。控制元件的位置由 game.gd 決定。
var mirrored := false
## 發射力道 0–1。取代了原本的左打／右打兩檔——slider 就是瞄準。
var power := 0.5

var big_pocket_open := false
var electric_gate_open := false                   # 電チュー：確變中才開

## 命釘的半間距。**校準到 12 発/轉的旋鈕**，而且是平滑的（實測曲線見 README）。
## 量級是球徑：2×19 = 38 px 的縫對上 20 px 的球。低於 16 是懸崖（14 量到 111 発/轉），
## 因為縫只剩 1.4 個球寬，球擠不進去。
var guide_mouth := 19.0
var guide_half_width := 300.0
## 電チュー的寬度。確變中右打的入賞率旋鈕，目標每 4 発一轉。
var gate_width := 110.0

## 釘調整（[ADR 0006](../docs/adr/0006-nails-are-reset-each-session.md)）。
## `-1` ＝**固定標準台，不抽**，而這是預設值：驗收必須可重複。
var nail_seed := -1
## 釘調整範圍 10–15.5 発/轉 的開口對應區間（由 README 的校準曲線反解）。
## 辛端 16.3 是推導值不是喜好：SP ≥ 3 次需要入賞率 ≤ 15.54 発/轉。
const NAIL_CENTER := 19.0
const NAIL_SIGMA := 1.0
const NAIL_CLAMP := Vector2(16.3, 20.7)

var _rect: Rect2
var _cx := 0.0
var _balls: Array[RigidBody2D] = []
var _nails: Array[Vector2] = []
var _segs: Array[PackedVector2Array] = []
var _start_pocket: Rect2
var _big_pocket: Rect2
var _gate: Rect2
var _warp_in: Rect2
var _warp_out := Vector2.ZERO
var _launch := Vector2.ZERO
var _launch_dir := Vector2.UP
var _rail_path: Array[Vector2] = []
var _rail_len := 0.0
var _railing: Array[Dictionary] = []
var _guide_top := 0.0
var _guide_bot := 0.0
var _windmill: AnimatableBody2D
var _windmill_pos := Vector2.ZERO
var _windmill_a := 0.0


func _init(rect: Rect2) -> void:
	_rect = rect
	_cx = rect.get_center().x


# --- 鏡射（左撇子設定）--------------------------------------------------
# 所有幾何都在「右撇子」空間算，建構與碰撞判定時才翻。

func _mx(x: float) -> float:
	return 2.0 * _cx - x if mirrored else x


func _mv(v: Vector2) -> Vector2:
	return Vector2(-v.x, v.y) if mirrored else v


func _mp(p: Vector2) -> Vector2:
	return Vector2(_mx(p.x), p.y)


func _mrect(r: Rect2) -> Rect2:
	if not mirrored:
		return r
	return Rect2(Vector2(_mx(r.end.x), r.position.y), r.size)


func _ready() -> void:
	_build()


func balls_in_flight() -> int:
	return _balls.size()


func debug_balls() -> Array[RigidBody2D]:
	return _balls


func debug_nail_count() -> int:
	return _nails.size()


func debug_start_pocket() -> Rect2:
	return _mrect(_start_pocket)


func debug_launch() -> Vector2:
	return _mp(_launch)


func debug_launch_dir() -> Vector2:
	return _mv(_launch_dir)


# --- 盤面配置 -----------------------------------------------------------

func _build() -> void:
	if nail_seed >= 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = nail_seed
		guide_mouth = clampf(NAIL_CENTER + rng.randfn(0.0, NAIL_SIGMA), NAIL_CLAMP.x, NAIL_CLAMP.y)

	var walls := StaticBody2D.new()
	walls.name = "Walls"
	add_child(walls)

	var inset := 24.0
	var left := _rect.position.x + inset
	var right := _rect.end.x - inset
	var bottom := _rect.end.y - 60.0
	# 右側路線的分界：這條線右邊不長釘子，右打的球才到得了電チュー與大入賞口
	var right_lane := right - 210.0

	_build_rail(walls, left, right, bottom)
	# 風車與誘導釘先放，釘子場才知道哪裡要讓開
	_build_windmill(bottom)
	_build_guide(walls, left, right_lane, bottom)
	_build_nails(walls, left, right_lane, bottom)
	_build_pockets(walls, left, right, right_lane, bottom)
	_build_outlanes(walls, left, right, bottom)


## 打出軌道：貼著左緣的一段直道，到**液晶上方**轉彎，出口水平朝右把球送進盤面。
##
## 兩件事決定了這個形狀。其一，第一版的定半徑大圓弧（r=330）把出口推到 x=480，
## 已經在液晶（x 262–818）裡面，而且球從液晶後面被甩出來。其二，出口必須**高過液晶
## 上緣**，球才有一段夠長的自由飛行把力道翻譯成落點——落差越大，同樣的速度差拉開的
## 水平距離越大，瞄準才有解析度。所以轉彎半徑收到 90，出口落在液晶左緣外側的
## (left+124, rect.y+70)，水平朝右。
##
## 軌道的牆只畫不擋：球在通道裡是被帶著走的（見 EXIT_SPEED），碰撞形狀留著只會讓
## 它在 46 px 寬的縫裡反覆擦撞掉能量。
func _build_rail(walls: StaticBody2D, left: float, right: float, bottom: float) -> void:
	var x_rail := left + 34.0
	var y_lo := bottom - 30.0
	var r := 90.0
	var y_exit := _rect.position.y + 70.0
	var arc_c := Vector2(x_rail + r, y_exit + r)

	var mid: Array[Vector2] = []
	for i in 7:
		mid.append(Vector2(x_rail, lerpf(y_lo, arc_c.y, float(i) / 6.0)))
	var steps := 10
	for i in range(1, steps + 1):
		var a := deg_to_rad(lerpf(180.0, 270.0, float(i) / steps))
		mid.append(arc_c + Vector2(cos(a), sin(a)) * r)

	_rail_path = mid
	_rail_len = 0.0
	for i in range(mid.size() - 1):
		_rail_len += mid[i].distance_to(mid[i + 1])

	# 由中線往兩側偏移生出通道的內外壁（只畫，不擋）
	var half := 23.0
	for i in range(mid.size() - 1):
		var d := (mid[i + 1] - mid[i]).normalized()
		var n := Vector2(-d.y, d.x)
		_seg(walls, mid[i] - n * half, mid[i + 1] - n * half, false)
		if i < mid.size() - 3:
			_seg(walls, mid[i] + n * half, mid[i + 1] + n * half, false)

	_launch = mid[0]
	_launch_dir = (mid[1] - mid[0]).normalized()

	_seg(walls, Vector2(right, _rect.position.y + 120.0), Vector2(right, bottom))


## 釘子場：交錯排列，從液晶下緣一路長到風車上方。
##
## 第一版只長出 3 排、而且離誘導釘還有 400 px 的空白落差，等於沒有散射——落點分布是
## 一根尖峰，入賞率就退化成「不是 1.00 就是 0」。釘子場的功用不是裝飾，它是把
## **落點變成一個寬分布**的東西，而「力道 ±10% 內都接近 12 発/轉」的寬容度完全來自
## 這個分布有多寬。所以排距要小到球會真的一路撞下來。
func _build_nails(walls: StaticBody2D, left: float, right_lane: float, bottom: float) -> void:
	var y0 := _rect.position.y + _rect.size.y * 0.42
	var y1 := _guide_top - 20.0
	var pitch := NAIL_PITCH
	var rows := maxi(int((y1 - y0) / pitch), 1)
	for r in rows + 1:
		var y: float = y0 + r * pitch
		var x: float = left + 26.0 + (pitch * 0.5 if r % 2 == 1 else 0.0)
		while x < right_lane - 16.0:
			if _nail_fits(Vector2(x, y)):
				_nail(walls, Vector2(x, y))
			x += pitch


## 釘子場是**滿的**，只在風車和誘導釘的位置讓開。
##
## 前兩版都在中央留通道：漸縮的漏斗會主動把球往中間趕（九成入賞，1.1 発/轉），
## 等寬的直通道則是一條沒有釘子的滑梯，結果一樣。真機的釘子場不替玩家把球送到
## 始動口——它只是把落點打散，始動口本來就是個小目標。
func _nail_fits(p: Vector2) -> bool:
	if p.distance_to(_windmill_pos) < 74.0:
		return false
	# 誘導釘 V 的內側要淨空，否則球在臂上滑的時候會被釘子彈回釘子場
	if p.y > _guide_top - 30.0 and absf(p.x - _cx) < guide_half_width + 20.0:
		return false
	return true


## 風車：一個持續轉動的撥片，把落到中央的球打向左或右。
## 打對邊才進得了中央通道，不然就被撥出去——那幾秒的轉向就是這一段的懸念。
func _build_windmill(bottom: float) -> void:
	# 風車擺在釘子場**裡面**，下面還留得下兩排釘子。擺在誘導釘正上方時它會把中央
	# 掃空——到達分布在始動口正上方出現一個洞，而在撥出去的那一側堆出 46% 的尖峰。
	_windmill_pos = Vector2(_cx, bottom - 400.0)
	_windmill = AnimatableBody2D.new()
	_windmill.sync_to_physics = true
	_windmill.position = _mp(_windmill_pos)
	for i in 2:
		var cs := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(84.0, 12.0)
		cs.shape = box
		cs.rotation = PI * 0.5 * i
		_windmill.add_child(cs)
	add_child(_windmill)


## 誘導釘：始動口正上方的一對**命釘**，加上上方兩道傾斜的寄り釘。
##
## `guide_mouth` 是命釘之間的半間距——真機店家調的就是這兩根釘，而這裡它也是唯一
## 校準到 12 発/轉的旋鈕。始動口的寬度跟著命釘走：釘縫就是入口。
##
## 三條死路走過了，留著免得再走一次。
## 1. **實心 V 牆**：兩臂接到的球會 100% 滑進開口，所以真正的旋鈕變成兩臂的寬度，
##    而那是懸崖（gw 70 給 0、100 給 1.10 発/轉）。牆太會導球了。
## 2. **V 牆＋固定杯**：慢速落球下曲線很漂亮（開口 76→11.4、108→20.0），接上軌道
##    之後球太快，全部從杯口上方滑過去，一路量到 0。
## 3. **V 形釘列**：開口每動一格就重新量化整排釘位，96→5.17、102→0、108→31.91。
## 命釘只有兩根，所以沒有量化問題；它也不導球，只是把入口縮窄——縮窄的量直接就是
## 入賞率，這是三者裡唯一平滑又有物理意義的。
func _build_guide(walls: StaticBody2D, left: float, right_lane: float, bottom: float) -> void:
	var gy_top := bottom - 250.0
	var gy_bot := bottom - 96.0
	_guide_top = gy_top
	_guide_bot = gy_bot
	# 寄り釘：兩道往中間斜下的釘列，把球**稍微**帶向中央。是釘不是牆，所以會漏。
	# 左右不對稱：右邊那道要夾在右側路線分界內，否則會把右打的球也一起接走
	var gw_r: float = minf(guide_half_width, right_lane - _cx - 24.0)
	var gw_l: float = minf(guide_half_width, _cx - left - 24.0)
	_nail_run(walls, Vector2(_cx - gw_l, gy_top), Vector2(_cx - 66.0, gy_bot - 40.0))
	_nail_run(walls, Vector2(_cx + gw_r, gy_top), Vector2(_cx + 66.0, gy_bot - 40.0))
	# 命釘：始動口的入口就是這兩根之間的縫
	_nail(walls, Vector2(_cx - guide_mouth, gy_bot - 14.0))
	_nail(walls, Vector2(_cx + guide_mouth, gy_bot - 14.0))


## 沿一條線種釘子，間距固定、從終點端起算。等分的話動一次開口就會重新量化整排。
func _nail_run(walls: StaticBody2D, from: Vector2, to: Vector2) -> void:
	var d := (from - to).normalized()
	var span := from.distance_to(to)
	var t := 0.0
	while t <= span:
		_nail(walls, to + d * t)
		t += 46.0


func _build_pockets(walls: StaticBody2D, left: float, right: float,
		right_lane: float, bottom: float) -> void:
	_seg(walls, Vector2(right_lane, _rect.position.y + _rect.size.y * 0.44),
		Vector2(right_lane, bottom - 40.0))

	# 始動口就在 V 底的縫正下方，寬度跟著縫走——縫是入口，杯只是接住掉進來的球。
	# 第一版把杯做成固定 68 px 寬、擺在盤底，而底部漏斗的上緣只在它下方 8 px：
	# 沒進的球撞漏斗彈一下就回到判定區裡，等於整個盤底都是始動口（量到 1.00 発/轉）。
	_start_pocket = Rect2(Vector2(_cx - guide_mouth, _guide_bot),
		Vector2(guide_mouth * 2.0, 30.0))
	_gate = Rect2(Vector2(right_lane + 6.0, _rect.position.y + _rect.size.y * 0.60),
		Vector2(gate_width, 30.0))
	_big_pocket = Rect2(Vector2(right - 160.0, _rect.position.y + _rect.size.y * 0.76),
		Vector2(130.0, 38.0))

	# 捷徑通道：入口是釘子場左緣一道很窄的斜縫，出口直接在誘導釘正上方。
	# 進得去就幾乎穩進始動口，但**角度很刁**——球得以夠平的角度往左下滑才卡得進去。
	# 難進正是它的價值：它是這個盤面唯一「技術有回報」的地方。
	_warp_in = Rect2(Vector2(left + 62.0, _rect.position.y + _rect.size.y * 0.66),
		Vector2(34.0, 42.0))
	_warp_out = Vector2(_cx - 22.0, bottom - 196.0)
	var wy := _warp_in.position.y
	_seg(walls, Vector2(left + 100.0, wy - 56.0), Vector2(left + 98.0, wy))


## アウト：沒進始動口的球要**離開盤面**，不能在盤底彈來彈去。兩片朝外的斜板把它們
## 帶到畫面外，盤面因此清得空——終局結算與校準量測都靠這件事才會收斂。
func _build_outlanes(walls: StaticBody2D, left: float, right: float, bottom: float) -> void:
	_seg(walls, Vector2(_cx - 40.0, bottom - 10.0), Vector2(left + 40.0, bottom + 70.0))
	_seg(walls, Vector2(_cx + 40.0, bottom - 10.0), Vector2(right - 40.0, bottom + 70.0))


func _seg(parent: StaticBody2D, a: Vector2, b: Vector2, solid := true) -> void:
	var pa := _mp(a)
	var pb := _mp(b)
	if solid:
		var cs := CollisionShape2D.new()
		var s := SegmentShape2D.new()
		s.a = pa
		s.b = pb
		cs.shape = s
		parent.add_child(cs)
	_segs.append(PackedVector2Array([pa, pb]))


func _nail(parent: StaticBody2D, p: Vector2) -> void:
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = NAIL_RADIUS
	cs.shape = c
	cs.position = _mp(p)
	parent.add_child(cs)
	_nails.append(cs.position)


# --- 球 -----------------------------------------------------------------

func _spawn(pos: Vector2, vel: Vector2) -> RigidBody2D:
	var b := RigidBody2D.new()
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = BALL_RADIUS
	cs.shape = c
	b.add_child(cs)
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.28
	mat.friction = 0.06
	b.physics_material_override = mat
	b.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	# 球不和球碰撞，只和釘子、牆與風車碰撞。這讓始動口入賞率**與發射速度無關**，
	# 校準時就能用比真機快十倍的速度射 2 萬顆。代價是失去球擠在一起的真機行為。
	b.collision_layer = 2
	b.collision_mask = 1
	b.position = pos
	b.linear_velocity = vel
	add_child(b)
	_balls.append(b)
	return b


## 直接把球放到盤面某處。校準用：把「軌道有沒有把球送到 x」和「x 落點能不能進始動口」
## 分成兩件事量，否則壞掉的時候分不出是哪一半壞。
func debug_drop(pos: Vector2, vel: Vector2) -> void:
	_spawn(_mp(pos), _mv(vel))


func fire_ball() -> void:
	var p := clampf(power, 0.0, 1.0)
	var b := _spawn(_mp(_launch), Vector2.ZERO)
	b.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	b.freeze = true
	_railing.append({
		"body": b,
		"dist": 0.0,
		# 真機的打出強弱也不是完全一致，而這個抖動正是落點分布的寬度來源之一
		"transit": lerpf(RAIL_TRANSIT.x, RAIL_TRANSIT.y, p),
		"exit": lerpf(EXIT_SPEED.x, EXIT_SPEED.y, p) * randf_range(0.97, 1.03),
	})


## 帶著球沿軌道走，走完才把速度交還給物理。
func _advance_rail(delta: float) -> void:
	for i in range(_railing.size() - 1, -1, -1):
		var r: Dictionary = _railing[i]
		var b: RigidBody2D = r["body"]
		if not is_instance_valid(b):
			_railing.remove_at(i)
			continue
		r["dist"] = float(r["dist"]) + float(r["transit"]) * delta
		var d := float(r["dist"])
		if d >= _rail_len:
			var n := _rail_path.size()
			var tangent := (_rail_path[n - 1] - _rail_path[n - 2]).normalized()
			b.freeze = false
			b.position = _mp(_rail_path[n - 1])
			b.linear_velocity = _mv(tangent) * float(r["exit"])
			_railing.remove_at(i)
		else:
			b.position = _mp(_rail_point(d))


func _rail_point(d: float) -> Vector2:
	var acc := 0.0
	for i in range(_rail_path.size() - 1):
		var seg := _rail_path[i].distance_to(_rail_path[i + 1])
		if acc + seg >= d:
			return _rail_path[i].lerp(_rail_path[i + 1], (d - acc) / seg)
		acc += seg
	return _rail_path[_rail_path.size() - 1]


func _physics_process(delta: float) -> void:
	_advance_rail(delta)
	_windmill_a += delta * 3.4
	if _windmill:
		_windmill.rotation = -_windmill_a if mirrored else _windmill_a

	var sp := _mrect(_start_pocket)
	var gate := _mrect(_gate)
	var big := _mrect(_big_pocket)
	var warp := _mrect(_warp_in)

	for i in range(_balls.size() - 1, -1, -1):
		var b := _balls[i]
		# 還在軌道裡的球不參與任何判定。它是被帶著走的，速度為 0——
		# 不排除的話「卡住的球」那條回收規則會把整條軌道上的球全部吃掉。
		if b.freeze:
			continue
		var p := b.position
		var consumed := false
		if sp.has_point(p):
			start_pocket_hit.emit()
			consumed = true
		elif electric_gate_open and gate.has_point(p):
			start_pocket_hit.emit()
			consumed = true
		elif big_pocket_open and big.has_point(p):
			big_pocket_hit.emit()
			consumed = true
		elif warp.has_point(p) and _warp_accepts(b):
			# 傳送到誘導釘正上方，往下輕輕放
			b.position = _mp(_warp_out)
			b.linear_velocity = Vector2(0.0, 120.0)
			warped.emit()
		elif p.y > _rect.end.y + 80.0:
			consumed = true
		elif b.linear_velocity.length() < 12.0:
			# 卡在角落的球。留著的話盤面永遠清不空——終局結算會卡住，量測也會卡住。
			b.set_meta("still", float(b.get_meta("still", 0.0)) + delta)
			if float(b.get_meta("still")) > 1.2:
				consumed = true
		else:
			b.set_meta("still", 0.0)
		if consumed:
			b.queue_free()
			_balls.remove_at(i)
	queue_redraw()


## 角度決定進不進得去。球得往左下、而且夠平——垂直掉下來的球會直接滑過縫口。
## 這是通道難進的來源，也是它能給高回報而不破壞平衡的原因。
func _warp_accepts(b: RigidBody2D) -> bool:
	var v := b.linear_velocity
	if mirrored:
		v.x = -v.x
	return v.x < -40.0 and v.y > 0.0 and absf(v.y) < absf(v.x) * 1.6


# --- 繪製 ---------------------------------------------------------------

func _draw() -> void:
	for s in _segs:
		draw_line(s[0], s[1], Color(0.30, 0.38, 0.58), 3.0)
	for n in _nails:
		draw_circle(n, NAIL_RADIUS, Color(0.52, 0.58, 0.72))

	# 風車
	var wp := _mp(_windmill_pos)
	for i in 2:
		var a := (-_windmill_a if mirrored else _windmill_a) + PI * 0.5 * i
		var d := Vector2(cos(a), sin(a)) * 42.0
		draw_line(wp - d, wp + d, Color(0.85, 0.72, 0.45), 11.0)
	draw_circle(wp, 10.0, Color(0.95, 0.85, 0.60))

	# 捷徑通道：入口與出口都要看得見，否則玩家不知道自己剛剛賺到了什麼
	var wi := _mrect(_warp_in)
	draw_rect(wi, Color(0.45, 0.95, 1.0, 0.20), true)
	draw_rect(wi, Color(0.45, 0.95, 1.0), false, 3.0)
	draw_line(wi.get_center(), _mp(_warp_out), Color(0.45, 0.95, 1.0, 0.18), 2.0)
	draw_circle(_mp(_warp_out), 9.0, Color(0.45, 0.95, 1.0, 0.55))

	var sp := _mrect(_start_pocket)
	draw_rect(sp, Color(1.0, 0.72, 0.25, 0.18), true)
	draw_rect(sp, Color(1.0, 0.72, 0.25), false, 3.0)

	if electric_gate_open:
		var g := _mrect(_gate)
		draw_rect(g, Color(0.45, 1.0, 0.70, 0.22), true)
		draw_rect(g, Color(0.45, 1.0, 0.70), false, 3.0)
	if big_pocket_open:
		var bp := _mrect(_big_pocket)
		draw_rect(bp, Color(1.0, 0.45, 0.35, 0.28), true)
		draw_rect(bp, Color(1.0, 0.45, 0.35), false, 4.0)

	for b in _balls:
		draw_circle(b.position, BALL_RADIUS, Color(0.92, 0.95, 1.0))
