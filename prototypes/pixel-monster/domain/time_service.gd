extends RefCounted
class_name TimeService

const CareServiceScript = preload("res://domain/care_service.gd")


static func advance(state: Dictionary, now: int) -> Dictionary:
	var last_tick: int = int(state.get("last_tick", now))
	if now <= last_tick:
		return {
			"elapsed": 0,
			"protected": _pet_is_hibernating(state),
			"message": "裝置時間沒有前進，未重複結算。",
		}

	var raw_elapsed: int = now - last_tick
	var pet_variant: Variant = state.get("pet", {})
	if not pet_variant is Dictionary or (pet_variant as Dictionary).is_empty():
		state["last_tick"] = now
		return {"elapsed": raw_elapsed, "protected": false, "message": "目前沒有怪獸，時間標記已更新。"}

	var pet: Dictionary = pet_variant
	var conditions: Dictionary = _mutable_dictionary(pet, "conditions")
	if bool(conditions.get("hibernating", false)):
		_update_age(pet, now)
		state["last_tick"] = now
		return {"elapsed": 0, "protected": true, "message": "怪獸正在保護性休眠，需求暫停結算。"}

	var time_config: Dictionary = _dict(CareServiceScript.balance().get("time", {}))
	var cap_seconds: int = maxi(0, int(time_config.get("offline_cap_seconds", 43200)))
	var elapsed: int = mini(raw_elapsed, cap_seconds)
	var process_end: int = last_tick + elapsed
	var applied: Dictionary = _apply_needs(state, pet, last_tick, process_end, time_config)
	var completed_care: Array = applied.get("completed_care", [])
	var slept_seconds: int = int(applied.get("sleep_seconds", 0))
	var protected: bool = raw_elapsed > cap_seconds
	if protected:
		conditions["hibernating"] = true
		pet["behavior"] = "sleeping"
		pet["sleep_reason"] = "protective"
		pet["lights_on"] = false
		pet["hibernating_at"] = process_end
		pet["need_events"] = {}
	_update_age(pet, now)
	state["last_tick"] = now
	var message: String
	if protected:
		message = "離線超過 12 小時，已進入保護性休眠。"
	else:
		message = "已結算 %d 秒離線需求。" % elapsed
	if not completed_care.is_empty():
		message += " 療護完成。"
	return {
		"elapsed": elapsed,
		"protected": protected,
		"message": message,
		"sleep_seconds": slept_seconds,
		"completed_care": completed_care,
	}


static func _apply_needs(state: Dictionary, pet: Dictionary, from_utc: int, to_utc: int, time_config: Dictionary) -> Dictionary:
	var duration: int = maxi(0, to_utc - from_utc)
	var completed_care: Array = []
	_append_completed(completed_care, CareServiceScript.settle_care_timers(state, from_utc))
	if duration <= 0:
		var settled_poop: int = _materialize_poop(pet, from_utc)
		if settled_poop > 0:
			_apply_poop_effect(pet, settled_poop, from_utc, time_config)
		return {"sleep_seconds": 0, "awake_seconds": 0, "completed_care": completed_care}

	# Offline settlement is intentionally segmented.  A short fixed step keeps
	# continuous decay deterministic, while explicit poop/care boundaries keep
	# discrete events from being smeared across the whole offline interval.
	var cursor: int = from_utc
	var total_sleep_seconds: int = 0
	var total_awake_seconds: int = 0
	var initial_poop: int = _materialize_poop(pet, from_utc)
	if initial_poop > 0:
		_apply_poop_effect(pet, initial_poop, from_utc, time_config)
	while cursor < to_utc:
		var next_boundary: int = _next_settlement_boundary(pet, cursor, to_utc, time_config)
		var segment: Dictionary = _apply_need_segment(state, pet, cursor, next_boundary, time_config)
		total_sleep_seconds += int(segment.get("sleep_seconds", 0))
		total_awake_seconds += int(segment.get("awake_seconds", 0))
		_append_completed(completed_care, CareServiceScript.settle_care_timers(state, next_boundary))
		cursor = next_boundary
	return {
		"sleep_seconds": total_sleep_seconds,
		"awake_seconds": total_awake_seconds,
		"completed_care": completed_care,
	}


