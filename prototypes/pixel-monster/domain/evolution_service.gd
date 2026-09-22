extends RefCounted
class_name EvolutionService

const PetModelScript = preload("res://domain/pet_model.gd")
const CareServiceScript = preload("res://domain/care_service.gd")


static func check(state: Dictionary, now: int) -> Array:
	var pet_variant: Variant = state.get("pet", {})
	if not pet_variant is Dictionary or (pet_variant as Dictionary).is_empty():
		return []
	var last_tick: int = int(state.get("last_tick", now))
	if now < last_tick:
		return []
	var effective_now: int = maxi(now, last_tick)
	var pet: Dictionary = pet_variant
	var evolution_config: Dictionary = _dict(CareServiceScript.balance().get("evolution", {}))
	var results: Array = []
	var transition_count: int = 0

	while transition_count < 2:
		var stage: String = str(pet.get("stage", "baby"))
		var stage_started_at: int = int(pet.get("stage_started_at", pet.get("born_at", effective_now)))
		if stage == "baby":
			var baby_at: int = stage_started_at + int(evolution_config.get("baby_seconds", 7200))
			if effective_now < baby_at:
				break
			pet["stage"] = "growing"
			pet["species"] = str(evolution_config.get("growing_species", "bloom"))
			pet["stage_started_at"] = baby_at
			_record_transition(pet, "baby", "growing", baby_at, "", {})
			results.append("芽芽長大了，進入成長階段。")
			transition_count += 1
			continue
		if stage == "growing":
			var growing_at: int = stage_started_at + int(evolution_config.get("growing_seconds", 86400))
			if effective_now < growing_at or int(pet.get("training_count", 0)) < int(evolution_config.get("growing_training_count", 3)):
				break
			var mature_at: int = maxi(growing_at, _third_training_at(pet, effective_now, int(evolution_config.get("growing_training_count", 3))))
			var branch: String = _select_branch(pet)
			var mature_species: Dictionary = _dict(evolution_config.get("mature_species", {}))
			pet["stage"] = "mature"
			pet["species"] = str(mature_species.get(branch, "ember"))
			pet["stage_started_at"] = mature_at
			pet["evolution_branch"] = branch
			pet["evolution_modifiers"] = _finite_modifiers(pet, evolution_config)
			_record_transition(pet, "growing", "mature", mature_at, branch, _dict(pet.get("evolution_modifiers", {})))
			results.append("成長完成，進化為%s型成熟體。" % _branch_name(branch))
			transition_count += 1
			continue
		break

	return results


static func archive(state: Dictionary, now: int) -> Dictionary:
	var pet_variant: Variant = state.get("pet", {})
	if not pet_variant is Dictionary or (pet_variant as Dictionary).is_empty():
		return {"ok": false, "message": "目前沒有可收藏的怪獸。"}
	var pet: Dictionary = pet_variant
	if str(pet.get("stage", "")) != "mature":
		return {"ok": false, "message": "只有成熟體可以收藏。"}
	var pending_variant: Variant = state.get("pending_battle", {})
	if not pending_variant is Dictionary:
		return {"ok": false, "message": "戰鬥資料格式無效，暫時不能收藏。"}
	var pending_battle: Dictionary = pending_variant
	if not pending_battle.is_empty() and not bool(pending_battle.get("settled", false)):
		return {"ok": false, "message": "還有一場戰鬥尚未結算，完成後才能收藏。"}
	var effective_now: int = maxi(now, int(state.get("last_tick", now)))
	var archived: Dictionary = pet.duplicate(true)
	archived["archived_at"] = effective_now
	var collection_variant: Variant = state.get("collection", [])
	var collection: Array = collection_variant if collection_variant is Array else []
	collection.append(archived)
	state["collection"] = collection
	state["pet"] = {}
	state["egg"] = {}
	return {"ok": true, "message": "%s 已收藏，可以開始下一顆蛋。" % str(archived.get("name", "怪獸")), "archived": archived}


static func _select_branch(pet: Dictionary) -> String:
	var training_variant: Variant = pet.get("training", {})
	var training: Dictionary = training_variant if training_variant is Dictionary else {}
	var power: int = int(training.get("power", 0))
	var guard: int = int(training.get("guard", 0))
	var swift: int = int(training.get("swift", 0))
	# The explicit >= ordering makes ties deterministic: power > guard > swift.
	if power >= guard and power >= swift:
		return "power"
	if guard >= swift:
		return "guard"
	return "swift"


static func _finite_modifiers(pet: Dictionary, evolution_config: Dictionary) -> Dictionary:
	var finite_config: Dictionary = _dict(evolution_config.get("finite_modifiers", {}))
	var care_config: Dictionary = _dict(finite_config.get("care", {}))
	var mistakes: int = clampi(int(pet.get("care_mistakes", 0)), 0, int(care_config.get("mistakes_cap", 3)))
	var care_modifier: int = clampi(
		int(care_config.get("base", 2)) - mistakes,
		int(care_config.get("min", -2)),
		int(care_config.get("max", 2))
	)
	var sleep_config: Dictionary = _dict(finite_config.get("sleep", {}))
	var sleep_seconds_per_hour: int = maxi(1, int(sleep_config.get("seconds_per_hour", 3600)))
	var sleep_hours: int = clampi(
		int(int(pet.get("sleep_seconds", 0)) / sleep_seconds_per_hour),
		int(sleep_config.get("min", 0)),
		int(sleep_config.get("max", 3))
	)
	var battle_config: Dictionary = _dict(finite_config.get("battle", {}))
	var battle_modifier: int = clampi(
		int(pet.get("wins", 0)) - int(pet.get("losses", 0)),
		int(battle_config.get("min", -2)),
		int(battle_config.get("max", 3))
	)
	return {"care": care_modifier, "sleep": sleep_hours, "battle": battle_modifier}


static func _third_training_at(pet: Dictionary, effective_now: int, required_count: int) -> int:
	if required_count <= 0:
		return 0
	var history_variant: Variant = pet.get("history", [])
	if not history_variant is Array:
		return 0
	var history: Array = history_variant
	var training_times: Array = []
	for item_variant in history:
		if not item_variant is Dictionary:
			continue
		var item: Dictionary = item_variant
		if str(item.get("type", "")) != "train":
			continue
		var at: int = int(item.get("at", -1))
		if at >= 0 and at <= effective_now:
			training_times.append(at)
	training_times.sort()
	if training_times.size() < required_count:
		# Older valid saves may only have training_count; retain the historical
		# growing_at transition rather than inventing a timestamp.
		return 0
	return int(training_times[required_count - 1])


static func _record_transition(pet: Dictionary, from_stage: String, to_stage: String, at: int, branch: String, modifiers: Dictionary) -> void:
	var transition: Dictionary = {"from": from_stage, "to": to_stage, "at": at}
	if not branch.is_empty():
		transition["branch"] = branch
	if not modifiers.is_empty():
		transition["modifiers"] = modifiers.duplicate(true)
	var evolutions: Array = pet.get("evolutions", []) if pet.get("evolutions", []) is Array else []
	evolutions.append(transition)
	pet["evolutions"] = evolutions
	var history: Array = pet.get("history", []) if pet.get("history", []) is Array else []
	history.append({"type": "evolution", "from": from_stage, "to": to_stage, "at": at, "branch": branch})
	pet["history"] = history


static func _branch_name(branch: String) -> String:
	match branch:
		"power":
			return "力量"
		"guard":
			return "防禦"
		_:
			return "敏捷"


static func _dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}
