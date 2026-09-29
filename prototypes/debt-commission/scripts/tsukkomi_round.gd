extends RefCounted
## Round v2 (`boke_round` with a `mode`): a testimony of several lines where each line may hide
## a tsukkomi slot. The round ends only when every slot is caught. StoryRunner keeps the node
## jumps, saving and checkpoints; this file decides everything else and never reads the clock
## (QTE timing arrives as an argument), so it is testable headless.
##
## Step fields (mechanics only; every spoken reaction is a story node the round jumps to, and
## those nodes lead back to the round node):
##   mode              "testimony" (free ◀▶ reading, listen, press 吐槽 on any line)
##                     "combo" (lines in order, no listen; the timer shrinks with each catch)
##   id, speaker, timer_seconds, game_over, clear (node once every slot is caught)
##   lines[]           {id, text, speaker?, listen?: node, whiff?: node, hint?: node, slot?}
##   slot              {timeout: node, options?: [...], censor?: {...}, placard?: {...}, qte?: {...}}
##     options[]       {id, label, result, goto, require?: item, require_caught?: [line ids],
##                      set_flags?, when?: [...]}
##       when[]        conditional outcome: the first case whose conditions all hold replaces the
##                     option's result/goto/set_flags. Conditions (at least one): require_caught
##                     [line ids], require item, flags {key: value}. Case: {..., result, goto, set_flags?}
##     censor          fourth-wall bar: the line text marks it with ▇; {hidden, result, goto}
##     placard         fourth-wall placard (the holder's `Placard` node in their character scene):
##                     {text, goto, result? (perfect)}; the placard shows `text` while this line is
##                     current and uncaught, and tapping it answers the slot (reading or choosing)
##     qte             shrinking ring: {duration, window, late_after, perfect, early, late}
##   rules             {whiff_costs_glass (true), hint_after (3), hint_survives_retry (true),
##                      super?: node, combo_timers?: [s...], combo_bonus?: node, combo_break?: node}
## Results: perfect (+30 power) and weak (+10) catch the slot; fail costs a glass and stays on
## the line; hidden leaves the round through its goto.

const MODES: Array[String] = ["testimony", "combo"]
const RESULTS: Array[String] = ["perfect", "weak", "fail", "hidden"]
const POWER_GAIN: Dictionary = {"perfect": 30, "weak": 10}
const CENSOR_MARK: String = "▇"
const DEFAULT_RULES: Dictionary = {
	"whiff_costs_glass": true,
	"hint_after": 3,
	"hint_survives_retry": true,
	"combo_timers": [8.0, 6.0, 5.0, 4.0],
}


static func is_v2(step: Dictionary) -> bool:
	return String(step.get("op", "")) == "boke_round" and step.has("mode")


static func rules(step: Dictionary) -> Dictionary:
	var merged: Dictionary = DEFAULT_RULES.duplicate(true)
	merged.merge(step.get("rules", {}) as Dictionary, true)
	return merged


static func new_state(round_id: String) -> Dictionary:
	return {"id": round_id, "line_index": 0, "caught": {}, "fails": {}, "listened": [], "combo": 0,
		"combo_broken": false, "super_used": false, "queue": []}


## State after a Game Over retry: back to the start of the round, keeping per-line fail counts
## when the round lets hints survive a retry.
static func retry_state(step: Dictionary, state: Dictionary) -> Dictionary:
	var fresh: Dictionary = new_state(String(step.get("id", "")))
	if bool(rules(step)["hint_survives_retry"]):
		fresh["fails"] = (state.get("fails", {}) as Dictionary).duplicate()
	return fresh


static func line_index(step: Dictionary, state: Dictionary) -> int:
	var lines: Array = step.get("lines", [])
	if String(step.get("mode", "")) == "combo":
		for index: int in range(lines.size()):
			if not (state["caught"] as Dictionary).has(String(lines[index]["id"])):
				return index
		return lines.size() - 1
	return clampi(int(state.get("line_index", 0)), 0, lines.size() - 1)


static func all_caught(step: Dictionary, state: Dictionary) -> bool:
	for line: Dictionary in step.get("lines", []):
		if line.has("slot") and not (state["caught"] as Dictionary).has(String(line["id"])):
			return false
	return true


