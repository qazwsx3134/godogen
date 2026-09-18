extends Node2D
class_name Game

## 完整的機台：盤面物理＋狀態機＋HUD＋演出。
##
## 三者的分工是刻意的——`Playfield` 只知道球撞到什麼，`Machine` 只知道球什麼時候進了
## 始動口，`Presentation` 只知道要演哪一條路徑。這條縫讓模擬腳本可以用抽象入賞率餵同一份
## 狀態機跑 2000 場（不跑物理），而遊戲用真的剛體餵它。

signal back_pressed

var _machine_rect: Rect2
var _lcd: Rect2
var _field: Playfield
var _machine: Machine
var _pres: Presentation
var _pres_key := -1

## 自走：影格擷取與釘子校準用。自動發射，並在該右打時自動切換。
var auto := false
## 釘調整（[ADR 0006]）。一場一台，重開才換。
## 驗收要跑**固定標準台**——否則「這版演出變差」和「這次抽到辛台」分不開，
## 所以 `--design`（驗收組態）會關掉抽台。
var fixed_nails := false
var _firing := false
var _fire_accum := 0.0
var _balls_fired := 0
var _show_spin_rate := false
var _rate_hold := 0.0

var _hud_top: Label
var _hud_chain: Label
var _fire_button: Rect2
var _aim_button: Rect2
var _rate_button: Rect2
var _back_button: Rect2


func _ready() -> void:
	_compute_layout()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_machine = Machine.new(rng)

	_field = Playfield.new(_machine_rect)
	if not fixed_nails:
		_field.nail_seed = randi() % 1000000
	_field.start_pocket_hit.connect(_on_start_pocket)
	add_child(_field)
	# 只印到 stdout，**不顯示在畫面上**：真機玩家看不出釘調整，他們是靠數轉數推斷的，
	# 而那個推斷入口是要按才看得到的回轉率按鈕（ADR 0006）。畫面上寫出來就破壞掉了。
	print("[nails] seed=%s  guide_mouth=%.1f" % [
		"fixed" if fixed_nails else str(_field.nail_seed), _field.guide_mouth])

	_pres = Presentation.new(_lcd)
	add_child(_pres)

	_build_hud()


func _compute_layout() -> void:
	var vp := Spec.VIEWPORT
	var h := vp.y * 0.70
	var w := h * Spec.MACHINE_ASPECT
	if w > vp.x * 0.96:
		w = vp.x * 0.96
		h = w / Spec.MACHINE_ASPECT
	_machine_rect = Rect2(Vector2((vp.x - w) * 0.5, vp.y * 0.12), Vector2(w, h))
	var lw := w * Spec.LCD_COVERAGE
	var lh := lw * 0.66
	_lcd = Rect2(Vector2(_machine_rect.position.x + (w - lw) * 0.5,
		_machine_rect.position.y + h * 0.04), Vector2(lw, lh))


func _build_hud() -> void:
	var vp := Spec.VIEWPORT
	_hud_top = _label(Vector2(22.0, 14.0), 30, vp.x - 210.0)
	_hud_chain = _label(Vector2(22.0, _machine_rect.end.y + 10.0), 28, vp.x - 44.0)
	var bw := vp.x * 0.40
	var by := vp.y - 132.0
	_fire_button = Rect2(Vector2(vp.x - bw - 24.0, by), Vector2(bw, 108.0))
	_aim_button = Rect2(Vector2(24.0, by), Vector2(bw * 0.72, 108.0))
	_rate_button = Rect2(Vector2(24.0 + bw * 0.78, by), Vector2(bw * 0.44, 108.0))
	_back_button = Rect2(Vector2(vp.x - 180.0, 16.0), Vector2(160.0, 78.0))


func _label(pos: Vector2, size_px: int, width: float) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(width, 260.0)
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", Color(0.86, 0.91, 1.0))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(l)
	return l


# --- 迴圈 ---------------------------------------------------------------

func _process(delta: float) -> void:
	# 盤面要知道現在是什麼狀態才知道哪些口是開的
	_field.big_pocket_open = _machine.state == Machine.State.JACKPOT
	_field.electric_gate_open = _machine.state == Machine.State.KAKUHEN
	_machine.balls_in_flight = _field.balls_in_flight()

	if auto:
		_firing = true
		_field.right_aim = _machine.right_aim()

	if _firing and _machine.can_fire():
		_fire_accum += delta
		while _fire_accum >= Spec.FIRE_INTERVAL and _machine.can_fire():
			_fire_accum -= Spec.FIRE_INTERVAL
			_machine.fire()
			_field.fire_ball()
			_balls_fired += 1

	_machine.advance(delta)
	_sync_presentation()
	if _rate_hold > 0.0:
		_rate_hold -= delta
		if _rate_hold <= 0.0:
			_show_spin_rate = false
	_refresh_hud()
	queue_redraw()


