extends SceneTree

## 落點掃描：**繞過打出軌道**，直接把球放在釘子場上方的某個 x，量始動口入賞率。
##
##   godot --headless --path . --script tools/measure_drop.gd -- --balls=800
##   godot --headless --path . --script tools/measure_drop.gd -- --x=540 --mouth=96
##
## 為什麼要有這個工具：入賞率壞掉的時候，「軌道沒把球送到該去的 x」和「那個 x 本來就
## 進不了始動口」是兩個不同的 bug，而從一個 0.00 発/轉 分不出是哪一個。先把下半盤量成
## 一張 x → 入賞率的表，軌道的校準目標才有定義。

const BURST := 8

var _balls := 600
var _xs: Array[float] = []
var _mouth := -1.0
var _vx := 0.0
var _vy := 260.0
var _jx := 20.0
var _jv := 60.0
var _band := Vector2.ZERO
var _field: Playfield
var _rect: Rect2
var _drop_y := 0.0
var _fired := 0
var _hits := 0
var _frame := 0
var _rows: Array = []
var _i := 0


func _init() -> void:
	var single := -1.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--balls="):
			_balls = int(arg.substr(8))
		elif arg.begins_with("--x="):
			single = float(arg.substr(4))
		elif arg.begins_with("--mouth="):
			_mouth = float(arg.substr(8))
		elif arg.begins_with("--vx="):
			_vx = float(arg.substr(5))
		elif arg.begins_with("--vy="):
			_vy = float(arg.substr(5))
		elif arg.begins_with("--jx="):
			_jx = float(arg.substr(5))
		elif arg.begins_with("--jv="):
			_jv = float(arg.substr(5))
		elif arg.begins_with("--band="):
			var parts := arg.substr(7).split(":")
			_band = Vector2(float(parts[0]), float(parts[1]))

	var vp := Spec.VIEWPORT
	var h := vp.y * 0.70
	var w := h * Spec.MACHINE_ASPECT
	if w > vp.x * 0.96:
		w = vp.x * 0.96
		h = w / Spec.MACHINE_ASPECT
	_rect = Rect2(Vector2((vp.x - w) * 0.5, vp.y * 0.12), Vector2(w, h))
	_drop_y = _rect.position.y + _rect.size.y * 0.50

	if _band != Vector2.ZERO:
		# 一整段落點隨機抽——這就是軌道送過來的到達分布，校準要量的是它的總和，
		# 不是某一個 x 的切片。
		_xs = [(_band.x + _band.y) * 0.5]
	elif single > 0.0:
		_xs = [single]
	else:
		var x := _rect.position.x + 60.0
		while x < _rect.end.x - 40.0:
			_xs.append(x)
			x += 40.0

	_field = Playfield.new(_rect)
	if _mouth > 0.0:
		_field.guide_mouth = _mouth
	_field.start_pocket_hit.connect(func() -> void: _hits += 1)
	root.add_child(_field)
	physics_frame.connect(_tick)
	print("盤面 x %.0f–%.0f  中線 %.0f  落球 y %.0f  初速 (%.0f, %.0f)"
		% [_rect.position.x, _rect.end.x, _rect.get_center().x, _drop_y, _vx, _vy])
	print("釘子 %d 根  誘導開口半寬 %.0f" % [_field.debug_nail_count(), _field.guide_mouth])


func _tick() -> void:
	_frame += 1
	for i in BURST:
		if _fired >= _balls:
			break
		# 抖動是必要的，不是雜訊：沒有它每顆球走的是同一條決定性軌跡，
		# 300 顆量到的只會是 0 或 300，那是一張軌跡圖不是入賞率。
		var dx: float = randf_range(_band.x, _band.y) if _band != Vector2.ZERO \
			else _xs[_i] + randf_range(-_jx, _jx)
		_field.debug_drop(Vector2(dx, _drop_y),
			Vector2(_vx + randf_range(-_jv, _jv), _vy))
		_fired += 1
	if _fired >= _balls and _field.balls_in_flight() == 0:
		_next()
	elif _frame > _balls / BURST + 3000:
		print("！卡住 %d 顆" % _field.balls_in_flight())
		_next()


func _next() -> void:
	var rate := 999.0 if _hits == 0 else float(_fired) / _hits
	_rows.append([_xs[_i], _fired, _hits, rate])
	print("x %4.0f   發射 %4d   入賞 %4d   %s"
		% [_xs[_i], _fired, _hits, "—" if _hits == 0 else "%.2f 発/轉" % rate])
	_fired = 0
	_hits = 0
	_frame = 0
	_i += 1
	if _i >= _xs.size():
		_summary()
		quit(0)


func _summary() -> void:
	var best := -1
	for i in _rows.size():
		if _rows[i][2] > 0 and (best < 0 or absf(_rows[i][3] - 12.0) < absf(_rows[best][3] - 12.0)):
			best = i
	if best < 0:
		print("\n全部落點都進不了始動口 — 下半盤壞了，不是軌道的問題")
	else:
		print("\n最接近 12 発/轉 的落點：x %.0f → %.2f 発/轉" % [_rows[best][0], _rows[best][3]])