static func _apply_need_segment(state: Dictionary, pet: Dictionary, from_utc: int, to_utc: int, time_config: Dictionary) -> Dictionary:
	var duration: int = maxi(0, to_utc - from_utc)
	if duration <= 0:
		return {"sleep_seconds": 0, "awake_seconds": 0}
	var settings: Dictionary = _dict(state.get("settings", {}))
	var sleep_seconds: int = _sleep_seconds_between(from_utc, to_utc, pet, settings)
	var awake_seconds: int = maxi(0, duration - sleep_seconds)
	var pet_config: Dictionary = _dict(CareServiceScript.balance().get("pet", {}))
	var value_min: float = float(pet_config.get("value_min", 0.0))
	var value_max: float = float(pet_config.get("value_max", 100.0))
	var seconds_per_hour: int = maxi(1, int(time_config.get("seconds_per_hour", 3600)))
	var old_fullness: float = float(pet.get("fullness", 0.0))
	var old_cleanliness: float = float(pet.get("cleanliness", 0.0))
	var hunger_awake_before: float = _need_awake_seconds(pet, "hunger")
	var cleanliness_awake_before: float = _need_awake_seconds(pet, "cleanliness")

	# Ordered offline settlement: rest/energy, hunger, then waste/cleanliness,
	# followed by mood and one-time care mistakes.
	var energy: float = float(pet.get("energy", 0.0))
	energy += float(time_config.get("energy_recovery_per_sleep_hour", 8.0)) * float(sleep_seconds) / float(seconds_per_hour)
	energy -= float(time_config.get("energy_loss_per_hour", 2.0)) * float(awake_seconds) / float(seconds_per_hour)
	pet["energy"] = clampf(energy, value_min, value_max)
	pet["sleep_seconds"] = int(pet.get("sleep_seconds", 0)) + sleep_seconds

	var fullness: float = old_fullness - float(time_config.get("fullness_loss_per_hour", 4.0)) * float(awake_seconds) / float(seconds_per_hour)
	pet["fullness"] = clampf(fullness, value_min, value_max)
	var mood: float = float(pet.get("mood", 0.0)) - float(time_config.get("mood_loss_per_hour", 1.5)) * float(awake_seconds) / float(seconds_per_hour)
	pet["mood"] = clampf(mood, value_min, value_max)

	var cleanliness_before_poop: float = old_cleanliness - float(time_config.get("cleanliness_loss_per_hour", 0.75)) * float(awake_seconds) / float(seconds_per_hour)
	pet["cleanliness"] = clampf(cleanliness_before_poop, value_min, value_max)

	var grace_seconds: float = float(time_config.get("grace_seconds", 7200))
	_update_need_event(
		pet,
		"hunger",
		old_fullness,
		float(pet["fullness"]),
		float(time_config.get("hunger_threshold", 20.0)),
		awake_seconds,
		grace_seconds,
		float(time_config.get("health_loss_per_mistake", 5.0)),
		float(time_config.get("mood_loss_per_mistake", 6.0)),
		from_utc,
		to_utc
	)
	_update_need_event(
		pet,
		"cleanliness",
		old_cleanliness,
		float(pet["cleanliness"]),
		float(time_config.get("cleanliness_threshold", 30.0)),
		awake_seconds,
		grace_seconds,
		float(time_config.get("health_loss_per_mistake", 5.0)),
		float(time_config.get("mood_loss_per_mistake", 6.0)),
		from_utc,
		to_utc
	)
	var spawned_poop: int = _materialize_poop(pet, to_utc)
	if spawned_poop > 0:
		_apply_poop_effect(pet, spawned_poop, to_utc, time_config)

	var hunger_awake_after: float = _need_awake_seconds(pet, "hunger")
	var cleanliness_awake_after: float = _need_awake_seconds(pet, "cleanliness")
	var health_loss: float = 0.0
	health_loss += _unresolved_health_loss(hunger_awake_before, hunger_awake_after, grace_seconds, float(time_config.get("untreated_health_loss_per_hour", 1.0)), seconds_per_hour)
	health_loss += _unresolved_health_loss(cleanliness_awake_before, cleanliness_awake_after, grace_seconds, float(time_config.get("untreated_health_loss_per_hour", 1.0)), seconds_per_hour)
	if health_loss > 0.0:
		pet["health"] = clampf(float(pet.get("health", value_max)) - health_loss, value_min, value_max)
	_update_sickness(pet, time_config, to_utc)
	_apply_sleep_schedule(pet, settings, to_utc, time_config)
	return {"sleep_seconds": sleep_seconds, "awake_seconds": awake_seconds}


