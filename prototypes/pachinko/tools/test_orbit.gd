extends SceneTree

## 接管中段運動模型的斷言測試。跑：
##   godot --headless --path . --script tools/test_orbit.gd
##
## 被推翻的那一版（`sin()` 疊 drift）也**通過得了**「有幾次接近標記」這種檢查——
## 它的形狀是對的，錯的是背後沒有速度。所以這裡驗的不是形狀而是**運動學**：
## 角速度會不會隨半徑變、靠近標記時是不是真的在減速、遠離時是不是真的在加速。
## 那三件事正是正弦波給不了、而「差一點」的張力要靠的東西。

const STEPS := 1200

var _fails := 0
var _p: Presentation


func _init() -> void:
	_p = Presentation.new(Rect2(Vector2(262.0, 459.0), Vector2(555.0, 322.0)))
	root.add_child(_p)
	_p.restart(Sequence.Path.SP_MISS)

	var t0: float = _p.beat_time("takeover_start")
	var t1: float = _p.beat_time("silence")
	var ts: Array[float] = []
	var ang: Array[float] = []
	var rad: Array[float] = []
	for i in STEPS + 1:
		var u := float(i) / STEPS
		ts.append(lerpf(t0, t1, u))
		ang.append(_p.orbit_angle_at(u))
		rad.append(_p.orbit_radius_at(u))

	var dt: float = (t1 - t0) / STEPS
	var w: Array[float] = []          # 角速度
	for i in STEPS:
		w.append(absf(wrapf(ang[i + 1] - ang[i], -PI, PI)) / dt)

	_check_continuity(t0, t1)
	_check_speed_varies(w)
	_check_kepler(w, rad)
	_check_approaches(ang, rad)
	_check_decelerates_into_the_mark(ang, w)
	_check_pure_function()

	print("")
	if _fails == 0:
		print("PASS — 全部斷言通過")
	else:
		print("FAIL — %d 項不符" % _fails)
	quit(1 if _fails > 0 else 0)


func _ok(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok    %s%s" % [label, "" if detail.is_empty() else "  " + detail])
	else:
		print("  FAIL  %s%s" % [label, "" if detail.is_empty() else "  " + detail])
		_fails += 1


## 接管的頭尾要和前後段接得上，否則畫面上是一次瞬移——而瞬移正是被推翻的症狀。
func _check_continuity(t0: float, t1: float) -> void:
	print("接縫")
	var before: float = _p.third_angle_at(t0 - 0.004)
	var at: float = _p.third_angle_at(t0 + 0.004)
	var jump := absf(wrapf(at - before, -PI, PI))
	_ok("接管入口無瞬移（< 0.05 rad）", jump < 0.05, "%.4f rad" % jump)
	var last: float = _p.third_angle_at(t1 - 0.004)
	var held: float = _p.third_angle_at(t1 + 0.004)
	var jump2 := absf(wrapf(held - last, -PI, PI))
	_ok("靜默入口無瞬移（< 0.05 rad）", jump2 < 0.05, "%.4f rad" % jump2)
	_ok("遠日點半徑回到外圈（1.00）", absf(_p.orbit_radius_at(0.0) - 1.0) < 0.02,
		"%.3f" % _p.orbit_radius_at(0.0))


## 這一條是舊版過不了的那一條。等速 drift 疊正弦的角速度變化很小且和半徑無關。
func _check_speed_varies(w: Array[float]) -> void:
	print("角速度")
	var lo := INF
	var hi := 0.0
	for v in w:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	_ok("最快／最慢 ≥ 4 倍", hi / maxf(lo, 1e-6) >= 4.0, "%.2f 倍（%.3f–%.3f rad/s）" % [hi / maxf(lo, 1e-6), lo, hi])
	_ok("全程沒有倒退", lo > 0.0, "最慢 %.4f rad/s" % lo)


## 克卜勒第二定律：r²ω 是常數（同一圈內）。這是「真的在跑軌道」最硬的證據。
## 週期會衰減，所以只在單一圈內查，容差留給衰減本身。
func _check_kepler(w: Array[float], rad: Array[float]) -> void:
	print("面積速度 r²ω")
	var lo := INF
	var hi := 0.0
	# 取中間 10% 的一小段（約四分之一圈），衰減在這段裡可以忽略
	for i in range(int(STEPS * 0.45), int(STEPS * 0.55)):
		var h: float = rad[i] * rad[i] * w[i]
		lo = minf(lo, h)
		hi = maxf(hi, h)
	_ok("單段內 r²ω 近似守恆（變動 < 12%）", hi / maxf(lo, 1e-9) < 1.12,
		"%.1f%%" % ((hi / maxf(lo, 1e-9) - 1.0) * 100.0)) 


## 每一圈都要在標記附近慢下來，而且一圈比一圈近——那才是「一次比一次更差一點」。
func _check_approaches(ang: Array[float], rad: Array[float]) -> void:
	print("幾次差一步")
	var misses: Array[float] = []
	for i in range(1, STEPS):
		if rad[i] >= rad[i - 1] or rad[i] <= rad[i + 1]:
			continue                          # 只看遠日點（半徑的局部極大）
		misses.append(absf(wrapf(ang[i] - Presentation.ALIGN, -PI, PI)))
	_ok("接管中有 2–4 次接近", misses.size() >= 2 and misses.size() <= 4,
		"%d 次" % misses.size())
	var closing := true
	for i in range(1, misses.size()):
		if misses[i] > misses[i - 1] + 1e-3:
			closing = false
	_ok("一次比一次接近標記", closing,
		", ".join(misses.map(func(m: float) -> String: return "%.3f" % m)))
	if misses.size() > 0:
		_ok("最後一次仍然沒進（> 0.02 rad）", misses[misses.size() - 1] > 0.02,
			"%.3f rad" % misses[misses.size() - 1])


## 「差一點」的張力在於**真的慢下來**：最接近標記的那一刻要落在角速度的低谷。
func _check_decelerates_into_the_mark(ang: Array[float], w: Array[float]) -> void:
	print("吸附是減速")
	var best := 0
	var bestd := INF
	for i in range(int(STEPS * 0.6), STEPS):
		var d := absf(wrapf(ang[i] - Presentation.ALIGN, -PI, PI))
		if d < bestd:
			bestd = d
			best = i
	var mean := 0.0
	for v in w:
		mean += v
	mean /= w.size()
	_ok("最接近的一刻角速度低於全程平均的一半",
		w[mini(best, w.size() - 1)] < mean * 0.5,
		"%.3f vs 平均 %.3f rad/s" % [w[mini(best, w.size() - 1)], mean])


## ADR 0009：序列測試要能重播，所以位置必須是時間的純函式。
func _check_pure_function() -> void:
	print("可重播")
	var a1: float = _p.orbit_angle_at(0.37)
	for i in 50:
		_p.orbit_angle_at(randf())
	var a2: float = _p.orbit_angle_at(0.37)
	_ok("同一個 u 永遠得到同一個角度", a1 == a2, "%.9f" % a1)
