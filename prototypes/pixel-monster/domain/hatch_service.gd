extends RefCounted
class_name HatchService

## Owns the egg lifecycle.  The egg remains in state after hatching as a
## replayable record; callers must clear/archive it before starting another
## egg.  This makes a repeated check harmless and makes the one-time pet
## creation transition visible in a save.

const TIME_MODE_SECONDS: int = 24 * 60 * 60
const TARGETS: Dictionary = {
	"starter": 500,
	"regular": 2000,
	"special": 5000,
}

static func start_egg(state: Dictionary, now: int, kind: String = "starter") -> Dictionary:
	var target: int = int(TARGETS.get(kind, 0))
	if target <= 0:
		return {
			"ok": false,
			"message": "未知的蛋種，無法開始孵化。",
			"egg": {},
		}

	var pet_value: Variant = state.get("pet", {})
	if pet_value is Dictionary and not (pet_value as Dictionary).is_empty():
		return {
			"ok": false,
			"message": "目前已有怪獸，不能取代牠開始新蛋。",
			"egg": _copy_dictionary(state.get("egg", {})),
		}
	var existing_egg_value: Variant = state.get("egg", {})
	if not (existing_egg_value is Dictionary):
		return {
			"ok": false,
			"message": "目前蛋的資料格式無效，未覆寫。",
			"egg": {},
		}
	var existing_egg: Dictionary = existing_egg_value
	if not existing_egg.is_empty():
		return {
			"ok": false,
			"message": "目前已有一顆蛋，不能靜默替換。",
			"egg": existing_egg.duplicate(true),
		}

	var sequence: int = int(state.get("egg_sequence", 0)) + 1
	var egg_id: String = "egg-%d" % sequence
	var ledger: Dictionary = {
		"version": 1,
		"egg_id": egg_id,
		"source": "",
		"status": "not_synced",
		"last_source_status": "",
		"last_sync": 0,
		"query_from": now,
		"query_to": now,
		"coverage": {},
		"buckets": {},
		"observed_steps": 0,
	}
	var egg: Dictionary = {
		"id": egg_id,
		"kind": kind,
		"started_at": now,
		"target_steps": target,
		"credited_steps": 0,
		"mode": "steps",
		"hatched": false,
		"hatched_at": 0,
		"time_started_at": now,
		"time_required_seconds": TIME_MODE_SECONDS,
		"step_source": "",
		"step_coverage": {},
		"last_sync": 0,
		"step_buckets": {},
		"step_ledger": ledger,
	}
	state["egg_sequence"] = sequence
	state["egg"] = egg
	# The ledger is rooted at the state so it survives an egg object being
	# reconstructed from JSON. It is also mirrored on egg for UI convenience.
	state["step_ledger"] = ledger
	return {
		"ok": true,
		"message": "已開始%s蛋的孵化。" % _kind_name(kind),
		"egg": egg.duplicate(true),
	}

static func check(state: Dictionary, now: int) -> Dictionary:
	var egg_result: Dictionary = _get_active_egg(state)
	if not bool(egg_result.get("ok", false)):
		return {
			"ok": false,
			"hatched": false,
			"message": String(egg_result.get("message", "目前沒有蛋。")),
		}
	var egg: Dictionary = egg_result["egg"]
	if bool(egg.get("hatched", false)):
		return {
			"ok": true,
			"hatched": false,
			"message": "這顆蛋已經孵化。",
			"egg": egg.duplicate(true),
			"pet": _copy_dictionary(state.get("pet", {})),
		}

	var started_at: int = int(egg.get("started_at", now))
	if now < started_at:
		return {
			"ok": false,
			"hatched": false,
			"message": "裝置時間早於蛋的開始時間，暫停孵化結算。",
			"egg": egg.duplicate(true),
		}
	var mode: String = String(egg.get("mode", "steps"))
	var ready: bool = false
	if mode == "time":
		ready = now - started_at >= TIME_MODE_SECONDS
	else:
		var target: int = max(0, int(egg.get("target_steps", 0)))
		ready = target > 0 and int(egg.get("credited_steps", 0)) >= target
	if not ready:
		return {
			"ok": true,
			"hatched": false,
			"message": _progress_message(egg, now),
			"egg": egg.duplicate(true),
		}
	return _hatch(state, egg, now)

