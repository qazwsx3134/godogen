extends "res://addons/proto_kit/test_kit.gd"
## Scene contract: every scene loads, has the nodes its script looks up, and the
## chapter is wired the way main.gd expects. Uses the saved scenes, not the builder.

const HANDLED_IDS: Array[StringName] = [&"front", &"multishot", &"diagonal", &"side", &"rear", &"pierce",
	&"ricochet", &"wall_bounce", &"attack_boost", &"attack_speed", &"crit", &"fire", &"freeze", &"hp_boost", &"heal"]

## Every actor, projectile and pickup shows its picture through a %Sprite.
const SPRITE_SCENES: Array[String] = ["res://player/hero.tscn", "res://player/sugarcane.tscn", "res://enemies/rat.tscn",
	"res://enemies/tank.tscn", "res://enemies/plate.tscn", "res://enemies/boss_tank.tscn", "res://enemies/chiang_boss.tscn",
	"res://enemies/bullet.tscn", "res://enemies/pea.tscn", "res://enemies/corn.tscn", "res://enemies/carrot.tscn",
	"res://pickups/exp_gem.tscn", "res://pickups/heart.tscn", "res://pickups/coin.tscn"]

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var required: Dictionary = {
		"res://player/hero.tscn": ["Body", "Sprite", "Hand", "HpBar", "HpLabel"],
		"res://player/sugarcane.tscn": ["Visual", "Sprite"],
		"res://enemies/rat.tscn": ["Body", "Sprite", "HpBar", "ContactArea"],
		"res://enemies/tank.tscn": ["Body", "Sprite", "HpBar", "ContactArea", "DashLine"],
		"res://enemies/plate.tscn": ["Body", "Sprite", "Muzzle", "HpBar", "ContactArea"],
		"res://enemies/boss_tank.tscn": ["Body", "Sprite", "HpBar", "ContactArea", "DashLine"],
		"res://enemies/chiang_boss.tscn": ["Body", "Sprite", "GunArm", "Muzzle", "HpBar", "ContactArea", "RageSteam", "RageMark"],
		"res://effects/aoe_circle.tscn": ["Fill", "Ring", "Grow"],
		"res://arena/door.tscn": ["Bars", "Glow"],
		"res://arena/arena_temple.tscn": ["Background", "Door"],
		"res://arena/arena_square.tscn": ["Background", "Door"],
		"res://arena/arena_memorial.tscn": ["Background", "Door"],
		"res://arena/arena_hall.tscn": ["Background", "Door"],
		"res://arena/crate.tscn": ["Sprite"],
		"res://arena/barrier.tscn": ["Sprite"],
		"res://arena/hedgehog.tscn": ["Sprite"],
		"res://arena/stone_block.tscn": ["Sprite"],
		"res://ui/hud.tscn": ["Joystick", "RoomLabel", "LevelLabel", "ExpBar", "HpBar", "HpLabel", "HeroPortrait", "PlayerPanel",
			"BossPanel", "BossPortrait", "BossName", "BossBar", "BottomHeroPanel", "BottomPortrait", "BottomHpBar",
			"CoinIcon", "CoinLabel", "AbilityChips", "PauseButton", "PauseOverlay", "ResumeButton", "Fade", "Banner",
			"HpGhost", "BottomHpGhost", "Vignette", "WhiteFlash"],
		"res://effects/spark.tscn": [],
		"res://effects/dust.tscn": [],
		"res://effects/debris.tscn": [],
		"res://effects/gold_burst.tscn": [],
		"res://effects/level_ring.tscn": ["Ring", "Rays"],
		"res://ui/ability_slot.tscn": ["Frame", "Swatch", "Initial", "Icon", "Pips"],
		"res://pickups/coin.tscn": ["Visual"],
		"res://ui/joystick.tscn": ["Base", "Knob"],
		"res://ui/choice_panel.tscn": ["Title", "Subtitle", "Cards"],
		"res://ui/ability_card.tscn": ["Swatch", "Icon", "Title", "Description", "Stack"],
		"res://ui/result_panel.tscn": ["Title", "Summary", "CoinsLabel", "RestartButton"],
		"res://main.tscn": ["Camera", "RoomHolder", "Hero", "Shots", "EnemyShots", "Pickups", "Effects", "Hud", "ChoicePanel", "ResultPanel", "TimeControl", "Sfx", "Juice"],
	}
	for path: String in required:
		var scene: Node = (load(path) as PackedScene).instantiate()
		for node_name: String in required[path]:
			_expect(scene.get_node_or_null("%" + node_name) != null, "%s has %%%s" % [path.get_file(), node_name])
		scene.free()
	for path: String in SPRITE_SCENES:
		var scene: Node = (load(path) as PackedScene).instantiate()
		var sprite: Sprite2D = scene.get_node_or_null("%Sprite") as Sprite2D
		_expect(sprite != null and sprite.texture != null, "%s shows a picture through %%Sprite" % path.get_file())
		scene.free()
	for path: String in ["res://arena/crate.tscn", "res://arena/barrier.tscn", "res://arena/hedgehog.tscn", "res://arena/stone_block.tscn"]:
		var obstacle: Node = (load(path) as PackedScene).instantiate()
		var sprite: Sprite2D = obstacle.get_node("%Sprite") as Sprite2D
		var base: Shape2D = (obstacle.get_node("CollisionShape2D") as CollisionShape2D).shape
		_expect(sprite.texture != null, "%s shows a picture" % path.get_file())
		# 3/4 view: only the foot of the picture blocks, so the hero can walk behind the top half.
		_expect(base is RectangleShape2D and base.size.y < sprite.texture.get_height() * 0.4, "%s blocks only its base" % path.get_file())
		_expect(sprite.position.y + sprite.texture.get_height() * 0.5 < 30.0, "%s stands on its base (the picture ends just below the origin)" % path.get_file())
		obstacle.free()
	for path: String in ["res://arena/arena_temple.tscn", "res://arena/arena_square.tscn", "res://arena/arena_memorial.tscn", "res://arena/arena_hall.tscn"]:
		var stage: Node = (load(path) as PackedScene).instantiate()
		var background: Sprite2D = stage.get_node("%Background") as Sprite2D
		_expect(background.texture != null and background.texture.get_size() == Vector2(1080, 1920), "%s paints the whole world" % path.get_file())
		_expect(not background.centered and background.position == Vector2.ZERO, "%s background starts at the world's corner" % path.get_file())
		_expect(stage.z_index == -2, "%s draws below everything on the floor" % path.get_file())
		_expect(stage.walk_area.size.x > 700.0 and stage.walk_area.size.y > 1100.0, "%s has a walk area" % path.get_file())
		_expect(stage.get_node("Walls").get_child_count() >= 8, "%s has walls that follow the painting" % path.get_file())
		_expect(stage.walk_area.grow(160.0).has_point(stage.get_node("%Door").position), "%s door is at the edge of the walk area" % path.get_file())
		stage.free()

	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	_expect(main.rooms.size() == 10, "chapter has 10 rooms")
	_expect(main.abilities.size() == 15, "main offers 15 abilities")
	var ids: Dictionary = {}
	for def: Resource in main.abilities:
		ids[def.id] = true
		_expect(HANDLED_IDS.has(def.id), "ability %s has an effect in hero_stats" % def.id)
		_expect(def.icon != null, "ability %s has an icon" % def.id)
	_expect(ids.size() == 15, "ability ids are unique")
	for key: String in ["sugarcane_scene", "exp_gem_scene", "heart_scene", "coin_scene", "damage_number_scene", "explosion_scene",
			"spark_scene", "dust_scene", "debris_scene", "gold_burst_scene", "ring_scene"]:
		_expect(main.get(key) is PackedScene, "main.%s is set" % key)
	_expect(main.get_node("%RoomHolder").get_child_count() == 1, "main shows a preview room in the editor")
	_expect(main.get_node("%Hero").is_in_group("hero"), "hero is in the hero group (door uses it)")
	_expect(main.get_node("%Hero").get_node_or_null("%Body/Hat") == null, "the hero wears no hat")
	_expect(main.get_node("%Hero").get_node("%Hand").get_parent() == main.get_node("%Hero").get_node("%Body"), "the hand (where the cane starts) flips with the hero")
	var hero_sprite: Sprite2D = main.get_node("%Hero").get_node("%Sprite") as Sprite2D
	_expect(hero_sprite.hframes == 6 and hero_sprite.vframes == 1 and hero_sprite.frame == 0, "the hero's picture is the 6-frame throw strip, in the ready pose")
	_expect(hero_sprite.texture.resource_path.ends_with("hero_throw.png") and hero_sprite.texture.get_width() % 6 == 0, "the hero uses hero_throw.png, which splits into 6 equal cells")
	_expect(main.get_node("%Hero").frame_drop.size() == 6, "one foot correction per throw frame")
	var cane_scene: Node = (load("res://player/sugarcane.tscn") as PackedScene).instantiate()
	_expect((cane_scene.get_node("%Sprite") as Sprite2D).texture.resource_path.ends_with("sugarcane_purple.png"), "the thrown cane is the purple sugarcane")
	_expect(cane_scene.spin_turns_per_second >= 2.0 and cane_scene.spin_turns_per_second <= 3.0, "the thrown cane turns 2–3 times a second")
	cane_scene.free()
	var plate: Node = (load("res://enemies/plate.tscn") as PackedScene).instantiate()
	var beans: Array = plate.bean_scenes.map(func(scene: PackedScene) -> String: return scene.resource_path.get_file())
	_expect(beans == ["pea.tscn", "corn.tscn", "carrot.tscn"], "plate throws pea, corn and carrot")
	_expect(plate.display_name == "廚師", "the plate enemy is the chef")
	_expect(plate.get_node("%Muzzle").get_parent() == plate.get_node("%Body"), "the chef's pan (muzzle) flips with its body")
	plate.free()
	var boss_scene: Node = (load("res://enemies/boss_tank.tscn") as PackedScene).instantiate()
	_expect(boss_scene.rat_scene != null and boss_scene.rat_scene.resource_path.ends_with("rat.tscn"), "boss calls rats")
	_expect(boss_scene.portrait != null, "the boss tank has a portrait for the boss bar")
	boss_scene.free()
	var chiang: Node = (load("res://enemies/chiang_boss.tscn") as PackedScene).instantiate()
	_expect(chiang.portrait != null, "the final boss has a portrait for the boss bar")
	_expect(chiang.get_node("%GunArm/Pistol") is Sprite2D and chiang.get_node("%GunArm/Pistol").texture != null, "the pistol is a picture in the gun arm")
	_expect(chiang.get_node("%Muzzle").get_parent() == chiang.get_node("%GunArm"), "the muzzle turns with the pistol")
	_expect(chiang.aoe_scene != null and chiang.aoe_scene.resource_path.ends_with("aoe_circle.tscn"), "final boss drops red circles")
	_expect(chiang.Pattern.AOE == 0, "the red circles are the first pattern, so every fight shows them")
	_expect(chiang.rage_bounces >= 1 and chiang.rage_bounces <= 2, "the angry boss's bullets bounce once or twice (rage_bounces)")
	_expect(not chiang.raging and not chiang.get_node("%RageSteam").emitting and not chiang.get_node("%RageMark").visible, "the rage look is in the scene but off until he is angry")
	chiang.free()
	for plain: String in ["res://enemies/bullet.tscn", "res://enemies/pea.tscn", "res://enemies/corn.tscn", "res://enemies/carrot.tscn"]:
		var shot: Node = (load(plain) as PackedScene).instantiate()
		_expect(shot.bounces == 0, "%s does not bounce unless the angry boss sets it" % plain.get_file())
		shot.free()

	var stage_files: Array[String] = ["arena_temple", "arena_temple", "arena_temple", "arena_square", "arena_square", "arena_square",
		"arena_square", "arena_memorial", "arena_memorial", "arena_hall"]
	for i: int in main.rooms.size():
		var room: Node = main.rooms[i].instantiate()
		var stage: Node = room.get_node("%Arena")
		var arena: Rect2 = stage.walk_area
		_expect(stage.scene_file_path.ends_with(stage_files[i] + ".tscn"), "room %d is staged in %s" % [i + 1, stage_files[i]])
		for obstacle: Node2D in room.get_node("Obstacles").get_children():
			_expect(arena.has_point(obstacle.position) and not _in_wall(stage, obstacle.position, 0.0), "room %d: %s stands on the floor" % [i + 1, obstacle.name])
		_expect(room.get_node("Obstacles").get_child_count() in [2, 3, 4], "room %d has 2-4 obstacles" % (i + 1))
		var enemies: Array[Node] = room.get_node("%Enemies").get_children()
		_expect(not enemies.is_empty(), "room %d has enemies" % (i + 1))
		var bosses: int = 0
		for enemy: Node in enemies:
			_expect(enemy.has_method("activate"), "room %d: %s is an enemy" % [i + 1, enemy.name])
			_expect(arena.has_point(enemy.position) and not _in_wall(stage, enemy.position, 40.0), "room %d: %s is inside the arena, off the walls" % [i + 1, enemy.name])
			if enemy.is_boss:
				bosses += 1
			if i == 0:
				_expect(enemy.scene_file_path.ends_with("rat.tscn"), "room 1 has only rats (the first enemy)")
		var is_boss_room: bool = i == 4 or i == 9
		if i == 9:
			_expect(enemies[0].scene_file_path.ends_with("chiang_boss.tscn") and enemies[0].display_name == "蔣介石", "final boss is 蔣介石")
		_expect(room.boss_room == is_boss_room, "room %d boss flag" % (i + 1))
		_expect(bosses == (1 if is_boss_room else 0), "room %d boss count" % (i + 1))
		_expect(arena.has_point(room.get_node("%PlayerStart").position) and not _in_wall(stage, room.get_node("%PlayerStart").position, 40.0), "room %d start inside arena, off the walls" % (i + 1))
		_expect(room.get_node("%Arena").get_node_or_null("%Door") != null, "room %d has a door" % (i + 1))
		var area: String = "宮廟" if i < 3 else ("天安門廣場" if i < 7 else "中正紀念堂")
		_expect(room.area_name == area, "room %d is in %s" % [i + 1, area])
		room.free()
	main.free()
	var coin: Node = (load("res://pickups/coin.tscn") as PackedScene).instantiate()
	_expect(coin.kind == coin.Kind.COIN, "coin.tscn is a coin pickup")
	coin.free()
	await _facing()
	await _hud_api()
	await _level_up_cards()
	_finish("SCENE TESTS")

