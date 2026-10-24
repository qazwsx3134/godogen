extends RefCounted
## One combatant inside the battle simulation. Plain data; the battle owns every rule.

enum Order { NONE, MOVE, ATTACK }

var id: int
var team: int  # 0 = party, 1 = monster
var role: String  # leader, guardian, support, monster
var kind_id: String  # monster id, or the role for party members
var display_name: String
var level: int = 1

var pos: Vector2
var spawn: Vector2
var facing: Vector2 = Vector2(1, 1).normalized()

var max_hp: float
var hp: float
var attack: float
var defense: float
var agility: float
var crit_chance: float
var block_chance: float
var attack_ms: float
var range_cells: float
var speed: float

var alive: bool = true
var respawn_at_ms: float = -1.0
var next_attack_ms: float = 0.0
var busy_until_ms: float = 0.0
var action_ms: float = -1.0e9  # sim time of the last swing or cast start; the view plays it once
var action: StringName = &"attack"

var order: Order = Order.NONE
var target_id: int = -1
var move_goal: Vector2
var steer: Vector2 = Vector2.ZERO
var moving: bool = false  # moved during the last step; drives the walk animation

var cooldowns: Dictionary = {}  # skill or utility id -> sim time when ready
var hot_left_ms: float = 0.0
var hot_rate: float = 0.0  # HP per ms
var taunted_by: int = -1
var taunt_until_ms: float = 0.0
var last_attacker: int = -1
var last_hit_ms: float = -1.0e9
var returning: bool = false
var unreachable: Dictionary = {}  # target id -> sim time when it may be chosen again
var stuck_ms: float = 0.0
var stuck_best: float = INF

var is_boss: bool = false
var cover_until_ms: float = -1.0
var cover_ratio: float = 1.0

# Monster rewards.
var base_exp: float = 0.0
var gold: int = 0


func hp_ratio() -> float:
	return hp / max_hp if max_hp > 0.0 else 0.0


func is_ready(id_: String, now_ms: float) -> bool:
	return now_ms >= float(cooldowns.get(id_, 0.0))
