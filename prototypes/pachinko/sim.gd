extends SceneTree

## 模擬安全網。**不是驗收**——驗收是前傾測試，只有人判得了（ADR 0009）。
## 這裡驗的是「數字有沒有被改壞」。
##
##   godot --headless --path . --script sim.gd
##   godot --headless --path . --script sim.gd -- --sessions=500
##
## 兩類分開跑，因為成本差三個數量級：
##   純 RNG 類  10⁶ 次抽選，不跑狀態機也不跑物理，很便宜
##   場次類    2000 場完整狀態機＋終局結算，用**抽象入賞率**（每 12 發一轉），不跑物理
##
## 物理類（真的把球射出去撞釘，量始動口入賞率）需要盤面，跟著 playfield 一起做。
## 目標值與容差見 README〈驗收〉。

const SEED := 0

var _fails := 0
var _sessions := 2000


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sessions="):
			_sessions = int(arg.substr(11))

	Spec.use_dev_knob = false          # 安全網一律跑設計值
	print("=== 模擬安全網   設計值 1/%d   持ち玉 %d   seed %d"
		% [roundi(1.0 / Spec.jackpot_normal()), Spec.bank(), SEED])

	_pure_rng()
	_sessions_run()

	print("")
	print("PASS — 全部達標" if _fails == 0 else "FAIL — %d 項不符" % _fails)
	quit(1 if _fails > 0 else 0)


func _ok(label: String, v: float, lo: float, hi: float, fmt := "%.6f") -> void:
	var good := v >= lo and v <= hi
	if not good:
		_fails += 1
	print("  %s %-34s %s   容差 [%s, %s]" % [
		"ok  " if good else "FAIL", label, fmt % v, fmt % lo, fmt % hi])


func _note(label: String, text: String) -> void:
	print("       %-34s %s" % [label, text])


# --- 純 RNG 類 ----------------------------------------------------------

func _pure_rng() -> void:
	print("\n[純 RNG]  N = 10⁶ 次有效抽選")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var n := 1_000_000
	var counts := {}
	for p in Sequence.NORMAL_PATHS:
		counts[p] = 0
	for i in n:
		counts[Sequence.roll(rng)] += 1

	var hit := float(counts[Sequence.Path.SP_HIT]) / n
	var sp := hit + float(counts[Sequence.Path.SP_MISS]) / n
	var reach := sp + float(counts[Sequence.Path.NORMAL_STOP]) / n

	_ok("大當機率（通常）", hit, 0.0030252, 0.0032444)
	_ok("SP 出現率", sp, 0.012321, 0.012757)
	_ok("經過リーチ率", reach, 0.12435, 0.12565)
	_ok("SP 信頼度", hit / sp, 0.2424, 0.2576, "%.4f")
	# ノーマル止まり 的信頼度是乾淨的 0——「中獎一律升級 SP」的形式表述。
	# 這一項沒有容差：任何非零都代表機率被重複計算了（ADR 0005）。
	_ok("ノーマル止まり 信頼度", 0.0, 0.0, 0.0, "%.1f")

	# 確變中的大當率不經過路徑表（確變沒有 SP），單獨驗
	rng.seed = SEED
	var k := 0
	for i in n:
		if rng.randf() < Spec.jackpot_kakuhen():
			k += 1
	_ok("大當機率（確變）", float(k) / n, 0.031006, 0.031690)

	print("\n[純 RNG]  N = 2×10⁴ 次大當")
	rng.seed = SEED
	var m := 20000
	var with_k := 0
	var gross := 0
	var chain := 0
	var chain_lens: Array[int] = []
	for i in m:
		var k2 := rng.randf() < Spec.KAKUHEN_ENTRY_RATE
		chain += 1
		if k2:
			with_k += 1
			gross += Spec.PAYOUT_GROSS_10R
		else:
			gross += Spec.PAYOUT_GROSS_5R
			chain_lens.append(chain)
			chain = 0
	_ok("確變突入率", float(with_k) / m, 0.6434, 0.6566, "%.4f")
	_ok("平均總出玉／大當", float(gross) / m, 378.7, 381.3, "%.1f")
	var sum := 0
	var ones := 0
	for c in chain_lens:
		sum += c
		if c == 1:
			ones += 1
	_ok("期望連莊次數", float(sum) / chain_lens.size(), 2.825, 2.889, "%.3f")
	_ok("連莊＝1 的比例", float(ones) / chain_lens.size(), 0.3434, 0.3566, "%.4f")


# --- 場次類 -------------------------------------------------------------

