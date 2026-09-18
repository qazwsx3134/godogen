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

## 力道 0→1 對應的發射速度。**下限不是 0**：球得先有足夠動能爬完整條軌道
## （出入口落差約 590 px，光是爬上去就要 1284），力道控制的是**甩出去時剩多少速度**。
## 低力道＝勉強爬過去＝從左上角掉下來＝左打；高力道＝出口還很快＝飛到右側路線＝右打。
const LAUNCH_SPEED := Vector2(1320.0, 1850.0)
## 軌道的起訖角度（沿左緣爬到左上角）。
const RAIL_ENTRY_ANGLE := 148.0
const RAIL_EXIT_ANGLE := 250.0

## 左撇子設定：整個盤面鏡射。控制元件的位置由 game.gd 決定。
var mirrored := false
## 發射力道 0–1。取代了原本的左打／右打兩檔——slider 就是瞄準。
var power := 0.5

var big_pocket_open := false
var electric_gate_open := false                   # 電チュー：確變中才開

## 誘導釘 V 底的開口半寬。**校準到 12 発/轉的旋鈕**，而且是平滑的。
var guide_mouth := 96.0
var guide_half_width := 300.0
## 電チュー的寬度。確變中右打的入賞率旋鈕，目標每 4 発一轉。
var gate_width := 110.0

## 釘調整（[ADR 0006](../docs/adr/0006-nails-are-reset-each-session.md)）。
## `-1` ＝**固定標準台，不抽**，而這是預設值：驗收必須可重複。
var nail_seed := -1
## 中心 95 而不是 96，因為入賞率對開口是**凸函數**，對稱地抽會得到偏辛的平均值。
## 辛端夾在 101 是推導值：SP ≥ 3 次需要入賞率 ≤ 15.54 発/轉。
const NAIL_CENTER := 95.0
const NAIL_SIGMA := 3.0
const NAIL_CLAMP := Vector2(89.0, 101.0)

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
	_build_nails(walls, left, right_lane, bottom)
	_build_windmill(bottom)
	_build_guide(walls, left, right_lane, bottom)
	_build_pockets(walls, left, right, right_lane, bottom)


## 打出軌道：貼著左緣的一段直道，到上方再轉彎把球甩進盤面。
##
## 第一版用一個定半徑的大圓弧，結果**圓弧直接穿過液晶**——球從液晶後面被甩出來。
## 68% 寬的大液晶塞不進那個圓。真機的軌道本來就不是圓：它是沿邊的直段加頂部轉彎，
## 所以中間讓得出一塊完整的矩形給液晶。這裡照那個形狀做。
func _build_rail(walls: StaticBody2D, left: float, right: float, bottom: float) -> void:
	var x_rail := left + 34.0
	var y_lo := bottom - 30.0
	var y_hi := _rect.position.y + _rect.size.y * 0.31
	var r := 330.0
	var arc_c := Vector2(x_rail + r, y_hi)

	var mid: Array[Vector2] = []
	for i in 7:
		mid.append(Vector2(x_rail, lerpf(y_lo, y_hi, float(i) / 6.0)))
	var steps := 16
	for i in range(1, steps + 1):
		var a := deg_to_rad(lerpf(180.0, 270.0, float(i) / steps))
		mid.append(arc_c + Vector2(cos(a), sin(a)) * r)

	# 由中線往兩側偏移生出通道的內外壁
	var half := 23.0
	for i in range(mid.size() - 1):
		var d := (mid[i + 1] - mid[i]).normalized()
		var n := Vector2(-d.y, d.x)
		_seg(walls, mid[i] - n * half, mid[i + 1] - n * half)
		# 內壁在出口前就結束，球才甩得出去
		if i < mid.size() - 4:
			_seg(walls, mid[i] + n * half, mid[i + 1] + n * half)

	_launch = mid[0]
	_launch_dir = (mid[1] - mid[0]).normalized()

	# 右緣與底部漏斗
	_seg(walls, Vector2(right, _rect.position.y + 120.0), Vector2(right, bottom))
	_seg(walls, Vector2(x_rail + half, bottom - 40.0), Vector2(_cx - 90.0, bottom + 54.0))
	_seg(walls, Vector2(right, bottom), Vector2(_cx + 90.0, bottom + 54.0))


