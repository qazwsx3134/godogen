extends RefCounted
class_name CareService

## Player-facing care operations.  All timestamps come from the caller; this
## service never reads the system clock.

const BALANCE_PATH: String = "res://data/balance.json"


static func balance() -> Dictionary:
	var fallback: Dictionary = _fallback_balance()
	if not FileAccess.file_exists(BALANCE_PATH):
		return fallback
	var file := FileAccess.open(BALANCE_PATH, FileAccess.READ)
	if file == null:
		return fallback
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return fallback


static func can_act(state: Dictionary, action: String, now: int) -> String:
	var pet_variant: Variant = state.get("pet", {})
	if not pet_variant is Dictionary or (pet_variant as Dictionary).is_empty():
		return "目前沒有怪獸可照顧。"
	var pet: Dictionary = pet_variant
	if not _is_known_action(action):
		return "未知的照顧操作。"
	var check_now: int = _effective_now(state, now)
	var balance_config: Dictionary = balance()
	var care_config: Dictionary = _dict(balance_config.get("care", {}))
	var conditions_variant: Variant = pet.get("conditions", {})
	var conditions: Dictionary = conditions_variant if conditions_variant is Dictionary else {}
	if action != "wake" and bool(conditions.get("hibernating", false)):
		return "怪獸正在保護性休眠，請先喚醒。"
	if action != "wake" and action != "lights" and str(pet.get("behavior", "idle")) == "sleeping":
		return "怪獸正在睡覺，請先開燈或喚醒。"

	match action:
		"wake":
			if not bool(conditions.get("hibernating", false)) and str(pet.get("behavior", "idle")) != "sleeping":
				return "怪獸目前已經醒著。"
		"meal":
			var meal_config: Dictionary = _dict(care_config.get("meal", {}))
			if _cooldown_remaining(pet, action, check_now) > 0:
				return _cooldown_message("正餐", _cooldown_remaining(pet, action, check_now))
			if float(pet.get("fullness", 0.0)) >= float(meal_config.get("refuse_at_fullness", 95.0)):
				return "怪獸已經接近吃飽，先不要再餵正餐。"
		"snack":
			var snack_config: Dictionary = _dict(care_config.get("snack", {}))
			if _cooldown_remaining(pet, action, check_now) > 0:
				return _cooldown_message("點心", _cooldown_remaining(pet, action, check_now))
			if float(pet.get("fullness", 0.0)) >= float(snack_config.get("refuse_at_fullness", 98.0)):
				return "怪獸已經吃飽，暫時不需要點心。"
		"clean":
			var poop_variant: Variant = pet.get("poop", [])
			var poop: Array = poop_variant if poop_variant is Array else []
			if poop.is_empty() and float(pet.get("cleanliness", 0.0)) >= 99.0:
				return "房間目前很乾淨。"
			if _cooldown_remaining(pet, action, check_now) > 0:
				return _cooldown_message("清潔", _cooldown_remaining(pet, action, check_now))
		"heal_injury":
			return _can_start_or_finish_heal(pet, "injured", action, check_now)
		"heal_sickness":
			return _can_start_or_finish_heal(pet, "sick", action, check_now)
		"train":
			var training_balance: Dictionary = _dict(balance().get("training", {}))
			var costs: Dictionary = _dict(training_balance.get("energy_cost", {}))
			var minimum_cost: int = int(costs.get("1", 8))
			if float(pet.get("energy", 0.0)) < float(minimum_cost):
				return "精力不足，先休息一下。"
			if _cooldown_remaining(pet, action, check_now) > 0:
				return _cooldown_message("訓練", _cooldown_remaining(pet, action, check_now))
			if bool(conditions.get("injured", false)) or bool(conditions.get("sick", false)):
				return "身體狀況不適，暫時不能訓練。"
		"battle":
			if bool(conditions.get("injured", false)):
				return "受傷中，暫時不能戰鬥。"
			if bool(conditions.get("sick", false)):
				return "生病中，暫時不能戰鬥。"
			var battle_config: Dictionary = _dict(balance_config.get("battle", {}))
			var battle_energy_cost: float = float(battle_config.get("energy_cost", 12))
			if float(pet.get("energy", 0.0)) < battle_energy_cost:
				return "精力不足，至少需要 %d 點才能戰鬥。" % int(battle_energy_cost)
			var pending_variant: Variant = state.get("pending_battle", {})
			if pending_variant is Dictionary and not (pending_variant as Dictionary).is_empty() and not bool((pending_variant as Dictionary).get("settled", false)):
				return "還有一場戰鬥尚未結算。"
		_:
			pass
	return ""


