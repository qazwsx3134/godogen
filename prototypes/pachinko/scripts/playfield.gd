extends Node2D
class_name Playfield

## 盤面物理。它只負責一件事：**始動口入賞率**——同樣的球數能買到幾次抽選。
##
## 抽選在球落入始動口的瞬間就定案（ADR 0002），所以球往哪彈不影響結果。不要為了讓遊戲
## 「比較公平」或「比較有趣」而加物理細節，那碰不到結果。釘子存在的唯一理由是這個數字，
## 而它是全機唯一無法用數學推導的量——只能實跑球得知。

signal start_pocket_hit
signal big_pocket_hit

const BALL_RADIUS := 10.0
const NAIL_RADIUS := 5.0
## 打出軌道在**左下角**，球往右上飛過頂部再落下——真機就是這個拓樸，而它決定了
## 「左打／右打」到底是什麼意思：同一個發射口，強弱決定球落在盤面的哪一側。
##   左打（弱）→ 落在中央的釘子場 → 往始動口漏
##   右打（強）→ 飛過釘子場落到右側路線 → 電チュー與大入賞口在那裡
## 第一版把發射台放在右下角，球落在 x 693–816 而始動口在 540，永遠進不去。
const LEFT_LAUNCH := Vector2(194.0, -1758.0)
const RIGHT_LAUNCH := Vector2(323.0, -1850.0)

var right_aim := false
var big_pocket_open := false
var electric_gate_open := false                   # 電チュー：確變中才開

## 誘導釘的開口半寬（px）。始動口上方的一對導引牆，把落在這個範圍內的球送進去。
## 靠釘子自然收束是不可靠的——量到 30–55 発/轉，而且抖得厲害。真機也是用導引結構
## 而不是靠運氣。**這是校準到 12 発/轉的主要旋鈕**，用 tools/measure_start_rate.gd 掃。
## 寬度本身**不是**好旋鈕：掃過一遍發現它是懸崖（260 給 17.4 発/轉，275 給 5.8），
## 校準會很脆。它只要夠寬到「確實接得到球」就好。
var guide_half_width := 300.0
## V 底的開口半寬。**這才是校準到 12 発/轉的旋鈕**，而且是平滑的：
## 實測校準曲線（N=14000，tools/measure_start_rate.gd）：
##   90 → 9.54   93 → 11.44   96 → 12.14   99 → 14.04   （約 102 → 16）
## 也就是 ADR 0006 的釘調整範圍 10–16 只需要 ±6% 的開口變動——那正是
## 「肉眼看不出來的細微變動」該有的量級。
var guide_mouth := 96.0
## 電チュー的寬度。確變中右打的入賞率旋鈕，目標每 4 発一轉。
var gate_width := 110.0

var _rect: Rect2
var _balls: Array[RigidBody2D] = []
var _nails: Array[Vector2] = []
var _segs: Array[PackedVector2Array] = []
var _start_pocket: Rect2
var _big_pocket: Rect2
var _gate: Rect2
var _launch := Vector2.ZERO


func _init(rect: Rect2) -> void:
	_rect = rect


func _ready() -> void:
	_build()


func balls_in_flight() -> int:
	return _balls.size()


# --- 盤面配置 -----------------------------------------------------------

func _build() -> void:
	var walls := StaticBody2D.new()
	walls.name = "Walls"
	add_child(walls)

	var inset := 24.0
	var left := _rect.position.x + inset
	var right := _rect.end.x - inset
	var top := _rect.position.y + 12.0
	var bottom := _rect.end.y - 60.0
	var cx := _rect.get_center().x
	_launch = Vector2(left + 24.0, bottom - 8.0)
	# 右側路線的分界：這條線右邊不長釘子，右打的球才到得了電チュー與大入賞口
	var right_lane := right - 210.0

	# 外框：左右兩道牆，加上頂部的圓弧把右打的球導回盤面
	_seg(walls, Vector2(left, top + 90.0), Vector2(left, bottom))
	_seg(walls, Vector2(right, top + 90.0), Vector2(right, bottom))
	var arc_r := (right - left) * 0.5
	var steps := 22
	for i in steps:
		var a0 := PI + PI * float(i) / steps
		var a1 := PI + PI * float(i + 1) / steps
		_seg(walls, Vector2(cx + cos(a0) * arc_r, top + 90.0 + sin(a0) * arc_r * 0.55),
			Vector2(cx + cos(a1) * arc_r, top + 90.0 + sin(a1) * arc_r * 0.55))

	# 底部漏斗，中間留口讓沒進任何口的球漏掉
	_seg(walls, Vector2(left, bottom), Vector2(cx - 90.0, bottom + 54.0))
	_seg(walls, Vector2(right, bottom), Vector2(cx + 90.0, bottom + 54.0))

	# 釘子場。基準配置是自由參數，用 sim 量出的入賞率反覆校準到每 12 發一轉——
	# 這是 M2 最花時間的一步，而且沒有捷徑。
	var y0 := _rect.position.y + _rect.size.y * 0.46
	var spacing := (right - left) / 9.5
	var rows := 8
	for r in rows:
		var y: float = y0 + r * spacing * 0.84
		if y > bottom - 110.0:
			break
		var x: float = left + spacing * 0.6 + (spacing * 0.5 if r % 2 == 1 else 0.0)
		while x < right_lane:
			# 始動口正上方留一條漸縮的通道：越靠近底部開口越窄，球才會有「差一點」的進出
			var funnel: float = spacing * (1.35 - 0.11 * r)
			if absf(x - cx) > funnel:
				_nail(walls, Vector2(x, y))
			x += spacing

	# 誘導釘：始動口正上方的一對導引牆，把落在開口內的球收進去。
	# 這是入賞率的主要旋鈕——開口越寬，同樣的球數買到越多轉。
	var gy_top := bottom - 152.0
	var gy_bot := bottom - 80.0
	# 左右不對稱：右臂要夾在右側路線分界內，否則會把右打的球也一起接走；
	# 左臂沒有這個限制，而球是從左下角打出、落在中央偏左，所以左臂才是主要的接球面。
	# 對稱地一起夾會把左臂也砍半，入賞率從 12 掉到 44 発/轉。
	var gw_r: float = minf(guide_half_width, right_lane - cx - 24.0)
	var gw_l: float = minf(guide_half_width, cx - left - 24.0)
	_seg(walls, Vector2(cx - gw_l, gy_top), Vector2(cx - guide_mouth, gy_bot))
	_seg(walls, Vector2(cx + gw_r, gy_top), Vector2(cx + guide_mouth, gy_bot))

	# 右側路線的導引牆：把落到右邊的球接住往下送，不要讓它們散回釘子場
	_seg(walls, Vector2(right_lane, _rect.position.y + _rect.size.y * 0.44),
		Vector2(right_lane, bottom - 40.0))

	_start_pocket = Rect2(Vector2(cx - 34.0, bottom - 74.0), Vector2(68.0, 26.0))
	# 電チュー：確變中右打從右側進的第二個始動口，不受釘調整影響
	_gate = Rect2(Vector2(right_lane + 6.0, _rect.position.y + _rect.size.y * 0.60),
		Vector2(gate_width, 30.0))
	# 大入賞口：只在大當中開。開著的時候球進去不抽選，出玉是腳本化的。
	_big_pocket = Rect2(Vector2(right - 160.0, _rect.position.y + _rect.size.y * 0.76),
		Vector2(130.0, 38.0))