## Where the round goes once every slot is caught.
static func exit_target(step: Dictionary, state: Dictionary) -> String:
	var round_rules: Dictionary = rules(step)
	if String(step.get("mode", "")) == "combo" and not bool(state.get("combo_broken", false)) \
			and round_rules.has("combo_bonus"):
		return String(round_rules["combo_bonus"])
	return String(step.get("clear", ""))


static func timer_seconds(step: Dictionary, state: Dictionary) -> float:
	if String(step.get("mode", "")) == "combo":
		var timers: Array = rules(step)["combo_timers"]
		return float(timers[mini(int(state.get("combo", 0)), timers.size() - 1)])
	return float(step.get("timer_seconds", 8.0))


static func visible_options(line: Dictionary, state: Dictionary, items: Array) -> Array:
	var visible: Array = []
	var slot: Dictionary = line.get("slot", {}) as Dictionary
	for option: Dictionary in slot.get("options", []):
		if option.has("require") and not items.has(String(option["require"])):
			continue
		var locked: bool = false
		for caught_id: Variant in option.get("require_caught", []):
			locked = locked or not (state["caught"] as Dictionary).has(String(caught_id))
		if not locked:
			visible.append(option.duplicate(true))
	return visible


static func super_available(step: Dictionary, state: Dictionary, gameplay: Dictionary) -> bool:
	if not rules(step).has("super") or bool(state.get("super_used", false)):
		return false
	if int(gameplay.get("power", 0)) < int(gameplay.get("max_power", 100)):
		return false
	return not _super_targets(step, state).is_empty()


## What the shell needs to draw the round.
static func decorate(step: Dictionary, state: Dictionary, items: Array, gameplay: Dictionary) -> Dictionary:
	var view: Dictionary = step.duplicate(true)
	var index: int = line_index(step, state)
	var line: Dictionary = (step["lines"] as Array)[index]
	var slot: Dictionary = line.get("slot", {}) as Dictionary
	view["line_index"] = index
	view["current_line"] = {
		"id": line["id"], "text": line["text"],
		"speaker": String(line.get("speaker", step.get("speaker", ""))),
		"caught": (state["caught"] as Dictionary).has(String(line["id"])),
		"can_listen": line.has("listen") and String(step["mode"]) == "testimony",
		"can_whiff": line.has("whiff") and not line.has("slot"),
		"listened": (state["listened"] as Array).has(String(line["id"])),
		"has_slot": line.has("slot"),
		"options": visible_options(line, state, items),
		"censor": slot.get("censor", {}),
		"placard": slot.get("placard", {}),
		"qte": slot.get("qte", {}),
	}
	view["caught_line_ids"] = (state["caught"] as Dictionary).keys()
	view["combo"] = int(state["combo"])
	view["timer_seconds"] = timer_seconds(step, state)
	view["super_available"] = super_available(step, state, gameplay)
	return view


static func judge_qte(qte: Dictionary, tapped: bool, offset: float) -> String:
	if not tapped or offset > float(qte.get("window", 0.12)):
		return "late"
	if offset < -float(qte.get("window", 0.12)):
		return "early"
	return "perfect"


## What choosing this option does now: its own result/goto/set_flags, or those of the first
## `when` case whose conditions all hold (caught lines of this round, items held, flag values).
static func option_outcome(option: Dictionary, state: Dictionary, items: Array, flags: Dictionary) -> Dictionary:
	for case: Dictionary in option.get("when", []):
		if _case_holds(case, state, items, flags):
			return {"result": String(case["result"]), "goto": String(case["goto"]),
				"set_flags": case.get("set_flags", option.get("set_flags", {}))}
	return {"result": String(option["result"]), "goto": String(option["goto"]),
		"set_flags": option.get("set_flags", {})}


static func _case_holds(case: Dictionary, state: Dictionary, items: Array, flags: Dictionary) -> bool:
	for line_id: Variant in case.get("require_caught", []):
		if not (state["caught"] as Dictionary).has(String(line_id)):
			return false
	if case.has("require") and not items.has(String(case["require"])):
		return false
	for key: Variant in (case.get("flags", {}) as Dictionary).keys():
		if not flags.has(key) or flags[key] != case["flags"][key]:
			return false
	return true


