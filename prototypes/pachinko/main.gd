extends Node2D

## 入口。整棵場景樹在執行期用 GDScript 組出來，只有這一個極小的 main.tscn 存在檔案裡
## ——這樣完全繞過 .tscn 的序列化陷阱（owner chain、靜默掉節點），而試作的標準本來就
## 允許這種做法。
##
## 手機上沒有命令列，所以預設先給一個選單。桌機批次跑仍然可以用 --mode= 直接進去。
##
## 選單和兩個模式一樣，全部畫在 1080x1920 的 Node2D 空間裡，不用 Control 容器。
## 混用兩套座標空間正是第一版在手機上被切掉的原因：stretch 之後 CanvasLayer 裡的
## Control 量到的是視窗像素，_draw() 量到的是 viewport，兩者在手機上差很多。

const MODE_PROBE := "probe"
const MODE_STRESS := "stress"
const MODE_SHOW := "show"
const MODE_GAME := "game"

var _in_menu := true
var _current: Node = null
var _buttons: Array[Dictionary] = []
var _start_path: int = Sequence.Path.SP_HIT


func _ready() -> void:
	var mode := ""
	var auto := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			mode = arg.substr(7)
		elif arg == "--auto":
			auto = true
		elif arg.begins_with("--path="):
			# 影格擷取要能指定路徑，否則只驗得到預設那一條
			match arg.substr(7):
				"sp_hit": _start_path = Sequence.Path.SP_HIT
				"sp_miss": _start_path = Sequence.Path.SP_MISS
				"normal_stop": _start_path = Sequence.Path.NORMAL_STOP
				"straight_miss": _start_path = Sequence.Path.STRAIGHT_MISS
				_: push_error("未知的 --path=%s" % arg.substr(7))
		elif arg == "--design":
			# 驗收跑設計值（ADR 0002）。畫面上會印出來，免得跑錯旋鈕還不知道。
			Spec.use_dev_knob = false

	_layout_menu()
	if not mode.is_empty():
		_launch(mode, auto)


func _layout_menu() -> void:
	# 上下各留 14%：iPhone 的瀏海與 home indicator 會吃掉邊緣，按鈕靠太邊就點不到。
	var vp := Spec.VIEWPORT
	var w := vp.x * 0.78
	var x := (vp.x - w) * 0.5
	_buttons = [
		{
			"rect": Rect2(Vector2(x, vp.y * 0.22), Vector2(w, 200.0)),
			"title": "PLAY THE MACHINE",
			"sub": "playfield, draws, kakuhen loop, settlement",
			"mode": MODE_GAME,
		},
		{
			"rect": Rect2(Vector2(x, vp.y * 0.37), Vector2(w, 200.0)),
			"title": "SEQUENCES",
			"sub": "SP jackpot / SP miss / normal stop",
			"mode": MODE_SHOW,
		},
		{
			"rect": Rect2(Vector2(x, vp.y * 0.52), Vector2(w, 200.0)),
			"title": "AUDIO + TOUCH PROBE",
			"sub": "gesture unlock, ramp timing, fire A/B",
			"mode": MODE_PROBE,
		},
		{
			"rect": Rect2(Vector2(x, vp.y * 0.67), Vector2(w, 200.0)),
			"title": "BLACK HOLE STRESS",
			"sub": "cold vs steady, 3 cost classes",
			"mode": MODE_STRESS,
		},
	]


func _launch(mode: String, auto: bool) -> void:
	_in_menu = false
	match mode:
		MODE_PROBE:
			var p := Probe.new()
			p.auto = auto
			p.back_pressed.connect(_return_to_menu)
			_current = p
			add_child(p)
		MODE_GAME:
			var g := Game.new()
			g.auto = auto
			g.back_pressed.connect(_return_to_menu)
			_current = g
			add_child(g)
		MODE_SHOW:
			var sh := Show.new()
			sh.start_path = _start_path
			sh.back_pressed.connect(_return_to_menu)
			_current = sh
			add_child(sh)
		MODE_STRESS:
			var s := Stress.new()
			s.back_pressed.connect(_return_to_menu)
			_current = s
			add_child(s)
			if auto:
				s.quit_when_done = true
				s.call_deferred("_start_run")
		_:
			push_error("未知的 --mode=%s" % mode)
			get_tree().quit(1)
	queue_redraw()


func _return_to_menu() -> void:
	if _current:
		_current.queue_free()
		_current = null
	_in_menu = true
	queue_redraw()


func _process(_delta: float) -> void:
	if _in_menu:
		queue_redraw()


func _draw() -> void:
	if not _in_menu:
		return
	var vp := Spec.VIEWPORT
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.027, 0.031, 0.063), true)
	var f := ThemeDB.fallback_font

	_text(f, "ORBITAL PACHINKO", Vector2(vp.x * 0.5, vp.y * 0.17), 58, Color(0.90, 0.94, 1.0), true)
	_text(f, "M1 device checks", Vector2(vp.x * 0.5, vp.y * 0.17 + 70.0), 34,
		Color(0.62, 0.70, 0.88), true)

	for b in _buttons:
		var r: Rect2 = b["rect"]
		draw_rect(r, Color(0.13, 0.17, 0.30), true)
		draw_rect(r, Color(0.52, 0.66, 1.0), false, 3.0)
		_text(f, b["title"], r.get_center() + Vector2(0.0, -20.0), 40, Color(0.90, 0.94, 1.0), true)
		_text(f, b["sub"], r.get_center() + Vector2(0.0, 40.0), 26, Color(0.62, 0.72, 0.92), true)

	_text(f, Spec.knob_label(), Vector2(vp.x * 0.5, vp.y * 0.78), 26, Color(0.58, 0.66, 0.84), true)
	_text(f, RenderingServer.get_video_adapter_name(), Vector2(vp.x * 0.5, vp.y * 0.78 + 40.0),
		24, Color(0.45, 0.52, 0.70), true)
	_text(f, "threads: %s" % ("yes" if OS.has_feature("threads") else "no"),
		Vector2(vp.x * 0.5, vp.y * 0.78 + 78.0), 24, Color(0.45, 0.52, 0.70), true)


func _text(f: Font, s: String, pos: Vector2, size_px: int, col: Color, centered: bool) -> void:
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px).x
	draw_string(f, pos + Vector2(-w * 0.5 if centered else 0.0, 0.0), s,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px, col)


func _unhandled_input(event: InputEvent) -> void:
	if not _in_menu:
		return
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		pos = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pos = (event as InputEventMouseButton).position
	else:
		return
	for b in _buttons:
		if (b["rect"] as Rect2).has_point(pos):
			_launch(b["mode"], false)
			return