static func _next_settlement_boundary(pet: Dictionary, cursor: int, to_utc: int, time_config: Dictionary) -> int:
	var step_seconds: int = maxi(1, int(time_config.get("settlement_step_seconds", 60)))
	var next_boundary: int = mini(to_utc, cursor + step_seconds)
	var queue_variant: Variant = pet.get("poop_queue", [])
	if queue_variant is Array:
		for due_variant in queue_variant:
			var due: int = int(due_variant)
			if due > cursor and due < next_boundary:
				next_boundary = due
	var timers_variant: Variant = pet.get("care_timers", {})
	if timers_variant is Dictionary:
		for timer_variant in (timers_variant as Dictionary).values():
			var timer_end: int = int(timer_variant)
			if timer_end > cursor and timer_end < next_boundary:
				next_boundary = timer_end
	return maxi(cursor + 1, next_boundary)


static func _append_completed(target: Array, completed: Array) -> void:
	for action in completed:
		if not target.has(action):
			target.append(action)


static func _apply_poop_effect(pet: Dictionary, spawned: int, at: int, time_config: Dictionary) -> void:
	if spawned <= 0:
		return
	var pet_config: Dictionary = _dict(CareServiceScript.balance().get("pet", {}))
	var value_min: float = float(pet_config.get("value_min", 0.0))
	var value_max: float = float(pet_config.get("value_max", 100.0))
	var before: float = float(pet.get("cleanliness", value_max))
	var penalty: float = float(time_config.get("poop_cleanliness_penalty", 8.0)) * float(spawned)
	var after: float = clampf(before - penalty, value_min, value_max)
	pet["cleanliness"] = after
	_update_need_event(
		pet,
		"cleanliness",
		before,
		after,
		float(time_config.get("cleanliness_threshold", 30.0)),
		0,
		float(time_config.get("grace_seconds", 7200)),
		float(time_config.get("health_loss_per_mistake", 5.0)),
		float(time_config.get("mood_loss_per_mistake", 6.0)),
		at,
		at
	)


static func _need_awake_seconds(pet: Dictionary, kind: String) -> float:
	var events_variant: Variant = pet.get("need_events", {})
	if not events_variant is Dictionary:
		return 0.0
	var event_variant: Variant = (events_variant as Dictionary).get(kind, {})
	if not event_variant is Dictionary:
		return 0.0
	return maxf(0.0, float((event_variant as Dictionary).get("awake_seconds", 0.0)))


static func _unresolved_health_loss(previous_awake: float, current_awake: float, grace_seconds: float, loss_per_hour: float, seconds_per_hour: int) -> float:
	if loss_per_hour <= 0.0 or seconds_per_hour <= 0:
		return 0.0
	var previous_after_grace: float = maxf(0.0, previous_awake - grace_seconds)
	var current_after_grace: float = maxf(0.0, current_awake - grace_seconds)
	return maxf(0.0, current_after_grace - previous_after_grace) * loss_per_hour / float(seconds_per_hour)