## Applies one player action to the round. kind: "option" (payload.id), "censor", "placard",
## "qte" (payload.tapped, payload.offset: seconds from the ring's target), "timeout", "whiff",
## "super". flags: the story flags, for options with `when` cases. Returns {"error"} or
## {"result", "goto", "state", "gameplay", "set_flags", "game_over", "leaves_round", "stats"};
## the caller commits everything or nothing. A Game Over keeps the state so the retry can restore
## the round (and its hint counts).
static func resolve(step: Dictionary, state: Dictionary, gameplay: Dictionary, items: Array,
		kind: String, payload: Dictionary = {}, flags: Dictionary = {}) -> Dictionary:
	var index: int = line_index(step, state)
	var line: Dictionary = (step["lines"] as Array)[index]
	var line_id: String = String(line["id"])
	var slot: Dictionary = line.get("slot", {}) as Dictionary
	var caught: bool = (state["caught"] as Dictionary).has(line_id)
	var result: String = ""
	var target: String = ""
	var set_flags: Dictionary = {}
	match kind:
		"option":
			if slot.is_empty() or caught:
				return {"error": "line '%s' has no open tsukkomi slot" % line_id}
			for option: Dictionary in visible_options(line, state, items):
				if String(option["id"]) == String(payload.get("id", "")):
					var outcome: Dictionary = option_outcome(option, state, items, flags)
					result = outcome["result"]
					target = outcome["goto"]
					set_flags = outcome["set_flags"]
			if result.is_empty():
				return {"error": "option '%s' is not available on line '%s'" % [payload.get("id", ""), line_id]}
		"censor":
			var censor: Dictionary = slot.get("censor", {}) as Dictionary
			if censor.is_empty() or caught:
				return {"error": "line '%s' has no censor bar to tap" % line_id}
			result = String(censor.get("result", "perfect"))
			target = String(censor["goto"])
		"placard":
			var placard: Dictionary = slot.get("placard", {}) as Dictionary
			if placard.is_empty() or caught:
				return {"error": "line '%s' has no placard to tap" % line_id}
			result = String(placard.get("result", "perfect"))
			target = String(placard["goto"])
		"qte":
			var qte: Dictionary = slot.get("qte", {}) as Dictionary
			if qte.is_empty() or caught:
				return {"error": "line '%s' has no QTE" % line_id}
			var timing: String = judge_qte(qte, bool(payload.get("tapped", false)), float(payload.get("offset", 0.0)))
			result = "perfect" if timing == "perfect" else "fail"
			target = String(qte[timing])
		"timeout":
			if slot.is_empty() or caught:
				return {"error": "line '%s' has no running tsukkomi timer" % line_id}
			result = "fail"
			target = String(slot["timeout"])
		"whiff":
			if not slot.is_empty() or not line.has("whiff"):
				return {"error": "line '%s' cannot be whiffed" % line_id}
			result = "fail"
			target = String(line["whiff"])
		"super":
			if not super_available(step, state, gameplay):
				return {"error": "the ultimate tsukkomi is not available"}
			return _resolve_super(step, state, gameplay)
		_:
			return {"error": "unknown round action '%s'" % kind}

	var round_rules: Dictionary = rules(step)
	var next_state: Dictionary = state.duplicate(true)
	var next_gameplay: Dictionary = gameplay.duplicate(true)
	var stats: Dictionary = {}
	next_state["queue"] = []
	match result:
		"perfect", "weak":
			next_state["caught"][line_id] = result
			next_state["combo"] = int(next_state["combo"]) + 1
			next_gameplay["power"] = mini(int(next_gameplay["max_power"]), int(next_gameplay["power"]) + int(POWER_GAIN[result]))
			stats = {"caught": 1, "perfect": 1 if result == "perfect" else 0, "combo": int(next_state["combo"])}
		"fail":
			if kind != "whiff" or bool(round_rules["whiff_costs_glass"]):
				next_gameplay["glasses"] = maxi(0, int(next_gameplay["glasses"]) - 1)
			var fails: int = int((next_state["fails"] as Dictionary).get(line_id, 0)) + 1
			next_state["fails"][line_id] = fails
			if int(next_state["combo"]) > 0 and round_rules.has("combo_break"):
				next_state["queue"].append(String(round_rules["combo_break"]))
			if int(next_state["combo"]) > 0:
				next_state["combo_broken"] = true
			next_state["combo"] = 0
			if fails >= int(round_rules["hint_after"]) and line.has("hint"):
				next_state["queue"].append(String(line["hint"]))
			stats = {"fails": 1}
		"hidden":
			stats = {"hidden": 1}
	var game_over: bool = result == "fail" and int(next_gameplay["glasses"]) == 0
	if game_over:
		target = String(step["game_over"])
		next_state["queue"] = []
	return {"result": result, "goto": target, "state": next_state, "gameplay": next_gameplay,
		"set_flags": set_flags, "game_over": game_over, "leaves_round": result == "hidden",
		"stats": stats}


