extends SceneTree

## 到達分布：球通過誘導釘上緣那條線時的 x 直方圖。
## 校準卡住的時候，這張圖比任何猜測都快——它直接說「球是不是自己走到中央去了」。

var _power := 0.33
var _n := 1500
var _field: Playfield
var _rect: Rect2
var _y := 0.0
var _hist := {}
var _seen := {}
var _fired := 0
var _frame := 0


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--power="):
			_power = float(arg.substr(8))
		elif arg.begins_with("--balls="):
			_n = int(arg.substr(8))
	var vp := Spec.VIEWPORT
	var h := vp.y * 0.70
	var w := h * Spec.MACHINE_ASPECT
	if w > vp.x * 0.96:
		w = vp.x * 0.96
		h = w / Spec.MACHINE_ASPECT
	_rect = Rect2(Vector2((vp.x - w) * 0.5, vp.y * 0.12), Vector2(w, h))
	_y = _rect.end.y - 60.0 - 230.0
	_field = Playfield.new(_rect)
	_field.power = _power
	root.add_child(_field)
	physics_frame.connect(_tick)


func _tick() -> void:
	_frame += 1
	for i in 10:
		if _fired >= _n:
			break
		_field.fire_ball()
		_fired += 1
	for b in _field.debug_balls():
		if b.freeze or _seen.has(b.get_instance_id()):
			continue
		if b.position.y > _y:
			_seen[b.get_instance_id()] = true
			var bucket := int(b.position.x / 40.0) * 40
			_hist[bucket] = int(_hist.get(bucket, 0)) + 1
	if (_fired >= _n and _field.balls_in_flight() == 0) or _frame > 40000:
		var keys := _hist.keys()
		keys.sort()
		var total := 0
		for k in keys:
			total += int(_hist[k])
		print("通過 y=%.0f 的球 %d / 發射 %d" % [_y, total, _fired])
		for k in keys:
			var c := int(_hist[k])
			print("x %4d–%4d  %5d  %s" % [k, k + 39, c, "#".repeat(int(c * 60.0 / maxf(total, 1) * 4))])
		quit(0)
