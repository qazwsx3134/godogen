extends RefCounted
## Run and lifetime goals from {id, tier, event, need, per_run, reward} records.
## `const RunGoals = preload("res://addons/proto_kit/run_goals.gd")`
## Completion unlocks rewards permanently; saves omit per-run counters.

var _goals: Dictionary = {}
var _counts: Dictionary = {}
var _completed: Array[String] = []
var _tier: int = 0

func _init(goals: Array[Dictionary]) -> void:
	for goal: Dictionary in goals:
		_goals[str(goal.id)] = goal.duplicate(true)

func begin_run(tier: int = 0) -> void:
	_tier = tier
	for id: String in _goals:
		if bool(_goals[id].get("per_run", true)):
			_counts.erase(id)

func note(event: String, amount: int = 1) -> Array:
	var newly_completed: Array[String] = []
	for id: String in _goals:
		var goal: Dictionary = _goals[id]
		if id in _completed or int(goal.get("tier", 0)) > _tier or str(goal.get("event", "")) != event:
			continue
		_counts[id] = mini(int(goal.need), int(_counts.get(id, 0)) + maxi(0, amount))
		if int(_counts[id]) >= int(goal.need):
			_completed.append(id)
			newly_completed.append(id)
	return newly_completed

func progress(id: String) -> Vector2i:
	if not _goals.has(id):
		return Vector2i(-1, 0)
	var need: int = int(_goals[id].need)
	if int(_goals[id].get("tier", 0)) > _tier:
		return Vector2i(-1, need)
	return Vector2i(need if id in _completed else int(_counts.get(id, 0)), need)

func claimed() -> int:
	return _completed.size()

func total() -> int:
	return _goals.size()

func rewards_unlocked() -> Array:
	var rewards: Array[String] = []
	for id: String in _completed:
		var reward: String = str(_goals[id].get("reward", ""))
		if not reward.is_empty() and reward not in rewards:
			rewards.append(reward)
	return rewards

func to_dict() -> Dictionary:
	var persistent: Dictionary = {}
	for id: String in _counts:
		if not bool(_goals[id].get("per_run", true)):
			persistent[id] = _counts[id]
	return {"completed": _completed.duplicate(), "claimed": claimed(), "persistent_counts": persistent}

func from_dict(data: Dictionary) -> void:
	_completed.clear()
	_counts.clear()
	_tier = 0
	for id: Variant in data.get("completed", []):
		if _goals.has(str(id)) and str(id) not in _completed:
			_completed.append(str(id))
	for id: String in data.get("persistent_counts", {}):
		if _goals.has(id) and not bool(_goals[id].get("per_run", true)):
			_counts[id] = clampi(int(data.persistent_counts[id]), 0, int(_goals[id].need))
