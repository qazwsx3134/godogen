extends Node2D
class_name Presentation

## 軌道連珠：把 Sequence 的拍點演成畫面。
##
## 這是整個試作真正要驗的東西。抽象幾何沒有表情，所以「差一步」的可讀性必須靠構圖明說
## ——玩家要看得出**還差多遠**、什麼時候**該期待**、以及落空時**差了多少**。
## 四件事都在 README〈差一步的視覺語法〉裡定死了，這裡是它們的實作。
##
## 所有位置都是時間的純函式，沒有累積狀態。同一條路徑、同一個時刻永遠得到同一個畫面
## ——序列測試能重播靠的就是這個（ADR 0009）。

const ALIGN := -PI * 0.5          # 連珠軸指向正上方
const SQUASH := 0.80              # 軌道壓扁成橢圓，給一點深度
## 落空時第三顆天體停在離標記多遠的地方。這個數字直接決定「差一步」讀起來是
## 「差一點點」還是「差很多」——太大就沒有懊惱，太小就分不清有沒有進去。
## 0.22 rad 在外圈上大約是一個天體的寬度：看得出沒進去，也看得出只差那麼一點。
const MISS_MARGIN := 0.22
const BODY_COLORS := [
	Color(1.00, 0.86, 0.55),
	Color(0.72, 0.88, 1.00),
	Color(1.00, 0.68, 0.78),
]

var path: int = Sequence.Path.SP_HIT

## 接管時整個軌道系統跟著放大並移到畫面中心。越界的是**演出本身**，不是背景換張圖
## ——液晶框裡的東西衝出來，那才是「規則被打破」的具象化。
const EXPAND_SCALE := 2.1

var _lcd: Rect2
var _lcd_center := Vector2.ZERO
var _base_radii: Array[float] = [0.0, 0.0, 0.0]
# 這一幀的實際幾何（接管會改變它）
var _center := Vector2.ZERO
var _radii: Array[float] = [0.0, 0.0, 0.0]
var _beats: Array[Dictionary] = []
var _t := 0.0
var _fired := {}
var _player: AudioStreamPlayer
var _takeover: ColorRect
var _shards: Array[Dictionary] = []

# 每顆天體的到位時刻。錯開比同時鎖定好讀——玩家看得到「一顆、兩顆、還差一顆」。
const LOCK_AT: Array[float] = [2.1, 3.0]


func _init(lcd: Rect2) -> void:
	_lcd = lcd
	_lcd_center = lcd.get_center()
	_center = _lcd_center
	var base: float = minf(lcd.size.x, lcd.size.y) * 0.48
	_base_radii = [base * 0.40, base * 0.70, base * 1.0]
	_radii = _base_radii.duplicate()


func _ready() -> void:
	# 繪製順序：載具的背景（z=0）→ 接管（z_as_relative 預設為真，所以 1+(-1)=0，
	# 但身為後代所以排在背景之後）→ 軌道與天體（z=1）。
	# 少了這一行，接管會被載具那張不透明的液晶底色整個蓋掉。
	z_index = 1
	_player = AudioStreamPlayer.new()
	add_child(_player)

	# 接管用的全螢幕 rect。一開始藏在液晶框內，越界是它長出去的結果。
	_takeover = ColorRect.new()
	_takeover.material = ShaderMaterial.new()
	(_takeover.material as ShaderMaterial).shader = BlackHoleShader.procedural()
	_takeover.visible = false
	_takeover.z_index = -1
	add_child(_takeover)
	# **不要在這裡自動開演。** 狀態機才是時間的權威——載入就自己播一段 SP 接管的話，
	# 一次抽選都還沒發生，整個盤面就被全螢幕蓋掉了。等 restart() 被叫才動。


func restart(p: int) -> void:
	path = p
	_beats = Sequence.beats(p)
	_t = 0.0
	_fired.clear()
	_shards.clear()
	_takeover.visible = false