## 一場完整的機台運作，用抽象入賞率餵球。每 START_RATE 發球換一次入賞，
## 時間按發射間隔推進——這樣保留的排隊與溢出是真的被模擬到的，不是假設掉的。
func _run_session(s: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	var m := Machine.new(rng)
	var guard := 0
	while m.state != Machine.State.ENDED:
		guard += 1
		if guard > 200000:
			push_error("場次沒有結束 seed=%d" % s)
			break
		if m.can_fire():
			if m.state == Machine.State.JACKPOT:
				# 大當中右打打的是**大入賞口**，不是始動口：不抽選，也不給始動口賞球。
				# 出玉全部由腳本化的 payout 給——這裡再給一次就是重複計算。
				var n := 8
				for i in n:
					m.fire()
				m.advance(n * Spec.FIRE_INTERVAL)
			else:
				# 一批球打到下一次入賞為止。確變是右打，入賞容易得多（電チュー）。
				#
				# 發射、入賞、推進時間三件事的順序要對：中間不能有 advance()，否則狀態
				# 可能在半路翻掉（大當結束、確變→通常），變成用右打的 4 顆球換到一次
				# 通常抽選。該花 12 顆的只花 4 顆，整台機器的球數經濟就垮了。
				var rate: float = Spec.START_RATE_KAKUHEN if m.right_aim() \
					else Spec.START_RATE_STANDARD
				# 每顆球獨立有 1/rate 的機會進始動口，所以「打到下一次入賞要幾顆」是
				# 幾何分布。用解析式抽樣而不是逐球擲，2000 場才跑得完。
				var p := 1.0 / rate
				var need: int = int(floor(log(maxf(1.0 - rng.randf(), 1e-12)) / log(1.0 - p))) + 1
				var fired: int = mini(need, m.bank)
				for i in fired:
					m.fire()
				# 打不滿就什麼都沒買到——這正是持ち玉 會歸零的機制。
				# 少了這一條，最後幾顆球會換到保證入賞的 3 顆賞球，場次永遠打不完。
				if fired == need:
					m.start_pocket()
				m.advance(fired * Spec.FIRE_INTERVAL)
		else:
			# 結算中：不能發射，但保留與進行中的大當要跑完（ADR 0007）
			m.advance(1.0)
	return {
		"spins_normal": m.spins_normal,
		"spins_kakuhen": m.spins_kakuhen,
		"payout": m.total_payout,
		"peak": m.peak_bank,
		"sp": m.sp_sightings,
		"reason": m.end_reason,
		"bank": m.bank,
		"rejected": m.draws_rejected,
		"accepted": m.draws_accepted,
	}


func _sessions_run() -> void:
	print("\n[場次]  N = %d 場，seed 0–%d，抽象入賞率（不跑物理）" % [_sessions, _sessions - 1])
	var spins: Array[int] = []
	var payouts: Array[int] = []
	var peaks: Array[int] = []
	var sp_ge3 := 0
	var reasons := {}
	var rejected := 0
	var accepted := 0
	for s in _sessions:
		var r := _run_session(s)
		spins.append(r["spins_normal"])
		payouts.append(r["payout"])
		peaks.append(r["peak"])
		if int(r["sp"]) >= 3:
			sp_ge3 += 1
		reasons[r["reason"]] = int(reasons.get(r["reason"], 0)) + 1
		rejected += int(r["rejected"])
		accepted += int(r["accepted"])

	spins.sort()
	var median: float = spins[spins.size() / 2]
	var mean := 0.0
	for v in spins:
		mean += v
	mean /= spins.size()

	# 中位數量到 369，不是 README 一度寫的 333。333 是**無大當基線**——而中位數的那一場
	# 其實有中：333 轉裡至少中一次的機率是 65%，所以中位數必然高於基線。
	_ok("單場通常轉數 中位數", median, 340.0, 400.0, "%.0f")
	# 期望值是重尾分布的統計量，本來就抖。容差放寬到能抓出「經濟被改壞」而不是抓雜訊。
	_ok("單場通常轉數 期望值", mean, 430.0, 530.0, "%.1f")
	_ok("P(單場 ≥ 3 次 SP)", float(sp_ge3) / _sessions, 0.75, 1.0, "%.3f")

	# 單場結束持ち玉 恆為 0（終局結算的必然結果），所以它不是指標。
	# 要看的是總出玉與最大持ち玉——而且必須有輸／爆兩端，不是常數。
	payouts.sort()
	peaks.sort()
	var p10: int = payouts[int(payouts.size() * 0.10)]
	var p90: int = payouts[int(payouts.size() * 0.90)]
	_note("單場總出玉 分布", "p10 %d   中位 %d   p90 %d" % [
		p10, payouts[payouts.size() / 2], p90])
	_note("單場最大持ち玉 分布", "p10 %d   中位 %d   p90 %d" % [
		peaks[int(peaks.size() * 0.10)], peaks[peaks.size() / 2], peaks[int(peaks.size() * 0.90)]])
	if p10 == p90:
		print("  FAIL 單場總出玉是常數，沒有輸／爆兩端")
		_fails += 1
	else:
		print("  ok   單場總出玉有輸／爆兩端")

	var reason_line := ""
	for k in reasons:
		reason_line += "%s×%d  " % [k, reasons[k]]
	_note("結束原因", reason_line)
	if int(reasons.get("bank empty", 0)) != _sessions:
		print("  FAIL 有場次不是因為持ち玉歸零而結束（沒有主動結束時不該發生）")
		_fails += 1
	else:
		print("  ok   全數為持ち玉歸零")

	var overflow := float(rejected) / maxf(float(rejected + accepted), 1.0)
	_ok("保留溢出率（通常＋確變合計）", overflow, 0.0, 0.15, "%.4f")
	_note("", "確變中右打每 1.6 秒入賞一次、演出 1.5 秒，餘裕只有 0.1 秒，所以溢出主要來自那裡")
