extends Node2D
class_name Probe

## M1 的裝置往返骨架。
##
## 它存在的唯一理由是回答 M1 出場條件的四個問題，而那四個問題**沒有一個**能在
## macOS 原生跑出答案：幀數、音訊 gesture 解鎖、Web Sample 播放模式的斜坡時序、
## 觸控發射手感。所以先做這個、先上一次手機，再回頭做演出——否則等於把
## ROADMAP 剛修掉的錯誤順序搬進 M1 重演一次。
##
## 畫面文字一律 ASCII：Godot Web 拿不到系統字型，內嵌一套 CJK 字型要好幾 MB，
## 而效能預算是設計約束（ADR 0004）。這是診斷工具，英文標籤就夠。

const BALL_RADIUS := 11.0
const NAIL_RADIUS := 5.0

signal back_pressed

## 自走模式：給影格擷取用。--write-movie 驅動不了輸入，所以驗證跑要能自己按下去。
var auto := false
var _auto_t := 0.0
var _back_button: Rect2

var _machine: Rect2
var _lcd: Rect2

var _audio_started := false
var _audio_t := -1.0
var _audio_step := -1
var _audio_log: Array[String] = []
var _player: AudioStreamPlayer

var _fire_mode_hold := true      # true=按住連發，false=點一下開始／再點停止
var _firing := false
var _fire_accum := 0.0
var _balls: Array[RigidBody2D] = []
var _pocket_hits := 0
var _fired := 0

var _fps_min := 999.0
var _fps_settle := 0

var _header: Label
var _audio_panel: Label
var _phys_panel: Label
var _tap_hint: Label
var _fire_button: Rect2
var _mode_button: Rect2
var _pocket_pos := Vector2.ZERO
var _nails: Array[Vector2] = []
var _segs: Array[PackedVector2Array] = []

# 音訊時間軸：{ at = 排定秒數, kind, label }
var _timeline: Array[Dictionary] = []


func _ready() -> void:
	_compute_layout()
	_build_audio_timeline()
	_build_playfield()
	_build_ui()
	# 所有初始 transform 都在 _ready 裡定好：--write-movie 的第一影格在 _process
	# 之前就 render，任何依賴第一個 tick 的定位都會讓 frame 0 是錯的。
	_refresh_text()
	queue_redraw()


# --- 版面 ---------------------------------------------------------------

func _compute_layout() -> void:
	var vp := Spec.VIEWPORT
	# 機台照實物 2:3 置中，上下留 HUD 帶
	var h := vp.y * 0.66
	var w := h * Spec.MACHINE_ASPECT
	if w > vp.x * 0.94:
		w = vp.x * 0.94
		h = w / Spec.MACHINE_ASPECT
	_machine = Rect2(Vector2((vp.x - w) * 0.5, vp.y * 0.15), Vector2(w, h))
	# 液晶採大液晶規格（佔盤面 65–70%）。SP 要越出這個框，所以它得是畫面上看得見
	# 的實體邊界，不是抽象概念。
	var lw := w * Spec.LCD_COVERAGE
	var lh := lw * 0.78
	_lcd = Rect2(Vector2(_machine.position.x + (w - lw) * 0.5, _machine.position.y + h * 0.10),
		Vector2(lw, lh))


# --- 音訊探測 -----------------------------------------------------------

func _build_audio_timeline() -> void:
	# 這段刻意複製混音設計的形狀：機械聲 → 聲音長出來 → 抽掉 → 爆。
	# 斜坡是重點；單發短音在 Web 上會通過，測不到 Sample 模式的限制。
	_timeline = [
		{"at": 0.0, "kind": "click", "label": "1. mechanical click (short)"},
		{"at": 0.6, "kind": "ramp_up", "label": "2. sound grows in (2.0s rising ramp)"},
		{"at": 2.6, "kind": "silence", "label": "3. cut to silence (0.5s)"},
		{"at": 3.1, "kind": "burst", "label": "4. burst"},
		{"at": 4.4, "kind": "done", "label": "-- end --"},
	]


