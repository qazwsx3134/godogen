extends "res://domain/step_provider.gd"
class_name MockStepProvider

## Deterministic development provider.
##
## All input is stored in state.step_debug.  There is no process-global
## counter, so a saved state and a relaunch produce the same query result.

const SOURCE_MOCK: String = "mock"
const DAY_SECONDS: int = 86400
const MODE_NORMAL: String = "normal"
const MODE_DENIED: String = "denied"
const MODE_UNAVAILABLE: String = "unavailable"
const MODE_DELAYED: String = "delayed"
const MODE_DUPLICATE: String = "duplicate"
const MODE_REBOOT: String = "reboot"
const VALID_MODES: Array[String] = [
	MODE_NORMAL,
	MODE_DENIED,
	MODE_UNAVAILABLE,
	MODE_DELAYED,
	MODE_DUPLICATE,
	MODE_REBOOT,
]

func capabilities() -> Dictionary:
	return {
		"source": SOURCE_MOCK,
		"available": true,
		"historical": true,
		"background": true,
		"debug": true,
	}

func permission() -> String:
	return "granted"

func add_steps(state: Dictionary, count: int, now: int) -> void:
	if count < 0:
		return
	var debug: Dictionary = _ensure_debug(state)
	var next_event_id: int = int(debug.get("next_event_id", 0)) + 1
	var sensor_epoch: int = int(debug.get("sensor_epoch", 0))
	var events: Array = debug.get("events", [])
	events.append({
		"id": "step-event-%d" % next_event_id,
		"at_utc": now,
		"steps": count,
		"sensor_epoch": sensor_epoch,
	})
	debug["events"] = events
	debug["next_event_id"] = next_event_id
	debug["total_steps"] = int(debug.get("total_steps", 0)) + count
	state["step_debug"] = debug

func set_mode(state: Dictionary, mode: String, now: int) -> void:
	if not VALID_MODES.has(mode):
		return
	var debug: Dictionary = _ensure_debug(state)
	debug["mode"] = mode
	debug["last_mode_at"] = now
	if mode == MODE_DELAYED:
		# The first query is intentionally unavailable.  The next query is the
		# re-check that receives the now-available persisted event history.
		debug["delay_pending"] = true
	elif mode != MODE_DELAYED:
		debug["delay_pending"] = false
	if mode == MODE_REBOOT:
		var next_epoch: int = int(debug.get("sensor_epoch", 0)) + 1
		debug["sensor_epoch"] = next_epoch
		var reboots: Array = debug.get("reboots", [])
		reboots.append({
			"at_utc": now,
			"sensor_epoch": next_epoch,
		})
		debug["reboots"] = reboots
	state["step_debug"] = debug

func query(state: Dictionary, from_utc: int, to_utc: int) -> Dictionary:
	var query_from: int = from_utc
	var query_to: int = max(to_utc, query_from)
	var debug: Dictionary = _ensure_debug(state)
	var mode: String = String(debug.get("mode", MODE_NORMAL))
	var coverage: Dictionary = {
		"from_utc": query_from,
		"to_utc": query_to,
		"complete": false,
		"known": false,
	}

	if query_to < query_from:
		return {
			"source": SOURCE_MOCK,
			"status": "error",
			"coverage": coverage,
			"buckets": [],
			"today_steps": null,
			"message": "模擬步數查詢區間無效。",
		}

	if mode == MODE_DENIED:
		return {
			"source": SOURCE_MOCK,
			"status": "denied",
			"coverage": coverage,
			"buckets": [],
			"today_steps": null,
			"message": "模擬步數權限被拒絕。",
		}
	if mode == MODE_UNAVAILABLE:
		return {
			"source": SOURCE_MOCK,
			"status": "unavailable",
			"coverage": coverage,
			"buckets": [],
			"today_steps": null,
			"message": "模擬裝置沒有步數來源。",
		}
	if mode == MODE_DELAYED and bool(debug.get("delay_pending", true)):
		# Persist the consumed delay marker so this behaves consistently after a
		# save/relaunch: a later explicit query is the retry, not a new total.
		debug["delay_pending"] = false
		state["step_debug"] = debug
		return {
			"source": SOURCE_MOCK,
			"status": "delayed",
			"coverage": coverage,
			"buckets": [],
			"today_steps": null,
			"message": "模擬步數資料尚未到達，請稍後重查。",
		}

	var buckets: Array = _build_buckets(debug, query_from, query_to)
	if mode == MODE_DUPLICATE:
		var duplicated: Array = []
		for bucket_value in buckets:
			var bucket: Dictionary = bucket_value
			duplicated.append(bucket.duplicate(true))
			duplicated.append(bucket.duplicate(true))
		buckets = duplicated

	coverage["complete"] = true
	coverage["known"] = true
	coverage["bucket_count"] = buckets.size()
	return {
		"source": SOURCE_MOCK,
		"status": "ok",
		"coverage": coverage,
		"buckets": buckets,
		# This is the mock device's current local-day total, deliberately
		# independent from the active egg query range.
		"today_steps": _today_total(debug, state, query_to),
		"message": "模擬步數同步完成。",
	}

