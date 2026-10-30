extends "res://addons/proto_kit/test_kit.gd"
const Progression = preload("res://domain/progression.gd")
const PATH := "user://save_protection.json"

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for content: String in [JSON.stringify({"version": 99, "gold": 999999}), "{broken", "", "[]", '{"gold":99}']:
		var file := FileAccess.open(PATH, FileAccess.WRITE)
		file.store_string(content)
		file.close()
		var original := FileAccess.get_file_as_bytes(PATH)
		var progress := Progression.load_from(PATH)
		progress.gold += 123
		var result: Error = progress.save(PATH)
		_expect(result != OK and FileAccess.get_file_as_bytes(PATH) == original,
			"unreadable or newer save remains byte-for-byte intact: %s" % content)
	# A stale in-memory instance must also refuse a newly replaced future file.
	var stale := Progression.new(1)
	_write(JSON.stringify({"version": 99, "gold": 777}))
	var future_bytes := FileAccess.get_file_as_bytes(PATH)
	_expect(stale.save(PATH) != OK and FileAccess.get_file_as_bytes(PATH) == future_bytes,
		"write preflight protects a future save replaced during gameplay")
	var home: Control = (load("res://scenes/home.tscn") as PackedScene).instantiate()
	home.save_path = PATH
	root.add_child(home)
	await _frames(3)
	_expect(home.get_node("%Dialog").visible and home.get_node("%DialogTitle").text == "存檔受保護",
		"home explains that the unreadable save is protected and this session is not saved")
	home.save()
	_expect(FileAccess.get_file_as_bytes(PATH) == future_bytes, "home autosave path leaves future bytes intact")
	home.queue_free()
	await _frames(2)
	DirAccess.remove_absolute(PATH)
	var fresh := Progression.load_from(PATH)
	_expect(fresh.save_blocked_reason.is_empty() and fresh.save(PATH) == OK, "missing file still creates a normal save")
	var legacy: Dictionary = fresh.to_dict()
	legacy.version = 1
	legacy.erase("armory")
	legacy.bag = {}
	_write(JSON.stringify(legacy))
	var migrated := Progression.load_from(PATH)
	_expect(migrated.save_blocked_reason.is_empty() and migrated.save(PATH) == OK,
		"supported v1 data still migrates and saves")
	DirAccess.remove_absolute(PATH)
	_test_payload_guard()
	var invalid_live := Progression.new(2)
	invalid_live.march[0] = 100
	_expect(invalid_live.save(PATH) != OK and not FileAccess.file_exists(PATH), "invalid live state cannot create a broken save")
	DirAccess.remove_absolute(PATH)
	_finish("SAVE PROTECTION TESTS")


func _write(content: String) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(content)
	file.close()


func _test_payload_guard() -> void:
	var template := Progression.new(17)
	template.add_item(template.new_item("w0_1"))
	var cases := [
		["short hero array", func(d: Dictionary) -> void: d.hero_level.resize(99)],
		["invalid hero index", func(d: Dictionary) -> void: d.march = [100]],
		["duplicate squad member", func(d: Dictionary) -> void: d.march = [13, 13]],
		["short charm array", func(d: Dictionary) -> void: d.charm.resize(99)],
		["unknown item", func(d: Dictionary) -> void: d.bag[0].id = "c999"],
		["broken affix", func(d: Dictionary) -> void: d.bag[0].aff = [["atk"]]],
		["unknown affix", func(d: Dictionary) -> void: d.bag[0].aff = [["unknown", 0.1]]],
		["duplicate item UID", func(d: Dictionary) -> void: d.armory[0] = d.bag[0].duplicate(true)],
		["colliding next UID", func(d: Dictionary) -> void: d.next_uid = 1],
		["extra talent", func(d: Dictionary) -> void: d.talent.append(1)],
		["extra potion", func(d: Dictionary) -> void: d.potions.append(1)],
		["missing gold", func(d: Dictionary) -> void: d.erase("gold")],
		["fractional hero level", func(d: Dictionary) -> void: d.hero_level[0] = 1.5],
		["wrong equipment slot", func(d: Dictionary) -> void: d.armory[0] = {"uid": 9, "id": "c0", "aff": []}],
		["string quantity", func(d: Dictionary) -> void: d.gold = "100"],
		["long hero array", func(d: Dictionary) -> void: d.hero_exp.append(9)],
		["too many relics", func(d: Dictionary) -> void: d.relic_stars.append(1)],
		["invalid RNG state", func(d: Dictionary) -> void: d.loot_state = "not-a-state"],
		["unknown payload field", func(d: Dictionary) -> void: d.future_inventory = [1]],
		["bag overflow", func(d: Dictionary) -> void:
			d.bag.clear()
			for i: int in 61:
				d.bag.append({"uid": i + 1, "id": "c0", "aff": []})
			d.next_uid = 62],
	]
	for entry: Array in cases:
		var data: Dictionary = template.to_dict().duplicate(true)
		entry[1].call(data)
		_write(JSON.stringify(data))
		var original := FileAccess.get_file_as_bytes(PATH)
		var stale := Progression.new(2)
		var rejected: bool = stale.save(PATH) != OK
		_expect(rejected and FileAccess.get_file_as_bytes(PATH) == original, "schema write guard: " + entry[0])
		if rejected:
			var loaded := Progression.load_from(PATH)
			_expect(not loaded.save_blocked_reason.is_empty(), "schema load guard: " + entry[0])
	var old_v2: Dictionary = Progression.new(17).to_dict()
	old_v2.talent.resize(6)
	old_v2.relic_stars.resize(2)
	old_v2.potions = 3
	_write(JSON.stringify(old_v2))
	var compatible := Progression.load_from(PATH)
	_expect(compatible.save_blocked_reason.is_empty() and compatible.potions[0] == 3 and compatible.save(PATH) == OK,
		"older v2 short talent/relic arrays and scalar potions remain migratable")

	var v1: Dictionary = Progression.new(17).to_dict()
	v1.version = 1
	v1.class_level = [3, 1, 1, 1, 1, 1]
	v1.armory = [-1, 2, -1, -1, -1, -1]
	v1.charm = []
	v1.charm.resize(100)
	v1.charm.fill(-1)
	v1.bag = {"w0_1": 2, "c3": 1}
	_write(JSON.stringify(v1))
	var old := Progression.load_from(PATH)
	_expect(old.save_blocked_reason.is_empty() and old.bag.size() == 3 and old.weapon_rarity(1) == 2 and old.save(PATH) == OK,
		"v1 equipment and counted bag migrate without losing items")
	v1.bag = {"w0_1": 61}
	_write(JSON.stringify(v1))
	var overloaded_bytes := FileAccess.get_file_as_bytes(PATH)
	var overloaded := Progression.load_from(PATH)
	_expect(not overloaded.save_blocked_reason.is_empty() and overloaded.save(PATH) != OK
		and FileAccess.get_file_as_bytes(PATH) == overloaded_bytes, "over-capacity legacy inventory is protected without truncation")
	DirAccess.remove_absolute(PATH)
