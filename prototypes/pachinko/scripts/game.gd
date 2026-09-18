extends Node2D
class_name Game

## 完整的機台：盤面物理＋狀態機＋HUD＋演出。
##
## 三者的分工是刻意的——`Playfield` 只知道球撞到什麼，`Machine` 只知道球什麼時候進了
## 始動口，`Presentation` 只知道要演哪一條路徑。這條縫讓模擬腳本可以用抽象入賞率餵同一份
## 狀態機跑 600 場（不跑物理），而遊戲用真的剛體餵它。

signal back_pressed

## 自走：影格擷取與釘子校準用。自動發射，並在該右打時自動把力道拉滿。
var auto := false
## 釘調整（[ADR 0006]）。一場一台，重開才換。
## 驗收要跑**固定標準台**——否則「這版演出變差」和「這次抽到辛台」分不開。
var fixed_nails := false
## 右撇子預設。左撇子把整個盤面與控制元件鏡射。
var right_handed := true

const POWER_LEFT := 0.32     # 左打的最佳力道（校準出來的）
const POWER_RIGHT := 1.0     # 右打：拉到底

var _machine_rect: Rect2
var _lcd: Rect2
var _field: Playfield
var _machine: Machine
var _pres: Presentation
var _pres_key := -1

var _firing := false
var _fire_accum := 0.0
var _balls_fired := 0
var _show_spin_rate := false
var _rate_hold := 0.0
var _drag_id := -1

var _hud_top: Label
var _hud_chain: Label
var _track: Rect2            # 力道 slider 的軌道（也是發射鍵：按住就發射）
var _hand_button: Rect2
var _rate_button: Rect2
var _back_button: Rect2


func _ready() -> void:
	_compute_layout()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_machine = Machine.new(rng)

	_field = Playfield.new(_machine_rect)
	_field.mirrored = not right_handed
	_field.power = POWER_LEFT
	if not fixed_nails:
		_field.nail_seed = randi() % 1000000
	_field.start_pocket_hit.connect(_on_start_pocket)
	add_child(_field)
	# 只印到 stdout，**不顯示在畫面上**：真機玩家看不出釘調整，他們是靠數轉數推斷的，
	# 而那個推斷入口是要按才看得到的回轉率按鈕（ADR 0006）。
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
	_machine_rect = Rect2(Vector2((vp.x - w) * 0.5, vp.y * 0.11), Vector2(w, h))
	# 液晶要讓開打出軌道：軌道沿左緣直上、到 0.31 高度處轉彎，所以液晶從 0.17 才開始，
	# 而且寬度收到 0.62——68% 的大液晶會被軌道的轉彎切到。
	var lw := w * 0.62
	var lh := lw * 0.58
	_lcd = Rect2(Vector2(_machine_rect.position.x + (w - lw) * 0.5,
		_machine_rect.position.y + h * 0.17), Vector2(lw, lh))


func _build_hud() -> void:
	var vp := Spec.VIEWPORT
	_hud_top = _label(Vector2(22.0, 12.0), 29, vp.x - 210.0)
	_hud_chain = _label(Vector2(22.0, _machine_rect.end.y + 8.0), 27, vp.x - 44.0)
	_back_button = Rect2(Vector2(vp.x - 180.0, 14.0), Vector2(160.0, 74.0))

	# 手把在右下角（右撇子）。軌道**往外拉力道越大**——外側就是機台邊緣那一側，
	# 和真機轉動手把的方向一致。
	var ty := vp.y - 150.0
	var tw := vp.x * 0.56
	var tx: float = vp.x - tw - 26.0 if right_handed else 26.0
	_track = Rect2(Vector2(tx, ty), Vector2(tw, 124.0))
	var bw := (vp.x - tw - 78.0) * 0.5
	var bx: float = 26.0 if right_handed else vp.x - 26.0 - bw * 2.0 - 12.0
	_rate_button = Rect2(Vector2(bx, ty), Vector2(bw, 124.0))
	_hand_button = Rect2(Vector2(bx + bw + 12.0, ty), Vector2(bw, 124.0))


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


# --- 力道 slider ---------------------------------------------------------
# 軌道本身就是發射鍵：按住就發射，沿著拉就改力道。和真機握著手把轉是同一個動作，
# 手機上也不用多一根手指。

func _power_from_x(x: float) -> float:
	var t: float = (x - _track.position.x) / _track.size.x
	if not right_handed:
		t = 1.0 - t
	return clampf(t, 0.0, 1.0)


func _knob_x() -> float:
	var t: float = _field.power if right_handed else 1.0 - _field.power
	return _track.position.x + t * _track.size.x


# --- 迴圈 ---------------------------------------------------------------

func _process(delta: float) -> void:
	_field.big_pocket_open = _machine.state == Machine.State.JACKPOT
	_field.electric_gate_open = _machine.state == Machine.State.KAKUHEN
	_machine.balls_in_flight = _field.balls_in_flight()

	if auto:
		_firing = true
		_field.power = POWER_RIGHT if _machine.right_aim() else POWER_LEFT

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

	_draw_track()
	_button(_rate_button, "RATE", _show_spin_rate)
	_button(_hand_button, "RH" if right_handed else "LH", false)
	_button(_back_button, "BACK", false)


