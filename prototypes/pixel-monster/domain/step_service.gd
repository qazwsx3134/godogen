extends RefCounted
class_name StepService

## Reconciles provider buckets into the active egg.
##
## A bucket is an authoritative observation for one provider/source interval.
## The saved ledger keeps its high-water observation and only the positive
## difference is credited.  This makes delayed data and duplicate responses
## idempotent without ever adding two sources together.

const STATUS_OK: String = "ok"
const STATUS_PARTIAL: String = "partial"
const STATUS_UNAVAILABLE: String = "unavailable"
const STATUS_DENIED: String = "denied"
const STATUS_DELAYED: String = "delayed"
const STATUS_SOURCE_CONFLICT: String = "source_conflict"
const STATUS_INVALID: String = "invalid"
const STATUS_NO_EGG: String = "no_egg"
const STATUS_TIME_MODE: String = "time_mode"
const STATUS_ROLLBACK: String = "rollback"

static func synchronize(state: Dictionary, provider: StepProvider, now: int) -> Dictionary:
	var egg_value: Variant = state.get("egg", {})
	if not (egg_value is Dictionary):
		return _failure(STATUS_NO_EGG, "目前沒有可同步的蛋。")
	var egg: Dictionary = egg_value
	if egg.is_empty():
		return _failure(STATUS_NO_EGG, "目前沒有可同步的蛋。")
	if bool(egg.get("hatched", false)):
		return _failure("hatched", "這顆蛋已經孵化，步數不再入帳。")
	if String(egg.get("mode", "steps")) == "time":
		return _failure(STATUS_TIME_MODE, "目前使用時間孵化，步數不會再入帳。")

	var started_at: int = int(egg.get("started_at", now))
	if now < started_at:
		return _failure(STATUS_ROLLBACK, "裝置時間早於蛋的開始時間，暫停步數同步。")
	var query_from: int = started_at
	var query_to: int = now

	var ledger: Dictionary = _ensure_ledger(state, egg, query_from)
	var response_value: Variant = provider.query(state, query_from, query_to)
	if not (response_value is Dictionary):
		return _record_unavailable(state, egg, ledger, now, "步數來源回傳格式無效。", STATUS_INVALID)
	var response: Dictionary = response_value
	var source: String = String(response.get("source", ""))
	var raw_status: String = String(response.get("status", "unknown"))
	var status: String = raw_status
	var coverage_value: Variant = response.get("coverage", null)
	if not (coverage_value is Dictionary):
		return _record_unavailable(
			state,
			egg,
			ledger,
			now,
			"步數 coverage 格式無效，未入帳。",
			STATUS_INVALID,
			source
		)
	var coverage: Dictionary = coverage_value
	if not _valid_coverage_shape(coverage):
		return _record_unavailable(
			state,
			egg,
			ledger,
			now,
			"步數 coverage 欄位無效，未入帳。",
			STATUS_INVALID,
			source,
			coverage
		)
	var coverage_from: int = int(coverage.get("from_utc"))
	var coverage_to: int = int(coverage.get("to_utc"))
	var provider_complete: bool = bool(coverage.get("complete"))
	var provider_known: bool = bool(coverage.get("known"))
	var covers_query: bool = coverage_from <= query_from and coverage_to >= query_to
	coverage["provider_complete"] = provider_complete
	coverage["covers_query"] = covers_query
	var locked_source: String = String(ledger.get("source", ""))
	# Refuse a source switch even when the new provider currently has no data;
	# otherwise a later response from that provider could silently overlap the
	# already-authoritative source.
	if not locked_source.is_empty() and not source.is_empty() and locked_source != source:
		return {
			"ok": false,
			"message": "步數來源不可相加；請繼續使用「%s」來源。" % locked_source,
			"status": STATUS_SOURCE_CONFLICT,
			"source": source,
			"coverage": coverage,
			"today_steps": null,
			"credited_steps": int(egg.get("credited_steps", 0)),
			"credited_delta": 0,
			"last_sync": now,
			"egg_id": String(egg.get("id", "")),
		}

	var has_known_buckets: bool = raw_status == STATUS_OK or raw_status == STATUS_PARTIAL
	if not has_known_buckets:
		var unavailable_message: String = String(response.get("message", "步數目前不可用，請稍後重試。"))
		return _record_unavailable(state, egg, ledger, now, unavailable_message, raw_status, source, coverage)
	if source.is_empty() or source == "unknown":
		return _record_unavailable(state, egg, ledger, now, "步數來源未標明，未入帳。", STATUS_INVALID, source, coverage)

	var incoming: Dictionary = {}
	var buckets_value: Variant = response.get("buckets", [])
	if not (buckets_value is Array):
		return _record_unavailable(state, egg, ledger, now, "步數 bucket 格式無效，未入帳。", STATUS_INVALID, source, coverage)
	for bucket_value in buckets_value:
		if not (bucket_value is Dictionary):
			return _record_unavailable(state, egg, ledger, now, "步數 bucket 格式無效，未入帳。", STATUS_INVALID, source, coverage)
		var bucket: Dictionary = bucket_value
		var bucket_id: String = String(bucket.get("id", bucket.get("bucket_id", "")))
		if bucket_id.is_empty():
			return _record_unavailable(state, egg, ledger, now, "步數 bucket 缺少穩定 ID，未入帳。", STATUS_INVALID, source, coverage)
		if not bucket.has("from_utc") or not bucket.has("to_utc") or not bucket.has("steps") or not bucket.has("complete"):
			return _record_unavailable(state, egg, ledger, now, "步數 bucket 欄位不完整，未入帳。", STATUS_INVALID, source, coverage)
		if not _is_integer_number(bucket.get("from_utc")) or not _is_integer_number(bucket.get("to_utc")) or not _is_integer_number(bucket.get("steps")):
			return _record_unavailable(state, egg, ledger, now, "步數 bucket 數值格式無效，未入帳。", STATUS_INVALID, source, coverage)
		if typeof(bucket.get("complete")) != TYPE_BOOL:
			return _record_unavailable(state, egg, ledger, now, "步數 bucket complete 格式無效，未入帳。", STATUS_INVALID, source, coverage)
		var bucket_from: int = int(bucket.get("from_utc"))
		var bucket_to: int = int(bucket.get("to_utc"))
		var observed_steps: int = int(bucket.get("steps"))
		# A bucket outside this egg's actual query cannot be safely reconciled:
		# accepting it would let a provider leak pre-egg steps into a new egg or
		# credit a future interval before `now`.
		if bucket_from < query_from or bucket_to > query_to or bucket_to < bucket_from or observed_steps < 0:
			return _record_unavailable(state, egg, ledger, now, "步數 bucket 數值無效，未入帳。", STATUS_INVALID, source, coverage)
		var normalized: Dictionary = {
			"id": bucket_id,
			"from_utc": bucket_from,
			"to_utc": bucket_to,
			"steps": observed_steps,
			"complete": bool(bucket.get("complete")),
		}
		if bucket.has("sensor_epoch"):
			if not _is_integer_number(bucket.get("sensor_epoch")):
				return _record_unavailable(state, egg, ledger, now, "步數 sensor epoch 格式無效，未入帳。", STATUS_INVALID, source, coverage)
			normalized["sensor_epoch"] = int(bucket.get("sensor_epoch"))
		# A duplicate payload must not add itself twice.  If a provider sends
		# two observations for the same ID, keep the greatest observation and
		# let the high-water delta account for it once.
		if incoming.has(bucket_id):
			var previous: Dictionary = incoming[bucket_id]
			normalized["from_utc"] = min(int(previous.get("from_utc", bucket_from)), bucket_from)
			normalized["to_utc"] = max(int(previous.get("to_utc", bucket_to)), bucket_to)
			normalized["steps"] = max(int(previous.get("steps", 0)), observed_steps)
			if previous.has("sensor_epoch") and normalized.has("sensor_epoch"):
				normalized["sensor_epoch"] = int(previous.get("sensor_epoch"))
			if not bool(previous.get("complete", true)):
				normalized["complete"] = false
		incoming[bucket_id] = normalized

	var ledger_buckets: Dictionary = ledger.get("buckets", {})
	var credited_steps: int = max(0, int(egg.get("credited_steps", 0)))
	var target_steps: int = max(0, int(egg.get("target_steps", 0)))
	var credited_delta: int = 0
	var groups: Array = _group_observations(incoming.values())
	for group_value in groups:
		var group: Dictionary = group_value
		var old_ids: Array[String] = _find_overlapping_ledger_ids(ledger_buckets, group)
		var old_observed: int = _sum_union_observed(ledger_buckets, old_ids)
		var new_observed: int = int(group.get("steps", 0))
		var positive_delta: int = max(0, new_observed - old_observed)
		var remaining: int = max(0, target_steps - credited_steps)
		var applied: int = min(positive_delta, remaining)
		credited_steps += applied
		credited_delta += applied

		var canonical_id: String = String(group.get("id", ""))
		if not old_ids.is_empty():
			canonical_id = old_ids[0]
		var old_canonical_value: Variant = ledger_buckets.get(canonical_id, {})
		var old_canonical: Dictionary = old_canonical_value if old_canonical_value is Dictionary else {}
		var stored_bucket: Dictionary = old_canonical.duplicate(true)
		var aliases: Array = []
		var old_credited_total: int = 0
		for old_id_value in old_ids:
			var old_id: String = String(old_id_value)
			_append_unique(aliases, old_id)
			var old_entry_value: Variant = ledger_buckets.get(old_id, {})
			if old_entry_value is Dictionary:
				var old_entry: Dictionary = old_entry_value
				old_credited_total += max(0, int(old_entry.get("credited_steps", 0)))
				var old_aliases_value: Variant = old_entry.get("aliases", [])
				if old_aliases_value is Array:
					for alias_value in old_aliases_value:
						_append_unique(aliases, String(alias_value))
		for alias_value in group.get("aliases", []):
			_append_unique(aliases, String(alias_value))
		_append_unique(aliases, canonical_id)
		for old_id_value in old_ids:
			var old_id: String = String(old_id_value)
			if old_id != canonical_id:
				ledger_buckets.erase(old_id)

		stored_bucket["id"] = canonical_id
		stored_bucket["aliases"] = aliases
		stored_bucket["from_utc"] = int(group.get("from_utc", query_from))
		stored_bucket["to_utc"] = int(group.get("to_utc", query_to))
		# Keep a high-water mark. A lower value is a source correction or a
		# sensor reset; it must never create a negative credit or a later replay.
		stored_bucket["observed_steps"] = max(old_observed, new_observed)
		stored_bucket["complete"] = bool(group.get("complete", true))
		stored_bucket["last_seen_at"] = now
		stored_bucket["credited_steps"] = old_credited_total + applied
		if group.has("sensor_epoch"):
			stored_bucket["sensor_epoch"] = int(group.get("sensor_epoch"))
		ledger_buckets[canonical_id] = stored_bucket

	var complete: bool = provider_complete and provider_known and covers_query and raw_status == STATUS_OK
	if not complete:
		status = STATUS_PARTIAL
		coverage["complete"] = false
		coverage["known"] = provider_known
	else:
		status = STATUS_OK
		coverage["complete"] = true
		coverage["known"] = true

	ledger["egg_id"] = String(egg.get("id", ""))
	ledger["source"] = source
	ledger["status"] = status
	ledger["last_source_status"] = raw_status
	ledger["last_sync"] = now
	ledger["query_from"] = query_from
	ledger["query_to"] = query_to
	ledger["coverage"] = coverage.duplicate(true)
	ledger["buckets"] = ledger_buckets
	ledger["observed_steps"] = _sum_observed(ledger_buckets)
	state["step_ledger"] = ledger

	egg["credited_steps"] = credited_steps
	egg["step_source"] = source
	egg["step_coverage"] = coverage.duplicate(true)
	egg["last_sync"] = now
	egg["step_buckets"] = ledger_buckets.duplicate(true)
	egg["step_ledger"] = ledger
	state["egg"] = egg

	var today_steps: Variant = null
	if complete and response.has("today_steps") and _is_non_negative_integer(response["today_steps"]):
		today_steps = int(response["today_steps"])
	var message: String = String(response.get("message", "步數同步完成。"))
	if status == STATUS_PARTIAL:
		message = "步數已部分同步，仍有區間尚未完整覆蓋。"
	return {
		"ok": status == STATUS_OK,
		"message": message,
		"status": status,
		"source": source,
		"coverage": coverage,
		"today_steps": today_steps,
		"credited_steps": credited_steps,
		"credited_delta": credited_delta,
		"last_sync": now,
		"egg_id": String(egg.get("id", "")),
	}

