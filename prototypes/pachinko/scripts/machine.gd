extends RefCounted
class_name Machine

## 機台的狀態機。**沒有畫面、沒有物理**——它只知道球什麼時候進了始動口。
##
## 這個分界是刻意的：模擬腳本的場次類用抽象入賞率（每 12 發一轉）餵它，遊戲用真的
## RigidBody2D 餵它，兩邊跑的是同一份狀態機。2000 場 × 480 轉若真的射球是一千萬顆
## 剛體，做不到；而分開之後，物理只需要負責一個數字——始動口入賞率（ADR 0002）。
##
## 規格見 README〈狀態與終局〉。終局結算的規則見 ADR 0007。

enum State { NORMAL, KAKUHEN, JACKPOT, ENDED }

## 畫面文字一律 ASCII——Godot Web 拿不到系統字型，內嵌 CJK 要好幾 MB（見 TODO.md）。
const STATE_NAMES := {
	State.NORMAL: "NORMAL", State.KAKUHEN: "KAKUHEN",
	State.JACKPOT: "JACKPOT", State.ENDED: "ENDED",
}

# --- 狀態 ---------------------------------------------------------------
var state: State = State.NORMAL
var bank: int
## 持ち玉 歸零後的結算期：不能發射，但飛行中的球與保留全部跑完（ADR 0007）。
var settling := false
var end_reason := ""

var pending: Array[Dictionary] = []      # 保留，上限 4
var current: Dictionary = {}             # 正在演出的那一次抽選（不佔保留）
var current_t := 0.0

## 外界要告訴機台盤面上還有沒有球在飛，否則結算不知道什麼時候算完。
var balls_in_flight := 0

# --- 連莊 ---------------------------------------------------------------
var chain_len := 0                       # 第幾連莊（含起始大當）
var chain_payout := 0                    # 本次連莊累計出玉
var _payout_left := 0
var _payout_t := 0.0
var _payout_total_t := 0.0
var _payout_with_kakuhen := false

# --- 統計（給 sim.gd）---------------------------------------------------
var spins_normal := 0
var spins_kakuhen := 0
var total_payout := 0
var peak_bank := 0
var chains: Array[int] = []
var draws_accepted := 0
var draws_rejected := 0                  # 保留滿而被拒絕的入賞
var sp_sightings := 0                    # 驗收條件的可用性檢查：一場要看得到 3 次

var _rng: RandomNumberGenerator


func _init(rng: RandomNumberGenerator) -> void:
	_rng = rng
	bank = Spec.bank()
	peak_bank = bank


# --- 外界事件 -----------------------------------------------------------

func can_fire() -> bool:
	return state != State.ENDED and not settling and bank > 0


func fire() -> void:
	if not can_fire():
		return
	bank -= 1
	if bank <= 0:
		settling = true


## 球實際進了始動口。賞球一定給——**實體入賞即給，保留滿也給**（README 機台規格）。
## 有效抽選則要保留未滿才成立，而所有機率都是對有效抽選講的，不是對入賞講的。
func start_pocket() -> void:
	if state == State.ENDED:
		return
	bank += Spec.START_POCKET_AWARD
	peak_bank = maxi(peak_bank, bank)
	if bank > 0:
		settling = false
	# 大當中右打打大入賞口，不產生抽選
	if state == State.JACKPOT:
		return
	if pending.size() >= Spec.PENDING_MAX:
		draws_rejected += 1
		return
	draws_accepted += 1
	pending.append(_draw())


func _draw() -> Dictionary:
	if state == State.KAKUHEN:
		var hit := _rng.randf() < Spec.jackpot_kakuhen()
		return {
			"hit": hit,
			"path": Sequence.Path.KAKUHEN_HIT if hit else Sequence.Path.KAKUHEN_SPIN,
		}
	# 通常：路徑和結果在同一瞬間一起選定（ADR 0002）。四個終點互斥，
	# 所以「是不是大當」直接由路徑決定，不必再擲一次。
	var p := Sequence.roll(_rng)
	return {"hit": p == Sequence.Path.SP_HIT, "path": p}


# --- 推進 ---------------------------------------------------------------