func total_time() -> float:
	return Sequence.duration(path)


# --- 時間軸 -------------------------------------------------------------

func _process(delta: float) -> void:
	if _beats.is_empty():
		return                      # 閒置：還沒有任何一次抽選要演
	_t += delta
	for i in _beats.size():
		if not _fired.has(i) and _t >= float(_beats[i]["at"]):
			_fired[i] = true
			_on_beat(_beats[i])
	_update_transform()
	_update_takeover()
	var ct := _collapse_time()
	if ct > 0.0 and _t >= ct and _shards.is_empty():
		_spawn_shards()
	queue_redraw()


## 崩解的時刻。**擦過標記之後**才崩，不是同時——先崩再擦的話玩家看不到「差了多少」，
## 而那正是落空唯一要傳達的東西（README〈差一步的視覺語法〉）。
func _collapse_time() -> float:
	if path == Sequence.Path.NORMAL_STOP:
		return _beat_at("window_close_dead") + Spec.T_NORMAL_TAIL * 0.55
	if path == Sequence.Path.SP_MISS:
		return _beat_at("resolve_collapse") + Spec.T_RESOLVE * 0.72
	return -1.0


## 接管的展開程度 0→1。液晶框內是 0，全螢幕是 1。
func _expand() -> float:
	if not _is_sp():
		return 0.0
	var t0 := _beat_at("takeover_start")
	if _t < t0:
		return 0.0
	var g: float = clampf((_t - t0) / 2.0, 0.0, 1.0)
	return 1.0 - pow(1.0 - g, 3.0)


func _update_transform() -> void:
	var e := _expand()
	_center = _lcd_center.lerp(Spec.VIEWPORT * 0.5, e)
	var s := lerpf(1.0, EXPAND_SCALE, e)
	for i in 3:
		_radii[i] = _base_radii[i] * s


func _on_beat(b: Dictionary) -> void:
	var a: String = b["audio"]
	if a == "cut":
		_player.stop()
		return
	if a.is_empty():
		return
	match a:
		"mechanical": _player.stream = Tones.click(0.08, 0.30)
		"body_stop": _player.stream = Tones.click(0.14, 0.45, 14.0)
		# リーチ 進來，聲音才長出來
		"reach_in": _player.stream = Tones.ramp(180.0, 340.0, Spec.T_REACH, 0.10, 0.42, 1.4)
		# 接管：一路爬到靜默為止
		"sp_theme": _player.stream = Tones.ramp(120.0, 760.0, Spec.T_TAKEOVER, 0.16, 0.62, 2.2)
		"jackpot": _player.stream = Tones.ramp(900.0, 1500.0, 1.2, 0.72, 0.30, 0.7)
		"collapse": _player.stream = Tones.ramp(400.0, 60.0, 1.4, 0.55, 0.02, 0.8)
		_: return
	_player.play()


func _beat_at(name: String) -> float:
	for b in _beats:
		if b["beat"] == name:
			return float(b["at"])
	return -1.0


func _is_sp() -> bool:
	return path == Sequence.Path.SP_HIT or path == Sequence.Path.SP_MISS


func _wins() -> bool:
	return path == Sequence.Path.SP_HIT


# --- 天體位置（時間的純函式）-------------------------------------------

## 前兩顆：轉進連珠軸然後鎖住。ease-out 讓它們是「停下來」不是「被切掉」。
func _body_angle(i: int) -> float:
	if i < 2:
		var arrive: float = LOCK_AT[i]
		var start := PI * (0.8 + i * 0.9)
		var turns := 2.0 + i * 0.5
		if _t >= arrive:
			return ALIGN
		var x: float = clampf(_t / arrive, 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - x, 3.0)
		return start + (ALIGN + TAU * turns - start) * eased
	return _third_angle()


