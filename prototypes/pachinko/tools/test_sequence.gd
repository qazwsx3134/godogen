extends SceneTree

## 序列時序的斷言測試。跑：
##   godot --headless --path . --script tools/test_sequence.gd
##
## 這是 T3 的驗收憑據。它驗的是**節奏**——前傾測試三個變因裡唯一能用斷言驗的那個
## （另外兩個是可讀性與回饋強度，只有人判得了，見 ADR 0009）。

var _fails := 0

func _init() -> void:
	_check_path_weights()
	_check_durations()
	_check_monotonic()
	_check_escalation_window()
	_check_normal_stop_tail()
	_check_silence_is_scheduled()
	_check_divergence_point()
	_check_sp_ceiling()
	_check_roll_distribution()
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


func _near(a: float, b: float) -> bool:
	return absf(a - b) < 1e-6


func _at(path: Sequence.Path, beat: String) -> float:
	for b in Sequence.beats(path):
		if b["beat"] == beat:
			return float(b["at"])
	return -1.0


# --- 互斥路徑 -----------------------------------------------------------

func _check_path_weights() -> void:
	print("路徑權重（四個終點互斥，加總必為 1）")
	for dev in [true, false]:
		Spec.use_dev_knob = dev
		var w := Spec.path_weights()
		var total := 0.0
		var all_positive := true
		for k in w:
			total += float(w[k])
			if float(w[k]) <= 0.0:
				all_positive = false
		var label := "DEV 1/99" if dev else "DESIGN 1/319"
		_ok("%s 加總 = 1" % label, _near(total, 1.0), "total=%.9f" % total)
		_ok("%s 四項皆為正" % label, all_positive)
		# SP 信頼度由大當率導出，不是自由參數
		var sp_total := float(w["sp_miss"]) + float(w["sp_hit"])
		_ok("%s SP 信頼度 = 25%%" % label,
			_near(float(w["sp_hit"]) / sp_total, Spec.SP_RELIABILITY),
			"%.6f" % (float(w["sp_hit"]) / sp_total))
		# ノーマル止まり 的信頼度是乾淨的 0——這是「中獎一律升級 SP」的形式表述
		_ok("%s 經過リーチ = 1/8" % label,
			_near(float(w["normal_stop"]) + sp_total, Spec.REACH_PASSED_RATE),
			"%.6f" % (float(w["normal_stop"]) + sp_total))
	Spec.use_dev_knob = true


# --- 時長 ---------------------------------------------------------------

func _check_durations() -> void:
	print("路徑總長（README〈節奏〉表）")
	_ok("直接落空 = 3.0", _near(Sequence.duration(Sequence.Path.STRAIGHT_MISS), 3.0))
	_ok("ノーマル止まり = 6.0", _near(Sequence.duration(Sequence.Path.NORMAL_STOP), 6.0))
	_ok("SP 落空 = 18.0", _near(Sequence.duration(Sequence.Path.SP_MISS), 18.0))
	_ok("SP 大當 = 20.0（含三星連珠）", _near(Sequence.duration(Sequence.Path.SP_HIT), 20.0))
	# 平均演出長度必須短於球間隔，否則保留會系統性堆積。
	# 兩個旋鈕都要驗：開發旋鈕的 SP 頻率是 3.2 倍，平均值會明顯高一截。
	var gap := Spec.START_RATE_STANDARD * Spec.FIRE_INTERVAL
	for dev in [false, true]:
		Spec.use_dev_knob = dev
		var w := Spec.path_weights()
		var avg := 0.0
		for p in [Sequence.Path.STRAIGHT_MISS, Sequence.Path.NORMAL_STOP,
				Sequence.Path.SP_MISS, Sequence.Path.SP_HIT]:
			avg += float(w[Sequence.PATH_NAMES[p]]) * Sequence.duration(p)
		_ok("%s 平均演出 < 球間隔" % ("DEV" if dev else "DESIGN"), avg < gap,
			"avg=%.3f  gap=%.1f" % [avg, gap])
	Spec.use_dev_knob = true


func _check_monotonic() -> void:
	print("拍點單調遞增")
	for p in [Sequence.Path.STRAIGHT_MISS, Sequence.Path.NORMAL_STOP,
			Sequence.Path.SP_MISS, Sequence.Path.SP_HIT]:
		var prev := -1.0
		var mono := true
		for b in Sequence.beats(p):
			if float(b["at"]) < prev:
				mono = false
			prev = float(b["at"])
		_ok("%s 單調" % Sequence.PATH_NAMES[p], mono)


# --- 升級窗口 -----------------------------------------------------------

func _check_escalation_window() -> void:
	print("升級窗口（ノーマル止まり 唯一的懸念來源）")
	var reach_end := Spec.T_SPIN_NORMAL + Spec.T_REACH
	for p in [Sequence.Path.NORMAL_STOP, Sequence.Path.SP_MISS, Sequence.Path.SP_HIT]:
		var open_at := _at(p, "window_open")
		_ok("%s 窗口長度 = 1.5" % Sequence.PATH_NAMES[p],
			_near(reach_end - open_at, Spec.T_ESCALATION_WINDOW),
			"open=%.2f  reach_end=%.2f" % [open_at, reach_end])
	# 窗口在三條路徑上開在同一時刻——否則玩家可以從開窗時間預判結果
	var a := _at(Sequence.Path.NORMAL_STOP, "window_open")
	var b := _at(Sequence.Path.SP_MISS, "window_open")
	var c := _at(Sequence.Path.SP_HIT, "window_open")
	_ok("三條路徑的窗口同時開", _near(a, b) and _near(b, c), "%.2f / %.2f / %.2f" % [a, b, c])


