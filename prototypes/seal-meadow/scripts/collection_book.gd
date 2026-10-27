extends RefCounted
## Single-player monster discoveries and claim-once achievements (S19).

const MONSTERS := [
	{"id": "slime", "name": "蓬蓬果凍", "where": "蓬蓬草原的果凍群"},
	{"id": "boar", "name": "刺莓野豬", "where": "蓬蓬草原"},
	{"id": "hound", "name": "遺跡獵犬", "where": "蓬蓬草原"},
]
const ACHIEVEMENTS := [
	{"id": "first_slime", "name": "果凍初遇", "hint": "打倒 1 隻蓬蓬果凍", "metric": "slime", "need": 1, "gold": 30, "fame": 5},
	{"id": "slime_hunter", "name": "草原守護者", "hint": "打倒 5 隻蓬蓬果凍", "metric": "slime", "need": 5, "gold": 60, "fame": 15},
	{"id": "first_quest", "name": "村子的幫手", "hint": "完成 1 個村長任務", "metric": "quests", "need": 1, "gold": 100, "fame": 10},
	{"id": "pet_evolved", "name": "蓬蓬的夥伴", "hint": "讓寵物進化到第 2 階", "metric": "pet_stage", "need": 2,
		"items": {"crystal": 2}, "fame": 20},
]
const RANKS := [
	{"at": 0, "name": "新朋友"}, {"at": 10, "name": "草原行者"},
	{"at": 25, "name": "村莊幫手"}, {"at": 50, "name": "蓬蓬夥伴"},
]

var kills := {}
var claimed: Array[String] = []


func record_kill(kind: String) -> void:
	if MONSTERS.any(func(m: Dictionary) -> bool: return m.id == kind):
		kills[kind] = mini(1000000, int(kills.get(kind, 0)) + 1)


func progress(definition: Dictionary, player: Node) -> int:
	match definition.metric:
		"quests":
			return player.quests.index
		"pet_stage":
			return player.pet.stage
		_:
			return int(kills.get(definition.metric, 0))


func fame() -> int:
	var total := 0
	for definition: Dictionary in ACHIEVEMENTS:
		if definition.id in claimed:
			total += int(definition.fame)
	return total


func rank_name() -> String:
	var name_text := String(RANKS[0].name)
	for rank: Dictionary in RANKS:
		if fame() >= rank.at:
			name_text = rank.name
	return name_text


## The bag, currency, claim and fame advance together; a full bag leaves everything untouched.
func claim(player: Node, id: String) -> String:
	var found := ACHIEVEMENTS.filter(func(a: Dictionary) -> bool: return a.id == id)
	if found.is_empty():
		return "unknown"
	if id in claimed:
		return "claimed"
	var definition: Dictionary = found[0]
	if progress(definition, player) < definition.need:
		return "not_ready"
	var trial = player.bag.duplicate_bag()
	for item: String in definition.get("items", {}):
		if not trial.add(item, int(definition.items[item])):
			return "bag_full"
	player.bag.slots = trial.slots
	player.gold += int(definition.get("gold", 0))
	claimed.append(id)
	player.stats_changed.emit()
	return ""


func to_data() -> Dictionary:
	return {"kills": kills.duplicate(), "claimed": claimed.duplicate()}


func load_data(data: Dictionary) -> void:
	kills.clear()
	claimed.clear()
	var saved_kills: Dictionary = data.get("kills", {}) if data.get("kills", {}) is Dictionary else {}
	for id: String in saved_kills:
		var n: Variant = saved_kills[id]
		if n is int or n is float:
			kills[id] = clampi(int(n), 0, 1000000)
	var saved_claims: Array = data.get("claimed", []) if data.get("claimed", []) is Array else []
	for id: Variant in saved_claims:
		if id is String and not id.is_empty() and id not in claimed:
			claimed.append(id)