## 第三顆是整段演出的主角：它的位置就是「還差多遠」。
func _third_angle() -> float:
	var reach := _beat_at("reach_lock")           # 3.0
	var win_open := _beat_at("window_open")       # 3.5
	var start := PI * 0.35
	var spin_turns := 3.0

	if _t < win_open:
		# 還在跑，速度大致固定
		var x: float = _t / win_open
		return start + TAU * spin_turns * x

	var base := start + TAU * spin_turns

	if not _is_sp():
		# ノーマル止まり：窗口 1.5 秒內減速逼近標記，窗口一關就擦過去。
		var dead := _beat_at("window_close_dead")  # 5.0
		if _t < dead:
			var x: float = (_t - win_open) / (dead - win_open)
			var eased := 1.0 - pow(1.0 - x, 2.4)
			return base + _short_way(base, ALIGN - MISS_MARGIN) * eased
		# 擦過去：再滑一點點，讓「差了多少」留在畫面上
		var y: float = clampf((_t - dead) / Spec.T_NORMAL_TAIL, 0.0, 1.0)
		return ALIGN - MISS_MARGIN + MISS_MARGIN * 0.45 * (1.0 - pow(1.0 - y, 2.0))

	# SP：黑洞把軌道接管過去，第三顆在它的影響下繞行，最後才做決定性的一次逼近。
	var takeover := _beat_at("takeover_start")     # 5.0
	var silence := _beat_at("silence")             # 16.0
	var resolve := silence + Spec.T_PRE_CLIMAX_SILENCE  # 16.5

	if _t < takeover:
		var x: float = (_t - win_open) / (takeover - win_open)
		return base + _short_way(base, ALIGN - MISS_MARGIN * 1.6) * (1.0 - pow(1.0 - x, 2.4))

	if _t < silence:
		return _orbit_angle((_t - takeover) / (silence - takeover))
	if _t < resolve:
		return _orbit_angle(1.0)      # 靜默：整個凍住
	# 決著
	var z: float = clampf((_t - resolve) / Spec.T_RESOLVE, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - z, 3.0)
	var from := _orbit_angle(1.0)
	var to := ALIGN if _wins() else ALIGN - MISS_MARGIN
	return from + _short_way(from, to) * eased


## --- 接管中段的軌道運動 ---------------------------------------------
##
## 被推翻的那一版是 `sin()` 疊一個等速 drift。它做得出「幾次接近又被甩開」的形狀，
## 但天體沒有**速度**這個量——沒有近日點加速、沒有遠日點拖慢，看起來就是被瞬移，
## 而「差一點」的張力需要它真的慢下來、真的滑過去。
##
## 這一版解真的克卜勒軌道。積分是解析的：給平近點角 M 解 E − e·sinE = M（牛頓法
## 四次就收斂到畫面精度），再換成真近點角。所以位置**仍然是時間的純函式**
## ——序列測試能重播靠的就是這個（ADR 0009）——但角速度是真的隨半徑變化。
##
## 三件事同時在跑，都是為了「一圈比一圈更差一點」：
##   遠日點擺在連珠標記上 → 天體每一圈都**在標記正上方慢下來**，那就是差一步；
##   軌道進動         → 遠日點一圈比一圈更靠近標記；
##   週期衰減＋離心率變大 → 被黑洞拉得越來越急，近日點衝得越來越快。

## 遠日點離連珠標記多遠，單位是 MISS_MARGIN。從「差很多」收到「就快進去了」。
const ORBIT_APPROACH := Vector2(1.7, 0.30)
## 離心率：越大＝近日點越急、遠日點越拖。一圈比一圈極端。
const ORBIT_ECC := Vector2(0.34, 0.66)
## 軌道週期（秒）。11 秒的接管裡大約跑三圈，所以有三次「差一步」。
const ORBIT_PERIOD := Vector2(4.6, 2.6)