static func use_time_mode(state: Dictionary, now: int) -> Dictionary:
	var egg_result: Dictionary = _get_active_egg(state)
	if not bool(egg_result.get("ok", false)):
		return {
			"ok": false,
			"hatched": false,
			"message": String(egg_result.get("message", "目前沒有蛋。")),
		}
	var egg: Dictionary = egg_result["egg"]
	if bool(egg.get("hatched", false)):
		return {
			"ok": true,
			"hatched": false,
			"message": "這顆蛋已經孵化，時間模式不需重複設定。",
			"egg": egg.duplicate(true),
		}
	var started_at: int = int(egg.get("started_at", now))
	if now < started_at:
		return {
			"ok": false,
			"hatched": false,
			"message": "裝置時間早於蛋的開始時間，暫停時間孵化。",
			"egg": egg.duplicate(true),
		}

	var candidate: Dictionary = egg.duplicate(true)
	candidate["mode"] = "time"
	candidate["time_started_at"] = started_at
	candidate["time_required_seconds"] = TIME_MODE_SECONDS
	if now - started_at >= TIME_MODE_SECONDS:
		return _hatch(state, candidate, now)
	state["egg"] = candidate
	# A time-mode egg deliberately has no step source or step carry.  Resetting
	# its ledger prevents a later accidental provider call from adding steps.
	var ledger: Dictionary = _new_ledger(String(candidate.get("id", "")), started_at)
	ledger["status"] = "time_mode"
	state["step_ledger"] = ledger
	candidate["step_ledger"] = ledger
	candidate["step_source"] = ""
	candidate["step_buckets"] = {}
	return {
		"ok": true,
		"hatched": false,
		"message": "已切換時間孵化；從蛋開始時間起滿 24 小時完成。",
		"egg": candidate.duplicate(true),
	}

static func _hatch(state: Dictionary, egg: Dictionary, now: int) -> Dictionary:
	# Build the pet before mutating the egg. If the care worker's PetModel is
	# not available yet, the transition remains retryable and no half-hatched
	# state is written.
	var pet_script_value: Variant = load("res://domain/pet_model.gd")
	if pet_script_value == null or not (pet_script_value is Script):
		return {
			"ok": false,
			"hatched": false,
			"message": "PetModel 尚未可用，孵化未完成。",
			"egg": egg.duplicate(true),
		}
	var pet_script: Script = pet_script_value
	if not pet_script.has_method("create_pet"):
		return {
			"ok": false,
			"hatched": false,
			"message": "PetModel 缺少 create_pet(now) API，孵化未完成。",
			"egg": egg.duplicate(true),
		}
	var pet_value: Variant = pet_script.call("create_pet", now)
	if not (pet_value is Dictionary) or (pet_value as Dictionary).is_empty():
		return {
			"ok": false,
			"hatched": false,
			"message": "PetModel 未產生有效怪獸，孵化未完成。",
			"egg": egg.duplicate(true),
		}
	var new_pet: Dictionary = pet_value
	var hatched_egg: Dictionary = egg.duplicate(true)
	hatched_egg["hatched"] = true
	hatched_egg["hatched_at"] = now
	if String(hatched_egg.get("mode", "steps")) == "steps":
		hatched_egg["credited_steps"] = max(
			int(hatched_egg.get("target_steps", 0)),
			int(hatched_egg.get("credited_steps", 0))
		)
	state["pet"] = new_pet
	state["egg"] = hatched_egg
	state["step_ledger"] = hatched_egg.get("step_ledger", state.get("step_ledger", {}))
	return {
		"ok": true,
		"hatched": true,
		"message": "蛋孵化完成，芽芽來到身邊了。",
		"egg": hatched_egg.duplicate(true),
		"pet": new_pet.duplicate(true),
	}

static func _get_active_egg(state: Dictionary) -> Dictionary:
	var egg_value: Variant = state.get("egg", {})
	if not (egg_value is Dictionary):
		return {"ok": false, "message": "蛋的資料格式無效。", "egg": {}}
	var egg: Dictionary = egg_value
	if egg.is_empty():
		return {"ok": false, "message": "目前沒有蛋。", "egg": {}}
	return {"ok": true, "egg": egg}

static func _new_ledger(egg_id: String, started_at: int) -> Dictionary:
	return {
		"version": 1,
		"egg_id": egg_id,
		"source": "",
		"status": "not_synced",
		"last_source_status": "",
		"last_sync": 0,
		"query_from": started_at,
		"query_to": started_at,
		"coverage": {},
		"buckets": {},
		"observed_steps": 0,
	}

static func _progress_message(egg: Dictionary, now: int) -> String:
	if String(egg.get("mode", "steps")) == "time":
		var elapsed: int = max(0, now - int(egg.get("started_at", now)))
		var remaining: int = max(0, TIME_MODE_SECONDS - elapsed)
		return "時間孵化進行中，還差 %d 秒。" % remaining
	return "孵化進度 %d / %d 步。" % [
		int(egg.get("credited_steps", 0)),
		int(egg.get("target_steps", 0)),
	]

static func _kind_name(kind: String) -> String:
	match kind:
		"starter":
			return "新手"
		"regular":
			return "普通"
		"special":
			return "特殊"
	return kind

static func _copy_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}