func _start_audio() -> void:
	if _audio_started:
		return
	_audio_started = true
	_audio_t = 0.0
	_audio_step = -1
	_audio_log.clear()
	_player = AudioStreamPlayer.new()
	add_child(_player)


func _advance_audio(delta: float) -> void:
	if not _audio_started or _audio_step >= _timeline.size() - 1:
		return
	_audio_t += delta
	var next := _audio_step + 1
	var entry := _timeline[next]
	if _audio_t < float(entry["at"]):
		return
	_audio_step = next
	var drift := (_audio_t - float(entry["at"])) * 1000.0
	_audio_log.append("%s  [at %.1fs, drift %+.0fms]" % [entry["label"], entry["at"], drift])
	match entry["kind"]:
		"click":
			_player.stream = Tones.click(0.10)
			_player.play()
		"ramp_up":
			# 頻率與音量同時爬升，curve 2.0 讓後段更陡——斜坡壞掉會很明顯
			_player.stream = Tones.ramp(220.0, 880.0, 2.0, 0.12, 0.6, 2.0)
			_player.play()
		"silence":
			_player.stop()
		"burst":
			_player.stream = Tones.ramp(1200.0, 180.0, 1.2, 0.7, 0.05, 0.6)
			_player.play()
		"done":
			pass


# --- 盤面 ---------------------------------------------------------------

func _build_playfield() -> void:
	# M1 的盤面是**固定標準盤**：釘子寫死、不隨機、不校準。此時只要求球到得了
	# 始動口。把始動口入賞率校準到 12 發/轉是 M2 的事，而且是全機最花時間的一步。
	var walls := StaticBody2D.new()
	add_child(walls)
	var inset := 26.0
	var left := _machine.position.x + inset
	var right := _machine.end.x - inset
	var top := _machine.position.y + 10.0
	var bottom := _machine.end.y - 70.0
	var cx := _machine.get_center().x
	_add_seg(walls, Vector2(left, top), Vector2(left, bottom))
	_add_seg(walls, Vector2(right, top), Vector2(right, bottom))
	# 底部漏斗，讓沒進始動口的球滑掉。端點夾在機台框內。
	_add_seg(walls, Vector2(left, bottom), Vector2(cx - 80.0, bottom + 55.0))
	_add_seg(walls, Vector2(right, bottom), Vector2(cx + 80.0, bottom + 55.0))

	var nails := StaticBody2D.new()
	add_child(nails)
	var y0 := _lcd.end.y + 60.0
	var rows := 7
	var spacing := (right - left) / 9.0
	for r in rows:
		var y: float = y0 + r * spacing * 0.88
		if y > bottom - 90.0:
			break
		var x: float = left + spacing * 0.75 + (spacing * 0.5 if r % 2 == 1 else 0.0)
		while x < right - spacing * 0.4:
			# 始動口正上方留一條通道，否則球永遠到不了——M1 只要求這件事成立
			if absf(x - cx) > spacing * 0.45 or r < rows - 3:
				_add_nail(nails, Vector2(x, y))
			x += spacing

	_pocket_pos = Vector2(cx, bottom - 70.0)
	var pocket := Area2D.new()
	pocket.name = "StartPocket"
	var ps := CollisionShape2D.new()
	var pr := RectangleShape2D.new()
	pr.size = Vector2(80.0, 32.0)
	ps.shape = pr
	pocket.add_child(ps)
	pocket.position = _pocket_pos
	pocket.body_entered.connect(_on_pocket_entered)
	add_child(pocket)


func _add_seg(parent: StaticBody2D, a: Vector2, b: Vector2) -> void:
	var cs := CollisionShape2D.new()
	var seg := SegmentShape2D.new()
	seg.a = a
	seg.b = b
	cs.shape = seg
	parent.add_child(cs)
	_segs.append(PackedVector2Array([a, b]))


func _add_nail(parent: StaticBody2D, p: Vector2) -> void:
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = NAIL_RADIUS
	cs.shape = c
	cs.position = p
	parent.add_child(cs)
	_nails.append(p)


