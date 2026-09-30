extends "res://addons/proto_kit/test_kit.gd"
## Scene contract: every scene loads, has the nodes its script looks up, and the
## chapter is wired the way main.gd expects. Uses the saved scenes, not the builder.

const HANDLED_IDS: Array[StringName] = [&"front", &"multishot", &"diagonal", &"side", &"rear", &"pierce",
	&"ricochet", &"wall_bounce", &"attack_boost", &"attack_speed", &"crit", &"fire", &"freeze", &"hp_boost", &"heal"]

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var required: Dictionary = {
		"res://player/hero.tscn": ["Body", "HeldCane", "Hand", "HpBar", "HpLabel"],
		"res://player/sugarcane.tscn": ["Visual"],
		"res://enemies/rat.tscn": ["Body", "Tail", "HpBar", "ContactArea"],
		"res://enemies/tank.tscn": ["Body", "HpBar", "ContactArea", "DashLine"],
		"res://enemies/plate.tscn": ["Body", "Muzzle", "HpBar", "ContactArea"],
		"res://enemies/boss_tank.tscn": ["Body", "HpBar", "ContactArea", "DashLine"],
		"res://enemies/chiang_boss.tscn": ["Body", "GunArm", "Muzzle", "HpBar", "ContactArea"],
		"res://arena/door.tscn": ["Bars", "Glow"],
		"res://arena/arena_temple.tscn": ["Door"],
		"res://arena/arena_square.tscn": ["Door"],
		"res://arena/arena_memorial.tscn": ["Door"],
		"res://ui/hud.tscn": ["Joystick", "RoomLabel", "LevelLabel", "ExpBar", "BossPanel", "BossBar", "AbilityChips", "PauseButton", "PauseOverlay", "ResumeButton", "Fade", "Banner"],
		"res://ui/joystick.tscn": ["Base", "Knob"],
		"res://ui/choice_panel.tscn": ["Title", "Subtitle", "Cards"],
		"res://ui/ability_card.tscn": ["Swatch", "Title", "Description", "Stack"],
		"res://ui/result_panel.tscn": ["Title", "Summary", "RestartButton"],
		"res://main.tscn": ["Camera", "RoomHolder", "Hero", "Shots", "EnemyShots", "Pickups", "Effects", "Hud", "ChoicePanel", "ResultPanel", "TimeControl", "Sfx"],
	}
	for path: String in required:
		var scene: Node = (load(path) as PackedScene).instantiate()
		for node_name: String in required[path]:
			_expect(scene.get_node_or_null("%" + node_name) != null, "%s has %%%s" % [path.get_file(), node_name])
		scene.free()

	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	_expect(main.rooms.size() == 10, "chapter has 10 rooms")
	_expect(main.abilities.size() == 15, "main offers 15 abilities")
	var ids: Dictionary = {}
	for def: Resource in main.abilities:
		ids[def.id] = true
		_expect(HANDLED_IDS.has(def.id), "ability %s has an effect in hero_stats" % def.id)
	_expect(ids.size() == 15, "ability ids are unique")
	for key: String in ["sugarcane_scene", "exp_gem_scene", "heart_scene", "damage_number_scene", "explosion_scene"]:
		_expect(main.get(key) is PackedScene, "main.%s is set" % key)
	_expect(main.get_node("%RoomHolder").get_child_count() == 1, "main shows a preview room in the editor")
	_expect(main.get_node("%Hero").is_in_group("hero"), "hero is in the hero group (door uses it)")
	_expect(main.get_node("%Hero").get_node_or_null("%Body/Hat") == null, "the hero wears no hat")
	var plate: Node = (load("res://enemies/plate.tscn") as PackedScene).instantiate()
	var beans: Array = plate.bean_scenes.map(func(scene: PackedScene) -> String: return scene.resource_path.get_file())
	_expect(beans == ["pea.tscn", "corn.tscn", "carrot.tscn"], "plate throws pea, corn and carrot")
	plate.free()
	var boss_scene: Node = (load("res://enemies/boss_tank.tscn") as PackedScene).instantiate()
	_expect(boss_scene.rat_scene != null and boss_scene.rat_scene.resource_path.ends_with("rat.tscn"), "boss calls rats")
	boss_scene.free()

	var arena := Rect2(60, 260, 960, 1500)
	for i: int in main.rooms.size():
		var room: Node = main.rooms[i].instantiate()
		var enemies: Array[Node] = room.get_node("%Enemies").get_children()
		_expect(not enemies.is_empty(), "room %d has enemies" % (i + 1))
		var bosses: int = 0
		for enemy: Node in enemies:
			_expect(enemy.has_method("activate"), "room %d: %s is an enemy" % [i + 1, enemy.name])
			_expect(arena.has_point(enemy.position), "room %d: %s is inside the arena" % [i + 1, enemy.name])
			if enemy.is_boss:
				bosses += 1
			if i == 0:
				_expect(enemy.scene_file_path.ends_with("rat.tscn"), "room 1 has only rats (the first enemy)")
		var is_boss_room: bool = i == 4 or i == 9
		if i == 9:
			_expect(enemies[0].scene_file_path.ends_with("chiang_boss.tscn") and enemies[0].display_name == "蔣介石", "final boss is 蔣介石")
		_expect(room.boss_room == is_boss_room, "room %d boss flag" % (i + 1))
		_expect(bosses == (1 if is_boss_room else 0), "room %d boss count" % (i + 1))
		_expect(arena.has_point(room.get_node("%PlayerStart").position), "room %d start inside arena" % (i + 1))
		_expect(room.get_node("%Arena").get_node_or_null("%Door") != null, "room %d has a door" % (i + 1))
		var area: String = "宮廟" if i < 3 else ("天安門廣場" if i < 7 else "中正紀念堂")
		_expect(room.area_name == area, "room %d is in %s" % [i + 1, area])
		room.free()
	main.free()
	_finish("SCENE TESTS")