static func _ensure_ledger(state: Dictionary, egg: Dictionary, query_from: int) -> Dictionary:
	var raw: Variant = state.get("step_ledger", null)
	var ledger: Dictionary = raw if raw is Dictionary else {}
	var egg_id: String = String(egg.get("id", ""))
	if String(ledger.get("egg_id", "")) != egg_id:
		var egg_ledger_value: Variant = egg.get("step_ledger", null)
		if egg_ledger_value is Dictionary and String(egg_ledger_value.get("egg_id", "")) == egg_id:
			ledger = egg_ledger_value
		else:
			ledger = _new_ledger(egg_id, query_from)
	if not ledger.has("buckets") or not (ledger["buckets"] is Dictionary):
		ledger["buckets"] = {}
	if not ledger.has("source"):
		ledger["source"] = ""
	if not ledger.has("status"):
		ledger["status"] = "not_synced"
	if not ledger.has("coverage") or not (ledger["coverage"] is Dictionary):
		ledger["coverage"] = {}
	ledger["egg_id"] = egg_id
	ledger["query_from"] = int(ledger.get("query_from", query_from))
	state["step_ledger"] = ledger
	return ledger

static func _new_ledger(egg_id: String, query_from: int) -> Dictionary:
	return {
		"version": 1,
		"egg_id": egg_id,
		"source": "",
		"status": "not_synced",
		"last_source_status": "",
		"last_sync": 0,
		"query_from": query_from,
		"query_to": query_from,
		"coverage": {},
		"buckets": {},
		"observed_steps": 0,
	}

