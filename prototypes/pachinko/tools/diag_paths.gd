extends SceneTree

## 診斷用：射幾顆球，每 N 影格印出位置，看球到底走到哪裡去。
##   godot --headless --path . --script tools/diag_paths.gd -- --power=0.32 --balls=3

var _power := 0.32
var _n := 3
var _field: Playfield
var _frame := 0
var _rect: Rect2


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

	_field = Playfield.new(_rect)
	_field.power = _power
	root.add_child(_field)
	physics_frame.connect(_tick)
	print("rect %s  center.x %.0f" % [_rect, _rect.get_center().x])
	print("start_pocket %s" % [_field.debug_start_pocket()])
	print("launch %s dir %s speed %.0f" % [_field.debug_launch(), _field.debug_launch_dir(), 0.0])


func _tick() -> void:
	_frame += 1
	if _frame == 1:
		for i in _n:
			_field.fire_ball()
	if _frame % 10 == 0:
		var s := "f%4d " % _frame
		for b in _field.debug_balls():
			s += "(%.0f,%.0f v%.0f) " % [b.position.x, b.position.y, b.linear_velocity.length()]
		print(s)
	if _frame > 900 or (_frame > 5 and _field.balls_in_flight() == 0):
		print("done, in flight %d" % _field.balls_in_flight())
		quit(0)