static func _resolve_super(step: Dictionary, state: Dictionary, gameplay: Dictionary) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	var targets: Array[String] = _super_targets(step, state)
	for line_id: String in targets:
		next_state["caught"][line_id] = "perfect"
	next_state["combo"] = int(next_state["combo"]) + targets.size()
	next_state["super_used"] = true
	next_state["queue"] = []
	var next_gameplay: Dictionary = gameplay.duplicate(true)
	next_gameplay["power"] = 0
	return {"result": "perfect", "goto": String(rules(step)["super"]), "state": next_state,
		"gameplay": next_gameplay, "set_flags": {}, "game_over": false, "leaves_round": false,
		"stats": {"caught": targets.size(), "perfect": targets.size(), "combo": int(next_state["combo"])}}


## The ultimate tsukkomi catches every open slot that is answered by choosing an option.
static func _super_targets(step: Dictionary, state: Dictionary) -> Array[String]:
	var targets: Array[String] = []
	for line: Dictionary in step.get("lines", []):
		var slot: Dictionary = line.get("slot", {}) as Dictionary
		if slot.has("options") and not (state["caught"] as Dictionary).has(String(line["id"])):
			targets.append(String(line["id"]))
	return targets


static func set_line(step: Dictionary, state: Dictionary, index: int) -> Dictionary:
	if String(step["mode"]) != "testimony":
		return {"error": "combo rounds advance by themselves"}
	if index < 0 or index >= (step["lines"] as Array).size():
		return {"error": "line index is outside the round"}
	var next_state: Dictionary = state.duplicate(true)
	next_state["line_index"] = index
	return {"state": next_state}


## Listening plays the line's listen node; it may grant items and it leads back to the round.
static func listen(step: Dictionary, state: Dictionary) -> Dictionary:
	var line: Dictionary = (step["lines"] as Array)[line_index(step, state)]
	if String(step["mode"]) != "testimony" or not line.has("listen"):
		return {"error": "line '%s' has nothing more to listen to" % line.get("id", "")}
	var next_state: Dictionary = state.duplicate(true)
	if not (next_state["listened"] as Array).has(String(line["id"])):
		next_state["listened"].append(String(line["id"]))
	next_state["queue"] = []
	return {"state": next_state, "goto": String(line["listen"])}


# ---------------------------------------------------------------- data checks

