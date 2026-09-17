extends Node2D
class_name Stress

## 黑洞接管的效能壓力測試。
##
## 存在的理由：M1 的出場條件寫「黑洞接管期間 ≥ 30 fps」，但如果先把整個演出做完才去
## 量，發現不行的時候已經付掉了全部的 shader 工。更糟的是 ADR 0010 指出的那個風險——
## 把效果削薄到跑得動，然後前傾測試失敗，看起來會像「抽象幾何撐不起期待感」，
## 實際上量到的是效能地板。那是假的失敗，而且看不出來。
##
## 所以先量，再做。三個變體刻意不是三種美術風格，而是三個**成本類別**：
##
##   A  full-screen + 讀 backbuffer   → 量 TBDR GPU 的 resolve 成本
##   B  full-screen 純程序生成         → 量全螢幕 fragment 成本（沒有 resolve）
##   C  局部 quad 純程序生成           → 量便宜路徑
##
## A 和 B 的差額就是「讀螢幕」要付的錢；B 和 C 的差額是「全螢幕」要付的錢。
## 知道錢花在哪裡，才知道要不要換引擎、還是只要換寫法。

## 分成兩個量測窗，因為它們量的是**兩件不同的事**，而混在一起會得到錯的結論。
##
## 實測踩過一次：第一輪（40 球）量到 A 59/40/27、B 60/42/37；第二輪（80 球，跑過一次
## 之後）三個變體全是 60/60/60。球變多反而更快，唯一的解釋是第一輪量到的根本不是穩態
## ——shader 程式快取、Safari 的 WASM tier-up、iPhone 的時脈爬升，三個都要數秒才到位。
## 原本 0.8 秒的暖機在行動瀏覽器上遠遠不夠。
##
## 兩個窗都有意義：玩家點開連結拿到的是冷的那條路徑，之後才進穩態。
const SETTLE := 0.3      # 讓 shader 至少畫過一次
const COLD := 2.0        # 冷啟動窗：玩家剛載入時的體感
const STEADY := 4.0      # 穩態窗：真正的持續成本
const BALL_RADIUS := 11.0

enum Variant { LENSED_FULL, PROC_FULL, PROC_LOCAL }

const VARIANT_NAMES := {
	Variant.LENSED_FULL: "A  full-screen + screen read",
	Variant.PROC_FULL: "B  full-screen procedural",
	Variant.PROC_LOCAL: "C  local quad procedural",
}

signal back_pressed

var ball_load := 40
var _back_button: Rect2
## 批次跑：量完就離開。桌機拿來看 A/B/C 的比值，實機才看絕對值。
var quit_when_done := false

var _rects := {}
var _backbuffer: BackBufferCopy
var _order: Array[Variant] = [Variant.LENSED_FULL, Variant.PROC_FULL, Variant.PROC_LOCAL]
var _idx := -1
var _phase := "idle"        # idle | settle | cold | steady | done
var _phase_t := 0.0
var _t := 0.0
var _first_frame_ms := 0.0
var _samples: Array[float] = []
var _cold: Dictionary = {}
var _results := {}

var _balls: Array[RigidBody2D] = []
var _orbit_phase := 0.0

var _header: Label
var _body: Label
var _run_button: Rect2
var _load_button: Rect2


func _ready() -> void:
	# 桌機要關 vsync，否則三個變體都被壓在螢幕更新率上，量到的是「都達標」而不是
	# 各自的 GPU 成本。iOS Safari 的 rAF 關不掉（鎖 60／120），但那邊要的本來就是
	# 「撐不撐得住 30」的是非題，不是排名。
	if OS.get_name() != "Web":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		# 視窗開到螢幕塞得下的最大，逼近手機的實際像素量。fragment 成本和像素數成
		# 正比，用 432x768 量出來的結論會低估近一個數量級。
		var screen := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
		var want := Vector2i(1080, 1920)
		var scale: float = minf(float(screen.size.x) / want.x, float(screen.size.y) / want.y)
		if scale < 1.0:
			want = Vector2i(int(want.x * scale), int(want.y * scale))
		DisplayServer.window_set_size(want)
	RenderingServer.set_default_clear_color(Color(0.012, 0.014, 0.035))
	_build_background()
	_build_variants()
	_build_ui()
	_spawn_balls()
	_refresh_text()