## True if `point`, grown by `margin`, is inside one of the stage's wall rectangles (Walls > CollisionShape2D).
func _in_wall(stage: Node, point: Vector2, margin: float) -> bool:
	for wall: CollisionShape2D in stage.get_node("Walls").get_children():
		var size: Vector2 = (wall.shape as RectangleShape2D).size
		if Rect2(wall.position - size * 0.5, size).grow(margin).has_point(point):
			return true
	return false

## The level-up card of every ability shows its picture, and the title, the description and the count stay
## inside the frame with 16 px to spare. The description keeps its own line breaks only: a "\r\n" from a .tres
## checked out with Windows line endings once showed a blank line that pushed the second line onto the border.
## A made-up long text wraps to at most three lines. The angel's heal card has no picture and shows a square.
func _level_up_cards() -> void:
	root.size = Vector2i(1080, 1920)
	var panel: Control = (load("res://ui/choice_panel.tscn") as PackedScene).instantiate() as Control
	root.add_child(panel)
	var defs: Array[Resource] = []
	for id: StringName in HANDLED_IDS:
		defs.append(load("res://data/abilities/%s.tres" % id))
	var rounds: Array = []
	for i: int in range(0, defs.size(), 3):
		var options: Array = []
		for def: Resource in defs.slice(i, i + 3):
			options.append({"title": def.title, "description": def.description, "color": def.color, "icon": def.icon, "stack": "0 / %d" % def.max_stacks})
		rounds.append(options)
	rounds.append([
		{"title": "天使的祝福", "description": "回復 40% 生命", "color": Color(1.0, 0.92, 0.55)},
		{"title": "天使的禮物：正面甘蔗 +1", "description": "正前方多丟一根\n每根傷害 −25%", "color": Color.WHITE, "icon": defs[0].icon, "stack": "0 / 3"},
		{"title": "很長很長的能力名稱很長很長的能力名稱", "description": "這是一段刻意寫得很長的說明文字，用來確認自動換行之後最多只佔三行，而且不會跑出卡片外框。這一句是多出來的，再多寫幾句湊字數：甘蔗穿過坦克，每穿一台傷害減少三成三，命中後燃燒兩秒，冰凍減速一點五秒，碰到牆會反彈兩次，攻擊力提高兩成。", "color": Color.WHITE, "icon": defs[1].icon, "stack": "0 / 3", "long": true},
	])
	for options: Array in rounds:
		panel.open("升級！", "選擇一項能力", options)
		await _frames(4)
		var cards: Array[Node] = panel.cards()
		_expect(cards.size() == options.size(), "the panel makes one card per option")
		for i: int in cards.size():
			var card: Control = cards[i]
			var label: String = options[i]["title"]
			var picture: bool = options[i].get("icon") != null
			_expect(card.get_node("%Icon").visible == picture and card.get_node("%Swatch").visible == not picture, "%s: a picture when it has one, else the colour square" % label)
			_expect(not picture or card.get_node("%Icon").texture == options[i]["icon"], "%s shows its own ability picture" % label)
			var frame: Rect2 = card.get_global_rect().grow(-16.0)
			for part: String in ["%Title", "%Description", "%Stack", "%Icon" if picture else "%Swatch"]:
				_expect(frame.encloses(card.get_node(part).get_global_rect()), "%s: %s is inside the card frame" % [label, part.trim_prefix("%")])
			var description: Label = card.get_node("%Description")
			_expect(description.get_visible_line_count() <= 3, "%s: the description takes at most three lines" % label)
			if not options[i].get("long", false):
				var written: int = String(options[i]["description"]).replace("\r", "").count("\n") + 1
				_expect(description.get_line_count() == written, "%s: the description has exactly the lines it was written with" % label)
	# the regression itself: Windows line endings inside the text
	panel.open("升級！", "選擇一項能力", [{"title": "暴擊強化", "description": "暴擊率 +10%\r\n暴擊造成 2 倍傷害", "color": Color.WHITE, "icon": defs[0].icon, "stack": "0 / 4"}])
	await _frames(4)
	_expect((panel.cards()[0].get_node("%Description") as Label).get_line_count() == 2, "a \\r\\n in a description is one line break, not two")
	panel.queue_free()
	await _frames(2)

