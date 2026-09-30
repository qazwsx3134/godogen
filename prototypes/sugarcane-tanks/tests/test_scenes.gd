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
		"res://effects/aoe_circle.tscn": ["Fill", "Ring", "Grow"],
		"res://arena/door.tscn": ["Bars", "Glow"],
		"res://arena/arena_temple.tscn": ["Door"],
		"res://arena/arena_square.tscn": ["Door"],
		"res://arena/arena_memorial.tscn": ["Door"],
		"res://ui/hud.tscn": ["Joystick", "RoomLabel", "LevelLabel", "ExpBar", "HpBar", "HpLabel", "HeroPortrait", "PlayerPanel",
			"BossPanel", "BossPortrait", "BossName", "BossBar", "BottomHeroPanel", "BottomPortrait", "BottomHpBar",
			"CoinIcon", "CoinLabel", "AbilityChips", "PauseButton", "PauseOverlay", "ResumeButton", "Fade", "Banner"],
		"res://ui/ability_slot.tscn": ["Frame", "Swatch", "Initial", "Icon", "Pips"],
		"res://pickups/coin.tscn": ["Visual"],
		"res://ui/joystick.tscn": ["Base", "Knob"],
		"res://ui/choice_panel.tscn": ["Title", "Subtitle", "Cards"],
		"res://ui/ability_card.tscn": ["Swatch", "Title", "Description", "Stack"],
		"res://ui/result_panel.tscn": ["Title", "Summary", "CoinsLabel", "RestartButton"],
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
	for key: String in ["sugarcane_scene", "exp_gem_scene", "heart_scene", "coin_scene", "damage_number_scene", "explosion_scene"]:
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
	var chiang: Node = (load("res://enemies/chiang_boss.tscn") as PackedScene).instantiate()
	_expect(chiang.aoe_scene != null and chiang.aoe_scene.resource_path.ends_with("aoe_circle.tscn"), "final boss drops red circles")
	_expect(chiang.Pattern.AOE == 0, "the red circles are the first pattern, so every fight shows them")
	chiang.free()

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
	var coin: Node = (load("res://pickups/coin.tscn") as PackedScene).instantiate()
	_expect(coin.kind == coin.Kind.COIN, "coin.tscn is a coin pickup")
	coin.free()
	await _hud_api()
	_finish("SCENE TESTS")