func _spawn_ball() -> void:
	var b := RigidBody2D.new()
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = BALL_RADIUS
	cs.shape = c
	b.add_child(cs)
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.30
	mat.friction = 0.08
	b.physics_material_override = mat
	b.position = Vector2(_machine.end.x - 52.0, _machine.end.y - 80.0)
	b.linear_velocity = Vector2(-80.0, -1500.0)
	add_child(b)
	_balls.append(b)
	_fired += 1


func _on_pocket_entered(body: Node) -> void:
	if body is RigidBody2D:
		_pocket_hits += 1


# --- UI -----------------------------------------------------------------

func _build_ui() -> void:
	_header = _mk_label(Vector2(24.0, 18.0), 30, Spec.VIEWPORT.x - 48.0)
	_audio_panel = _mk_label(Vector2(_lcd.position.x + 18.0, _lcd.position.y + 14.0), 22, _lcd.size.x - 36.0)
	_tap_hint = _mk_label(Vector2(_lcd.position.x, _lcd.get_center().y - 30.0), 44, _lcd.size.x)
	_tap_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phys_panel = _mk_label(Vector2(24.0, _machine.end.y + 16.0), 25, Spec.VIEWPORT.x - 48.0)

	var bw := Spec.VIEWPORT.x * 0.42
	var by := Spec.VIEWPORT.y - 150.0
	_fire_button = Rect2(Vector2(Spec.VIEWPORT.x - bw - 30.0, by), Vector2(bw, 120.0))
	_mode_button = Rect2(Vector2(30.0, by), Vector2(bw * 0.7, 120.0))
	_back_button = Rect2(Vector2(Spec.VIEWPORT.x - 190.0, 20.0), Vector2(170.0, 84.0))


func _mk_label(pos: Vector2, size_px: int, width: float) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", Color(0.82, 0.88, 1.0))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size = Vector2(width, 520.0)
	add_child(l)
	return l


# --- 迴圈 ---------------------------------------------------------------

func _process(delta: float) -> void:
	var fps := Engine.get_frames_per_second()
	_fps_settle += 1
	if _fps_settle > 45 and fps > 0.0:
		_fps_min = minf(_fps_min, fps)

	if auto:
		_auto_t += delta
		if _auto_t > 0.3 and not _audio_started:
			_start_audio()
			_firing = true
			_fire_accum = Spec.FIRE_INTERVAL

	_advance_audio(delta)

	if _firing:
		_fire_accum += delta
		while _fire_accum >= Spec.FIRE_INTERVAL:
			_fire_accum -= Spec.FIRE_INTERVAL
			_spawn_ball()

	# 回收：掉出畫面的，以及卡在漏斗角落不動的。卡住的球會一路累積下去把幀數吃掉，
	# 而幀數正是這個探測要量的東西——所以這不是潔癖，是不讓量測失真。
	for i in range(_balls.size() - 1, -1, -1):
		var b := _balls[i]
		if b.position.y > Spec.VIEWPORT.y + 120.0:
			b.queue_free()
			_balls.remove_at(i)
		elif b.linear_velocity.length() < 14.0:
			b.set_meta("still", float(b.get_meta("still", 0.0)) + delta)
			if float(b.get_meta("still")) > 1.5:
				b.queue_free()
				_balls.remove_at(i)
		else:
			b.set_meta("still", 0.0)

	_refresh_text()
	queue_redraw()