static func perform(state: Dictionary, action: String, now: int) -> Dictionary:
	var denial: String = can_act(state, action, now)
	if not denial.is_empty():
		return _result(false, denial, "idle")
	var pet: Dictionary = state["pet"]
	var action_now: int = _effective_now(state, now)
	var care_balance: Dictionary = balance()
	var care_config: Dictionary = _dict(care_balance.get("care", {}))
	var max_value: float = float(care_config.get("max_value", 100.0))
	var pet_balance: Dictionary = _dict(care_balance.get("pet", {}))
	var weight_floor: float = float(pet_balance.get("weight_floor", 0.1))

	match action:
		"wake":
			var wake_conditions: Dictionary = _mutable_conditions(pet)
			wake_conditions["hibernating"] = false
			pet["conditions"] = wake_conditions
			pet["behavior"] = "idle"
			pet["sleep_reason"] = ""
			pet["lights_on"] = true
			_append_history(pet, {"type": "wake", "at": action_now})
			_touch(state, action_now)
			return _result(true, "怪獸醒來了。", "happy")
		"lights":
			var lights_on: bool = not bool(pet.get("lights_on", true))
			pet["lights_on"] = lights_on
			if lights_on:
				pet["behavior"] = "idle"
				pet["sleep_reason"] = ""
				_append_history(pet, {"type": "lights_on", "at": action_now})
				_touch(state, action_now)
				return _result(true, "開燈了，怪獸慢慢醒來。", "idle")
			var sleep_reason: String = sleep_reason_for(state, action_now)
			if sleep_reason.is_empty():
				pet["behavior"] = "idle"
				pet["sleep_reason"] = ""
				_append_history(pet, {"type": "lights_off", "at": action_now, "sleep": false})
				_touch(state, action_now)
				return _result(true, "關燈了，但怪獸精神還足，先保持清醒。", "idle")
			pet["behavior"] = "sleeping"
			pet["sleep_reason"] = sleep_reason
			_append_history(pet, {"type": "lights_off", "at": action_now})
			_touch(state, action_now)
			return _result(true, "關燈休息吧。", "sleep")
		"meal", "snack":
			var food_config: Dictionary = _dict(care_config.get(action, {}))
			var fullness: float = clampf(float(pet.get("fullness", 0.0)) + float(food_config.get("fullness", 0.0)), 0.0, max_value)
			pet["fullness"] = fullness
			pet["mood"] = clampf(float(pet.get("mood", 0.0)) + float(food_config.get("mood", 0.0)), 0.0, max_value)
			pet["weight"] = maxf(weight_floor, float(pet.get("weight", weight_floor)) + float(food_config.get("weight", 0.0)))
			_queue_poop(pet, action_now + int(food_config.get("poop_delay_seconds", 0)))
			_resolve_need_event(pet, "hunger")
			_set_cooldown(pet, action, action_now + int(food_config.get("cooldown_seconds", 0)))
			_append_history(pet, {"type": action, "at": action_now, "fullness": food_config.get("fullness", 0.0)})
			_touch(state, action_now)
			return _result(true, "吃得很開心！", "eat")
		"clean":
			pet["poop"] = []
			var clean_config: Dictionary = _dict(care_config.get("clean", {}))
			pet["cleanliness"] = clampf(float(pet.get("cleanliness", 0.0)) + float(clean_config.get("cleanliness", 0.0)), 0.0, max_value)
			pet["mood"] = clampf(float(pet.get("mood", 0.0)) + float(clean_config.get("mood", 0.0)), 0.0, max_value)
			_resolve_need_event(pet, "cleanliness")
			_set_cooldown(pet, action, action_now + int(clean_config.get("cooldown_seconds", 0)))
			_append_history(pet, {"type": "clean", "at": action_now})
			_touch(state, action_now)
			return _result(true, "房間乾淨了，怪獸看起來舒服多了。", "happy")
		"heal_injury", "heal_sickness":
			var condition_name: String = "injured" if action == "heal_injury" else "sick"
			var timers: Dictionary = _mutable_timers(pet)
			var timer_end: int = int(timers.get(action, 0))
			if timer_end > 0 and action_now >= timer_end:
				settle_care_timers(state, action_now)
				_touch(state, action_now)
				return _result(true, "療護完成，狀態穩定下來了。", "heal")
			var heal_config: Dictionary = _dict(care_config.get("heal", {}))
			var duration_key: String = "injury_seconds" if action == "heal_injury" else "sickness_seconds"
			var duration: int = int(heal_config.get(duration_key, 1800))
			timers[action] = action_now + duration
			pet["care_timers"] = timers
			_set_cooldown(pet, action, action_now + duration)
			_append_history(pet, {"type": "care_start", "care": action, "condition": condition_name, "at": action_now, "complete_at": action_now + duration})
			_touch(state, action_now)
			return _result(true, "開始療護，還需 %d 秒。" % duration, "heal")
		_:
			return _result(false, "這個操作需要專用服務處理。", "idle")


