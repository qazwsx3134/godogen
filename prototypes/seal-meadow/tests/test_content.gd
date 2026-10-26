extends "res://addons/proto_kit/test_kit.gd"
## Content check (M2-05): every id reference resolves, every quest can be finished with what the game offers,
## every equipment sheet exists, and the font has every character the game writes.
## godot --headless --path . -s tests/test_content.gd

const Items = preload("res://scripts/items.gd")
const Quests = preload("res://scripts/quests.gd")
const FontCheck = preload("res://addons/proto_kit/font_check.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_expect(Items.broken_refs().is_empty(), "drop tables and shop point at defined items: %s" % [Items.broken_refs()])
	var droppable := {}
	for table: String in Items.DROPS:
		for e: Dictionary in Items.DROPS[table]:
			droppable[e.id] = true
	for id: String in Items.ALL:
		var def: Dictionary = Items.ALL[id]
		_expect(droppable.has(id) or Items.SHOP.has(id), "%s can be obtained (drop or shop)" % id)
		if def.has("sheet"):
			_expect(ResourceLoader.exists(def.sheet), "%s paper-doll sheet exists" % id)
		if def.has("slot"):
			_expect(Items.LAYER.has(def.slot), "%s slot has a paper-doll layer" % id)
	var monster_kinds := {}
	for f: String in DirAccess.get_files_at("res://scenes/monsters"):
		if f.ends_with(".tscn"):
			var m: Node = load("res://scenes/monsters/" + f).instantiate()
			monster_kinds[f.get_basename()] = true
			_expect(Items.DROPS.has(m.drop_table), "%s drop table '%s' exists" % [f, m.drop_table])
			m.free()
	var meadow: Node = load("res://scenes/meadow.tscn").instantiate()
	var placed := {}
	for m: Node in meadow.get_node("Monsters").get_children():
		placed[m.scene_file_path.get_file().get_basename()] = true
	meadow.free()
	for q: Dictionary in Quests.CHAIN:
		match q.goal.type:
			"kill":
				_expect(placed.has(q.goal.target), "quest %s: '%s' lives on the map" % [q.id, q.goal.target])
			"collect":
				_expect(droppable.has(q.goal.target) and Items.ALL[q.goal.target].stack >= 1, "quest %s: '%s' drops" % [q.id, q.goal.target])
			"equip":
				_expect(Items.ALL.get(q.goal.target, {}).has("slot") and Items.SHOP.has(q.goal.target),
					"quest %s: '%s' is wearable and sold" % [q.id, q.goal.target])
		for id: String in q.reward.get("items", {}):
			_expect(Items.ALL.has(id), "quest %s reward '%s' exists" % [q.id, id])
	var skip := FontCheck.SKIP_DIRS.duplicate()
	skip.append_array(["design", "production"])
	var missing: Dictionary = FontCheck.missing_report(load("res://assets/fonts/NotoSansTC.ttf"), "res://", FontCheck.EXTENSIONS, skip)
	_expect(missing.is_empty(), "font has every character the game writes: %s" % [missing])
	_finish("SEAL MEADOW CONTENT CHECK")
