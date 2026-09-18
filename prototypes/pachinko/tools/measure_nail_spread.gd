extends SceneTree

## 釘調整的分布量測（[ADR 0006](../docs/adr/0006-nails-are-reset-each-session.md)）。
##
##   godot --headless --path . --script tools/measure_nail_spread.gd -- --seeds=20 --balls=5000
##
## 每一個 seed 是一台機器。逐台真的射球量始動口入賞率，最後看整個分布落在哪裡。
##
## 這不是「量一個值」而是「量一個分布」——ADR 0006 的兩個要求：全部落在 9.5–16.5、
## 無離群。最辛的那台仍要看得到約 3 次 SP，那是 ADR 0005 樣本數論證的底線；
## 範圍再寬就會讓釘子決定一場能不能判讀。

const BURST := 12

var _seeds := 20
var _balls := 5000
var _field: Playfield
var _seed := 0
var _fired := 0
var _hits := 0
var _results: Array[Dictionary] = []
var _t0 := 0


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			_seeds = int(arg.substr(8))
		elif arg.begins_with("--balls="):
			_balls = int(arg.substr(8))
	# 安全網一律跑設計值。跑在 1/99 開發旋鈕上的話，SP 次數會虛報成四倍。
	Spec.use_dev_knob = false
	_t0 = Time.get_ticks_msec()
	print("釘調整分布：%d 台 × %d 顆（設計值 1/%d）"
		% [_seeds, _balls, roundi(1.0 / Spec.jackpot_normal())])
	physics_frame.connect(_tick)
	_start_seed()


func _start_seed() -> void:
	var vp := Spec.VIEWPORT
	var h := vp.y * 0.70
	var w := h * Spec.MACHINE_ASPECT
	if w > vp.x * 0.96:
		w = vp.x * 0.96
		h = w / Spec.MACHINE_ASPECT
	var rect := Rect2(Vector2((vp.x - w) * 0.5, vp.y * 0.12), Vector2(w, h))
	_field = Playfield.new(rect)
	_field.nail_seed = _seed
	_field.power = 0.32
	_field.start_pocket_hit.connect(func() -> void: _hits += 1)
	root.add_child(_field)
	_fired = 0
	_hits = 0


func _tick() -> void:
	if _field == null:
		return
	for i in BURST:
		if _fired >= _balls:
			break
		_field.fire_ball()
		_fired += 1
	if _fired < _balls or _field.balls_in_flight() > 0:
		return

	var rate := 1e9 if _hits == 0 else float(_fired) / _hits
	_results.append({"seed": _seed, "mouth": _field.guide_mouth, "rate": rate, "hits": _hits})
	print("  台 %2d   開口 %.1f   入賞 %4d   %.2f 発/轉" % [_seed, _field.guide_mouth, _hits, rate])

	_field.queue_free()
	_field = null
	_seed += 1
	if _seed >= _seeds:
		_report()
		quit(0)
		return
	_start_seed()


func _report() -> void:
	var rates: Array[float] = []
	for r in _results:
		rates.append(float(r["rate"]))
	rates.sort()
	var mean := 0.0
	for v in rates:
		mean += v
	mean /= rates.size()

	print("")
	print("分布   最甘 %.2f   中位 %.2f   平均 %.2f   最辛 %.2f   （%.1f 秒）" % [
		rates[0], rates[rates.size() / 2], mean, rates[-1],
		(Time.get_ticks_msec() - _t0) / 1000.0])

	var fails := 0
	# ADR 0006：全部落在 9.5–16.5，無離群。範圍再寬就會讓釘子決定一場能不能判讀。
	for r in _results:
		var v: float = r["rate"]
		if v < 9.5 or v > 16.5:
			print("  FAIL 台 %d 落在範圍外：%.2f 発/轉" % [r["seed"], v])
			fails += 1
	if fails == 0:
		print("  ok   全部落在 9.5–16.5，無離群")
	# 平均要回到標準台，否則整批機器系統性偏甘或偏辛
	if absf(mean - 12.0) > 1.2:
		print("  FAIL 平均 %.2f 偏離標準台 12.0 太多" % mean)
		fails += 1
	else:
		print("  ok   平均 %.2f 回到標準台附近" % mean)

	# 最辛的那台仍要看得到 3 次 SP（ADR 0005 的樣本數底線）。
	# 臨界入賞率是推導出來的，不是喜好：
	#   SP ≥ 3  →  基線 ≥ 3 ÷ SP出現率  →  持ち玉 ÷ (入賞率 − 賞球) ≥ 那個轉數
	var need_spins := 3.0 / Spec.sp_rate()
	var cap := float(Spec.bank()) / need_spins + Spec.START_POCKET_AWARD
	var harsh: float = rates[-1]
	# 無大當基線＝整場沒中的保守下限。驗收的樣本數論證用的是它，不是中位數。
	var baseline_spins := float(Spec.bank()) / (harsh - Spec.START_POCKET_AWARD)
	var sp := baseline_spins * Spec.sp_rate()
	print("  底線：入賞率須 ≤ %.2f 発/轉（3 次 SP 需要 %.0f 轉基線）" % [cap, need_spins])
	print("  最辛的台 %.2f 発/轉 → 基線 %.0f 轉 → SP %.1f 次 %s" % [
		harsh, baseline_spins, sp, "ok" if sp >= 3.0 else "FAIL 破 ADR 0005 的底線"])
	if sp < 3.0:
		fails += 1

	print("")
	print("PASS" if fails == 0 else "FAIL — %d 項不符" % fails)