static func train(state: Dictionary, kind: String, quality: int, now: int) -> Dictionary:
	if kind != "power" and kind != "guard" and kind != "swift":
		return _result(false, "訓練種類不正確。", "idle")
	if quality < 1 or quality > 3:
		return _result(false, "訓練品質必須是 1 到 3。", "idle")
	var denial: String = can_act(state, "train", now)
	if not denial.is_empty():
		return _result(false, denial, "idle")
	var pet: Dictionary = state["pet"]
	var action_now: int = _effective_now(state, now)
	var balance_config: Dictionary = balance()
	var training_config: Dictionary = _dict(balance_config.get("training", {}))
	var care_root: Dictionary = _dict(balance_config.get("care", {}))
	var max_value: float = float(care_root.get("max_value", 100.0))
	var pet_balance: Dictionary = _dict(balance_config.get("pet", {}))
	var weight_floor: float = float(pet_balance.get("weight_floor", 0.1))
	var energy_costs: Dictionary = _dict(training_config.get("energy_cost", {}))
	var gains: Dictionary = _dict(training_config.get("gain_by_quality", {}))
	var weights: Dictionary = _dict(training_config.get("weight_loss", {}))
	var energy_cost: int = int(energy_costs.get(str(quality), quality * 8))
	if float(pet.get("energy", 0.0)) < float(energy_cost):
		return _result(false, "這次訓練需要更多精力。", "idle")

	var training: Dictionary = _mutable_dictionary(pet, "training")
	var stage_caps: Dictionary = _dict(training_config.get("stage_caps", {}))
	var cap_config: Dictionary = _dict(stage_caps.get(str(pet.get("stage", "baby")), stage_caps.get("baby", {})))
	var current: int = int(training.get(kind, 0))
	var cap: int = int(cap_config.get(kind, 3))
	var requested_gain: int = int(gains.get(str(quality), quality))
	var gain: int = mini(requested_gain, maxi(0, cap - current))
	training[kind] = current + gain
	pet["training"] = training
	pet["training_count"] = int(pet.get("training_count", 0)) + 1
	pet["energy"] = clampf(float(pet.get("energy", 0.0)) - float(energy_cost), 0.0, max_value)
	pet["weight"] = maxf(weight_floor, float(pet.get("weight", weight_floor)) - float(weights.get(str(quality), quality * 0.05)))
	var cooldown_seconds: int = int(training_config.get("cooldown_seconds", 1800))
	_set_cooldown(pet, "train", action_now + cooldown_seconds)
	_append_history(pet, {"type": "train", "kind": kind, "quality": quality, "gain": gain, "at": action_now})
	_touch(state, action_now)
	var message: String = "訓練完成，%s 成長了 %d。" % [_kind_name(kind), gain]
	if gain == 0:
		message = "訓練完成，但 %s 已達本階段上限。" % _kind_name(kind)
	var result: Dictionary = _result(true, message, "happy")
	result["gain"] = gain
	result["kind"] = kind
	result["quality"] = quality
	return result