static func _record_unavailable(
	state: Dictionary,
	egg: Dictionary,
	ledger: Dictionary,
	now: int,
	message: String,
	status: String,
	source: String = "",
	coverage: Dictionary = {}
) -> Dictionary:
	ledger["status"] = status
	ledger["last_source_status"] = status
	ledger["last_sync"] = now
	if not source.is_empty():
		ledger["last_source"] = source
	if not coverage.is_empty():
		ledger["coverage"] = coverage.duplicate(true)
	state["step_ledger"] = ledger
	egg["last_sync"] = now
	egg["step_coverage"] = coverage.duplicate(true)
	egg["step_ledger"] = ledger
	state["egg"] = egg
	return {
		"ok": false,
		"message": message,
		"status": status,
		"source": source,
		"coverage": coverage,
		"today_steps": null,
		"credited_steps": max(0, int(egg.get("credited_steps", 0))),
		"credited_delta": 0,
		"last_sync": now,
		"egg_id": String(egg.get("id", "")),
	}

static func _failure(status: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"message": message,
		"status": status,
		"source": "",
		"coverage": {},
		"today_steps": null,
		"credited_steps": 0,
		"credited_delta": 0,
		"last_sync": null,
	}

static func _copy_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value.duplicate(true)
	return {}

static func _is_non_negative_integer(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and int(value) >= 0

static func _is_integer_number(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) != TYPE_FLOAT:
		return false
	var numeric: float = float(value)
	return numeric == floorf(numeric)

static func _valid_coverage_shape(coverage: Dictionary) -> bool:
	if not coverage.has("from_utc") or not coverage.has("to_utc"):
		return false
	if not coverage.has("complete") or not coverage.has("known"):
		return false
	if not _is_integer_number(coverage.get("from_utc")) or not _is_integer_number(coverage.get("to_utc")):
		return false
	if typeof(coverage.get("complete")) != TYPE_BOOL or typeof(coverage.get("known")) != TYPE_BOOL:
		return false
	return int(coverage.get("to_utc")) >= int(coverage.get("from_utc"))

static func _group_observations(observations: Array) -> Array:
	var groups: Array = []
	for value in observations:
		if not (value is Dictionary):
			continue
		var observation: Dictionary = value
		var merged_index: int = -1
		for index in range(groups.size()):
			var group: Dictionary = groups[index]
			if _ranges_can_merge(group, observation):
				merged_index = index
				break
		if merged_index < 0:
			var new_group: Dictionary = observation.duplicate(true)
			new_group["aliases"] = [String(observation.get("id", ""))]
			groups.append(new_group)
		else:
			groups[merged_index] = _merge_observation_group(groups[merged_index], observation)
	return groups

static func _ranges_can_merge(first: Dictionary, second: Dictionary) -> bool:
	if not _epochs_compatible(first, second):
		return false
	return _ranges_overlap(first, second)

static func _merge_observation_group(group: Dictionary, observation: Dictionary) -> Dictionary:
	var merged: Dictionary = group.duplicate(true)
	merged["from_utc"] = min(int(group.get("from_utc", 0)), int(observation.get("from_utc", 0)))
	merged["to_utc"] = max(int(group.get("to_utc", 0)), int(observation.get("to_utc", 0)))
	merged["steps"] = max(int(group.get("steps", 0)), int(observation.get("steps", 0)))
	merged["complete"] = bool(group.get("complete", true)) and bool(observation.get("complete", true))
	var aliases: Array = merged.get("aliases", []) if merged.get("aliases", []) is Array else []
	for alias_value in observation.get("aliases", [String(observation.get("id", ""))]):
		_append_unique(aliases, String(alias_value))
	merged["aliases"] = aliases
	if observation.has("sensor_epoch"):
		merged["sensor_epoch"] = int(observation.get("sensor_epoch"))
	return merged

static func _find_overlapping_ledger_ids(ledger_buckets: Dictionary, group: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key_value in ledger_buckets.keys():
		var key: String = String(key_value)
		var stored_value: Variant = ledger_buckets[key]
		if not (stored_value is Dictionary):
			continue
		var stored: Dictionary = stored_value
		var exact_alias: bool = _bucket_contains_id(stored, key) and _group_contains_id(group, key)
		if exact_alias and _epochs_compatible(group, stored):
			result.append(key)
		elif _ranges_can_merge(group, stored):
			result.append(key)
	result.sort()
	return result

static func _bucket_contains_id(bucket: Dictionary, bucket_id: String) -> bool:
	if String(bucket.get("id", "")) == bucket_id:
		return true
	var aliases_value: Variant = bucket.get("aliases", [])
	if aliases_value is Array:
		for alias_value in aliases_value:
			if String(alias_value) == bucket_id:
				return true
	return false

static func _append_unique(values: Array, value: String) -> void:
	if not values.has(value):
		values.append(value)

static func _group_contains_id(group: Dictionary, bucket_id: String) -> bool:
	if String(group.get("id", "")) == bucket_id:
		return true
	var aliases_value: Variant = group.get("aliases", [])
	if aliases_value is Array:
		for alias_value in aliases_value:
			if String(alias_value) == bucket_id:
				return true
	return false

static func _epochs_compatible(first: Dictionary, second: Dictionary) -> bool:
	var first_has_epoch: bool = first.has("sensor_epoch")
	var second_has_epoch: bool = second.has("sensor_epoch")
	if first_has_epoch != second_has_epoch:
		return false
	if first_has_epoch and int(first.get("sensor_epoch")) != int(second.get("sensor_epoch")):
		return false
	return true

static func _ranges_overlap(first: Dictionary, second: Dictionary) -> bool:
	var first_from: int = int(first.get("from_utc", 0))
	var first_to: int = int(first.get("to_utc", 0))
	var second_from: int = int(second.get("from_utc", 0))
	var second_to: int = int(second.get("to_utc", 0))
	var left: int = max(first_from, second_from)
	var right: int = min(first_to, second_to)
	if left < right:
		return true
	# A zero-length observation is a point. It overlaps a containing interval,
	# while two merely touching non-zero buckets remain separate.
	if first_from == first_to and first_from >= second_from and first_from <= second_to:
		return true
	if second_from == second_to and second_from >= first_from and second_from <= first_to:
		return true
	return first_from == second_from and first_to == second_to

static func _sum_union_observed(ledger_buckets: Dictionary, ids: Array[String]) -> int:
	var components: Array = []
	for id_value in ids:
		var id: String = String(id_value)
		var value: Variant = ledger_buckets.get(id, {})
		if not (value is Dictionary):
			continue
		var bucket: Dictionary = value
		var component: Dictionary = {
			"from_utc": int(bucket.get("from_utc", 0)),
			"to_utc": int(bucket.get("to_utc", 0)),
			"steps": max(0, int(bucket.get("observed_steps", 0))),
		}
		if bucket.has("sensor_epoch"):
			component["sensor_epoch"] = int(bucket.get("sensor_epoch"))
		var matching_indices: Array[int] = []
		for index in range(components.size()):
			if _ranges_can_merge(components[index], component):
				matching_indices.append(index)
		if matching_indices.is_empty():
			components.append(component)
			continue
		var merged: Dictionary = component
		for index in matching_indices:
			var other: Dictionary = components[index]
			merged["from_utc"] = min(int(merged.get("from_utc", 0)), int(other.get("from_utc", 0)))
			merged["to_utc"] = max(int(merged.get("to_utc", 0)), int(other.get("to_utc", 0)))
			merged["steps"] = max(int(merged.get("steps", 0)), int(other.get("steps", 0)))
		for offset in range(matching_indices.size() - 1, -1, -1):
			components.remove_at(matching_indices[offset])
		components.append(merged)
	var total: int = 0
	for component_value in components:
		var component: Dictionary = component_value
		total += max(0, int(component.get("steps", 0)))
	return total

static func _sum_observed(buckets: Dictionary) -> int:
	var total: int = 0
	for value in buckets.values():
		if value is Dictionary:
			total += max(0, int(value.get("observed_steps", 0)))
	return total
