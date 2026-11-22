extends RefCounted

const AtomicFile = preload("res://addons/proto_kit/atomic_file.gd")
const EGG_PRICE := 15
const BETTA := "betta"
const CARDINAL := "cardinal"
const CARDINAL_EGG := 4
const CARDINAL_PRICE := 18
const EGG_CHOICES := [2, 1, CARDINAL_EGG]
const HATCH_SECONDS := 90
const GROW_SECONDS := 240
const MEAL_SECONDS := 60
const PAIR_SECONDS := 60
const BREED_SECONDS := 180
const TRAITS := ["普通鬥魚", "長尾鬥魚", "銀紋鬥魚", "月影鬥魚"]
const DECOR := {"grass": ["水草", 10, 1], "wood": ["沉木", 15, 1], "lamp": ["靛藍缸燈", 20, 3]}
const FEED := {
	"flake": ["薄片飼料", 6, 5, 0.095, Color("#f6c581")],
	"sinking": ["沉底顆粒", 8, 5, 0.60, Color("#d798c7")],
}
const FLOOR_LIMIT := Rect2(-5.45, -3.4, 10.9, 7.8)
const VERSION := 4

var data: Dictionary
var last_error := ""
var _path: String


func open(path: String, now: int) -> void:
	_path = path
	for candidate in [path, path + ".old"]:
		var file := FileAccess.open(candidate, FileAccess.READ)
		if file != null:
			var loaded: Variant = _upgrade(file.get_var(false))
			if _valid(loaded):
				data = loaded
				return
	if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".old"):
		last_error = "無法讀取養成進度，原存檔已保留。"
		return
	data = {
		"version": VERSION, "saved_at": now, "coins": 60, "xp": 0, "capacity": 4,
		"next_id": 1, "fish": {}, "archive": {}, "pairs": {}, "achievements": {},
		"discovered": {}, "raised": 0, "notices": [], "decor": {}, "feed": {},
	}
	_add(1, now, "juvenile")
	data.discovered[1] = now
	if _commit({}, now) == false:
		data = {}


func _upgrade(loaded: Variant) -> Variant:
	if not loaded is Dictionary:
		return loaded
	if loaded.get("version") == 1 and not _upgrade_decor(loaded):
		return loaded
	if loaded.get("version") in [1, 2] and loaded.get("fish") is Dictionary and loaded.get("archive") is Dictionary:
		for roster in [loaded.fish, loaded.archive]:
			for entry in roster.values():
				if not entry is Dictionary:
					return loaded
				entry.species = BETTA
		loaded.version = 3
	if loaded.get("version") == 3 and loaded.get("fish") is Dictionary and loaded.get("saved_at") is int:
		for entry in loaded.fish.values():
			if not entry is Dictionary or not entry.get("breed_at") is int:
				return loaded
			if entry.get("stage") == "adult":
				entry.breed_at = maxi(entry.breed_at, loaded.saved_at + PAIR_SECONDS)
		loaded.version = VERSION
	return loaded


func _upgrade_decor(loaded: Dictionary) -> bool:
	if not loaded.get("decor") is Dictionary:
		return false
	var placements := {}
	for key in loaded.decor:
		var slot: Variant = loaded.decor[key]
		if not DECOR.has(key) or not slot is int or slot not in range(4):
			return false
		if slot == 0:
			placements[key] = null
			continue
		var position := Vector2(-2.8 + (slot - 1) * 2.8, -0.41)
		if key == "wood":
			position = Vector2(-2.96 + (slot - 1) * 2.96, -0.2)
		elif key == "lamp":
			position = Vector2(2.5, -1.35)
		placements[key] = {"position": position, "yaw": 0.0}
	loaded.decor = placements
	loaded.feed = {}
	return true