static func _update_sickness(pet: Dictionary, time_config: Dictionary, at: int) -> void:
	var conditions: Dictionary = _mutable_dictionary(pet, "conditions")
	var threshold: float = float(time_config.get("sickness_health_threshold", 40.0))
	if float(pet.get("health", 0.0)) > threshold or bool(conditions.get("sick", false)):
		pet["conditions"] = conditions
		return
	conditions["sick"] = true
	pet["conditions"] = conditions
	var history: Array = pet.get("history", []) if pet.get("history", []) is Array else []
	history.append({"type": "sick_start", "at": at, "health": pet.get("health", 0.0)})
	pet["history"] = history


static func _update_need_event(pet: Dictionary, kind: String, old_value: float, new_value: float, threshold: float, awake_seconds: int, grace_seconds: float, health_loss: float, mood_loss: float, from_utc: int, to_utc: int) -> void:
	var events: Dictionary = _mutable_dictionary(pet, "need_events")
	if new_value > threshold:
		events.erase(kind)
		return

	var event: Dictionary
	var existing: Variant = events.get(kind, {})
	if existing is Dictionary and not (existing as Dictionary).is_empty():
		event = existing
	else:
		event = {"started_at": from_utc, "awake_seconds": 0.0, "mistake_recorded": false}
		if old_value > threshold and new_value < old_value and awake_seconds > 0:
			var crossed_fraction: float = clampf((old_value - threshold) / (old_value - new_value), 0.0, 1.0)
			var after_crossing: float = float(awake_seconds) * (1.0 - crossed_fraction)
			event["started_at"] = maxi(from_utc, to_utc - int(after_crossing))
			event["awake_seconds"] = after_crossing
			events[kind] = event
			_check_mistake(pet, kind, event, grace_seconds, health_loss, mood_loss, to_utc)
			return
	event["awake_seconds"] = float(event.get("awake_seconds", 0.0)) + float(awake_seconds)
	events[kind] = event
	_check_mistake(pet, kind, event, grace_seconds, health_loss, mood_loss, to_utc)


static func _check_mistake(pet: Dictionary, kind: String, event: Dictionary, grace_seconds: float, health_loss: float, mood_loss: float, at: int) -> void:
	if bool(event.get("mistake_recorded", false)) or float(event.get("awake_seconds", 0.0)) < grace_seconds:
		return
	event["mistake_recorded"] = true
	pet["care_mistakes"] = int(pet.get("care_mistakes", 0)) + 1
	var care_config: Dictionary = _dict(CareServiceScript.balance().get("care", {}))
	var value_max: float = float(care_config.get("max_value", 100.0))
	pet["health"] = clampf(float(pet.get("health", 0.0)) - health_loss, 0.0, value_max)
	pet["mood"] = clampf(float(pet.get("mood", 0.0)) - mood_loss, 0.0, value_max)
	var history: Array = pet.get("history", []) if pet.get("history", []) is Array else []
	history.append({"type": "care_mistake", "need": kind, "at": at})
	pet["history"] = history


static func _materialize_poop(pet: Dictionary, at: int) -> int:
	var queue_variant: Variant = pet.get("poop_queue", [])
	var queue: Array = queue_variant if queue_variant is Array else []
	var remaining: Array = []
	var poop_variant: Variant = pet.get("poop", [])
	var poop: Array = poop_variant if poop_variant is Array else []
	var spawned: int = 0
	for due_variant in queue:
		var due: int = int(due_variant)
		if due <= at:
			poop.append(due)
			var history: Array = pet.get("history", []) if pet.get("history", []) is Array else []
			history.append({"type": "poop", "at": due})
			pet["history"] = history
			spawned += 1
		else:
			remaining.append(due)
	pet["poop"] = poop
	pet["poop_queue"] = remaining
	return spawned


