extends RefCounted
class_name Sequence

## 演出序列：把一條已經定案的路徑展開成一串有時刻的拍點。
##
## 這裡**只有時序，沒有畫面**。原因是 T3 要能在沒有 shader 的情況下先驗完——
## 節奏是 M3 前傾測試的三個變因之一（另外兩個是可讀性與回饋強度，見 ADR 0009），
## 而它是唯一可以用斷言驗的。畫面接上來之後，這裡仍然是唯一的時間來源。
##
## 路徑在球進始動口的瞬間就選定（ADR 0002），所以展開是純函式：同一條路徑永遠
## 得到同一串拍點，這也正是序列測試能重播的原因。

## 前四條是通常時的互斥終點，機率加總為 1（ADR 0005）。
## 後兩條只在確變中出現：確變沒有 SP，第一版的張力全押在連莊累積回饋上
## （見 ROADMAP 的已知風險）。它們不參與 path_weights，也不會被 roll() 抽到。
enum Path { STRAIGHT_MISS, NORMAL_STOP, SP_MISS, SP_HIT, KAKUHEN_SPIN, KAKUHEN_HIT }

const PATH_NAMES := {
	Path.STRAIGHT_MISS: "straight_miss",
	Path.NORMAL_STOP: "normal_stop",
	Path.SP_MISS: "sp_miss",
	Path.SP_HIT: "sp_hit",
	Path.KAKUHEN_SPIN: "kakuhen_spin",
	Path.KAKUHEN_HIT: "kakuhen_hit",
}

const NORMAL_PATHS: Array[Path] = [Path.STRAIGHT_MISS, Path.NORMAL_STOP, Path.SP_MISS, Path.SP_HIT]

## 拍點：{ at = 秒, beat = 名稱, audio = 音訊動作 }
## audio 的值：""＝不動、"cut"＝把聲音整個抽掉、其餘是要播的音名。
## 靜默是一個**被排程的事件**，不是「什麼都沒排」——它要能被量測。
static func beats(path: Path) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var t := 0.0

	# 確變中只有兩層：高速變動與三星連珠。速度是重點——1.5 秒的演出對上 1.6 秒的入賞
	# 間隔，餘裕只有 0.1 秒，所以這個數字動了就要重驗保留溢出率（README〈節奏〉）。
	if path == Path.KAKUHEN_SPIN:
		out.append({"at": 0.0, "beat": "spin_start", "audio": "mechanical"})
		out.append({"at": Spec.T_SPIN_KAKUHEN, "beat": "all_stop", "audio": ""})
		return out
	if path == Path.KAKUHEN_HIT:
		out.append({"at": 0.0, "beat": "spin_start", "audio": "mechanical"})
		out.append({"at": Spec.T_SPIN_KAKUHEN, "beat": "resolve_align", "audio": "jackpot"})
		out.append({"at": Spec.T_SPIN_KAKUHEN + Spec.T_SYZYGY, "beat": "payout_start", "audio": ""})
		return out

	# 1) 變動：三天體各自運行。四條路徑都一樣，所以到這裡玩家分不出來。
	out.append({"at": t, "beat": "spin_start", "audio": "mechanical"})
	t += Spec.T_SPIN_NORMAL

	if path == Path.STRAIGHT_MISS:
		out.append({"at": t, "beat": "all_stop", "audio": "body_stop"})
		return out

	# 2) リーチ：兩個天體鎖定連線，第三個還在轉。聲音從這裡才長出來。
	out.append({"at": t, "beat": "reach_lock", "audio": "reach_in"})
	var reach_end := t + Spec.T_REACH

	# 3) 升級窗口：第三顆天體通過目標位**之前**的 1.5 秒。
	#    ノーマル止まり 的信頼度是 0，所以這個窗口是它唯一的懸念來源。
	out.append({"at": reach_end - Spec.T_ESCALATION_WINDOW, "beat": "window_open", "audio": ""})
	t = reach_end

	if path == Path.NORMAL_STOP:
		# 窗口關了就等於這次已經死了。收尾必須俐落，否則這一段會變成
		# 「玩家已經知道輸了、卻還得看完」的段落。
		out.append({"at": t, "beat": "window_close_dead", "audio": "body_stop"})
		t += Spec.T_NORMAL_TAIL
		out.append({"at": t, "beat": "all_stop", "audio": ""})
		return out

	# 4) 黑洞接管：越出液晶邊界接管整個畫面。規則被打破的具象化。
	out.append({"at": t, "beat": "takeover_start", "audio": "sp_theme"})
	t += Spec.T_TAKEOVER

	# 5) 高潮前把聲音整個抽掉
	out.append({"at": t, "beat": "silence", "audio": "cut"})
	t += Spec.T_PRE_CLIMAX_SILENCE

	# 6) 決著：兩條 SP 路徑在這裡才分岔。
	if path == Path.SP_HIT:
		out.append({"at": t, "beat": "resolve_align", "audio": "jackpot"})
		t += Spec.T_RESOLVE
		out.append({"at": t, "beat": "syzygy", "audio": ""})
		t += Spec.T_SYZYGY
		out.append({"at": t, "beat": "payout_start", "audio": ""})
	else:
		# 落空要看得出差了多少：擦過標記之後軌道崩解，不是淡出。
		out.append({"at": t, "beat": "resolve_collapse", "audio": "collapse"})
		t += Spec.T_RESOLVE
		out.append({"at": t, "beat": "all_stop", "audio": ""})
	return out


## 演出本身的長度。最後一拍就是終點：落空是 all_stop，大當是 payout_start
## ——三星連珠那 2.0 秒是演出，payout 才是交棒之後的事。
static func duration(path: Path) -> float:
	return float(beats(path)[-1]["at"])


## 依抽選結果隨機選一條路徑。四個終點互斥，權重加總為 1（ADR 0005）。
static func roll(rng: RandomNumberGenerator) -> Path:
	var w := Spec.path_weights()
	var r := rng.randf()
	r -= float(w["straight_miss"])
	if r < 0.0:
		return Path.STRAIGHT_MISS
	r -= float(w["normal_stop"])
	if r < 0.0:
		return Path.NORMAL_STOP
	r -= float(w["sp_miss"])
	if r < 0.0:
		return Path.SP_MISS
	return Path.SP_HIT