## 解克卜勒方程 E − e·sinE = M。牛頓法，四次。
func _eccentric_anomaly(m: float, e: float) -> float:
	var ea := m
	for i in 4:
		ea -= (ea - e * sin(ea) - m) / maxf(1.0 - e * cos(ea), 0.05)
	return ea


## 從接管開始算起的平近點角。週期隨 u 線性衰減，所以這是 1/P 的積分而不是 u/P。
func _mean_anomaly(u: float) -> float:
	var span := Spec.T_TAKEOVER
	var p0 := ORBIT_PERIOD.x
	var k := ORBIT_PERIOD.y - ORBIT_PERIOD.x
	# 從遠日點起跑（M = π），才和接管前那一段的收尾角度接得上
	if absf(k) < 0.001:
		return PI + TAU * span * u / p0
	return PI + TAU * span / k * log((p0 + k * u) / p0)


## 這一圈的近點幅角。遠日點要落在標記附近，所以 ω = 目標 − π。
func _orbit_periapsis(u: float) -> float:
	return ALIGN - MISS_MARGIN * lerpf(ORBIT_APPROACH.x, ORBIT_APPROACH.y, u) - PI


func _orbit_ecc(u: float) -> float:
	return lerpf(ORBIT_ECC.x, ORBIT_ECC.y, clampf(u, 0.0, 1.0))


func _orbit_angle(u: float) -> float:
	var uu := clampf(u, 0.0, 1.0)
	var e := _orbit_ecc(uu)
	var ea := _eccentric_anomaly(_mean_anomaly(uu), e)
	# 真近點角
	var nu := 2.0 * atan2(sqrt(1.0 + e) * sin(ea * 0.5), sqrt(1.0 - e) * cos(ea * 0.5))
	return _orbit_periapsis(uu) + nu


## 軌道半徑相對外圈的比例。遠日點正好在外圈上（標記就在那裡），近日點被黑洞拉進去。
## 有了它，「被甩開」才是真的往外飛，不是只有角度在動。
func _orbit_radius_scale(u: float) -> float:
	var uu := clampf(u, 0.0, 1.0)
	var e := _orbit_ecc(uu)
	var ea := _eccentric_anomaly(_mean_anomaly(uu), e)
	return (1.0 - e * cos(ea)) / (1.0 + e)


## 第三顆天體這一幀的半徑倍率。接管以外都是 1。
func _third_radius_scale() -> float:
	if not _is_sp():
		return 1.0
	var takeover := _beat_at("takeover_start")
	var silence := _beat_at("silence")
	if _t < takeover:
		return 1.0
	if _t < silence:
		return _orbit_radius_scale((_t - takeover) / (silence - takeover))
	var resolve := silence + Spec.T_PRE_CLIMAX_SILENCE
	var held := _orbit_radius_scale(1.0)
	if _t < resolve:
		return held
	# 決著：收回外圈，連珠才對得上
	var z: float = clampf((_t - resolve) / Spec.T_RESOLVE, 0.0, 1.0)
	return lerpf(held, 1.0, 1.0 - pow(1.0 - z, 3.0))


## 給 tools/test_orbit.gd 的量測窗口。運動模型是這個試作被推翻過一次的地方，
## 所以它要能被斷言查——而查它需要拿得到未經畫面變換的角度與半徑。
func orbit_angle_at(u: float) -> float:
	return _orbit_angle(u)


func orbit_radius_at(u: float) -> float:
	return _orbit_radius_scale(u)


func third_angle_at(t: float) -> float:
	var keep := _t
	_t = t
	var a := _third_angle()
	_t = keep
	return a


func beat_time(name: String) -> float:
	return _beat_at(name)


func _short_way(from: float, to: float) -> float:
	var d := fposmod(to - from, TAU)
	return d if d <= PI else d - TAU


func _locked(i: int) -> bool:
	if i < 2:
		return _t >= LOCK_AT[i]
	return _wins() and _t >= total_time() - Spec.T_SYZYGY - 0.001