func _valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("version") != VERSION:
		return false
	for key in ["saved_at", "coins", "xp", "capacity", "next_id", "raised"]:
		if not value.get(key) is int or value[key] < 0:
			return false
	if value.capacity not in [4, 8] or value.next_id < 1 or not value.get("notices") is Array:
		return false
	for key in ["fish", "archive", "pairs", "achievements", "discovered", "decor", "feed"]:
		if not value.get(key) is Dictionary:
			return false
	for key in value.feed:
		if not FEED.has(key) or not value.feed[key] is int or value.feed[key] < 1:
			return false
	for key in value.decor:
		if not DECOR.has(key):
			return false
		var placement: Variant = value.decor[key]
		if placement == null:
			continue
		if not placement is Dictionary or not placement.get("position") is Vector2 or not placement.get("yaw") is float:
			return false
		if not placement.position.is_finite() or not is_finite(placement.yaw):
			return false
	for roster in [value.fish, value.archive]:
		for id in roster:
			var entry: Variant = roster[id]
			if not id is int or not entry is Dictionary or entry.get("stage") not in ["egg", "juvenile", "adult"]:
				return false
			for key in ["traits", "born_at", "meals", "last_meal", "breed_at", "slot", "clutch", "aid_day"]:
				if not entry.get(key) is int:
					return false
			if entry.get("species") not in [BETTA, CARDINAL] or entry.traits not in range(4) or entry.slot not in range(8):
				return false
			if entry.species == CARDINAL and entry.traits != 0:
				return false
			if entry.has("egg_cost") and entry.egg_cost not in [0, EGG_PRICE, CARDINAL_PRICE]:
				return false
			if not entry.get("name") is String or not entry.get("stored") is bool or not entry.get("parents") is Array:
				return false
	var slots := {}
	for id in value.fish:
		var slot: int = value.fish[id].slot
		if slots.has(slot) or slot >= value.capacity or value.archive.has(id):
			return false
		slots[slot] = true
	for roster in [value.fish, value.archive]:
		for id in roster:
			var parents: Array = roster[id].parents
			if id < 1 or id >= value.next_id or parents.size() not in [0, 2]:
				return false
			for parent in parents:
				if not parent is int or parent >= id or (not value.fish.has(parent) and not value.archive.has(parent)):
					return false
	for notice in value.notices:
		if not notice is Dictionary or not value.fish.has(notice.get("id")) or notice.get("kind") not in ["egg", "hatch", "adult"]:
			return false
	return true


func _commit(previous: Dictionary, now: int) -> bool:
	data.saved_at = maxi(data.saved_at, now)
	var result := AtomicFile.write_var(_path, data)
	if result == OK:
		last_error = ""
		return true
	data = previous
	last_error = "暫時無法寫入存檔，請再試一次。"
	return false


func fish(id: int) -> Dictionary:
	return data.fish.get(id, data.archive.get(id, {}))


func title(entry: Dictionary) -> String:
	return entry.name if not entry.name.is_empty() else phenotype(entry)


func phenotype(entry: Dictionary) -> String:
	return "紅蓮燈" if entry.species == CARDINAL else TRAITS[entry.traits]


func egg_title(choice: int) -> String:
	return "紅蓮燈卵" if choice == CARDINAL_EGG else "%s卵" % TRAITS[choice].trim_suffix("鬥魚")


func egg_price(choice: int) -> int:
	if choice == CARDINAL_EGG:
		return CARDINAL_PRICE
	return 0 if data.fish.is_empty() and data.coins < EGG_PRICE else EGG_PRICE


func egg_unlocked(choice: int) -> bool:
	return choice in EGG_CHOICES and (choice != CARDINAL_EGG or data.achievements.has("第二代"))



func level() -> int:
	return 3 if data.xp >= 70 else (2 if data.xp >= 40 else 1)


func buy(choice: int, now: int) -> bool:
	if not egg_unlocked(choice):
		last_error = "孵出第一胎子代後解鎖紅蓮燈卵。"
		return false
	var price := egg_price(choice)
	if data.coins < price or data.fish.size() >= data.capacity:
		last_error = "需要空位與足夠金幣才能買卵。"
		return false
	var previous := data.duplicate(true)
	data.coins -= price
	var egg_id: int = data.next_id
	var cardinal := choice == CARDINAL_EGG
	_add(0 if cardinal else choice, 0, "egg", [], 0, CARDINAL if cardinal else BETTA)
	fish(egg_id).stored = true
	fish(egg_id).egg_cost = price
	return _commit(previous, now)


func incubate(id: int, now: int) -> bool:
	var entry: Dictionary = data.fish.get(id, {})
	if entry.is_empty() or entry.stage != "egg" or not entry.stored:
		last_error = "這顆卵目前無法放入孵化盤。"
		return false
	var previous := data.duplicate(true)
	entry.stored = false
	entry.born_at = now + HATCH_SECONDS
	return _commit(previous, now)


func _add(traits: int, born: int, stage: String, parents: Array = [], clutch := 0,
		species := BETTA) -> void:
	var slot := 0
	var used := {}
	for entry: Dictionary in data.fish.values():
		used[entry.slot] = true
	while used.has(slot):
		slot += 1
	data.fish[data.next_id] = {
		"species": species, "traits": traits, "born_at": born, "stage": stage, "slot": slot,
		"name": "", "stored": false, "meals": 0, "last_meal": -1,
		"breed_at": 0, "parents": parents, "clutch": clutch, "aid_day": -1,
	}
	data.next_id += 1


