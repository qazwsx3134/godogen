extends "res://addons/proto_kit/test_kit.gd"
## S34 riding: real HUD input, non-stacking speed, combat and lifecycle resets.

const SAVE := "user://test_companions/save.json"
var main: Node3D
var player: Node3D
var hud: CanvasLayer
var pet: Node3D

func _init() -> void:
	_run.call_deferred()

func _calm() -> void:
	player.target = null
	player._since_hit = 99.0
	player.cancel_cast()
	player._has_goal = false

func _run() -> void:
	for path: String in [SAVE, SAVE + ".bak"]:
		DirAccess.remove_absolute(path)
	main = load("res://scenes/main.tscn").instantiate()
	main.save_path = SAVE
	root.add_child(main)
	await _frames(5)
	main.set_process(false)
	player = main.player
	hud = main.hud
	pet = main.pet_follower
	player.set_process(false)
	for monster: Node3D in get_nodes_in_group("monster"):
		monster.set_process(false)
	await _press(hud.pet_button)
	_expect(hud.pet_panel.visible and hud.mount_button.disabled and hud.mount_hint.text.contains("第 2 階"),
		"unevolved pet explains the locked riding button")
	_expect(player.set_mounted(true) == "not_ready" and not player.mounted, "rules enforce evolution unlock")
	player.pet.stage = 2
	player.pet.type = "leaf"
	player.refresh_stats()
	hud._refresh_pet()
	var base_speed: float = player.move_speed
	var attack: int = player.attack_power
	var hp: int = player.max_hp
	var rest_y: float = player.actor.position.y
	var follow_scale: Vector3 = pet.actor.scale
	await _press(hud.mount_button)
	_expect(player.mounted and not hud.pet_panel.visible, "real mount button starts riding and closes panel")
	_expect(is_equal_approx(player.movement_speed(), base_speed * 1.25)
		and is_equal_approx(player.actor.position.y, rest_y + player.ride_height), "riding applies speed and seat height")
	for i in 6:
		_expect(player.set_mounted(true) == "", "repeated mounting is idempotent")
	_expect(player.move_speed == base_speed and player.attack_power == attack and player.max_hp == hp,
		"mounting never changes base speed or duplicates pet stat bonuses")
	var start := Vector3(0, 0, 0)
	player.position = start
	var blockers: Array = player.blockers.duplicate()
	player.blockers.clear()
	player.move_to(start + Vector3(10, 0, 0))
	player._process(0.1)
	_expect(is_equal_approx(player.position.x, base_speed * 1.25 * 0.1), "real movement consumes the riding speed")
	player.blockers.assign(blockers)
	pet._process(0.1)
	_expect(pet.global_position.distance_to(player.global_position) < 0.01 and pet.actor.scale == pet.mounted_scale
		and not pet.actor.nameplate.visible, "existing follower becomes the mount at the player's feet")
	await _press(hud.pet_button)
	_expect(hud.mount_button.text == "下坐", "mounted pet panel offers dismount")
	await _press(hud.mount_button)
	pet._process(0.1)
	_expect(player.actor.position.y == rest_y and player.movement_speed() == base_speed
		and pet.actor.scale == follow_scale and pet.actor.nameplate.visible, "dismount restores editor height, scale and following")
	_calm()
	player.set_mounted(true)
	player.sweep_left = 2.0
	_expect(player.use_sweep() == "cooldown" and player.mounted, "failed skill keeps riding")
	player.sweep_left = 0.0
	player.ap = 0
	_expect(player.use_sweep() == "ap" and player.mounted, "insufficient AP keeps riding")
	player.ap = player.max_ap
	_expect(player.use_sweep() == "" and not player.mounted, "successful sweep dismounts before windup")
	_expect(player.set_mounted(true) == "casting", "cannot mount while casting")
	player.cancel_cast()
	_calm()
	player.set_mounted(true)
	var monster: Node3D = get_nodes_in_group("monster")[0]
	player.set_target(monster)
	_expect(not player.mounted and player.set_mounted(true) == "combat", "targeting dismounts and blocks mounting in combat")
	_calm()
	player.set_mounted(true)
	player.take_damage(1)
	_expect(not player.mounted and player.set_mounted(true) == "combat", "damage dismounts and enforces combat delay")
	_calm()
	player.set_mounted(true)
	player.respawn_seconds = 0.01
	player.take_damage(player.max_hp + 1)
	_expect(player.dead and not player.mounted and player.set_mounted(true) == "dead", "death dismounts and blocks mounting")
	await create_timer(0.04).timeout
	_expect(not player.dead and pet == main.pet_follower, "respawn keeps one companion entity")
	_calm()
	player.set_mounted(true)
	var town_portal: Node3D
	for portal: Node3D in get_nodes_in_group("portal"):
		if portal.arrival.x > 100:
			town_portal = portal
	await main.travel(town_portal)
	pet._process(0.1)
	_expect(not player.mounted and pet == main.pet_follower
		and pet.global_position.distance_to(player.global_position) < 2.0, "travel dismounts and relocates the same follower")
	_calm()
	player.set_mounted(true)
	main._on_backgrounded(true)
	_expect(not player.mounted, "background entry dismounts")
	_calm()
	player.bag.add("fishing_bait", 1)
	_expect(main.fishing.start(main.clock.now, player) == "", "fishing starts before mounting")
	var bait: int = player.bag.count("fishing_bait")
	player.set_mounted(true)
	_expect(not main.fishing.active and player.bag.count("fishing_bait") == bait, "mounting cancels fishing without spending bait")
	var data: Dictionary = player.save_data()
	_expect(not data.has("mounted"), "transient riding state is excluded from v6 snapshots")
	player.load_data(data)
	_expect(not player.mounted and player.pet.stage == 2, "loading restores evolution and walking")
	await _layout()
	await _scene_edit()
	main.queue_free()
	await _frames(3)
	main = load("res://scenes/main.tscn").instantiate()
	main.save_path = SAVE
	root.add_child(main)
	await _frames(4)
	_expect(not main.player.mounted and main.player.pet.stage == 2, "reopening saved game preserves evolution and starts walking")
	main.queue_free()
	await _frames(3)
	_finish("SEAL MEADOW COMPANIONS TESTS")

