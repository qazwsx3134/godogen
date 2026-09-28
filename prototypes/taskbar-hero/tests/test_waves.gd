extends "res://addons/proto_kit/test_kit.gd"

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	load("res://tests/test_bootstrap.gd").add_services(root)
	var game: Node = root.get_node("Game")
	game.set_combat_paused(true)
	var page := Control.new()
	var socket := Node2D.new()
	socket.position = Vector2(0,470)
	root.add_child(page)
	page.add_child(socket)
	var arena: Node2D = load("res://scenes/combat/reference_arena.tscn").instantiate()
	arena.auto_simulate = false
	socket.add_child(arena)
	await _frames(3)
	_expect(arena.live_units().size() == 8, "authored scene contains hero,4monsters,3enemies")
	var heroes := 0
	for unit: CombatUnit in arena.live_units():
		if unit.faction == "hero" and unit.active: heroes += 1
	_expect(heroes == 5, "all four owned monsters can deploy beside hero")
	var real_gold: int = game.gold
	var real_kills: int = game.kills
	var expected_gold := 0
	for id: String in ["enemy_0","enemy_1","enemy_2"]:
		var enemy: CombatUnit = arena.find_unit(id)
		expected_gold += enemy.unit_data.gold_reward
		enemy.take_damage(9999,arena.find_unit("knight"))
		enemy.take_damage(9999,arena.find_unit("knight"))
		enemy.simulate_step(10.0)
		_expect(enemy.is_dead, "wave enemies never individually respawn: "+id)
	_expect(game.gold == real_gold+expected_gold and game.kills == real_kills+3,"three kills award once each")
	game.set_combat_paused(false)
	arena.simulate_step(0.01)
	_expect(arena.phase == "advance", "clear wave starts marching")
	var knight: CombatUnit = arena.find_unit("knight")
	var start_x := knight.position.x
	arena.simulate_step(0.3)
	_expect(knight.position.x > start_x, "party rapidly advances forward in world space")
	_expect(arena.near_distance > arena.far_distance and arena.far_distance > 0.0,"near scenery travels faster than far scenery")
	game.toggle_deployment("fox")
	game.toggle_deployment("fox")
	arena.simulate_step(0.05)
	_expect(arena.find_unit("fox").active and arena.find_unit("fox").position.x > 350,"redeployment during marching joins the moving formation")
	_expect(is_equal_approx(arena.wave_label.position.x + arena.position.x,20.0),"wave HUD stays visible while camera tracks party")
	var elapsed: float = arena.advance_elapsed
	var pixels: float = arena.travel_pixels
	game.set_combat_paused(true)
	arena.simulate_step(0.5)
	_expect(arena.advance_elapsed == elapsed and arena.travel_pixels == pixels,"pause freezes marching and parallax")
	var other_socket := Node2D.new()
	other_socket.position = Vector2(0,700)
	page.add_child(other_socket)
	arena.reparent(other_socket,false)
	arena.refresh_spawns()
	_expect(arena.phase == "advance" and arena.advance_elapsed == elapsed,"page change retains wave/transition")
	game.set_combat_paused(false)
	arena.simulate_step(1.0)
	_expect(arena.wave == 2 and arena.phase == "combat", "next wave starts after travel")
	for id: String in ["enemy_0","enemy_1","enemy_2"]:
		var enemy: CombatUnit = arena.find_unit(id)
		_expect(not enemy.is_dead and enemy.current_health == enemy.unit_data.max_health,"nextwave full health "+id)
		_expect(enemy.appearance == "SoldierVisual","second wave uses soldier enemies")
	game.toggle_deployment("fox")
	_expect(not arena.find_unit("fox").active,"withdrawing one monster affects only it")
	_expect(arena.find_unit("sprout").active and arena.find_unit("aqua").active,"other deployed monsters stay active")
	game.toggle_deployment("fox")
	var count_before := get_nodes_in_group("combat_units").size()
	for step in 36000:
		arena.simulate_step(1.0/60.0)
	_expect(get_nodes_in_group("combat_units").size() == count_before,"600 simulatedseconds don't leak units")
	_expect(arena.cleared_waves > 3 and game.current_stage != "1-1","multiple waves progress into next stage")
	print("WAVES CLEARED: ",arena.cleared_waves," CURRENT STAGE: ",game.current_stage)
	page.queue_free()
	await _frames(3)
	_finish("PARTY WAVES PARALLAX AND SOAK")