func _on_start_pocket() -> void:
	_machine.start_pocket()


## 狀態機是時間的權威，演出跟著它。用 current 的身分當 key，換了就重播。
func _sync_presentation() -> void:
	if _machine.current.is_empty():
		_pres_key = -1
		return
	var key: int = _machine.current.get("id", -1)
	if key == -1:
		key = _machine.spins_total()
		_machine.current["id"] = key
	if key != _pres_key:
		_pres_key = key
		_pres.restart(_machine.current["path"])


func _refresh_hud() -> void:
	var m := _machine
	var state_txt: String = Machine.STATE_NAMES[m.state]
	if m.settling:
		state_txt = "SETTLING"
	var lines := [
		"BANK %d    %s    SPINS %d" % [m.bank, state_txt, m.spins_total()],
		"PENDING %s%s" % [
			"●".repeat(m.pending.size()) + "○".repeat(Spec.PENDING_MAX - m.pending.size()),
			"   FULL - stop firing" if m.pending_full() else ""],
	]
	if _show_spin_rate:
		var per_k := 0.0 if _balls_fired == 0 else float(m.spins_normal) * 1000.0 / _balls_fired
		lines.append("SPIN RATE  %.0f spins / 1000 balls" % per_k)
	_hud_top.text = "\n".join(lines)

	# 核心賣點是連莊，所以它要在畫面上一直看得見，不是等結束才結算
	if m.chain_len > 0:
		_hud_chain.text = "CHAIN %d    +%d balls this chain" % [m.chain_len, m.chain_payout]
	elif m.state == Machine.State.ENDED:
		_hud_chain.text = "SESSION OVER (%s)    total payout %d" % [m.end_reason, m.total_payout]
	else:
		_hud_chain.text = ""


# --- 繪製 ---------------------------------------------------------------

func _draw() -> void:
	var vp := Spec.VIEWPORT
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.027, 0.031, 0.063), true)
	draw_rect(_machine_rect, Color(0.06, 0.08, 0.15), true)
	draw_rect(_machine_rect, Color(0.28, 0.36, 0.60), false, 3.0)
	draw_rect(_lcd, Color(0.03, 0.04, 0.09), true)
	draw_rect(_lcd, Color(0.42, 0.56, 0.92), false, 3.0)

	_button(_fire_button, "FIRE", _firing)
	_button(_aim_button, "RIGHT AIM" if _field.right_aim else "LEFT AIM", _field.right_aim)
	_button(_rate_button, "RATE", _show_spin_rate)
	_button(_back_button, "BACK", false)

	# 該右打了：讓玩家能把注意力留在演出上，不用自己監控狀態
	if _machine.right_aim() != _field.right_aim:
		var r := _aim_button.grow(8.0)
		var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
		draw_rect(r, Color(1.0, 0.75, 0.25, 0.35 + 0.45 * pulse), false, 5.0)


func _button(r: Rect2, text: String, active: bool) -> void:
	draw_rect(r, Color(0.22, 0.32, 0.56, 0.95) if active else Color(0.11, 0.15, 0.27, 0.95), true)
	draw_rect(r, Color(0.50, 0.64, 0.98), false, 3.0)
	var f := ThemeDB.fallback_font
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 32).x
	draw_string(f, r.get_center() + Vector2(-w * 0.5, 11.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 32, Color(0.89, 0.93, 1.0))


# --- 輸入 ---------------------------------------------------------------

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
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		pressed = mb.pressed
		released = not mb.pressed
		pos = mb.position
	else:
		return

	if pressed:
		if _back_button.has_point(pos):
			back_pressed.emit()
		elif _aim_button.has_point(pos):
			_field.right_aim = not _field.right_aim
		elif _rate_button.has_point(pos):
			# 回轉率平時不顯示：真機玩家本來也是自己數轉數估的，藏起來更忠實
			_show_spin_rate = true
			_rate_hold = 4.0
		elif _fire_button.has_point(pos):
			_firing = true
			_fire_accum = Spec.FIRE_INTERVAL
	elif released:
		_firing = false