func _layout() -> void:
	main.update_setting("large_text", true)
	player.pet.stage = 1
	hud._refresh_pet()
	for viewport: Vector2i in [Vector2i(1280, 720), Vector2i(844, 390)]:
		root.size = viewport
		hud.pet_panel.visible = true
		await _frames(4)
		var safe: Rect2 = hud.get_node("Root").get_global_rect().grow(0.5)
		var close_button: Button = hud.get_node("%PetClose")
		var scroll: ScrollContainer = hud.pet_panel.get_node("Contents/Scroll")
		var close_rect := close_button.get_global_rect()
		_expect(safe.encloses(hud.pet_panel.get_global_rect()) and safe.encloses(close_rect),
			"large-text pet panel and fixed close stay inside safe area at %s" % viewport)
		for button: Button in [hud.mount_button, hud.evolve_button, hud.feed_rows.get_child(0).get_node("%Action")]:
			scroll.ensure_control_visible(button)
			await _frames(3)
			var rect := button.get_global_rect()
			var pixels: Vector2 = rect.size * root.get_final_transform().get_scale()
			_expect(scroll.get_global_rect().grow(0.5).encloses(rect) and minf(pixels.x, pixels.y) >= 44,
				"pet action %s scrolls into view with 44px target at %s" % [button.name, viewport])
		_expect(close_button.get_global_rect() == close_rect and scroll.scroll_vertical > 0,
			"close remains fixed when pet content scrolls")
		await _press(close_button)
		_expect(not hud.pet_panel.visible, "fixed close works after scrolling")
	root.size = Vector2i(1280, 720)

func _scene_edit() -> void:
	var source := "res://ui/hud.tscn"
	var before := FileAccess.get_sha256(source)
	var edited := (load(source) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	edited.scene_file_path = ""
	edited.get_node("Root/PetPanel/Contents").add_theme_constant_override("separation", 17)
	edited.get_node("%PetClose").text = "返回草原"
	var packed := PackedScene.new()
	_expect(packed.pack(edited) == OK, "editable pet panel packs")
	var path := "user://test_companions/edited.tscn"
	_expect(ResourceSaver.save(packed, path) == OK, "editable pet panel saves")
	edited.free()
	var restored := (load(path) as PackedScene).instantiate()
	root.add_child(restored)
	restored.main = main
	restored.bind(player)
	await _frames(2)
	_expect(restored.get_node("%PetClose").text == "返回草原"
		and restored.get_node("Root/PetPanel/Contents").get_theme_constant("separation") == 17,
		"runtime preserves pet panel editor text and spacing")
	_expect(FileAccess.get_sha256(source) == before, "runtime movement and pet state do not rewrite source scene")
	restored.queue_free()
	await _frames(2)