func _seg(parent: StaticBody2D, a: Vector2, b: Vector2) -> void:
	var cs := CollisionShape2D.new()
	var s := SegmentShape2D.new()
	s.a = a
	s.b = b
	cs.shape = s
	parent.add_child(cs)
	_segs.append(PackedVector2Array([a, b]))


func _nail(parent: StaticBody2D, p: Vector2) -> void:
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = NAIL_RADIUS
	cs.shape = c
	cs.position = p
	parent.add_child(cs)
	_nails.append(p)


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
	# 球不和球碰撞，只和釘子與牆碰撞。這讓始動口入賞率**與發射速度無關**——
	# 校準時就能用比真機快十倍的速度射 2 萬顆，而量到的還是同一個數字。
	# 代價是失去球擠在一起的真機行為，這是刻意接受的簡化。
	b.collision_layer = 2
	b.collision_mask = 1
	b.position = _launch
	var v := RIGHT_LAUNCH if right_aim else LEFT_LAUNCH
	# 發射強度的細微抖動：真機的打出強弱也不是完全一致，而且完全一致會讓球走同一條路
	b.linear_velocity = v * randf_range(0.97, 1.03)
	b.position.x += randf_range(-3.0, 3.0)
	add_child(b)
	_balls.append(b)


func _physics_process(_delta: float) -> void:
	for i in range(_balls.size() - 1, -1, -1):
		var b := _balls[i]
		var p := b.position
		var consumed := false
		if _start_pocket.has_point(p):
			start_pocket_hit.emit()
			consumed = true
		elif electric_gate_open and _gate.has_point(p):
			start_pocket_hit.emit()
			consumed = true
		elif big_pocket_open and _big_pocket.has_point(p):
			big_pocket_hit.emit()
			consumed = true
		elif p.y > _rect.end.y + 80.0:
			consumed = true
		elif b.linear_velocity.length() < 12.0:
			# 卡在漏斗角落的球。留著的話盤面永遠清不空——終局結算會卡住，
			# 校準量測也會卡住，而且球會一直累積把幀數吃掉。
			b.set_meta("still", float(b.get_meta("still", 0.0)) + _delta)
			if float(b.get_meta("still")) > 1.2:
				consumed = true
		else:
			b.set_meta("still", 0.0)
		if consumed:
			b.queue_free()
			_balls.remove_at(i)
	queue_redraw()


func _draw() -> void:
	for s in _segs:
		draw_line(s[0], s[1], Color(0.30, 0.38, 0.58), 3.0)
	for n in _nails:
		draw_circle(n, NAIL_RADIUS, Color(0.52, 0.58, 0.72))

	draw_rect(_start_pocket, Color(1.0, 0.72, 0.25, 0.18), true)
	draw_rect(_start_pocket, Color(1.0, 0.72, 0.25), false, 3.0)

	if electric_gate_open:
		draw_rect(_gate, Color(0.45, 1.0, 0.70, 0.22), true)
		draw_rect(_gate, Color(0.45, 1.0, 0.70), false, 3.0)
	if big_pocket_open:
		draw_rect(_big_pocket, Color(1.0, 0.45, 0.35, 0.28), true)
		draw_rect(_big_pocket, Color(1.0, 0.45, 0.35), false, 4.0)

	for b in _balls:
		draw_circle(b.position, BALL_RADIUS, Color(0.92, 0.95, 1.0))