## The art faces right; an enemy flips only when its direction is clearly sideways.
func _facing() -> void:
	var rat: Node = (load("res://enemies/rat.tscn") as PackedScene).instantiate()
	root.add_child(rat)
	await _frames(1)
	var body: Node2D = rat.get_node("%Body")
	_expect(is_equal_approx(body.scale.x, 1.0), "enemy art starts facing right")
	rat.face_toward(Vector2(-1.0, 0.1))
	_expect(is_equal_approx(body.scale.x, -1.0), "moving left flips the sprite")
	rat.face_toward(Vector2(0.2, 1.0))
	_expect(is_equal_approx(body.scale.x, -1.0), "near-vertical movement keeps the side (no flicker)")
	rat.face_toward(Vector2(0.9, -0.3))
	_expect(is_equal_approx(body.scale.x, 1.0), "moving right flips it back")
	rat.queue_free()
	await _frames(1)

## The HUD's own behaviour on the saved hud.tscn, without the main scene: numbers, ability slots
## (pips, one slot per ability, at most five, icon vs stand-in) and the room / boss layouts.
func _hud_api() -> void:
	var hud: Control = (load("res://ui/hud.tscn") as PackedScene).instantiate() as Control
	var slots: Container = hud.get_node("%AbilityChips")
	_expect(slots.get_child_count() > 0, "the editor view of hud.tscn shows sample ability slots")
	root.add_child(hud)
	await _frames(2)
	_expect(slots.get_child_count() == 0, "the sample slots are cleared when the game runs")
	_expect(hud.get_node("%HeroPortrait").texture != null and hud.get_node("%BottomPortrait").texture != null and hud.get_node("%CoinIcon").texture != null,
		"the hero portraits and the coin icon have their pictures")
	_expect(not hud.get_node("%HeroPortrait/Frame").visible and not hud.get_node("%BottomPortrait/Frame").visible and not hud.get_node("%CoinIcon/Frame").visible,
		"a portrait or coin icon with a picture hides its stand-in frame")
	var bare: Control = (load("res://ui/hud.tscn") as PackedScene).instantiate() as Control
	bare.get_node("%HeroPortrait").texture = null
	bare.get_node("%CoinIcon").texture = null
	root.add_child(bare)
	await _frames(2)
	_expect(bare.get_node("%HeroPortrait/Frame").visible and bare.get_node("%CoinIcon/Frame").visible, "without a picture they draw their stand-in frame")
	bare.queue_free()

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

	var front: Resource = (load("res://data/abilities/front.tres") as Resource).duplicate()   # 3 stacks: 三格
	front.icon = null   # these checks are about the stand-in; the real icons are checked in _run
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
	_expect(hud.get_node("%BossBar").value < 300.0, "the boss bar starts empty when the boss appears")
	await _until(func() -> bool: return is_equal_approx(hud.get_node("%BossBar").value, 300.0), "the boss bar fills up to the boss's HP", 3.0)
	_expect(hud.get_node("%BossName").text == "蔣介石", "boss name")
	_expect(hud.get_node("%BossPortrait/Frame").visible, "an empty boss portrait draws its stand-in frame")
	var art := GradientTexture2D.new()
	hud.show_boss("蔣介石", 200, 400, art)
	_expect(hud.get_node("%BossPortrait").texture == art and not hud.get_node("%BossPortrait/Frame").visible, "a boss portrait replaces the stand-in frame")
	hud.show_boss("蔣介石", 100, 400)
	_expect(hud.get_node("%BossPortrait").texture == art, "later updates without a portrait keep it")
	hud.hide_boss()
	_expect(player.visible and slots.visible and not boss.visible and not bottom.visible, "the room layout comes back after the boss")

	var stick: Control = hud.get_node("%Joystick")
	_expect(not stick.get_node("%Base").visible and not stick.get_node("Hint").visible, "the joystick is hidden until a touch and the hint text is off")
	# The scene file itself leaves the base visible (the editor shows how it looks) and half transparent.
	var stick_scene: Node = (load("res://ui/joystick.tscn") as PackedScene).instantiate()
	_expect(stick_scene.get_node("%Base").visible and is_equal_approx(stick_scene.get_node("%Base").modulate.a, 0.5), "joystick.tscn shows the base in the editor, at half opacity")
	stick_scene.free()
	hud.queue_free()
	await _frames(2)

func _initials(slots: Container) -> Array:
	return slots.get_children().map(func(slot: Node) -> String: return slot.get_node("%Initial").text)