func _build_nails(walls: StaticBody2D, left: float, right_lane: float, bottom: float) -> void:
	var y0 := _rect.position.y + _rect.size.y * 0.62
	var spacing := (right_lane - left) / 7.5
	for r in 8:
		var y: float = y0 + r * spacing * 0.82
		if y > bottom - 300.0:
			break
		var x: float = left + spacing * 0.5 + (spacing * 0.5 if r % 2 == 1 else 0.0)
		while x < right_lane - spacing * 0.2:
			# 中央留一條漸縮的通道，通往風車與誘導釘
			var funnel: float = spacing * (1.15 - 0.09 * r)
			if absf(x - _cx) > funnel:
				_nail(walls, Vector2(x, y))
			x += spacing


## 風車：一個持續轉動的撥片，把落到中央的球打向左或右。
## 打對邊才進得了中央通道，不然就被撥出去——那幾秒的轉向就是這一段的懸念。
func _build_windmill(bottom: float) -> void:
	_windmill_pos = Vector2(_cx, bottom - 258.0)
	_windmill = AnimatableBody2D.new()
	_windmill.sync_to_physics = true
	_windmill.position = _mp(_windmill_pos)
	for i in 2:
		var cs := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(108.0, 12.0)
		cs.shape = box
		cs.rotation = PI * 0.5 * i
		_windmill.add_child(cs)
	add_child(_windmill)


## 誘導釘：始動口正上方的一對導引牆。開口半寬是校準入賞率的旋鈕。
func _build_guide(walls: StaticBody2D, left: float, right_lane: float, bottom: float) -> void:
	var gy_top := bottom - 152.0
	var gy_bot := bottom - 80.0
	# 左右不對稱：右臂要夾在右側路線分界內，否則會把右打的球也一起接走
	var gw_r: float = minf(guide_half_width, right_lane - _cx - 24.0)
	var gw_l: float = minf(guide_half_width, _cx - left - 24.0)
	_seg(walls, Vector2(_cx - gw_l, gy_top), Vector2(_cx - guide_mouth, gy_bot))
	_seg(walls, Vector2(_cx + gw_r, gy_top), Vector2(_cx + guide_mouth, gy_bot))


func _build_pockets(walls: StaticBody2D, left: float, right: float,
		right_lane: float, bottom: float) -> void:
	_seg(walls, Vector2(right_lane, _rect.position.y + _rect.size.y * 0.44),
		Vector2(right_lane, bottom - 40.0))

	_start_pocket = Rect2(Vector2(_cx - 34.0, bottom - 74.0), Vector2(68.0, 26.0))
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


func _seg(parent: StaticBody2D, a: Vector2, b: Vector2) -> void:
	var cs := CollisionShape2D.new()
	var s := SegmentShape2D.new()
	s.a = _mp(a)
	s.b = _mp(b)
	cs.shape = s
	parent.add_child(cs)
	_segs.append(PackedVector2Array([s.a, s.b]))


func _nail(parent: StaticBody2D, p: Vector2) -> void:
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = NAIL_RADIUS
	cs.shape = c
	cs.position = _mp(p)
	parent.add_child(cs)
	_nails.append(cs.position)


# --- 球 -----------------------------------------------------------------

func fire_ball() -> void:
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
	b.position = _mp(_launch)
	# 沿軌道切線送進去，力道決定甩出去的速度
	var speed := lerpf(LAUNCH_SPEED.x, LAUNCH_SPEED.y, clampf(power, 0.0, 1.0))
	speed *= randf_range(0.99, 1.01)     # 真機的打出強弱也不是完全一致
	b.linear_velocity = _mv(_launch_dir) * speed
	add_child(b)
	_balls.append(b)


func _physics_process(delta: float) -> void:
	_windmill_a += delta * 3.4
	if _windmill:
		_windmill.rotation = -_windmill_a if mirrored else _windmill_a

	var sp := _mrect(_start_pocket)
	var gate := _mrect(_gate)
	var big := _mrect(_big_pocket)
	var warp := _mrect(_warp_in)

	for i in range(_balls.size() - 1, -1, -1):
		var b := _balls[i]
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
		var d := Vector2(cos(a), sin(a)) * 54.0
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
