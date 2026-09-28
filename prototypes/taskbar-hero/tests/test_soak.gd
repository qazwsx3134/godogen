extends "res://addons/proto_kit/test_kit.gd"

const MAIN_SCENE: PackedScene = preload("res://main.tscn")
const SIMULATED_SECONDS: int = 600
const STEP: float = 1.0 / 60.0
const TestBootstrap = preload("res://tests/test_bootstrap.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	TestBootstrap.add_services(root)
	var game: Node = root.get_node("Game")
	var data_registry: Node = root.get_node("DataRegistry")
	root.size = Vector2i(390, 844)
	game.call("set_combat_paused", false)
	var main: Control = MAIN_SCENE.instantiate() as Control
	root.add_child(main)
	await _frames(3)
	var arena: Node2D = main.find_child("CombatArena", true, false) as Node2D
	var units: Array[CombatUnit] = arena.live_units()
	var initial_group_count: int = get_nodes_in_group("combat_units").size()
	var initial_kills: int = int(game.get("kills"))
	var initial_gold: int = int(game.get("gold"))
	_expect(initial_group_count == 8, "real scene starts with eight arena units")

	var steps: int = SIMULATED_SECONDS * 60
	for _step: int in range(steps):
		arena.simulate_step(STEP)

	var final_group_count: int = get_nodes_in_group("combat_units").size()
	_expect(final_group_count == 8, "10 simulated minutes do not accumulate unit nodes")
	_expect(arena.live_units().size() == 8, "original authored instances remain the active units")
	_expect(int(game.get("kills")) - initial_kills >= 20, "10 simulated minutes complete repeated combat cycles")
	var enemy_data: UnitData = data_registry.call("current_enemy") as UnitData
	_expect(int(game.get("gold")) - initial_gold >= 20 * enemy_data.gold_reward, "kill rewards continue through the soak")
	for unit: CombatUnit in units:
		_expect(is_finite(unit.global_position.x) and is_finite(unit.global_position.y), "%s position remains finite" % unit.name)
	_expect(game.get("current_stage") != "1-1", "soak advances stages after every three waves")
	print("SOAK SIMULATED: %d seconds at 60 steps/second (%d ticks)" % [SIMULATED_SECONDS, steps])
	_finish("10-MINUTE SCENE SOAK")