func can_eat(id: int, now: int) -> bool:
	var entry: Dictionary = data.fish.get(id, {})
	return (not entry.is_empty() and entry.stage != "egg" and not entry.stored
		and (entry.last_meal == -1 or now >= entry.last_meal + MEAL_SECONDS))


func feed(id: int, now: int) -> bool:
	if not can_eat(id, now):
		return false
	var previous := data.duplicate(true)
	var entry := fish(id)
	entry.meals += 1
	entry.last_meal = now
	data.xp += 2
	var day := floori(now / 86400.0)
	if data.fish.size() == 1 and data.coins < EGG_PRICE and entry.stage == "adult" and entry.aid_day != day:
		entry.aid_day = day
		data.coins += 15
	_advance(id, now)
	return _commit(previous, now)


func settle(now: int) -> bool:
	var previous: Dictionary
	# Each event consumes a stage transition or a free slot. The tank capacity bounds offline work.
	while true:
		var next_time := now + 1
		var next_id := 0
		for id: int in data.fish:
			var entry := fish(id)
			var due := -1
			if entry.stage == "egg" and not entry.stored:
				due = entry.born_at
			elif entry.stage == "juvenile" and entry.meals >= 2:
				due = maxi(entry.born_at + GROW_SECONDS, entry.last_meal)
			if due >= 0 and maxi(due, data.saved_at) < next_time:
				next_time = maxi(due, data.saved_at)
				next_id = id
		var pair := next_pair()
		var pair_due: bool = not pair.is_empty() and pair.at < next_time
		if not pair_due and next_id == 0:
			break
		if previous.is_empty():
			previous = data.duplicate(true)
		if pair_due:
			_lay_egg(pair.first, pair.second, pair.at)
		else:
			_advance(next_id, next_time)
	return not previous.is_empty() and _commit(previous, now)


func _advance(id: int, now: int) -> void:
	var entry := fish(id)
	if entry.stage == "egg" and not entry.stored and now >= entry.born_at:
		entry.stage = "juvenile"
		data.notices.append({"id": id, "kind": "hatch"})
		var discovery: int = CARDINAL_EGG if entry.species == CARDINAL else entry.traits
		if not data.discovered.has(discovery):
			data.discovered[discovery] = entry.born_at
		_award("破殼", 10, 15)
		if entry.parents.size() == 2:
			_award("第二代", 20, 30)
		if entry.species == BETTA and entry.traits == 3:
			_award("月影", 30, 40)
			if entry.parents.size() == 2 and fish(entry.parents[0]).traits == 3 and fish(entry.parents[1]).traits == 3:
				_award("穩定月影家系", 0, 0)
	if entry.stage == "juvenile" and entry.meals >= 2 and now >= entry.born_at + GROW_SECONDS:
		entry.stage = "adult"
		entry.breed_at = now + PAIR_SECONDS
		data.raised += 1
		data.coins += 5
		data.xp += 5
		data.notices.append({"id": id, "kind": "adult"})
		if data.raised >= 2:
			_award("養成一對", 15, 20)


func _award(label: String, xp: int, coins: int) -> void:
	if not data.achievements.has(label):
		data.achievements[label] = true
		data.xp += xp
		data.coins += coins


func next_pair() -> Dictionary:
	if data.fish.size() >= data.capacity:
		return {}
	var adults: Array[int] = []
	for id: int in data.fish:
		var entry := fish(id)
		if entry.stage == "adult" and not entry.stored:
			adults.append(id)
	adults.sort_custom(func(a: int, b: int) -> bool:
		var ready_a: int = fish(a).breed_at
		var ready_b: int = fish(b).breed_at
		return a < b if ready_a == ready_b else ready_a < ready_b)
	var waiting := {}
	for id in adults:
		var entry := fish(id)
		if waiting.has(entry.species):
			return {"first": waiting[entry.species], "second": id, "at": maxi(data.saved_at, entry.breed_at)}
		waiting[entry.species] = id
	return {}