## Returns the reason a pet should enter sleep at this exact UTC timestamp.
## Turning the lights off is not itself a sleep command: a well-rested pet
## stays awake until its schedule or fatigue threshold says otherwise.
static func sleep_reason_for(state: Dictionary, now: int) -> String:
	var pet_variant: Variant = state.get("pet", {})
	if not pet_variant is Dictionary or (pet_variant as Dictionary).is_empty():
		return ""
	var pet: Dictionary = pet_variant
	var settings: Dictionary = _dict(state.get("settings", {}))
	if _is_sleep_window(now, settings):
		return "schedule"
	var time_config: Dictionary = _dict(balance().get("time", {}))
	var fatigue_threshold: float = float(time_config.get("fatigue_sleep_threshold", 30.0))
	if float(pet.get("energy", 0.0)) <= fatigue_threshold:
		return "fatigue"
	return ""


static func settle_care_timers(state: Dictionary, now: int) -> Array:
	var pet_variant: Variant = state.get("pet", {})
	if not pet_variant is Dictionary or (pet_variant as Dictionary).is_empty():
		return []
	var pet: Dictionary = pet_variant
	var effective_now: int = _effective_now(state, now)
	var timers: Dictionary = _mutable_timers(pet)
	var cooldowns: Dictionary = _mutable_dictionary(pet, "cooldowns")
	var conditions: Dictionary = _mutable_conditions(pet)
	var care_balance: Dictionary = balance()
	var care_root: Dictionary = _dict(care_balance.get("care", {}))
	var heal_config: Dictionary = _dict(care_root.get("heal", {}))
	var max_value: float = float(care_root.get("max_value", 100.0))
	var completed: Array = []
	for action in ["heal_injury", "heal_sickness"]:
		var timer_end: int = int(timers.get(action, 0))
		if timer_end <= 0 or effective_now < timer_end:
			continue
		var condition_name: String = "injured" if action == "heal_injury" else "sick"
		var health_key: String = "injury_health" if action == "heal_injury" else "sickness_health"
		conditions[condition_name] = false
		pet["health"] = clampf(float(pet.get("health", 0.0)) + float(heal_config.get(health_key, 12.0)), 0.0, max_value)
		pet["mood"] = clampf(float(pet.get("mood", 0.0)) + float(heal_config.get("mood", 3.0)), 0.0, max_value)
		timers.erase(action)
		cooldowns.erase(action)
		_resolve_need_event(pet, condition_name)
		_append_history(pet, {"type": "care_complete", "care": action, "at": timer_end})
		completed.append(action)
	pet["conditions"] = conditions
	pet["care_timers"] = timers
	pet["cooldowns"] = cooldowns
	return completed


