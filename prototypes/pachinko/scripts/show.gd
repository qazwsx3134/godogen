extends Node2D
class_name Show

## 三段可重播的演出序列（T3＋T4＋T5）。
##
## 這是序列測試的載具（ADR 0009）：固定路徑、可重播，用來判「可讀性與張力」，
## 和抽選運氣無關——所以它是唯一能拿來比較「這版演出比上版好還是壞」的東西。
##
## 開場先跑一次隱藏的暖機。實機量測發現效能成本是**前置**的而不是持續的：
## shader 編譯要 68 ms、Safari 的 WASM tier-up 與時脈爬升要數秒。序列測試強制立刻播
## SP，是唯一會撞上冷啟動的路徑；不暖機的話量到的是時脈爬升，卻會看起來像演出不行。

signal back_pressed

const WARMUP_TIME := 2.5

## 起始路徑。影格擷取要能指定，否則只驗得到預設那一條。
var start_path: int = Sequence.Path.SP_HIT

var _machine: Rect2
var _lcd: Rect2
var _pres: Presentation
var _warming := true
var _warm_t := 0.0

var _buttons: Array[Dictionary] = []
var _back_button: Rect2
var _replay_button: Rect2
var _info: Label


func _ready() -> void:
	_compute_layout()
	_build_ui()
	_pres = Presentation.new(_lcd)
	_pres.path = start_path
	add_child(_pres)
	# 暖機期間讓每個 shader 都畫過一次，但蓋住不給看
	_pres.modulate.a = 0.0


func _compute_layout() -> void:
	var vp := Spec.VIEWPORT
	var h := vp.y * 0.66
	var w := h * Spec.MACHINE_ASPECT
	if w > vp.x * 0.94:
		w = vp.x * 0.94
		h = w / Spec.MACHINE_ASPECT
	_machine = Rect2(Vector2((vp.x - w) * 0.5, vp.y * 0.15), Vector2(w, h))
	var lw := w * Spec.LCD_COVERAGE
	var lh := lw * 0.78
	_lcd = Rect2(Vector2(_machine.position.x + (w - lw) * 0.5, _machine.position.y + h * 0.10),
		Vector2(lw, lh))


func _build_ui() -> void:
	var vp := Spec.VIEWPORT
	_info = Label.new()
	_info.position = Vector2(24.0, 18.0)
	_info.size = Vector2(vp.x - 230.0, 200.0)
	_info.add_theme_font_size_override("font_size", 26)
	_info.add_theme_color_override("font_color", Color(0.84, 0.90, 1.0))
	_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_info.add_theme_constant_override("outline_size", 6)
	add_child(_info)

	_back_button = Rect2(Vector2(vp.x - 190.0, 20.0), Vector2(170.0, 84.0))

	var bw := (vp.x - 90.0) * 0.5
	var y0 := vp.y - 330.0
	var paths := [
		[Sequence.Path.SP_HIT, "SP JACKPOT"],
		[Sequence.Path.SP_MISS, "SP MISS"],
		[Sequence.Path.NORMAL_STOP, "NORMAL STOP"],
		[Sequence.Path.STRAIGHT_MISS, "NO REACH"],
	]
	for i in paths.size():
		var col := i % 2
		var row := i / 2
		_buttons.append({
			"rect": Rect2(Vector2(30.0 + col * (bw + 30.0), y0 + row * 110.0), Vector2(bw, 92.0)),
			"label": paths[i][1],
			"path": paths[i][0],
		})
	_replay_button = Rect2(Vector2(30.0, vp.y - 100.0), Vector2(vp.x - 60.0, 80.0))


func _process(delta: float) -> void:
	if _warming:
		_warm_t += delta
		# 暖機掃過兩條 SP 路徑的關鍵時刻，逼 shader 與音訊管線各編譯／初始化一次
		_pres._t = fmod(_warm_t * 7.0, 19.0)
		if _warm_t >= WARMUP_TIME:
			_warming = false
			_pres.modulate.a = 1.0
			_pres.restart(start_path)
	_refresh_text()
	queue_redraw()


func _refresh_text() -> void:
	if _warming:
		_info.text = "WARMING UP  %.1fs\ncompiling shaders, letting the clock ramp\n(cold start is the real cost, not steady state)" % _warm_t
		return
	var path_name: String = Sequence.PATH_NAMES[_pres.path]
	var beat := "-"
	for b in Sequence.beats(_pres.path):
		if _pres._t >= float(b["at"]):
			beat = b["beat"]
	_info.text = "%s   %.1f / %.1f s\nbeat: %s   %d fps" % [
		path_name.to_upper(), minf(_pres._t, _pres.total_time()), _pres.total_time(), beat,
		int(Engine.get_frames_per_second())]


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Spec.VIEWPORT), Color(0.027, 0.031, 0.063), true)
	draw_rect(_machine, Color(0.07, 0.09, 0.16), true)
	draw_rect(_machine, Color(0.28, 0.36, 0.60), false, 3.0)
	# 液晶框。SP 會越過它，所以它必須是畫面上看得見的實體邊界。
	draw_rect(_lcd, Color(0.03, 0.04, 0.09), true)
	draw_rect(_lcd, Color(0.42, 0.56, 0.92), false, 3.0)

	if _warming:
		return
	for b in _buttons:
		var active: bool = b["path"] == _pres.path
		_button(b["rect"], b["label"], active)
	_button(_replay_button, "REPLAY", false)
	_button(_back_button, "BACK", false)


func _button(r: Rect2, text: String, active: bool) -> void:
	draw_rect(r, Color(0.22, 0.32, 0.56, 0.95) if active else Color(0.11, 0.15, 0.27, 0.95), true)
	draw_rect(r, Color(0.50, 0.64, 0.98), false, 3.0)
	var f := ThemeDB.fallback_font
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 32).x
	draw_string(f, r.get_center() + Vector2(-w * 0.5, 11.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 32, Color(0.89, 0.93, 1.0))


func _unhandled_input(event: InputEvent) -> void:
	if _warming:
		return
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		pos = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pos = (event as InputEventMouseButton).position
	else:
		return

	if _back_button.has_point(pos):
		back_pressed.emit()
		return
	if _replay_button.has_point(pos):
		_pres.restart(_pres.path)
		return
	for b in _buttons:
		if (b["rect"] as Rect2).has_point(pos):
			_pres.restart(b["path"])
			return
