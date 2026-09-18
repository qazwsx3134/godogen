extends SceneTree

## 物理類的量測：真的把球射出去撞釘，量**始動口入賞率**。
##
##   godot --headless --path . --script tools/measure_start_rate.gd -- --balls=5000
##   godot --headless --path . --script tools/measure_start_rate.gd -- --balls=5000 --right
##
## 這是全機唯一無法用數學推導的數字，也是最容易被改壞的一個：動一根釘子，整台機器的
## 節奏就變了，而你不會立刻發現（ADR 0002）。目標每 12 發一轉，範圍 10–16。
##
## 球不和球碰撞（見 playfield.gd），所以這裡可以用比真機快得多的速度射，量到的還是
## 同一個數字。N 與實際達到的容差一起回報——不要先寫死容差再發現要跑六小時。

## 每個 physics frame 射一批。headless 的物理仍然照真實時間推進，逐顆射 1500 顆要 55 秒；
## 而球不互相碰撞（見 playfield.gd），所以同時在盤面上的是幾顆或幾百顆，量到的是同一個
## 數字——每顆都是獨立試驗。發射速度的抖動讓它們在撞過幾根釘子後就發散。
const BURST := 12

var _target := 5000
var _right := false
var _power := -1.0
var _guide := -1.0
var _mouth := -1.0
var _fired := 0
var _hits := 0
var _frame := 0
var _field: Playfield
var _t0 := 0


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--balls="):
			_target = int(arg.substr(8))
		elif arg == "--right":
			_right = true
		elif arg.begins_with("--power="):
			_power = float(arg.substr(8))
		elif arg.begins_with("--guide="):
			_guide = float(arg.substr(8))
		elif arg.begins_with("--mouth="):
			_mouth = float(arg.substr(8))

	var vp := Spec.VIEWPORT
	var h := vp.y * 0.70
	var w := h * Spec.MACHINE_ASPECT
	if w > vp.x * 0.96:
		w = vp.x * 0.96
		h = w / Spec.MACHINE_ASPECT
	var rect := Rect2(Vector2((vp.x - w) * 0.5, vp.y * 0.12), Vector2(w, h))

	_field = Playfield.new(rect)
	if _guide > 0.0:
		_field.guide_half_width = _guide
	if _mouth > 0.0:
		_field.guide_mouth = _mouth
	# 力道就是瞄準（slider 取代了左打／右打兩檔）
	_field.power = _power if _power >= 0.0 else (1.0 if _right else 0.32)
	_field.electric_gate_open = _right      # 確變中電チュー才開
	_field.start_pocket_hit.connect(func() -> void: _hits += 1)
	root.add_child(_field)
	physics_frame.connect(_tick)
	_t0 = Time.get_ticks_msec()
	print("量測中：%d 顆，%s，誘導開口半寬 %.0f" % [_target, "右打（電チュー開）" if _right else "左打", _field.guide_half_width])
	print("力道 %.2f" % _field.power)
	print("V 底開口半寬 %.0f" % _field.guide_mouth)


func _tick() -> void:
	_frame += 1
	for i in BURST:
		if _fired >= _target:
			break
		_field.fire_ball()
		_fired += 1
	if _fired >= _target and _field.balls_in_flight() == 0:
		_report()
		quit(0)
	# 球卡住的話盤面永遠清不空，加個上限
	if _frame > _target / BURST + 20000:
		print("！仍有 %d 顆球卡在盤面上" % _field.balls_in_flight())
		_report()
		quit(1)


func _report() -> void:
	var secs := (Time.get_ticks_msec() - _t0) / 1000.0
	if _hits == 0:
		print("入賞 0 次 — 球到不了始動口，通道被封死了")
		return
	var rate := float(_fired) / _hits
	# 95% CI：入賞是伯努利過程，p = 1/rate
	var p := 1.0 / rate
	var se := sqrt(p * (1.0 - p) / _fired)
	var lo := 1.0 / (p + 1.96 * se)
	var hi := 1.0 / (p - 1.96 * se)
	print("發射 %d   入賞 %d   始動口入賞率 %.2f 発/轉" % [_fired, _hits, rate])
	print("95%% CI [%.2f, %.2f]  （±%.2f）   耗時 %.1f 秒" % [lo, hi, (hi - lo) * 0.5, secs])
	var target := Spec.START_RATE_KAKUHEN if _right else Spec.START_RATE_STANDARD
	print("目標 %.0f 発/轉 — %s" % [target,
		"達標" if absf(rate - target) < (hi - lo) * 0.5 + 0.5 else "要調釘子"])
