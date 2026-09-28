extends "res://addons/proto_kit/test_kit.gd"

func _init() -> void:
	_run.call_deferred()

func _capture(path: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func _run() -> void:
	load("res://tests/test_bootstrap.gd").add_services(root)
	var game: Node = root.get_node("Game")
	game.set_combat_paused(true)
	var main: Control = load("res://main.tscn").instantiate()
	main.reference_preview = true
	root.add_child(main)
	root.size = Vector2i(941,1672)
	await _frames(3)
	main.show_page("equipment")
	var arena: Node2D = main.find_child("CombatArena",true,false)
	arena.auto_simulate = false
	var directory := "/tmp/taskbar-v2-review/waves"
	DirAccess.make_dir_recursive_absolute(directory)
	await _capture(directory+"/01-combat.png")
	for id: String in ["enemy_0","enemy_1","enemy_2"]:
		arena.find_unit(id).take_damage(99999,arena.find_unit("knight"))
	game.set_combat_paused(false)
	arena.simulate_step(0.01)
	arena.simulate_step(0.5)
	game.set_combat_paused(true)
	await _capture(directory+"/02-marching.png")
	game.set_combat_paused(false)
	arena.simulate_step(0.7)
	game.set_combat_paused(true)
	await _capture(directory+"/03-soldier-wave.png")
	main.queue_free()
	await _frames(2)
	_finish("WAVE RENDER CAPTURE")
