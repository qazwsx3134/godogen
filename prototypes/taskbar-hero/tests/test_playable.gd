extends "res://addons/proto_kit/test_kit.gd"
const DamageRules = preload("res://domain/combat/damage_rules.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	load("res://tests/test_bootstrap.gd").add_services(root)
	var game: Node = root.get_node("Game")
	game.set_combat_paused(true)
	var main: Control = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	var arena: Node2D = main.find_child("CombatArena",true,false)
	arena.auto_simulate = false
	var knight: CombatUnit = arena.find_unit("knight")
	var enemy: CombatUnit = arena.find_unit("enemy_0")
	_expect(arena.live_units().size() == 8,"main loads eight authored actors")
	_expect(DamageRules.final_damage(18,20) == 15,"central damage formula")
	_expect(not knight._attack(enemy),"out-of-range hit rejected")
	var foreign: Node2D = load("res://scenes/combat/reference_arena.tscn").instantiate()
	foreign.auto_simulate = false
	root.add_child(foreign)
	var foreign_enemy: CombatUnit = foreign.find_unit("enemy_0")
	foreign_enemy.global_position = knight.global_position
	_expect(not knight._attack(foreign_enemy),"cross-arena hit rejected")
	_expect(knight._nearest_opponent() == enemy,"target search remains within own arena")
	foreign.queue_free()
	await _frames(2)
	game.set_combat_paused(false)
	var before := knight.position
	knight.simulate_step(0.1)
	_expect(knight.position.x > before.x,"hero approaches enemies")
	# Isolate attack cadence from movement and from the rest of the party.
	enemy.global_position = knight.global_position + Vector2(30,0)
	enemy.current_health = 10000
	knight.current_target = enemy
	knight.attack_cooldown_remaining = 0
	knight.simulate_step(0.01)
	var first_health := enemy.current_health
	knight.simulate_step(0.4)
	_expect(enemy.current_health == first_health,"cooldown prevents an early second attack")
	knight.simulate_step(0.4)
	_expect(enemy.current_health < first_health,"next attack fires after 0.8 seconds")
	game.set_combat_paused(true)
	var health := enemy.current_health
	arena.simulate_step(2)
	_expect(enemy.current_health == health,"pause freezes whole arena")
	var arena_id := arena.get_instance_id()
	main.show_page("equipment")
	main.show_page("monster")
	_expect(main.find_child("CombatArena",true,false).get_instance_id() == arena_id,"page changes preserve live battle identity")
	_expect(enemy.current_health == health,"page changes preserve damage")
	var kills: int = game.kills
	knight.take_damage(999999,enemy)
	knight.take_damage(999999,enemy)
	_expect(knight.is_dead and not knight.visible,"hero death hides presentation")
	_expect(game.kills == kills,"hero death grants no enemy reward")
	game.set_combat_paused(false)
	knight.simulate_step(knight.unit_data.respawn_delay+0.01)
	_expect(not knight.is_dead and knight.current_health == knight.unit_data.max_health,"hero revives at full health")
	_expect(knight.global_position.is_equal_approx(knight.spawn_global_position),"revive uses current page spawn")
	game.set_combat_paused(true)
	main.queue_free()
	await _frames(2)
	_finish("PLAYABLE COMBAT")