static func _fallback_balance() -> Dictionary:
	return {
		"settings_defaults": {"sleep_hour": 22, "wake_hour": 7, "timezone_offset_minutes": 480, "debug_time_offset": 0},
		"pet": {
			"value_min": 0.0,
			"value_max": 100.0,
			"weight_floor": 0.1,
			"initial": {"fullness": 70.0, "mood": 75.0, "energy": 80.0, "health": 100.0, "cleanliness": 100.0, "weight": 2.0},
			"stat_floor": 1,
			"training_stat_cap": 12,
			"stage_base_stats": {"baby": {"attack": 8, "defense": 8, "agility": 8, "max_hp": 40}, "growing": {"attack": 14, "defense": 14, "agility": 14, "max_hp": 58}, "mature": {"attack": 20, "defense": 20, "agility": 20, "max_hp": 78}},
			"species_bonus": {"sprout": {"attack": 0, "defense": 0, "agility": 0}, "bloom": {"attack": 1, "defense": 1, "agility": 1}, "ember": {"attack": 2, "defense": 0, "agility": 0}, "moss": {"attack": 0, "defense": 2, "agility": 0}, "breeze": {"attack": 0, "defense": 0, "agility": 2}},
			"ideal_weight": {"baby": {"min": 1.5, "max": 3.2}, "growing": {"min": 2.8, "max": 5.5}, "mature": {"min": 4.5, "max": 8.5}},
			"species_weight_offset": {"sprout": 0.0, "bloom": 0.0, "ember": 0.2, "moss": 0.6, "breeze": -0.3},
		},
		"care": {
			"max_value": 100.0,
			"meal": {"fullness": 25.0, "mood": 4.0, "weight": 0.25, "cooldown_seconds": 900, "poop_delay_seconds": 1800, "refuse_at_fullness": 95.0},
			"snack": {"fullness": 8.0, "mood": 10.0, "weight": 0.08, "cooldown_seconds": 600, "poop_delay_seconds": 1200, "refuse_at_fullness": 98.0},
			"clean": {"cleanliness": 25.0, "mood": 5.0, "cooldown_seconds": 300},
			"heal": {"injury_seconds": 1800, "sickness_seconds": 3600, "injury_health": 18.0, "sickness_health": 12.0, "mood": 3.0, "cooldown_seconds": 1800},
		},
		"battle": {"energy_cost": 12},
		"time": {"seconds_per_hour": 3600, "offline_cap_seconds": 43200, "grace_seconds": 7200, "fullness_loss_per_hour": 4.0, "mood_loss_per_hour": 1.5, "cleanliness_loss_per_hour": 0.75, "energy_loss_per_hour": 2.0, "energy_recovery_per_sleep_hour": 8.0, "poop_cleanliness_penalty": 8.0, "health_loss_per_mistake": 5.0, "mood_loss_per_mistake": 6.0, "untreated_health_loss_per_hour": 1.0, "sickness_health_threshold": 40.0, "hunger_threshold": 20.0, "cleanliness_threshold": 30.0, "fatigue_sleep_threshold": 30.0, "settlement_step_seconds": 60},
		"training": {"energy_cost": {"1": 8, "2": 12, "3": 16}, "gain_by_quality": {"1": 1, "2": 2, "3": 3}, "weight_loss": {"1": 0.05, "2": 0.1, "3": 0.15}, "cooldown_seconds": 1800, "stage_caps": {"baby": {"power": 3, "guard": 3, "swift": 3}, "growing": {"power": 8, "guard": 8, "swift": 8}, "mature": {"power": 12, "guard": 12, "swift": 12}}},
		"evolution": {"baby_seconds": 7200, "growing_seconds": 86400, "growing_training_count": 3, "growing_species": "bloom", "mature_species": {"power": "ember", "guard": "moss", "swift": "breeze"}, "branch_modifiers": {"power": {"attack": 2, "defense": 0, "agility": 0}, "guard": {"attack": 0, "defense": 2, "agility": 0}, "swift": {"attack": 0, "defense": 0, "agility": 2}}, "finite_modifiers": {"care": {"base": 2, "mistakes_cap": 3, "min": -2, "max": 2}, "sleep": {"seconds_per_hour": 3600, "min": 0, "max": 3}, "battle": {"min": -2, "max": 3}}},
	}


static func _is_known_action(action: String) -> bool:
	return action in ["meal", "snack", "clean", "lights", "heal_injury", "heal_sickness", "train", "battle", "wake"]