## "" when the step is a valid v2 round. has_item/has_node: Callable(String) -> bool.
static func validate(step: Dictionary, prefix: String, has_node: Callable, has_item: Callable,
		has_speaker: Callable) -> String:
	if not MODES.has(String(step.get("mode", ""))):
		return "%s boke_round mode must be testimony or combo" % prefix
	if not _is_text(step.get("id")):
		return "%s boke_round id must be a non-empty string" % prefix
	if not has_speaker.call(String(step.get("speaker", ""))):
		return "%s boke_round speaker '%s' is not in asset catalog" % [prefix, step.get("speaker", "")]
	for key: String in ["game_over", "clear"]:
		if not has_node.call(String(step.get(key, ""))):
			return "%s boke_round %s target is invalid" % [prefix, key]
	if String(step["mode"]) == "testimony" and not _is_positive(step.get("timer_seconds")):
		return "%s boke_round timer_seconds must be positive" % prefix
	var round_rules: Variant = step.get("rules", {})
	if not round_rules is Dictionary:
		return "%s boke_round rules must be an object" % prefix
	for key: String in ["super", "combo_bonus", "combo_break"]:
		if (round_rules as Dictionary).has(key) and not has_node.call(String(round_rules[key])):
			return "%s boke_round rules.%s target is invalid" % [prefix, key]
	var timers: Variant = rules(step)["combo_timers"]
	if not timers is Array or (timers as Array).is_empty() \
			or not (timers as Array).all(func(seconds: Variant) -> bool: return _is_positive(seconds)):
		return "%s boke_round rules.combo_timers must be positive seconds" % prefix
	var lines: Variant = step.get("lines")
	if not lines is Array or (lines as Array).is_empty():
		return "%s boke_round lines must be a non-empty array" % prefix
	var line_ids: Array[String] = []
	var slots: int = 0
	for index: int in range((lines as Array).size()):
		var line: Variant = lines[index]
		if not line is Dictionary or not _is_text(line.get("id")) or not _is_text(line.get("text")):
			return "%s boke line %d needs id and text" % [prefix, index]
		var line_id: String = String(line["id"])
		var where: String = "%s boke line '%s'" % [prefix, line_id]
		if line_ids.has(line_id):
			return "%s repeats boke line id '%s'" % [prefix, line_id]
		line_ids.append(line_id)
		if line.has("speaker") and not has_speaker.call(String(line["speaker"])):
			return "%s speaker '%s' is not in asset catalog" % [where, line["speaker"]]
		for key: String in ["listen", "whiff", "hint"]:
			if line.has(key) and not has_node.call(String(line[key])):
				return "%s %s target is invalid" % [where, key]
		if line.has("listen") and String(step["mode"]) == "combo":
			return "%s cannot listen in a combo round" % where
		if not line.has("slot"):
			if String(step["mode"]) == "combo":
				return "%s needs a slot (every combo line is a tsukkomi)" % where
			if not line.has("whiff"):
				return "%s has no slot, so it needs a whiff node for pressing 吐槽" % where
			continue
		slots += 1
		var slot_error: String = _validate_slot(line as Dictionary, where, has_node, has_item)
		if not slot_error.is_empty():
			return slot_error
	for line: Dictionary in lines:
		for option: Dictionary in (line.get("slot", {}) as Dictionary).get("options", []):
			var caught_ids: Array = (option.get("require_caught", []) as Array).duplicate()
			for case: Dictionary in option.get("when", []):
				caught_ids.append_array(case.get("require_caught", []))
			for caught_id: Variant in caught_ids:
				if not line_ids.has(String(caught_id)):
					return "%s boke line '%s' option '%s' require_caught line '%s' is not in the round" % [prefix, line["id"], option.get("id", ""), caught_id]
	if slots == 0:
		return "%s boke_round needs at least one line with a slot" % prefix
	return ""


static func _validate_slot(line: Dictionary, where: String, has_node: Callable, has_item: Callable) -> String:
	var slot: Variant = line["slot"]
	if not slot is Dictionary:
		return "%s slot must be an object" % where
	var kinds: int = int(slot.has("options")) + int(slot.has("qte"))
	if kinds != 1:
		return "%s slot needs exactly one of options or qte" % where
	if slot.has("options") and not has_node.call(String(slot.get("timeout", ""))):
		return "%s slot timeout target is invalid" % where
	var option_ids: Array[String] = []
	var unconditional: int = 0
	for option: Variant in slot.get("options", []):
		if not option is Dictionary or not _is_text(option.get("id")) or not _is_text(option.get("label")):
			return "%s options need id and label" % where
		var option_id: String = String(option["id"])
		if option_ids.has(option_id):
			return "%s repeats option id '%s'" % [where, option_id]
		option_ids.append(option_id)
		if not RESULTS.has(String(option.get("result", ""))):
			return "%s option '%s' result is invalid" % [where, option_id]
		if not has_node.call(String(option.get("goto", ""))):
			return "%s option '%s' goto target is invalid" % [where, option_id]
		if option.has("require") and not has_item.call(String(option["require"])):
			return "%s option '%s' require item '%s' is not in asset catalog" % [where, option_id, option["require"]]
		if option.has("set_flags") and not option["set_flags"] is Dictionary:
			return "%s option '%s' set_flags must be an object" % [where, option_id]
		if option.has("require_caught") and not _is_text_array(option["require_caught"]):
			return "%s option '%s' require_caught must list line ids" % [where, option_id]
		if option.has("when"):
			var when_error: String = _validate_when(option["when"], "%s option '%s'" % [where, option_id], has_node, has_item)
			if not when_error.is_empty():
				return when_error
		if not option.has("require") and not option.has("require_caught"):
			unconditional += 1
	if slot.has("options") and unconditional == 0:
		return "%s needs at least one option without conditions" % where
	if slot.has("placard"):
		var placard: Variant = slot["placard"]
		if not slot.has("options"):
			return "%s placard needs options beside it (the timed sheet stays open while it glows)" % where
		if slot.has("censor"):
			return "%s slot has both a censor bar and a placard; keep one fourth-wall target" % where
		if not placard is Dictionary or not _is_text(placard.get("text")) or not has_node.call(String(placard.get("goto", ""))):
			return "%s placard needs text and a goto" % where
		if placard.has("result") and not RESULTS.has(String(placard["result"])):
			return "%s placard result is invalid" % where
	if slot.has("censor"):
		var censor: Variant = slot["censor"]
		if not censor is Dictionary or not _is_text(censor.get("hidden")) or not has_node.call(String(censor.get("goto", ""))):
			return "%s censor needs hidden text and a goto" % where
		if not String(line["text"]).contains(CENSOR_MARK):
			return "%s censor needs %s in the line text to mark the bar" % [where, CENSOR_MARK]
		if censor.has("result") and not RESULTS.has(String(censor["result"])):
			return "%s censor result is invalid" % where
	if slot.has("qte"):
		var qte: Variant = slot["qte"]
		if not qte is Dictionary:
			return "%s qte must be an object" % where
		for key: String in ["duration", "window", "late_after"]:
			if not _is_positive(qte.get(key)):
				return "%s qte.%s must be positive seconds" % [where, key]
		for key: String in ["perfect", "early", "late"]:
			if not has_node.call(String(qte.get(key, ""))):
				return "%s qte.%s target is invalid" % [where, key]
	return ""


