extends RefCounted
## 推王戰報: turns a finished push (push_sim.gd's stat_* counters) into what the result screen shows: the MVP, the
## top 3 per board (輸出, 承傷, 治療), the boss parts broken, and on a loss a diagnosis (what killed how many, which
## squad suffered, which parts were left whole) with the class to train next. Pure: reads the sim, changes nothing.

const PushSim = preload("res://domain/push_sim.gd")
const NAMES := "res://data/hero_names.json"
const TOP := 3

## Telegraphed attacks are dodged by moving; deaths to them are an operating problem, not a growth problem.
const DODGE_SHARE := 0.4


static func load_names() -> PackedStringArray:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(NAMES))
	var names := PackedStringArray()
	if data is Dictionary:
		for n: Variant in data.get("names", []):
			names.append(String(n))
	return names


static func hero_name(names: PackedStringArray, i: int) -> String:
	return names[i] if i < names.size() else "英雄%d" % (i + 1)


## {won, mvp, mvp_line, boards: [{title, rows: [{hero, name, value}]}], causes: [n per CAUSE], fallen, worst_squad,
##  broken: [part names], diagnosis: [String], train: class index or -1}
static func build(sim: PushSim, names: PackedStringArray) -> Dictionary:
	var n: int = sim.cls.size()
	var won: bool = sim.phase == PushSim.Phase.WON
	var report := {"won": won, "fallen": 0, "causes": [0, 0, 0, 0], "worst_squad": -1, "broken": [], "diagnosis": [], "train": -1}

	var sum_dealt: float = _sum(sim.stat_dealt)
	var sum_taken: float = _sum(sim.stat_taken)
	var sum_healed: float = _sum(sim.stat_healed)
	var best: int = 0
	var best_score: float = -1.0
	for i: int in n:
		var score: float = sim.stat_dealt[i] / maxf(sum_dealt, 1.0) + 0.6 * sim.stat_taken[i] / maxf(sum_taken, 1.0) \
			+ 0.8 * sim.stat_healed[i] / maxf(sum_healed, 1.0) + 0.03 * sim.stat_saves[i] + (0.01 if sim.alive(i) else 0.0)
		if score > best_score:
			best_score = score
			best = i
	report.mvp = best
	report.mvp_name = hero_name(names, best)
	report.mvp_line = _mvp_line(sim, best, sum_dealt)

	report.boards = [
		{"title": "輸出", "rows": _top(sim.stat_dealt, names)},
		{"title": "承傷", "rows": _top(sim.stat_taken, names)},
		{"title": "治療", "rows": _top(sim.stat_healed, names)},
	]

	var per_squad := PackedInt32Array()
	per_squad.resize(PushSim.SQUADS)
	for i: int in n:
		if sim.death_cause[i] >= 0:
			report.causes[sim.death_cause[i]] += 1
			report.fallen += 1
			per_squad[sim.death_squad[i]] += 1
	var worst: int = -1
	for s: int in PushSim.SQUADS:
		if per_squad[s] > 0 and (worst < 0 or per_squad[s] > per_squad[worst]):
			worst = s
	report.worst_squad = worst
	for p: int in PushSim.PART_NAMES.size():
		if sim.broken(p):
			report.broken.append(PushSim.PART_NAMES[p])
	if not won:
		_diagnose(sim, report, per_squad)
	return report


static func _diagnose(sim: PushSim, report: Dictionary, per_squad: PackedInt32Array) -> void:
	var lines: Array = report.diagnosis
	var causes: Array = report.causes
	var fallen: int = report.fallen
	var order: Array = [0, 1, 2, 3]
	order.sort_custom(func(a: int, b: int) -> bool: return causes[a] > causes[b])
	for c: int in order:
		if causes[c] > 0:
			lines.append("被「%s」打倒 %d 人" % [PushSim.CAUSE_NAMES[c], causes[c]])
	var dodgeable: int = causes[1] + causes[2] + causes[3]
	if report.worst_squad >= 0:
		lines.append("%s最慘：倒下 %d 人" % [PushSim.SQUAD_NAMES[report.worst_squad], per_squad[report.worst_squad]])
	if fallen > 0 and float(dodgeable) / fallen >= DODGE_SHARE:
		lines.append("建議：紅圈一出現就把那一團的旗子拖開，落下後按全員歸位")
	var whole := PackedStringArray()
	for p: int in [PushSim.Part.HORNS, PushSim.Part.ARM]:
		if not sim.broken(p):
			whole.append(PushSim.PART_NAMES[p])
	if not whole.is_empty():
		lines.append("建議：點王的%s讓遠程集火，打壞會讓王倒地、少一招" % "、".join(whole))
	if sim.living() == 0:
		# Worn down: front line or sustain.
		report.train = PushSim.SHIELD if causes[0] >= dodgeable else PushSim.HEALER
		lines.append("建議養成：%s（撐住王的攻擊）" % PushSim.CLASS_NAMES[report.train])
	else:
		# Time ran out: damage. The damage class whose heroes hit hardest each.
		var best: int = PushSim.SWORD
		var best_each: float = -1.0
		for c: int in [PushSim.SWORD, PushSim.SPEAR, PushSim.BOW, PushSim.MAGE]:
			var total: float = 0.0
			var count: int = 0
			for i: int in sim.cls.size():
				if sim.cls[i] == c:
					total += sim.stat_dealt[i]
					count += 1
			if count > 0 and total / count > best_each:
				best_each = total / count
				best = c
		report.train = best
		lines.append("輸出不夠：王還剩 %d%% 血" % ceili(sim.hp_ratio() * 100.0))
		lines.append("建議養成：%s（每人輸出最高）" % PushSim.CLASS_NAMES[best])


static func _mvp_line(sim: PushSim, i: int, sum_dealt: float) -> String:
	var parts := PackedStringArray()
	parts.append("%s %s" % [PushSim.RARITY_NAMES[sim.rarity[i]], PushSim.CLASS_NAMES[sim.cls[i]]])
	if sim.stat_dealt[i] > 0.0:
		parts.append("輸出 %s（%d%%）" % [short(sim.stat_dealt[i]), roundi(100.0 * sim.stat_dealt[i] / maxf(sum_dealt, 1.0))])
	if sim.stat_taken[i] > 0.0:
		parts.append("承傷 %s" % short(sim.stat_taken[i]))
	if sim.stat_healed[i] > 0.0:
		parts.append("治療 %s" % short(sim.stat_healed[i]))
	if sim.stat_saves[i] > 0:
		parts.append("救援 %d 次" % sim.stat_saves[i])
	if sim.sig_casts[i] > 0:
		parts.append("「%s」×%d" % [PushSim.SIG_NAMES[sim.sig[i]], sim.sig_casts[i]])
	return "　".join(parts)


static func _top(values: PackedFloat32Array, names: PackedStringArray) -> Array:
	var idx: Array = range(values.size())
	idx.sort_custom(func(a: int, b: int) -> bool: return values[a] > values[b])
	var rows: Array = []
	for k: int in mini(TOP, idx.size()):
		var i: int = idx[k]
		if values[i] <= 0.0:
			break
		rows.append({"hero": i, "name": hero_name(names, i), "value": short(values[i])})
	return rows


## 1234 -> "1234", 12345 -> "1.2萬".
static func short(v: float) -> String:
	return "%.1f萬" % (v / 10000.0) if v >= 10000.0 else str(roundi(v))


static func _sum(a: PackedFloat32Array) -> float:
	var s: float = 0.0
	for v: float in a:
		s += v
	return s