static func _can_start_or_finish_heal(pet: Dictionary, condition_name: String, action: String, now: int) -> String:
	var conditions_variant: Variant = pet.get("conditions", {})
	var conditions: Dictionary = conditions_variant if conditions_variant is Dictionary else {}
	if not bool(conditions.get(condition_name, false)):
		return "目前沒有需要這項療護的狀態。"
	var timers_variant: Variant = pet.get("care_timers", {})
	var timers: Dictionary = timers_variant if timers_variant is Dictionary else {}
	var timer_end: int = int(timers.get(action, 0))
	if timer_end > now:
		return "療護倒數中，還有 %d 秒。" % (timer_end - now)
	return ""


static func _effective_now(state: Dictionary, now: int) -> int:
	return maxi(now, int(state.get("last_tick", now)))


static func _cooldown_remaining(pet: Dictionary, action: String, now: int) -> int:
	var cooldowns_variant: Variant = pet.get("cooldowns", {})
	if not cooldowns_variant is Dictionary:
		return 0
	var ready_at: int = int((cooldowns_variant as Dictionary).get(action, 0))
	return maxi(0, ready_at - now)


static func _cooldown_message(label: String, seconds: int) -> String:
	return "%s還在冷卻，請再等 %d 秒。" % [label, seconds]


static func _result(ok: bool, message: String, animation: String) -> Dictionary:
	return {"ok": ok, "message": message, "animation": animation}


static func _dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


static func _mutable_dictionary(pet: Dictionary, key: String) -> Dictionary:
	var value: Variant = pet.get(key, {})
	var dictionary: Dictionary = value if value is Dictionary else {}
	pet[key] = dictionary
	return dictionary


static func _mutable_conditions(pet: Dictionary) -> Dictionary:
	return _mutable_dictionary(pet, "conditions")


static func _mutable_timers(pet: Dictionary) -> Dictionary:
	return _mutable_dictionary(pet, "care_timers")


static func _set_cooldown(pet: Dictionary, action: String, ready_at: int) -> void:
	var cooldowns: Dictionary = _mutable_dictionary(pet, "cooldowns")
	cooldowns[action] = ready_at


static func _queue_poop(pet: Dictionary, due_at: int) -> void:
	var queue: Array = pet.get("poop_queue", []) if pet.get("poop_queue", []) is Array else []
	queue.append(due_at)
	pet["poop_queue"] = queue


static func _append_history(pet: Dictionary, event: Dictionary) -> void:
	var history: Array = pet.get("history", []) if pet.get("history", []) is Array else []
	history.append(event)
	pet["history"] = history


static func _resolve_need_event(pet: Dictionary, kind: String) -> void:
	var events: Dictionary = _mutable_dictionary(pet, "need_events")
	var time_config: Dictionary = _dict(balance().get("time", {}))
	if kind == "hunger" and float(pet.get("fullness", 0.0)) <= float(time_config.get("hunger_threshold", 20.0)):
		return
	if kind == "cleanliness" and float(pet.get("cleanliness", 0.0)) <= float(time_config.get("cleanliness_threshold", 30.0)):
		return
	events.erase(kind)


static func _touch(state: Dictionary, now: int) -> void:
	state["last_tick"] = maxi(now, int(state.get("last_tick", now)))


static func _is_sleep_window(utc_second: int, settings: Dictionary) -> bool:
	var timezone_offset: int = int(settings.get("timezone_offset_minutes", 480)) * 60
	var sleep_hour: int = clampi(int(settings.get("sleep_hour", 22)), 0, 23)
	var wake_hour: int = clampi(int(settings.get("wake_hour", 7)), 0, 23)
	var local_hour: int = int(posmod(utc_second + timezone_offset, 86400) / 3600)
	if sleep_hour == wake_hour:
		return false
	if sleep_hour < wake_hour:
		return local_hour >= sleep_hour and local_hour < wake_hour
	return local_hour >= sleep_hour or local_hour < wake_hour


static func _kind_name(kind: String) -> String:
	match kind:
		"power":
			return "力量"
		"guard":
			return "防禦"
		_:
			return "敏捷"