## 吃得下任意大的 delta：一次呼叫可以跑完好幾轉。模擬要跑 2000 場 × 數百轉，
## 逐幀推進在 GDScript 裡太慢，所以這裡用事件切段而不是固定步長。
func advance(delta: float) -> void:
	var guard := 0
	while delta > 0.0 and state != State.ENDED:
		guard += 1
		if guard > 100000:
			push_error("machine.advance 沒有收斂")
			return
		var step := delta
		if state == State.JACKPOT:
			step = minf(delta, _payout_total_t - _payout_t)
			_advance_payout(step)
		elif current.is_empty():
			if pending.is_empty():
				# 沒有保留可演，剩下的時間對狀態機來說什麼都不會發生
				_check_settlement()
				return
			_start_next_spin()
			step = 0.0
		else:
			step = minf(delta, Sequence.duration(current["path"]) - current_t)
			current_t += step
			if current_t >= Sequence.duration(current["path"]) - 1e-9:
				var hit: bool = current["hit"]
				current = {}
				if hit:
					_begin_jackpot()
		delta -= step
		_check_settlement()


func _start_next_spin() -> void:
	current = pending.pop_front()
	current_t = 0.0
	if state == State.KAKUHEN:
		spins_kakuhen += 1
	else:
		spins_normal += 1
	var p: int = current["path"]
	if p == Sequence.Path.SP_MISS or p == Sequence.Path.SP_HIT:
		sp_sightings += 1


func _begin_jackpot() -> void:
	# 振り分け：這次是否伴隨確變，在大當發生的當下就決定，而且**出玉多寡本身就洩漏了
	# 答案**——10R 是確變、5R 不是。所以 payout 的長度就是玩家讀到的信號。
	_payout_with_kakuhen = _rng.randf() < Spec.KAKUHEN_ENTRY_RATE
	_payout_left = Spec.PAYOUT_GROSS_10R if _payout_with_kakuhen else Spec.PAYOUT_GROSS_5R
	_payout_total_t = Spec.T_PAYOUT_10R if _payout_with_kakuhen else Spec.T_PAYOUT_5R
	_payout_t = 0.0
	state = State.JACKPOT
	chain_len += 1


## payout 是腳本化的：固定時長固定速率，和大入賞口實際接到幾顆球無關。
## 這樣物理仍然只承擔一個數字——始動口入賞率（README〈狀態與終局〉）。
func _advance_payout(delta: float) -> void:
	_payout_t += delta
	var want := int(round(float(_payout_left + _paid()) * minf(_payout_t / _payout_total_t, 1.0)))
	var give := want - _paid()
	if give > 0:
		bank += give
		chain_payout += give
		total_payout += give
		peak_bank = maxi(peak_bank, bank)
		_payout_left -= give
		if bank > 0:
			settling = false
	if _payout_t >= _payout_total_t:
		if _payout_left > 0:
			bank += _payout_left
			chain_payout += _payout_left
			total_payout += _payout_left
			_payout_left = 0
		_end_jackpot()


func _paid() -> int:
	var gross := Spec.PAYOUT_GROSS_10R if _payout_with_kakuhen else Spec.PAYOUT_GROSS_5R
	return gross - _payout_left


func _end_jackpot() -> void:
	if _payout_with_kakuhen:
		state = State.KAKUHEN
	else:
		# 連莊在這裡斷掉。記錄長度，重置累計。
		state = State.NORMAL
		chains.append(chain_len)
		chain_len = 0
		chain_payout = 0


# --- 終局結算（ADR 0007）-----------------------------------------------

func _check_settlement() -> void:
	if not settling or state == State.ENDED:
		return
	# 結算要等：飛行中的球跑完、保留演完、進行中的大當付完。
	if balls_in_flight > 0 or not pending.is_empty() or not current.is_empty() \
			or state == State.JACKPOT:
		return
	if bank > 0:
		# 賞球涓滴或大當回血都走同一條規則：還打得出球就繼續（ADR 0007）。
		settling = false
		return
	state = State.ENDED
	end_reason = "bank empty"
	if chain_len > 0:
		chains.append(chain_len)
		chain_len = 0


## 玩家主動結束。持ち玉 分布只有在這條路徑上才有意義——
## 走歸零那條的話它恆為 0，所以它不是指標（ADR 0007）。
func cash_out() -> void:
	if state == State.ENDED:
		return
	state = State.ENDED
	end_reason = "cashed out"
	if chain_len > 0:
		chains.append(chain_len)


# --- 給畫面讀 -----------------------------------------------------------

func right_aim() -> bool:
	return state == State.KAKUHEN or state == State.JACKPOT


func pending_full() -> bool:
	return pending.size() >= Spec.PENDING_MAX


func spins_total() -> int:
	return spins_normal + spins_kakuhen