func _refresh_text() -> void:
	# 影格擷取時每格要編碼 PNG（約 10 ms），wall-clock 幀率因此永遠難看，和
	# --fixed-fps 的邏輯時間無關。標示出來，免得過幾天自己去追一個不存在的效能問題。
	var capturing := not Engine.get_write_movie_path().is_empty()
	var fps_line := "FPS (not meaningful while capturing)" if capturing else \
		"FPS %d (min %s)" % [int(Engine.get_frames_per_second()),
			"--" if _fps_min > 900.0 else str(int(_fps_min))]
	_header.text = "ORBITAL PACHINKO - M1 DEVICE PROBE\n%s / %s / threads: %s\n%s   balls on field %d\n%s" % [
		OS.get_name(),
		RenderingServer.get_video_adapter_name(),
		"yes" if OS.has_feature("threads") else "no",
		fps_line,
		_balls.size(),
		Spec.knob_label(),
	]

	if not _audio_started:
		_tap_hint.text = "TAP ANYWHERE\nto start audio test"
		_audio_panel.text = "Audio must stay silent until you touch the\nscreen. That is the gesture-unlock check."
	else:
		_tap_hint.text = ""
		var lines := ["AUDIO TIMING TEST   t=%.1fs" % _audio_t, ""]
		lines.append_array(_audio_log)
		if _audio_step >= _timeline.size() - 1:
			lines.append("")
			lines.append("LISTEN: step 2 must rise CONTINUOUSLY")
			lines.append("(not stepped, not flat). Step 3 silent.")
		_audio_panel.text = "\n".join(lines)

	_phys_panel.text = "PLAYFIELD  fired %d   start-pocket hits %d\nFIRE MODE: %s\nNails are a hardcoded standard board, not yet\ncalibrated to 12 balls/spin - that is M2." % [
		_fired, _pocket_hits,
		"hold to repeat" if _fire_mode_hold else "tap on / tap off",
	]


func _draw() -> void:
	draw_rect(_machine, Color(0.08, 0.10, 0.18), true)
	draw_rect(_machine, Color(0.30, 0.38, 0.62), false, 3.0)
	# 液晶框：SP 要越過它，所以它必須看得見
	draw_rect(_lcd, Color(0.04, 0.05, 0.11), true)
	draw_rect(_lcd, Color(0.45, 0.60, 0.95), false, 3.0)

	for s in _segs:
		draw_line(s[0], s[1], Color(0.35, 0.42, 0.62), 3.0)
	for n in _nails:
		draw_circle(n, NAIL_RADIUS, Color(0.55, 0.60, 0.72))

	draw_rect(Rect2(_pocket_pos - Vector2(40.0, 16.0), Vector2(80.0, 32.0)),
		Color(1.0, 0.72, 0.25), false, 3.0)

	for b in _balls:
		draw_circle(b.position, BALL_RADIUS, Color(0.92, 0.95, 1.0))

	_draw_button(_fire_button, "FIRE", _firing)
	_draw_button(_mode_button, "MODE", false)
	_draw_button(_back_button, "BACK", false)


func _draw_button(r: Rect2, text: String, active: bool) -> void:
	draw_rect(r, Color(0.22, 0.32, 0.56) if active else Color(0.12, 0.16, 0.28), true)
	draw_rect(r, Color(0.50, 0.64, 0.98), false, 3.0)
	var f := ThemeDB.fallback_font
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 38).x
	draw_string(f, r.get_center() + Vector2(-w * 0.5, 13.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 38, Color(0.88, 0.92, 1.0))


# --- 輸入 ---------------------------------------------------------------
# 觸控與滑鼠走同一條路徑。沒有用 InputMap action——這是試作，少一個會壞掉的
# 設定檔就少一個。

func _unhandled_input(event: InputEvent) -> void:
	var pressed := false
	var released := false
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		pressed = t.pressed
		released = not t.pressed
		pos = t.position
	elif event is InputEventMouseButton:
		var m := event as InputEventMouseButton
		if m.button_index != MOUSE_BUTTON_LEFT:
			return
		pressed = m.pressed
		released = not m.pressed
		pos = m.position
	else:
		return

	if pressed:
		if _back_button.has_point(pos):
			back_pressed.emit()
			return
		_start_audio()
		if _mode_button.has_point(pos):
			_fire_mode_hold = not _fire_mode_hold
			_firing = false
			return
		if _fire_button.has_point(pos):
			if _fire_mode_hold:
				_firing = true
			else:
				_firing = not _firing
			_fire_accum = Spec.FIRE_INTERVAL
	elif released and _fire_mode_hold:
		_firing = false