## The HUD's own behaviour on the saved hud.tscn, without the main scene: numbers, ability slots
## (pips, one slot per ability, at most five, icon vs stand-in) and the room / boss layouts.
func _hud_api() -> void:
	var hud: Control = (load("res://ui/hud.tscn") as PackedScene).instantiate() as Control
	var slots: Container = hud.get_node("%AbilityChips")
	_expect(slots.get_child_count() > 0, "the editor view of hud.tscn shows sample ability slots")
	root.add_child(hud)
	await _frames(2)
	_expect(slots.get_child_count() == 0, "the sample slots are cleared when the game runs")
	_expect(hud.get_node("%HeroPortrait/Frame").visible and hud.get_node("%CoinIcon/Frame").visible, "empty portraits and coin icon draw their stand-in frame")

	hud.set_room(3, 10)
	_expect(hud.get_node("%RoomLabel").text == "03", "the stage box shows the room number only")
	hud.set_level(12, 30, 100)
	_expect(hud.get_node("%LevelLabel").text == "LV 12" and hud.get_node("%ExpBar").value == 30, "level box and EXP bar")
	hud.set_coins(7)
	_expect(hud.get_node("%CoinLabel").text == "7", "the coin box shows the coin count")
	hud.set_hp(520, 600)
	_expect(hud.get_node("%HpLabel").text == "520 / 600", "the HP bar is labelled current / max")
	_expect(hud.get_node("%HpBar").value == 520 and hud.get_node("%HpBar").max_value == 600, "the HP bar follows the numbers")
	_expect(hud.get_node("%BottomHpBar").value == 520, "the boss-room HP bar follows too")

	var front: Resource = load("res://data/abilities/front.tres")   # 3 stacks: 三格
	hud.set_ability(front, 1)
	var pips: Label = slots.get_child(0).get_node("%Pips")
	_expect(slots.get_child_count() == 1 and pips.text == "◆◇◇", "one stack of a 3-stack ability shows ◆◇◇")
	hud.set_ability(front, 2)
	_expect(slots.get_child_count() == 1 and pips.text == "◆◆◇", "taking it again updates the same slot")
	_expect(slots.get_child(0).get_node("%Initial").text == "正" and slots.get_child(0).get_node("%Frame").visible, "without an icon the slot shows a square and the title's first letter")
	var with_icon: Resource = front.duplicate()
	with_icon.icon = GradientTexture2D.new()
	hud.set_ability(with_icon, 3)
	_expect(slots.get_child_count() == 1 and not slots.get_child(0).get_node("%Frame").visible, "with an icon the stand-in frame is hidden")
	_expect(slots.get_child(0).get_node("%Icon").texture == with_icon.icon and pips.text == "◆◆◆", "the icon shows and the pips fill")
	hud.set_ability(front, 3)
	_expect(slots.get_child(0).get_node("%Frame").visible, "clearing the icon brings the stand-in back")
	hud.set_ability(load("res://data/abilities/fire.tres"), 1)   # 1 stack only: 一格
	_expect(slots.get_child(1).get_node("%Pips").text == "◆", "a single-stack ability shows one pip")
	hud.set_ability(load("res://data/abilities/attack_boost.tres"), 5)   # 5 stacks: still capped at 三格
	_expect(slots.get_child(2).get_node("%Pips").text == "◆◆◆", "pips are capped at three")

	for id: String in ["multishot", "diagonal", "side"]:   # front, fire, attack_boost, then these three
		hud.set_ability(load("res://data/abilities/%s.tres" % id), 1)
	_expect(slots.get_child_count() == 5, "at most five slots are shown")
	_expect(_initials(slots) == ["火", "攻", "連", "斜", "側"], "the oldest ability (正面甘蔗) was dropped for the newest")
	hud.set_ability(load("res://data/abilities/fire.tres"), 1)   # 火 becomes the newest again
	hud.set_ability(load("res://data/abilities/rear.tres"), 1)
	_expect(_initials(slots).has("火") and not _initials(slots).has("攻"), "retaking an ability keeps it; the least recently taken goes")

	var player: Control = hud.get_node("%PlayerPanel")
	var boss: Control = hud.get_node("%BossPanel")
	var bottom: Control = hud.get_node("%BottomHeroPanel")
	_expect(player.visible and slots.visible and not boss.visible and not bottom.visible, "the room layout shows the player block and the ability slots")
	hud.show_boss("蔣介石", 300, 400)
	_expect(boss.visible and bottom.visible and not player.visible and not slots.visible, "the boss layout swaps in the boss bar and moves the HP to the bottom")
	_expect(hud.get_node("%BossName").text == "蔣介石" and hud.get_node("%BossBar").value == 300, "boss name and bar")
	_expect(hud.get_node("%BossPortrait/Frame").visible, "an empty boss portrait draws its stand-in frame")
	var art := GradientTexture2D.new()
	hud.show_boss("蔣介石", 200, 400, art)
	_expect(hud.get_node("%BossPortrait").texture == art and not hud.get_node("%BossPortrait/Frame").visible, "a boss portrait replaces the stand-in frame")
	hud.show_boss("蔣介石", 100, 400)
	_expect(hud.get_node("%BossPortrait").texture == art, "later updates without a portrait keep it")
	hud.hide_boss()
	_expect(player.visible and slots.visible and not boss.visible and not bottom.visible, "the room layout comes back after the boss")

	var stick: Control = hud.get_node("%Joystick")
	_expect(stick.get_node("%Base").visible and not stick.get_node("Hint").visible, "the joystick base is always shown and the hint text is off")
	hud.queue_free()
	await _frames(2)

func _initials(slots: Container) -> Array:
	return slots.get_children().map(func(slot: Node) -> String: return slot.get_node("%Initial").text)