func _lay_egg(a: int, b: int, now: int) -> void:
	var first := fish(a)
	var second := fish(b)
	var tail: int = first.traits if randi_range(0, 1) == 0 else second.traits
	var silver: int = first.traits if randi_range(0, 1) == 0 else second.traits
	var pair := "%d/%d" % [mini(a, b), maxi(a, b)]
	var clutch: int = data.pairs.get(pair, 0) + 1
	data.pairs[pair] = clutch
	first.breed_at = now + BREED_SECONDS
	second.breed_at = now + BREED_SECONDS
	var id: int = data.next_id
	_add((tail & 1) | (silver & 2), now + HATCH_SECONDS, "egg", [mini(a, b), maxi(a, b)], clutch, first.species)
	data.notices.append({"id": id, "kind": "egg"})


func rename_fish(id: int, title_text: String, now: int) -> bool:
	var previous := data.duplicate(true)
	fish(id).name = title_text.strip_edges().substr(0, 18)
	return _commit(previous, now)


func store_fish(id: int, stored: bool, now: int) -> bool:
	var previous := data.duplicate(true)
	var entry := fish(id)
	entry.stored = stored
	if not stored and entry.stage == "adult":
		entry.breed_at = maxi(entry.breed_at, now + PAIR_SECONDS)
	return _commit(previous, now)


func rehome(id: int, now: int) -> bool:
	var previous := data.duplicate(true)
	data.archive[id] = data.fish[id]
	data.fish.erase(id)
	for index in range(data.notices.size() - 1, -1, -1):
		if data.notices[index].id == id:
			data.notices.remove_at(index)
	return _commit(previous, now)


func dismiss_notice(index: int, now: int) -> bool:
	var previous := data.duplicate(true)
	data.notices.remove_at(index)
	return _commit(previous, now)


func expand(now: int) -> bool:
	if data.capacity >= 8 or level() < 2 or data.coins < 30:
		return false
	var previous := data.duplicate(true)
	data.coins -= 30
	data.capacity = 8
	return _commit(previous, now)


func buy_feed(key: String, now: int) -> bool:
	var item: Array = FEED[key]
	if data.coins < item[1]:
		last_error = "金幣不足，無法購買飼料。"
		return false
	var previous := data.duplicate(true)
	data.coins -= item[1]
	data.feed[key] = data.feed.get(key, 0) + item[2]
	return _commit(previous, now)


func spend_feed(key: String, now: int) -> bool:
	if data.feed.get(key, 0) <= 0:
		last_error = "這種飼料已用完。"
		return false
	var previous := data.duplicate(true)
	_take_feed(key)
	return _commit(previous, now)


func _take_feed(key: String) -> void:
	if data.feed[key] == 1:
		data.feed.erase(key)
	else:
		data.feed[key] -= 1


func resale_value(key: String, egg_id := 0) -> int:
	if key == "egg":
		var egg: Dictionary = data.fish.get(egg_id, {})
		if egg.get("stage") == "egg" and egg.stored:
			return int(egg.get("egg_cost", 0)) / 2
	elif data.feed.has(key):
		return 1
	elif data.decor.has(key):
		return int(DECOR[key][1]) / 2
	return -1


func sell_item(key: String, now: int, egg_id := 0) -> bool:
	var price := resale_value(key, egg_id)
	if price < 0:
		last_error = "這件道具已不在背包。"
		return false
	var previous := data.duplicate(true)
	if key == "egg":
		data.fish.erase(egg_id)
	elif data.feed.has(key):
		_take_feed(key)
	else:
		data.decor.erase(key)
	data.coins += price
	return _commit(previous, now)


func buy_decor(key: String, now: int) -> bool:
	var item: Array = DECOR[key]
	if data.decor.has(key):
		last_error = "這件道具已經買過了。"
		return false
	if level() < item[2] or data.coins < item[1]:
		last_error = "還沒達到解鎖等級，或金幣不足。"
		return false
	var previous := data.duplicate(true)
	data.coins -= item[1]
	data.decor[key] = null
	return _commit(previous, now)


func place_decor(key: String, position: Vector2, yaw: float, now: int) -> bool:
	if not data.decor.has(key) or not FLOOR_LIMIT.grow(0.001).has_point(position) or not is_finite(yaw):
		last_error = "請選擇魚缸內的擺放位置。"
		return false
	var previous := data.duplicate(true)
	data.decor[key] = {"position": position, "yaw": wrapf(yaw, -PI, PI)}
	return _commit(previous, now)


func remove_decor(key: String, now: int) -> bool:
	if not data.decor.has(key) or data.decor[key] == null:
		return false
	var previous := data.duplicate(true)
	data.decor[key] = null
	return _commit(previous, now)