# --- 背後的內容 ---------------------------------------------------------
# 變體 A 要有東西可以扭曲，否則讀 backbuffer 讀到的是一片黑，量到的成本會偏低。

func _build_background() -> void:
	pass  # 軌道與天體在 _draw 裡畫，位置在 _process 更新


func _spawn_balls() -> void:
	for b in _balls:
		b.queue_free()
	_balls.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var w := Spec.VIEWPORT.x
	for i in ball_load:
		var b := RigidBody2D.new()
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = BALL_RADIUS
		cs.shape = c
		b.add_child(cs)
		var mat := PhysicsMaterial.new()
		mat.bounce = 0.55
		mat.friction = 0.05
		b.physics_material_override = mat
		b.gravity_scale = 0.0
		b.position = Vector2(rng.randf_range(60.0, w - 60.0), rng.randf_range(200.0, Spec.VIEWPORT.y - 200.0))
		b.linear_velocity = Vector2(rng.randf_range(-320.0, 320.0), rng.randf_range(-320.0, 320.0))
		add_child(b)
		_balls.append(b)
	# 四面牆，讓球一直彈、負載穩定
	var walls := StaticBody2D.new()
	walls.name = "StressWalls"
	var old := get_node_or_null("StressWalls")
	if old:
		old.free()
	var r := Rect2(Vector2(30.0, 170.0), Spec.VIEWPORT - Vector2(60.0, 340.0))
	for pair in [[r.position, Vector2(r.end.x, r.position.y)],
			[Vector2(r.end.x, r.position.y), r.end],
			[r.end, Vector2(r.position.x, r.end.y)],
			[Vector2(r.position.x, r.end.y), r.position]]:
		var cs := CollisionShape2D.new()
		var seg := SegmentShape2D.new()
		seg.a = pair[0]
		seg.b = pair[1]
		cs.shape = seg
		walls.add_child(cs)
	add_child(walls)


# --- 三個變體 -----------------------------------------------------------

func _build_variants() -> void:
	# BackBufferCopy 只服務變體 A。它就是那筆要量的錢。
	_backbuffer = BackBufferCopy.new()
	_backbuffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_backbuffer.visible = false
	add_child(_backbuffer)

	var full := Rect2(Vector2.ZERO, Spec.VIEWPORT)
	# 局部 quad 取液晶框大小級距——變體 C 代表「不越界接管」的便宜做法
	var lw := Spec.VIEWPORT.x * 0.68
	var local := Rect2(Vector2((Spec.VIEWPORT.x - lw) * 0.5, Spec.VIEWPORT.y * 0.26), Vector2(lw, lw * 0.78))

	_rects[Variant.LENSED_FULL] = _mk_rect(full, BlackHoleShader.lensed())
	_rects[Variant.PROC_FULL] = _mk_rect(full, BlackHoleShader.procedural())
	_rects[Variant.PROC_LOCAL] = _mk_rect(local, BlackHoleShader.procedural())


func _mk_rect(r: Rect2, sh: Shader) -> ColorRect:
	var cr := ColorRect.new()
	cr.position = r.position
	cr.size = r.size
	cr.visible = false
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("aspect", r.size.x / r.size.y)
	mat.set_shader_parameter("bh_radius", 0.085)
	mat.set_shader_parameter("lens_strength", 0.010)
	cr.material = mat
	add_child(cr)
	return cr


func _show_only(v: int) -> void:
	for k in _rects:
		(_rects[k] as ColorRect).visible = (k == v)
	_backbuffer.visible = (v == Variant.LENSED_FULL)


# --- 量測 ---------------------------------------------------------------

func _running() -> bool:
	return _phase in ["settle", "cold", "steady"]


func _start_run() -> void:
	_results.clear()
	_idx = -1
	_next_variant()


