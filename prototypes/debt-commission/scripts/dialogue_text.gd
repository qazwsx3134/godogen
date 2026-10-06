extends RefCounted
## Compiles inline presentation into BBCode and a plain, grapheme-based reading timeline.
## [pause=seconds], [speed=seconds]...[/speed], [big]...[/big], and RichText formatting
## never count as dialogue characters. Unknown brackets remain visible literal text.

static func compile(source: String, base_interval: float, font_size: int = 48) -> Dictionary:
	var plain: String = ""
	var rendered: String = ""
	var speeds: Array[float] = []
	var pauses: Dictionary = {}
	var speed_stack: Array[float] = [base_interval]
	var pattern: RegEx = RegEx.new()
	pattern.compile("\\[([^\\]]+)\\]")
	var cursor: int = 0
	for match_result: RegExMatch in pattern.search_all(source):
		var before: String = source.substr(cursor, match_result.get_start() - cursor)
		plain += before
		rendered += before
		for _character in before.length():
			speeds.append(speed_stack.back())
		var tag: String = match_result.get_string(1)
		var consumed: bool = true
		if tag.begins_with("pause=") and tag.substr(6).is_valid_float():
			pauses[plain.length()] = float(pauses.get(plain.length(), 0.0)) + clampf(float(tag.substr(6)), 0.0, 10.0)
		elif tag.begins_with("speed=") and tag.substr(6).is_valid_float():
			speed_stack.append(clampf(float(tag.substr(6)), 0.001, 0.5))
		elif tag == "/speed":
			if speed_stack.size() > 1:
				speed_stack.pop_back()
		elif tag == "big":
			rendered += "[font_size=%d]" % roundi(font_size * 1.25)
		elif tag == "/big":
			rendered += "[/font_size]"
		elif tag in ["b", "/b", "i", "/i", "u", "/u", "s", "/s", "/color", "/font_size", "shake", "/shake", "wave", "/wave"] \
				or tag.begins_with("color=") or tag.begins_with("font_size=") or tag.begins_with("shake ") or tag.begins_with("wave "):
			rendered += match_result.get_string()
		else:
			consumed = false
		if not consumed:
			var literal: String = match_result.get_string()
			plain += literal
			rendered += "[lb]" + tag + "[rb]"
			for _character in literal.length():
				speeds.append(speed_stack.back())
		cursor = match_result.get_end()
	var tail: String = source.substr(cursor)
	plain += tail
	rendered += tail
	for _character in tail.length():
		speeds.append(speed_stack.back())
	var ends: PackedInt32Array = TextServerManager.get_primary_interface().string_get_character_breaks(plain)
	# TextServerFallback may not expose ICU graphemes in minimal builds.
	if ends.is_empty() and not plain.is_empty():
		for index in plain.length():
			ends.append(index + 1)
	return {"plain": plain, "rendered": rendered, "ends": ends, "speeds": speeds, "pauses": pauses}


static func before_delay(plan: Dictionary, offset: int) -> float:
	return float((plan.get("pauses", {}) as Dictionary).get(offset, 0.0))


static func after_delay(plan: Dictionary, offset: int) -> float:
	var plain: String = plan["plain"]
	var interval: float = float(plan["speeds"][maxi(0, offset - 1)])
	var last: String = plain.substr(maxi(0, offset - 1), 1)
	if last in ["。", "！", "？", ".", "!", "?", "…"]:
		return interval + 0.14
	if last in ["，", "、", ",", "：", ":", "；", ";"]:
		return interval + 0.06
	return interval


static func readable_count(text: String) -> int:
	return (compile(text, 0.0)["ends"] as PackedInt32Array).size()


static func valid_markup(source: String) -> bool:
	if source.contains("{{"):
		return false
	var pattern: RegEx = RegEx.new()
	pattern.compile("\\[([^\\]]+)\\]")
	var stripped: String = source
	for found: RegExMatch in pattern.search_all(source):
		var tag: String = found.get_string(1)
		var valid: bool = tag in ["b", "/b", "i", "/i", "u", "/u", "s", "/s", "big", "/big", "shake", "/shake", "wave", "/wave", "/color", "/font_size", "/speed"]
		if tag.begins_with("pause=") or tag.begins_with("speed="):
			valid = tag.substr(6).is_valid_float() and float(tag.substr(6)) >= 0.0 and float(tag.substr(6)) <= 10.0
		elif tag.begins_with("color="):
			valid = Color.html_is_valid(tag.substr(6))
		elif tag.begins_with("font_size="):
			valid = tag.substr(10).is_valid_int() and int(tag.substr(10)) >= 1 and int(tag.substr(10)) <= 200
		elif tag.begins_with("shake ") or tag.begins_with("wave "):
			valid = true
		if not valid:
			return false
		stripped = stripped.replace(found.get_string(), "")
	return not stripped.contains("[") and not stripped.contains("]")