func _check_normal_stop_tail() -> void:
	print("ノーマル止まり 的收尾")
	var dead := _at(Sequence.Path.NORMAL_STOP, "window_close_dead")
	var stop := _at(Sequence.Path.NORMAL_STOP, "all_stop")
	_ok("窗口關閉後 1.0 秒內收完", _near(stop - dead, Spec.T_NORMAL_TAIL),
		"dead=%.2f  stop=%.2f" % [dead, stop])
	_ok("收尾 ≤ 1.0 秒（不讓玩家等一段已知必輸的演出）", stop - dead <= 1.0 + 1e-6)


# --- SP ------------------------------------------------------------------

func _check_silence_is_scheduled() -> void:
	print("高潮前的靜默是被排程的事件")
	for p in [Sequence.Path.SP_MISS, Sequence.Path.SP_HIT]:
		var s := _at(p, "silence")
		_ok("%s 有 silence 拍" % Sequence.PATH_NAMES[p], s > 0.0, "at=%.2f" % s)
		var has_cut := false
		for b in Sequence.beats(p):
			if b["beat"] == "silence" and b["audio"] == "cut":
				has_cut = true
		_ok("%s silence 帶 cut 動作" % Sequence.PATH_NAMES[p], has_cut)
	_ok("靜默長度 = 0.5",
		_near(_at(Sequence.Path.SP_MISS, "resolve_collapse") - _at(Sequence.Path.SP_MISS, "silence"),
			Spec.T_PRE_CLIMAX_SILENCE))


func _check_divergence_point() -> void:
	print("兩條 SP 路徑的分岔點")
	var miss := Sequence.beats(Sequence.Path.SP_MISS)
	var hit := Sequence.beats(Sequence.Path.SP_HIT)
	# 分岔前必須逐拍相同，否則玩家可以提早看出結果
	var same := true
	var diverge_at := -1.0
	for i in mini(miss.size(), hit.size()):
		if miss[i]["beat"] != hit[i]["beat"] or not _near(float(miss[i]["at"]), float(hit[i]["at"])):
			diverge_at = float(miss[i]["at"])
			break
		if miss[i]["beat"] == "silence":
			pass
	for i in mini(miss.size(), hit.size()):
		if float(miss[i]["at"]) < diverge_at and miss[i]["beat"] != hit[i]["beat"]:
			same = false
	_ok("分岔前逐拍相同", same)
	_ok("分岔點在靜默之後", _near(diverge_at, _at(Sequence.Path.SP_MISS, "resolve_collapse")),
		"diverge=%.2f" % diverge_at)
	# 落空要有崩解的秒數可演，不能以靜默收尾
	_ok("落空有 1.5 秒崩解",
		_near(_at(Sequence.Path.SP_MISS, "all_stop") - _at(Sequence.Path.SP_MISS, "resolve_collapse"),
			Spec.T_RESOLVE))


func _check_sp_ceiling() -> void:
	print("SP 總長的硬上限（保留上限 × 球間隔）")
	var ceiling := Spec.sp_length_ceiling()
	for p in [Sequence.Path.SP_MISS, Sequence.Path.SP_HIT]:
		var d := Sequence.duration(p)
		# 大當之後不再發射進保留，所以上限只約束落空那條
		if p == Sequence.Path.SP_MISS:
			_ok("SP 落空 ≤ %.1f 秒" % ceiling, d <= ceiling, "%.1f" % d)
	_ok("上限 = 19.2", _near(ceiling, 19.2), "%.1f" % ceiling)


# --- 抽樣 ---------------------------------------------------------------

func _check_roll_distribution() -> void:
	print("roll() 的分布（10^6 次，固定 seed）")
	Spec.use_dev_knob = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 0
	var n := 1_000_000
	var counts := {}
	for p in Sequence.PATH_NAMES:
		counts[p] = 0
	for i in n:
		counts[Sequence.roll(rng)] += 1
	var hit := float(counts[Sequence.Path.SP_HIT]) / n
	var sp := hit + float(counts[Sequence.Path.SP_MISS]) / n
	var reach := sp + float(counts[Sequence.Path.NORMAL_STOP]) / n
	# 容差用 README 驗收表的 95% CI
	_ok("大當機率 ∈ [0.003025, 0.003244]", hit > 0.003025 and hit < 0.003244, "%.6f (1/%.0f)" % [hit, 1.0 / hit])
	_ok("SP 出現率 ∈ [0.012321, 0.012757]", sp > 0.012321 and sp < 0.012757, "%.6f (1/%.1f)" % [sp, 1.0 / sp])
	_ok("經過リーチ ∈ [0.12435, 0.12565]", reach > 0.12435 and reach < 0.12565, "%.6f" % reach)
	_ok("SP 信頼度 ∈ [0.2424, 0.2576]", hit / sp > 0.2424 and hit / sp < 0.2576, "%.4f" % (hit / sp))
	Spec.use_dev_knob = true
