extends "res://addons/proto_kit/test_kit.gd"
## Hero choice: opening weapon, stat personality, body shown, remembered pick, save round trip.
const META_PATH = "user://test_heroes_meta.json"
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(META_PATH))
	var game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	game.get_node("Services/Meta").save_path = META_PATH
	root.add_child(game)
	game.set_physics_process(false)
	await _frames(2)
	var street = game.street
	var player = street.player
	var menu = game.menu
	_expect(menu.get_node("%HeroMan").button_pressed and not menu.get_node("%HeroWoman").button_pressed, "menu starts on the man")
	game.start_run()
	_expect(street.build.weapons == [&"punch"] and player.body_man.visible and not player.body_woman.visible, "man opens with the punch and shows his body")
	var man_hp: float = player.hp_limit
	var man_speed: float = player.speed_scale
	game.show_menu()
	menu.get_node("%HeroWoman").pressed.emit()
	_expect(menu.get_node("%HeroWoman").button_pressed and not menu.get_node("%HeroMan").button_pressed and menu.get_node("%HeroNote").text.contains("衝擊波"), "picking the woman updates the buttons and the note")
	game.start_run()
	_expect(street.build.weapons == [&"wave"] and player.body_woman.visible and not player.body_man.visible, "woman opens with the wave and shows her body")
	_expect(player.hp_limit < man_hp and player.speed_scale > man_speed, "woman is faster and frailer than the man")
	var level_before: int = street.build.level
	street.build.award(1000.0)
	game.street.refresh_player_stats()
	_expect(street.build.level > level_before and is_equal_approx(player.speed_scale, player.hero_speed * (1.0 + street.build.stat(&"speed"))), "stat refresh keeps the hero multiplier")
	# A punch swing must still travel her shorter reach and come back to rest.
	player.punch(Vector2.RIGHT, 0.5)
	await create_timer(0.3).timeout
	_expect(player.fist.position.length() < 1.0, "fist returns to rest after a swing")
	game.meta.load_save()
	_expect(game.meta.hero == "woman", "the pick survives a reload of the save")
	game.queue_free()
	await _frames(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(META_PATH))
	_finish("SURVIVOR HEROES")