func _next_variant() -> void:
	_idx += 1
	if _idx >= _order.size():
		_phase = "done"
		for k in _rects:
			(_rects[k] as ColorRect).visible = false
		_backbuffer.visible = false
		# 也印到 stdout：實機要看畫面，但桌機批次跑要能收結果
		var size := get_viewport().get_visible_rect().size
		print("\n=== BLACK HOLE STRESS  %s  %.0fx%.0f (%.2f Mpx)  balls=%d" % [
			OS.get_name(), size.x, size.y, size.x * size.y / 1.0e6, _balls.size()])
		for v in _order:
			if _results.has(v):
				var r: Dictionary = _results[v]
				var c: Dictionary = r.get("cold", {})
				print("%-32s STEADY avg %6.1f  p99 %5.1f  min %5.1f fps  (%5.2f ms, %5.2f ms/Mpx)   COLD avg %6.1f  min %5.1f   compile %4.0f ms" % [
					VARIANT_NAMES[v], r["avg_fps"], r["p99_fps"], r["min_fps"],
					r["avg_ms"], r["ms_per_mpx"],
					c.get("avg_fps", 0.0), c.get("min_fps", 0.0), r["compile_ms"]])
		if _results.has(Variant.LENSED_FULL) and _results.has(Variant.PROC_FULL):
			var a: float = _results[Variant.LENSED_FULL]["avg_ms"]
			var b: float = _results[Variant.PROC_FULL]["avg_ms"]
			var c: float = _results[Variant.PROC_LOCAL]["avg_ms"]
			print("讀螢幕的代價 A-B = %+.2f ms/frame   全螢幕的代價 B-C = %+.2f ms/frame" % [a - b, b - c])
		if quit_when_done:
			get_tree().quit(0)
		return
	_show_only(_order[_idx])
	_phase = "settle"
	_phase_t = 0.0
	_samples.clear()
	_cold = {}
	_first_frame_ms = 0.0


func _tick_measure(delta: float) -> void:
	_phase_t += delta
	match _phase:
		"settle":
			# 第一幀特別慢＝shader 編譯 stall。那是 iOS 上真實存在的體感成本，
			# 所以單獨記下來，不要混進平均值裡。
			if _first_frame_ms <= 0.0:
				_first_frame_ms = delta * 1000.0
			if _phase_t >= SETTLE:
				_phase = "cold"
				_phase_t = 0.0
				_samples.clear()
		"cold":
			_samples.append(delta * 1000.0)
			if _phase_t >= COLD:
				_cold = _summarize()
				_phase = "steady"
				_phase_t = 0.0
				_samples.clear()
		"steady":
			_samples.append(delta * 1000.0)
			if _phase_t >= STEADY:
				var r := _summarize()
				r["cold"] = _cold
				_results[_order[_idx]] = r
				_next_variant()


func _summarize() -> Dictionary:
	if _samples.is_empty():
		return {}
	var s := _samples.duplicate()
	s.sort()
	var total := 0.0
	for x in s:
		total += x
	var avg := total / s.size()
	# p99 的 frame time＝最差 1% 的卡頓。平均值會把它藏起來，但人感覺得到。
	var p99: float = s[mini(s.size() - 1, int(s.size() * 0.99))]
	# ms/Mpx 讓不同視窗大小、不同裝置的數字可以直接比。fragment 成本和像素數成正比，
	# 少了這個換算，桌機小視窗量出來的結論會低估近一個數量級。
	var px := Vector2(get_viewport().get_visible_rect().size)
	var mpx: float = maxf(px.x * px.y / 1.0e6, 1e-6)
	return {
		"avg_fps": 1000.0 / avg,
		"min_fps": 1000.0 / s[s.size() - 1],
		"p99_fps": 1000.0 / p99,
		"avg_ms": avg,
		"ms_per_mpx": avg / mpx,
		"mpx": mpx,
		"compile_ms": _first_frame_ms,
		"n": s.size(),
	}


# --- UI -----------------------------------------------------------------

func _build_ui() -> void:
	_header = _mk_label(Vector2(24.0, 16.0), 28)
	_body = _mk_label(Vector2(24.0, Spec.VIEWPORT.y - 560.0), 25)
	var bw := Spec.VIEWPORT.x * 0.42
	var by := Spec.VIEWPORT.y - 150.0
	_run_button = Rect2(Vector2(Spec.VIEWPORT.x - bw - 30.0, by), Vector2(bw, 120.0))
	_load_button = Rect2(Vector2(30.0, by), Vector2(bw * 0.85, 120.0))
	_back_button = Rect2(Vector2(Spec.VIEWPORT.x - 190.0, 20.0), Vector2(170.0, 84.0))


