extends RefCounted
## What the shell shows for a boke round, from the command StoryRunner.current() returns. Covers
## Phase 3 rounds (one set of options for the whole round) and round v2 (a `mode`: a slot per
## line, whiffs, the censor bar, the QTE, combos; scripts/tsukkomi_round.gd), so main.gd only
## renders the answers.


static func is_v2(command: Dictionary) -> bool:
	return command.has("mode")


static func line(command: Dictionary) -> Dictionary:
	return command.get("current_line", {}) as Dictionary


## The current line; Phase 3 appends what listening revealed, v2 plays that as its own scene.
static func text(command: Dictionary) -> String:
	var shown: String = str(line(command).get("text", "（正在等你的吐槽。）"))
	if not is_v2(command) and bool(command.get("listened", false)):
		shown += "\n\n「" + str(line(command).get("listen_text", "")) + "」"
	return shown


static func speaker(command: Dictionary) -> String:
	var own: String = str(line(command).get("speaker", ""))
	return own if not own.is_empty() else str(command.get("speaker", "gintoki"))


static func listened(command: Dictionary) -> bool:
	return bool(line(command).get("listened", false)) if is_v2(command) else bool(command.get("listened", false))


static func can_listen(command: Dictionary) -> bool:
	return bool(line(command).get("can_listen", false)) if is_v2(command) else line(command).has("listen")


static func caught(command: Dictionary) -> bool:
	return bool(line(command).get("caught", false))


static func options(command: Dictionary) -> Array:
	if is_v2(command):
		return line(command).get("options", []) as Array
	return (command.get("tsukkomi", {}) as Dictionary).get("options", []) as Array


## The censor bar can be torn off this line (while reading and while the options run).
static func censor(command: Dictionary) -> bool:
	return is_v2(command) and not caught(command) and not (line(command).get("censor", {}) as Dictionary).is_empty()


static func qte(command: Dictionary) -> Dictionary:
	return line(command).get("qte", {}) as Dictionary


## Lines can be browsed with ‹ › (Phase 3 and testimony rounds; combo lines come one by one).
static func navigable(command: Dictionary) -> bool:
	return not is_v2(command) or str(command.get("mode", "")) == "testimony"


## Combo lines open their slot as soon as they are shown.
static func automatic(command: Dictionary) -> bool:
	return is_v2(command) and str(command.get("mode", "")) == "combo"


## What 吐槽！ does on this line: "options" (the timed sheet, with the censor bar if the line has
## one), "qte", "whiff" (a line without a slot), or "" when there is nothing left to press.
static func action(command: Dictionary) -> String:
	if not is_v2(command):
		return "options"
	if caught(command):
		return ""
	if not options(command).is_empty() or censor(command):
		return "options"
	if not qte(command).is_empty():
		return "qte"
	return "whiff" if bool(line(command).get("can_whiff", false)) else ""


## "2 / 4", and for v2 one mark per line: ● caught, ○ still open, · nothing to catch.
static func index_text(command: Dictionary) -> String:
	var lines: Array = command.get("lines", []) as Array
	var shown: String = "%d / %d" % [int(command.get("line_index", 0)) + 1, lines.size()]
	if not is_v2(command):
		return shown
	var caught_ids: Array = command.get("caught_line_ids", []) as Array
	var marks: String = ""
	for entry: Dictionary in lines:
		marks += "●" if caught_ids.has(entry.get("id")) else ("○" if entry.has("slot") else "·")
	return "%s　%s" % [shown, marks]