func _body_pos(i: int) -> Vector2:
	var a := _body_angle(i)
	var r: float = _radii[i]
	if i == 2:
		r *= _third_radius_scale()
	# 鎖定時軌道環往內收束一點——那是「扣上了」的觸感
	if _locked(i):
		r *= 0.965
	return _lens(_center + Vector2(cos(a), sin(a) * SQUASH) * r)


# --- 黑洞透鏡（解析式，不讀螢幕）---------------------------------------

func _lens_strength() -> float:
	if not _is_sp():
		return 0.0
	var t0 := _beat_at("takeover_start")
	if _t < t0:
		return 0.0
	var grow: float = clampf((_t - t0) / 2.0, 0.0, 1.0)
	var fade := 1.0
	if _wins() and _t > total_time() - Spec.T_SYZYGY:
		# 三星連珠的瞬間黑洞讓位，否則對齊會被扭曲到看不出來
		fade = clampf((total_time() - _t) / Spec.T_SYZYGY, 0.0, 1.0)
	return 26000.0 * grow * fade


## 軌道是我們自己畫的，所以直接把頂點推開就好——不必去扭別人的像素。
## 這正是實機量測後選定的路徑：讀 backbuffer 那條又貴又難看。
func _lens(p: Vector2) -> Vector2:
	var s := _lens_strength()
	if s <= 0.0:
		return p
	var d := p - _center
	var r: float = maxf(d.length(), 8.0)
	return p + d / r * (s / (r * r))


# --- 接管 ---------------------------------------------------------------

func _update_takeover() -> void:
	if not _is_sp():
		return
	var t0 := _beat_at("takeover_start")
	if _t < t0:
		_takeover.visible = false
		return
	_takeover.visible = true
	# 越界：從液晶框長到整個畫面。在軌道連珠的語彙裡黑洞＝規則被打破，
	# 而演出跑出液晶框正是那件事的具象化——所以這不是排版，是信號本身。
	var e := _expand()
	var r := Rect2(_lcd.position.lerp(Vector2.ZERO, e),
		_lcd.size.lerp(Spec.VIEWPORT, e))
	_takeover.position = r.position
	_takeover.size = r.size
	var m := _takeover.material as ShaderMaterial
	m.set_shader_parameter("aspect", r.size.x / r.size.y)
	m.set_shader_parameter("t", _t)
	m.set_shader_parameter("bh_center", (_center - r.position) / r.size)
	# 視界要比最內圈軌道小，否則軌道會被吞進黑盤裡看不見——那就沒有「扭曲軌道」可言了
	m.set_shader_parameter("bh_radius", lerpf(0.02, 0.052, e))
	m.set_shader_parameter("lens_strength", lerpf(0.0, 0.010, e))


# --- 崩解 ---------------------------------------------------------------

func _spawn_shards() -> void:
	# 落空要看得出差了多少：擦過標記之後軌道崩解，不是淡出。
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	for i in 46:
		var a := rng.randf_range(0.0, TAU)
		var r: float = _radii[rng.randi_range(0, 2)] * rng.randf_range(0.94, 1.06)
		_shards.append({
			"p": _center + Vector2(cos(a), sin(a) * SQUASH) * r,
			"v": Vector2(cos(a), sin(a) * SQUASH) * rng.randf_range(40.0, 150.0),
			"born": _t,
		})


# --- 繪製 ---------------------------------------------------------------

func _draw() -> void:
	if _beats.is_empty():
		return
	_draw_orbits()
	_draw_ghost_marker()
	_draw_shards()
	_draw_bodies()
	if _wins() and _t >= total_time() - Spec.T_SYZYGY:
		_draw_syzygy()