static func _sleep_seconds_between(from_utc: int, to_utc: int, pet: Dictionary, settings: Dictionary) -> int:
	var duration: int = maxi(0, to_utc - from_utc)
	if duration <= 0:
		return 0
	var behavior: String = str(pet.get("behavior", "idle"))
	var sleep_reason: String = str(pet.get("sleep_reason", ""))
	if behavior == "sleeping" and sleep_reason != "schedule" and sleep_reason != "protective":
		return duration
	var timezone_offset: int = int(settings.get("timezone_offset_minutes", 480)) * 60
	var sleep_hour: int = clampi(int(settings.get("sleep_hour", 22)), 0, 23)
	var wake_hour: int = clampi(int(settings.get("wake_hour", 7)), 0, 23)
	if sleep_hour == wake_hour:
		return 0
	var cursor: int = from_utc
	var sleeping: int = 0
	while cursor < to_utc:
		var local_second: int = posmod(cursor + timezone_offset, 86400)
		var to_hour_boundary: int = 3600 - posmod(local_second, 3600)
		var next: int = mini(to_utc, cursor + maxi(1, to_hour_boundary))
		var sample: int = cursor + maxi(1, int((next - cursor) / 2))
		if _is_sleep_window(sample, sleep_hour, wake_hour, timezone_offset):
			sleeping += next - cursor
		cursor = next
	return sleeping


static func _is_sleep_window(utc_second: int, sleep_hour: int, wake_hour: int, timezone_offset: int) -> bool:
	var local_hour: int = int(posmod(utc_second + timezone_offset, 86400) / 3600)
	if sleep_hour == wake_hour:
		return false
	if sleep_hour < wake_hour:
		return local_hour >= sleep_hour and local_hour < wake_hour
	return local_hour >= sleep_hour or local_hour < wake_hour


static func _apply_sleep_schedule(pet: Dictionary, settings: Dictionary, at: int, time_config: Dictionary) -> void:
	var sleep_hour: int = clampi(int(settings.get("sleep_hour", 22)), 0, 23)
	var wake_hour: int = clampi(int(settings.get("wake_hour", 7)), 0, 23)
	var timezone_offset: int = int(settings.get("timezone_offset_minutes", 480)) * 60
	var scheduled_sleep: bool = _is_sleep_window(at, sleep_hour, wake_hour, timezone_offset)
	var reason: String = str(pet.get("sleep_reason", ""))
	var fatigue_threshold: float = float(time_config.get("fatigue_sleep_threshold", 30.0))
	var fatigue_sleep: bool = float(pet.get("energy", 0.0)) <= fatigue_threshold
	if (scheduled_sleep or fatigue_sleep) and reason != "manual":
		pet["behavior"] = "sleeping"
		pet["sleep_reason"] = "schedule" if scheduled_sleep else "fatigue"
		if bool(settings.get("auto_lights", true)):
			if scheduled_sleep:
				pet["lights_on"] = false
	elif not scheduled_sleep and not fatigue_sleep and (reason == "schedule" or reason == "fatigue"):
		pet["behavior"] = "idle"
		pet["sleep_reason"] = ""
		if bool(settings.get("auto_lights", true)):
			pet["lights_on"] = true


static func _update_age(pet: Dictionary, now: int) -> void:
	var born_at: int = int(pet.get("born_at", now))
	pet["age_seconds"] = maxi(0, now - born_at)


static func _pet_is_hibernating(state: Dictionary) -> bool:
	var pet_variant: Variant = state.get("pet", {})
	if not pet_variant is Dictionary:
		return false
	var conditions_variant: Variant = (pet_variant as Dictionary).get("conditions", {})
	return conditions_variant is Dictionary and bool((conditions_variant as Dictionary).get("hibernating", false))


static func _mutable_dictionary(pet: Dictionary, key: String) -> Dictionary:
	var value: Variant = pet.get(key, {})
	var dictionary: Dictionary = value if value is Dictionary else {}
	pet[key] = dictionary
	return dictionary


static func _dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}