## `when` cases of one option: a non-empty array; each case has at least one condition and a
## valid result and goto.
static func _validate_when(value: Variant, where: String, has_node: Callable, has_item: Callable) -> String:
	if not value is Array or (value as Array).is_empty():
		return "%s when must be a non-empty array of cases" % where
	for index: int in range((value as Array).size()):
		var case: Variant = value[index]
		var at: String = "%s when[%d]" % [where, index]
		if not case is Dictionary:
			return "%s must be an object" % at
		var conditions: int = 0
		if case.has("require_caught"):
			if not _is_text_array(case["require_caught"]) or (case["require_caught"] as Array).is_empty():
				return "%s require_caught must list line ids" % at
			conditions += 1
		if case.has("require"):
			if not has_item.call(String(case["require"])):
				return "%s require item '%s' is not in asset catalog" % [at, case["require"]]
			conditions += 1
		if case.has("flags"):
			if not case["flags"] is Dictionary or (case["flags"] as Dictionary).is_empty():
				return "%s flags must map flag keys to values" % at
			conditions += 1
		if conditions == 0:
			return "%s needs a condition: require_caught, require or flags" % at
		for key: Variant in (case as Dictionary).keys():
			if not ["require_caught", "require", "flags", "result", "goto", "set_flags"].has(String(key)):
				return "%s has unknown field '%s'" % [at, key]
		if not RESULTS.has(String(case.get("result", ""))):
			return "%s result is invalid" % at
		if not has_node.call(String(case.get("goto", ""))):
			return "%s goto target is invalid" % at
		if case.has("set_flags") and not case["set_flags"] is Dictionary:
			return "%s set_flags must be an object" % at
	return ""


## "" when a saved round state fits this step.
static func validate_state(value: Variant, step: Dictionary) -> String:
	if not value is Dictionary:
		return "round state must be an object"
	var state: Dictionary = value
	for key: String in ["id", "line_index", "caught", "fails", "listened", "combo", "combo_broken", "super_used", "queue"]:
		if not state.has(key):
			return "round state is missing '%s'" % key
	if String(state["id"]) != String(step.get("id", "")):
		return "round state belongs to another round"
	var line_ids: Array = (step["lines"] as Array).map(func(line: Dictionary) -> String: return String(line["id"]))
	if typeof(state["line_index"]) != TYPE_INT or int(state["line_index"]) < 0 or int(state["line_index"]) >= line_ids.size():
		return "round state line_index is outside the round"
	if not state["caught"] is Dictionary or not state["fails"] is Dictionary or not state["listened"] is Array or not state["queue"] is Array:
		return "round state has malformed collections"
	for line_id: Variant in (state["caught"] as Dictionary).keys():
		if not line_ids.has(String(line_id)) or not ["perfect", "weak"].has(String(state["caught"][line_id])):
			return "round state has an invalid caught line"
	for line_id: Variant in (state["fails"] as Dictionary).keys():
		if not line_ids.has(String(line_id)) or typeof(state["fails"][line_id]) != TYPE_INT:
			return "round state has an invalid fail count"
	if typeof(state["combo"]) != TYPE_INT or int(state["combo"]) < 0:
		return "round state combo must be a non-negative integer"
	return ""