func _draw_orbits() -> void:
	var collapsing := not _shards.is_empty()
	for i in 3:
		var pts := PackedVector2Array()
		var steps := 84
		for s in steps + 1:
			var a := TAU * float(s) / steps
			var r: float = _radii[i]
			if _locked(i):
				r *= 0.965
			pts.append(_lens(_center + Vector2(cos(a), sin(a) * SQUASH) * r))
		var col := Color(0.26, 0.34, 0.58, 0.85)
		var width := 2.0
		if _locked(i):
			# 鎖定態：軌道環變亮並收束。和還在跑的那條要一眼可分。
			col = BODY_COLORS[i]
			col.a = 0.9
			width = 4.0
		if collapsing:
			col.a *= 0.25
		draw_polyline(pts, col, width)


func _draw_ghost_marker() -> void:
	# 目標位：第三顆天體要進入的地方。玩家看得到「還差多遠」。
	if _t < _beat_at("reach_lock"):
		return
	var p := _lens(_center + Vector2(cos(ALIGN), sin(ALIGN) * SQUASH) * _radii[2])
	var win_open := _beat_at("window_open")
	var pulse := 1.0
	if _t >= win_open:
		# 升級窗口開著的時候標記在呼吸——那是「現在該期待了」的信號
		pulse = 1.0 + 0.28 * sin((_t - win_open) * 9.0)
	var col := BODY_COLORS[2]
	col.a = 0.55
	draw_arc(p, 20.0 * pulse, 0.0, TAU, 28, col, 2.5)
	draw_arc(p, 30.0 * pulse, 0.0, TAU, 28, Color(col.r, col.g, col.b, 0.2), 1.5)


func _draw_bodies() -> void:
	for i in 3:
		var p := _body_pos(i)
		var col: Color = BODY_COLORS[i]
		var rad := 15.0 - i * 1.5
		if _locked(i):
			# 鎖定：停止自轉，外圈亮起
			draw_arc(p, rad + 11.0, 0.0, TAU, 26, Color(col.r, col.g, col.b, 0.75), 3.0)
			rad *= 1.12
		draw_circle(p, rad * 2.4, Color(col.r, col.g, col.b, 0.13))
		draw_circle(p, rad, col)

	# 吸附：第三顆接近目標位時，拉一條引力線出來
	var third := _body_pos(2)
	var target := _lens(_center + Vector2(cos(ALIGN), sin(ALIGN) * SQUASH) * _radii[2])
	# 門檻跟著軌道大小走，接管放大之後才不會整條線消失
	var reach: float = _radii[2] * 1.15
	var gap := third.distance_to(target)
	if gap < reach and _shards.is_empty():
		var k: float = 1.0 - gap / reach
		draw_line(third, target, Color(BODY_COLORS[2].r, BODY_COLORS[2].g, BODY_COLORS[2].b,
			0.5 * k * k), 1.0 + 3.0 * k)


func _draw_shards() -> void:
	for s in _shards:
		var age: float = _t - float(s["born"])
		if age < 0.0:
			continue
		var a: float = clampf(1.0 - age / 1.4, 0.0, 1.0)
		var p: Vector2 = s["p"] + s["v"] * age
		draw_circle(p, 3.0 * a + 0.5, Color(0.55, 0.62, 0.85, a * 0.8))


func _draw_syzygy() -> void:
	# 三星連珠：大當在畫面上的形式。三顆對齊，軸線點亮。
	var k: float = clampf((_t - (total_time() - Spec.T_SYZYGY)) / Spec.T_SYZYGY, 0.0, 1.0)
	var flash: float = 1.0 - pow(1.0 - k, 2.0)
	var tip := _center + Vector2(cos(ALIGN), sin(ALIGN) * SQUASH) * (_radii[2] + 60.0)
	draw_line(_center, tip, Color(1.0, 0.95, 0.8, 0.85 * (1.0 - k * 0.5)), 2.0 + 10.0 * flash)
	draw_circle(_center, 30.0 + 160.0 * flash, Color(1.0, 0.94, 0.78, 0.22 * (1.0 - k)))