static func _ensure_debug(state: Dictionary) -> Dictionary:
	var raw: Variant = state.get("step_debug", null)
	var debug: Dictionary
	if raw is Dictionary:
		debug = raw
	else:
		debug = {}
	if not debug.has("source"):
		debug["source"] = SOURCE_MOCK
	if not debug.has("mode") or not VALID_MODES.has(String(debug["mode"])):
		debug["mode"] = MODE_NORMAL
	if not debug.has("events") or not (debug["events"] is Array):
		debug["events"] = []
	if not debug.has("reboots") or not (debug["reboots"] is Array):
		debug["reboots"] = []
	if not debug.has("sensor_epoch"):
		debug["sensor_epoch"] = 0
	if not debug.has("next_event_id"):
		debug["next_event_id"] = 0
	if not debug.has("total_steps"):
		debug["total_steps"] = 0
	if not debug.has("delay_pending"):
		debug["delay_pending"] = false
	state["step_debug"] = debug
	return debug

static func _day_start(utc_seconds: int) -> int:
	return floori(float(utc_seconds) / float(DAY_SECONDS)) * DAY_SECONDS

static func _local_day_bounds(state: Dictionary, utc_seconds: int) -> Vector2i:
	var settings_value: Variant = state.get("settings", {})
	var settings: Dictionary = settings_value if settings_value is Dictionary else {}
	var offset_minutes: int = int(settings.get("timezone_offset_minutes", 0))
	var offset_seconds: int = offset_minutes * 60
	var local_seconds: int = utc_seconds + offset_seconds
	var local_start: int = floori(float(local_seconds) / float(DAY_SECONDS)) * DAY_SECONDS
	return Vector2i(local_start - offset_seconds, local_start - offset_seconds + DAY_SECONDS)

static func _event_in_range(event_at: int, query_from: int, query_to: int) -> bool:
	# The public query range is inclusive at both ends.  This makes a step
	# added with the caller's `now` visible immediately; bucket IDs still keep
	# the event from being counted again on the next query.
	return event_at >= query_from and event_at <= query_to

static func _build_buckets(debug: Dictionary, query_from: int, query_to: int) -> Array:
	var events_value: Variant = debug.get("events", [])
	var events: Array = events_value if events_value is Array else []
	var by_key: Dictionary = {}
	var first_day: int = _day_start(query_from)
	var last_day: int = _day_start(query_to)
	var cursor: int = first_day
	var current_epoch: int = int(debug.get("sensor_epoch", 0))

	while cursor <= last_day:
		var day_from: int = max(query_from, cursor)
		var day_to: int = min(query_to, cursor + DAY_SECONDS - 1)
		if day_to >= day_from:
			var current_key: String = _bucket_id(cursor, current_epoch)
			by_key[current_key] = {
				"id": current_key,
				"from_utc": day_from,
				"to_utc": day_to,
				"steps": 0,
				"complete": true,
				"sensor_epoch": current_epoch,
			}
		cursor += DAY_SECONDS

	for event_value in events:
		if not (event_value is Dictionary):
			continue
		var event: Dictionary = event_value
		var event_at: int = int(event.get("at_utc", 0))
		if not _event_in_range(event_at, query_from, query_to):
			continue
		var event_day: int = _day_start(event_at)
		var event_epoch: int = int(event.get("sensor_epoch", current_epoch))
		var key: String = _bucket_id(event_day, event_epoch)
		if not by_key.has(key):
			by_key[key] = {
				"id": key,
				"from_utc": max(query_from, event_day),
				"to_utc": min(query_to, event_day + DAY_SECONDS - 1),
				"steps": 0,
				"complete": true,
				"sensor_epoch": event_epoch,
			}
		var bucket: Dictionary = by_key[key]
		bucket["steps"] = int(bucket.get("steps", 0)) + max(0, int(event.get("steps", 0)))
		by_key[key] = bucket

	var keys: Array = by_key.keys()
	keys.sort()
	var result: Array = []
	for key_value in keys:
		result.append(by_key[key_value])
	return result

static func _bucket_id(day_start: int, sensor_epoch: int) -> String:
	return "mock:%d:epoch:%d" % [day_start, sensor_epoch]

static func _today_total(debug: Dictionary, state: Dictionary, utc_seconds: int) -> int:
	var bounds: Vector2i = _local_day_bounds(state, utc_seconds)
	var events_value: Variant = debug.get("events", [])
	var events: Array = events_value if events_value is Array else []
	var total: int = 0
	for event_value in events:
		if not (event_value is Dictionary):
			continue
		var event: Dictionary = event_value
		var event_at: int = int(event.get("at_utc", 0))
		if event_at >= bounds.x and event_at <= utc_seconds and event_at < bounds.y:
			total += max(0, int(event.get("steps", 0)))
	return total