func _mk_label(pos: Vector2, size_px: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", Color(0.86, 0.91, 1.0))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	l.size = Vector2(Spec.VIEWPORT.x - pos.x - 24.0, 540.0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(l)
	return l


func _process(delta: float) -> void:
	_t += delta
	_orbit_phase += delta * 0.55
	for k in _rects:
		var m := (_rects[k] as ColorRect).material as ShaderMaterial
		m.set_shader_parameter("t", _t)
	if _phase in ["settle", "cold", "steady"]:
		_tick_measure(delta)
	_refresh_text()
	queue_redraw()


func _refresh_text() -> void:
	_header.text = "BLACK HOLE STRESS TEST\n%s / %s\nballs %d   threads %s" % [
		OS.get_name(), RenderingServer.get_video_adapter_name(), _balls.size(),
		"yes" if OS.has_feature("threads") else "no"]

	var lines: Array[String] = []
	match _phase:
		"idle":
			lines.append("Tap RUN. 3 cost classes, %.0fs cold + %.0fs steady each."
				% [COLD, STEADY])
			lines.append("")
			lines.append("A vs B  = price of reading the screen")
			lines.append("B vs C  = price of going full-screen")
		"settle", "cold", "steady":
			lines.append("RUNNING  %s" % VARIANT_NAMES[_order[_idx]])
			lines.append("%s  %.1fs" % [_phase, _phase_t])
		"done":
			lines.append("        STEADY avg/p99/min   COLD avg/min  compile")
			for v in _order:
				if _results.has(v):
					var r: Dictionary = _results[v]
					var c: Dictionary = r.get("cold", {})
					lines.append("%s\n    %.0f/%.0f/%.0f      %.0f/%.0f     %.0f ms" % [
						VARIANT_NAMES[v], r["avg_fps"], r["p99_fps"], r["min_fps"],
						c.get("avg_fps", 0.0), c.get("min_fps", 0.0), r["compile_ms"]])
			lines.append("")
			lines.append("COLD is what a player gets on first load")
			lines.append("(shader cache + WASM tier-up + clock ramp).")
			lines.append("STEADY is the sustained cost. Both matter,")
			lines.append("for different reasons. Target 30 fps.")
	_body.text = "\n".join(lines)


func _draw() -> void:
	# 軌道連珠的佔位：三個天體沿軌道跑。變體 A 要有東西可以扭曲，不然讀 backbuffer
	# 讀到一片黑，量出來的成本會偏低，測試就白做了。
	var c := Spec.VIEWPORT * 0.5
	for i in 3:
		var rad := 250.0 + i * 130.0
		draw_arc(c, rad, 0.0, TAU, 96, Color(0.30, 0.42, 0.72, 0.65), 2.5)
		var a := _orbit_phase * (1.0 + i * 0.35) + i * 2.1
		draw_circle(c + Vector2(cos(a), sin(a) * 0.82) * rad, 26.0 - i * 4.0,
			Color(0.95, 0.88, 0.70))
	for b in _balls:
		draw_circle(b.position, BALL_RADIUS, Color(0.90, 0.94, 1.0, 0.9))

	_draw_button(_run_button, "RUN" if not _running() else "...")
	_draw_button(_load_button, "BALLS %d" % ball_load)
	_draw_button(_back_button, "BACK")


func _draw_button(r: Rect2, text: String) -> void:
	draw_rect(r, Color(0.14, 0.18, 0.32, 0.92), true)
	draw_rect(r, Color(0.52, 0.66, 1.0), false, 3.0)
	var f := ThemeDB.fallback_font
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 36).x
	draw_string(f, r.get_center() + Vector2(-w * 0.5, 13.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 36, Color(0.90, 0.94, 1.0))


func _unhandled_input(event: InputEvent) -> void:
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
	elif _run_button.has_point(pos) and not _running():
		_start_run()
	elif _load_button.has_point(pos) and not _running():
		ball_load = 20 if ball_load >= 80 else ball_load * 2
		_spawn_balls()
