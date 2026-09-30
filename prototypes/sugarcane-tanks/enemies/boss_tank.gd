extends "res://enemies/tank.gd"
## Boss tank. Cycles three patterns: one long dash, three quick dashes that re-aim each
## time, and calling in rats. Below half HP the wind-ups get shorter and more rats come.

enum Pattern { LONG_DASH, TRIPLE_DASH, SUMMON }

@export var rat_scene: PackedScene
@export var summon_count: int = 3
@export var long_dash_distance: float = 1200.0
@export var quick_windup: float = 0.4
@export var quick_dash_distance: float = 520.0

var _pattern_index: int = 0
var _chain_left: int = 0

func enraged() -> bool:
	return hp * 2 < max_hp

func begin_attack() -> void:
	var speed_up: float = 0.7 if enraged() else 1.0
	match _pattern_index % 3:
		Pattern.LONG_DASH:
			windup(windup_time * speed_up, long_dash_distance)
		Pattern.TRIPLE_DASH:
			_chain_left = 2
			windup(quick_windup * speed_up, quick_dash_distance)
		Pattern.SUMMON:
			_summon()
	_pattern_index += 1

func after_dash() -> void:
	if _chain_left > 0:
		_chain_left -= 1
		windup(quick_windup * (0.7 if enraged() else 1.0), quick_dash_distance)
		return
	super.after_dash()

func _summon() -> void:
	var count: int = summon_count + (2 if enraged() else 0)
	for i: int in count:
		var offset: Vector2 = Vector2.from_angle(TAU * i / count) * 170.0
		game.spawn_enemy(rat_scene, global_position + offset)
	game.sfx.play(&"squeak")
	game.shake(6.0, 0.2)
	phase = Phase.RECOVER
	_timer = recover_time