func _draw_track() -> void:
	draw_rect(_track, Color(0.10, 0.13, 0.24, 0.95), true)
	draw_rect(_track, Color(0.42, 0.54, 0.86), false, 3.0)

	# 左打甜區：畫出來，因為力道是寬容的——玩家該看得到自己在不在區內，
	# 而不是靠猜。這也是「力道調不對影響小」這個決定在畫面上的體現。
	var sweet := _sweet_rect()
	draw_rect(sweet, Color(0.45, 0.95, 0.70, 0.18), true)
	draw_rect(sweet, Color(0.45, 0.95, 0.70, 0.55), false, 2.0)

	var kx := _knob_x()
	var knob := Rect2(Vector2(kx - 26.0, _track.position.y - 8.0), Vector2(52.0, _track.size.y + 16.0))
	draw_rect(knob, Color(0.30, 0.44, 0.78) if _firing else Color(0.20, 0.27, 0.45), true)
	draw_rect(knob, Color(0.62, 0.78, 1.0), false, 3.0)

	var f := ThemeDB.fallback_font
	var label := "FIRE  %d%%" % int(_field.power * 100.0)
	var w := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 28).x
	draw_string(f, _track.get_center() + Vector2(-w * 0.5, -_track.size.y * 0.5 - 14.0),
		label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 28, Color(0.86, 0.92, 1.0))

	# 該右打了：拉到底的那一端亮起來，玩家不用自己監控狀態
	if _machine.right_aim() and _field.power < 0.9:
		var end_x: float = _track.end.x if right_handed else _track.position.x
		var flag := Rect2(Vector2(end_x - (34.0 if right_handed else 0.0), _track.position.y - 8.0),
			Vector2(34.0, _track.size.y + 16.0))
		var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
		draw_rect(flag, Color(1.0, 0.75, 0.25, 0.30 + 0.45 * pulse), true)


func _sweet_rect() -> Rect2:
	var lo := POWER_LEFT - 0.10
	var hi := POWER_LEFT + 0.10
	var x0 := _track.position.x + (lo if right_handed else 1.0 - hi) * _track.size.x
	return Rect2(Vector2(x0, _track.position.y + 6.0),
		Vector2((hi - lo) * _track.size.x, _track.size.y - 12.0))


func _button(r: Rect2, text: String, active: bool) -> void:
	draw_rect(r, Color(0.22, 0.32, 0.56, 0.95) if active else Color(0.11, 0.15, 0.27, 0.95), true)
	draw_rect(r, Color(0.50, 0.64, 0.98), false, 3.0)
	var f := ThemeDB.fallback_font
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 30).x
	draw_string(f, r.get_center() + Vector2(-w * 0.5, 10.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 30, Color(0.89, 0.93, 1.0))


# --- 輸入 ---------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# 拖曳：按住軌道不放，沿著拉就改力道
	if event is InputEventScreenDrag and _drag_id == (event as InputEventScreenDrag).index:
		_field.power = _power_from_x((event as InputEventScreenDrag).position.x)
		return
	if event is InputEventMouseMotion and _drag_id == 0:
		_field.power = _power_from_x((event as InputEventMouseMotion).position.x)
		return

	var pressed := false
	var released := false
	var pos := Vector2.ZERO
	var idx := 0
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		pressed = t.pressed
		released = not t.pressed
		pos = t.position
		idx = t.index
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
		elif _hand_button.has_point(pos):
			_set_handed(not right_handed)
		elif _rate_button.has_point(pos):
			# 回轉率平時不顯示：真機玩家本來也是自己數轉數估的，藏起來更忠實
			_show_spin_rate = true
			_rate_hold = 4.0
		elif _track.grow(14.0).has_point(pos):
			_drag_id = idx
			_field.power = _power_from_x(pos.x)
			_firing = true
			_fire_accum = Spec.FIRE_INTERVAL
	elif released and idx == _drag_id:
		_drag_id = -1
		_firing = false


## 左右撇子切換。盤面要重建（鏡射是建構期的事），所以保留狀態機與持ち玉，只換盤面。
func _set_handed(rh: bool) -> void:
	right_handed = rh
	_firing = false
	_drag_id = -1
	var old_seed := _field.nail_seed
	var old_power := _field.power
	_field.queue_free()
	_field = Playfield.new(_machine_rect)
	_field.mirrored = not right_handed
	_field.nail_seed = old_seed
	_field.power = old_power
	_field.start_pocket_hit.connect(_on_start_pocket)
	add_child(_field)
	_build_hud_geometry()


func _build_hud_geometry() -> void:
	var vp := Spec.VIEWPORT
	var ty := vp.y - 150.0
	var tw := vp.x * 0.56
	var tx: float = vp.x - tw - 26.0 if right_handed else 26.0
	_track = Rect2(Vector2(tx, ty), Vector2(tw, 124.0))
	var bw := (vp.x - tw - 78.0) * 0.5
	var bx: float = 26.0 if right_handed else vp.x - 26.0 - bw * 2.0 - 12.0
	_rate_button = Rect2(Vector2(bx, ty), Vector2(bw, 124.0))
	_hand_button = Rect2(Vector2(bx + bw + 12.0, ty), Vector2(bw, 124.0))
