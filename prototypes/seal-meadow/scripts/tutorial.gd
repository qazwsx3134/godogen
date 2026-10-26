extends RefCounted
## First-session hints, one at a time, advanced by what the player actually does. Skippable; the step is saved.

const STEPS := [
	"點一下地面，角色會走過去。",
	"點一隻蓬蓬果凍，角色會追上去自動攻擊。",
	"果凍會成群撲過來。身邊有 3 隻時，按右下的「範圍揮砍」。",
	"打倒後會掉東西，點地上的物品撿起來。",
	"走進下方的藍色傳送圈回蓬蓬村，點村長接任務。",
]

## Index of the hint showing; STEPS.size() = finished or skipped.
var step: int = 0
var _start: Vector3
var _started: bool = false


func finished() -> bool:
	return step >= STEPS.size()


func text() -> String:
	return "" if finished() else "（%d/%d）%s" % [step + 1, STEPS.size(), STEPS[step]]


func skip() -> void:
	step = STEPS.size()


## Advances when the current hint's action has happened. Returns true when the step changed.
func update(player: Node3D) -> bool:
	if finished():
		return false
	if not _started:
		_started = true
		_start = player.position
	var met := false
	match step:
		0:
			met = player.position.distance_to(_start) > 2.5
		1:
			met = player.target != null
		2:
			met = player.sweep_left > 0.0
		3:
			met = not player.bag.slots.is_empty()
		4:
			met = player.quests.accepted or player.quests.index > 0
	if met:
		step += 1
	return met