# ---------------------------------------------------------------- build tools

## Everything a save position depends on (for the story version fingerprint).
static func shape(step: Dictionary) -> Array:
	var round_shape: Array = [step.get("mode"), step.get("clear"), step.get("game_over"), rules(step)]
	for line: Dictionary in step.get("lines", []):
		var slot: Dictionary = line.get("slot", {}) as Dictionary
		var line_shape: Array = [line.get("id"), line.get("listen", ""), line.get("whiff", ""), line.get("hint", ""), slot.get("timeout", "")]
		for option: Dictionary in slot.get("options", []):
			var option_shape: Array = [option.get("id"), option.get("goto"), option.get("require", ""), option.get("require_caught", [])]
			for case: Dictionary in option.get("when", []):
				option_shape.append([case.get("goto"), case.get("require_caught", []), case.get("require", ""), case.get("flags", {})])
			line_shape.append(option_shape)
		line_shape.append((slot.get("censor", {}) as Dictionary).get("goto", ""))
		if slot.has("placard"):
			line_shape.append(["placard", (slot["placard"] as Dictionary).get("goto", "")])
		var qte: Dictionary = slot.get("qte", {}) as Dictionary
		line_shape.append([qte.get("perfect", ""), qte.get("early", ""), qte.get("late", "")])
		round_shape.append(line_shape)
	return round_shape


## Every node the round can jump to.
static func targets(step: Dictionary) -> Array[String]:
	var found: Array[String] = [String(step.get("clear", "")), String(step.get("game_over", ""))]
	for key: String in ["super", "combo_bonus", "combo_break"]:
		if (step.get("rules", {}) as Dictionary).has(key):
			found.append(String(step["rules"][key]))
	for line: Dictionary in step.get("lines", []):
		for key: String in ["listen", "whiff", "hint"]:
			if line.has(key):
				found.append(String(line[key]))
		var slot: Dictionary = line.get("slot", {}) as Dictionary
		if slot.has("timeout"):
			found.append(String(slot["timeout"]))
		for option: Dictionary in slot.get("options", []):
			found.append(String(option.get("goto", "")))
			for case: Dictionary in option.get("when", []):
				found.append(String(case.get("goto", "")))
		for key: String in ["censor", "placard"]:
			if slot.has(key):
				found.append(String(slot[key].get("goto", "")))
		for key: String in ["perfect", "early", "late"]:
			if (slot.get("qte", {}) as Dictionary).has(key):
				found.append(String(slot["qte"][key]))
	return found


## {key: [values]} the round's options may write, for the story's flag whitelist.
static func flag_writes(step: Dictionary) -> Array[Dictionary]:
	var writes: Array[Dictionary] = []
	for line: Dictionary in step.get("lines", []):
		for option: Dictionary in (line.get("slot", {}) as Dictionary).get("options", []):
			if option.get("set_flags") is Dictionary:
				writes.append(option["set_flags"])
			for case: Dictionary in option.get("when", []):
				if case.get("set_flags") is Dictionary:
					writes.append(case["set_flags"])
	return writes


## Every `flags` condition of the round's `when` cases, for the story's flag check.
static func flag_conditions(step: Dictionary) -> Array[Dictionary]:
	var conditions: Array[Dictionary] = []
	for line: Dictionary in step.get("lines", []):
		for option: Dictionary in (line.get("slot", {}) as Dictionary).get("options", []):
			for case: Dictionary in option.get("when", []):
				if case.get("flags") is Dictionary:
					conditions.append(case["flags"])
	return conditions


static func _is_text(value: Variant) -> bool:
	return value is String and not String(value).is_empty()


static func _is_text_array(value: Variant) -> bool:
	return value is Array and (value as Array).all(func(entry: Variant) -> bool: return _is_text(entry))


static func _is_positive(value: Variant) -> bool:
	return (value is float or value is int) and float(value) > 0.0
