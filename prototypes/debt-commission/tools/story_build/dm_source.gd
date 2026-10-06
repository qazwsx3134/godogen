extends RefCounted
## Dialogue Manager `.dialogue` -> StoryRunner nodes, parsed with Dialogue Manager's own compiler.
##
## Each `~ title` becomes a node with that id. Supported lines:
##   `Name: text` / plain text     say (Name is a catalog id or displayed name; plain = narrator)
##                                 tags: [#thought], [#<expression>], [#offscreen] (the speaker
##                                 talks from off stage: name plate only, the stage stays as is)
##   narration + `- label [ID:x]`  choice; the narration line is the prompt. Options take
##                                 `[if has("item") /]` (require), `set k = v` lines (set_flags)
##                                 and one `=> title`; a tag `[#loud]`, `[#calm]` or `[#tired]` on the
##                                 option is its tone (the round marker before the row; pov choices only)
##   `do pov("gintoki")`           right before the prompt: whose thought the options are (a catalog id
##                                 or name; without it the choice is Shinpachi's). Parley: an ACTION node
##   `do director()` / `director("※製作組經費有限")`  right before the prompt: a director choice, where
##                                 the player steps out of the story and decides what happens next
##                                 (two or more options, no tones); the optional text is the footnote
##                                 under the cards
##   `set key = value`             flag (a string, a number, or true / false)
##   `if key == value` / `else`    condition (the same kinds of value); each branch holds exactly one `=> title`
##   `do bg("id")`, `do char("id", "expression", "position")`, `do hide("id")`,
##   `do enter("id", "expression", "position")` (a character who has not spoken comes on stage),
##   `do placard("text")` / `placard("")` (what the placard holder's board says; "" = blank),
##   `do offscreen()` right before a line = [#offscreen] (Parley writes it as an ACTION node),
##   `do item("id")`, `do profile("character_id")`, `do investigate("block")`,
##   `do boke_round("block")`, `do end("text")`, `do result("block")` (the chapter result screen)
##   effects: `do shake()` / `shake("small")`, `do flash()` / `flash("#ff0000")`,
##   `do cutin("你在說什麼啊！！")` / `cutin("text", "shinpachi")`, `do freeze()` / `freeze(1.5)`,
##   `do comedy("tsukkomi_impact", "shinpachi", "line")` / `comedy(preset, speaker, text, "shout")`
##   (the manga overlay: preset tsukkomi_impact, small_reaction or full_manga_panel; the speaker is a
##   catalog id or name; the fourth argument is the optional expression of the cut-in)
##   `do bgm("bgm_meeting")` / `bgm("")` to stop, `do se("crow")`
##   `銀時＆神樂: text` is a line said together (speaker "gintoki+kagura")
##   `=> title`                    jump; `=> END` only after `do end(...)`
## Anything else is an error that names the title and step, never silently dropped.

## Tags a line may carry besides [#thought]: StoryRunner's expressions.
const EXPRESSIONS: Array[String] = preload("res://scripts/story_runner.gd").VALID_EXPRESSIONS
## The tone tags of a choice option (StoryRunner.VALID_TONES).
const TONES: Array[String] = preload("res://scripts/story_runner.gd").VALID_TONES
const END_TARGETS: Array[String] = ["end", "end!"]
## A tsukkomi round leaves through its option gotos, so nothing may follow it in its title.
const TERMINAL_OPS: Array[String] = ["end", "boke_round", "result"]
const EXPRESSION_SOURCE: String = "res://__story_build_expression.dialogue"


## A speaker by catalog id or displayed name ("" = narrator). Names joined with ＆, & or +
## ("銀時＆神樂") become one line said together: "gintoki+kagura". Returns "" when unknown.
static func speaker_id(name: String, speakers: Dictionary) -> String:
	if speakers.has(name):
		return String(speakers[name])
	var ids: Array[String] = []
	for part: String in name.replace("＆", "+").replace("&", "+").split("+"):
		var id: String = String(speakers.get(part.strip_edges(), ""))
		if id.is_empty() or id == "narrator":
			return ""
		ids.append(id)
	return "+".join(ids) if ids.size() > 1 else ""


## One command in the same grammar as a `.dialogue` line without its `do `: `bg("id")`,
## `char(...)`, `end("text")`, ... or `set key = value`. Other formats reuse this, so a
## command means the same thing whichever editor wrote it.
static func command_step(command: String, where: String) -> Dictionary:
	var source: String = command.strip_edges()
	var line_text: String = source if source.begins_with("set ") else "do " + source.trim_prefix("do ")
	var result: DMCompilerResult = DMCompiler.compile_string("~ command\n%s\n" % line_text, EXPRESSION_SOURCE)
	for line: Dictionary in result.lines.values():
		if result.errors.is_empty() and String(line.get("type", "")) == "mutation":
			return _mutation(line, where)
	return {"error": "%s: cannot read command `%s`" % [where, source]}


## Tokens of a condition expression such as `has("milk_bottle")` or `asked == "kagura"`;
## empty when it does not compile.
static func expression_tokens(expression: String) -> Array:
	var text: String = "~ expr\nif %s\n\t=> expr\n" % expression.strip_edges()
	var result: DMCompilerResult = DMCompiler.compile_string(text, EXPRESSION_SOURCE)
	if not result.errors.is_empty():
		return []
	for line: Dictionary in result.lines.values():
		if String(line.get("type", "")) == "condition":
			return line.get("condition", {}).get("expression", [])
	return []


## {"flag": key, "equals": value} for `key == value` tokens, else {}.
static func flag_equals(tokens: Array) -> Dictionary:
	if tokens.size() == 3 and tokens[0]["type"] == "variable" and tokens[1]["type"] == "comparison" \
			and tokens[1]["value"] == "==" and _is_literal(tokens[2]):
		return {"flag": tokens[0]["value"], "equals": _literal_value(tokens[2])}
	return {}


static func parse(text: String, context: Dictionary) -> Dictionary:
	var result: DMCompilerResult = DMCompiler.compile_string(text, String(context.get("source", "")))
	if not result.errors.is_empty():
		var first: DMError = result.errors[0]
		return _fail("line %d: %s" % [first.line_number + 1, DMConstants.get_error_message(first.error)])
	if result.cues.is_empty():
		return _fail("needs at least one `~ title`")

	var lines: Dictionary = result.lines
	var start_of: Dictionary = {}
	for cue_name: String in result.cues.keys():
		start_of[String(result.cues[cue_name])] = cue_name
	var cue_names: Array = result.cues.keys()
	cue_names.sort_custom(func(a: String, b: String) -> bool:
		return int(result.cues[a]) < int(result.cues[b]))

	var nodes: Dictionary = {}
	for cue_name: String in cue_names:
		var node: Dictionary = _parse_cue(cue_name, String(result.cues[cue_name]), lines, start_of, context)
		if node.has("error"):
			return _fail(node["error"])
		nodes[cue_name] = node
	return {"entry": cue_names[0], "nodes": nodes, "error": ""}


static func _parse_cue(cue_name: String, first_line: String, lines: Dictionary, start_of: Dictionary, context: Dictionary) -> Dictionary:
	var steps: Array = []
	var node: Dictionary = {}
	var line_id: String = first_line
	while true:
		var where: String = "~ %s, step %d" % [cue_name, steps.size()]
		if line_id != first_line and start_of.has(line_id):
			node["next"] = start_of[line_id]
			break
		if END_TARGETS.has(line_id) or line_id.is_empty() or not lines.has(line_id):
			if not steps.is_empty() and String(steps[-1]["op"]) == "end":
				break
			return {"error": "%s: reaches the end without `do end(\"text\")`" % where}
		var line: Dictionary = lines[line_id]
		var next_id: String = String(line.get("next_id", ""))
		match String(line.get("type", "")):
			"cue":
				if start_of.has(next_id):
					node["next"] = start_of[next_id]
					break
				line_id = next_id
			"dialogue":
				var next_line: Dictionary = lines.get(next_id, {})
				if String(next_line.get("type", "")) == "response":
					var choice: Dictionary = _choice(line, next_line, lines, start_of, where)
					if choice.has("error"):
						return choice
					steps.append(choice)
					break
				var say: Dictionary = _say(line, context, where)
				if say.has("error"):
					return say
				steps.append(say)
				line_id = next_id
			"mutation":
				var step: Dictionary = _mutation(line, where)
				if step.has("error"):
					return step
				steps.append(step)
				if TERMINAL_OPS.has(String(step["op"])):
					break
				line_id = next_id
			"condition":
				var condition: Dictionary = _condition(line, lines, start_of, where)
				if condition.has("error"):
					return condition
				steps.append(condition)
				break
			"goto":
				if bool(line.get("is_snippet", false)):
					return {"error": "%s: snippet jumps (=><) are not supported" % where}
				if END_TARGETS.has(next_id):
					line_id = next_id
					continue
				if not start_of.has(next_id):
					return {"error": "%s: jumps somewhere that is not a `~ title`" % where}
				node["next"] = start_of[next_id]
				break
			"response":
				return {"error": "%s: responses need a narration line right before them as the prompt" % where}
			var other:
				return {"error": "%s: `%s` lines are not supported" % [where, other]}
	if steps.is_empty():
		steps.append({"op": "goto", "target": node["next"]})
		node.erase("next")
	node["steps"] = steps
	return node


static func _say(line: Dictionary, context: Dictionary, where: String) -> Dictionary:
	var character: String = String(line.get("character", ""))
	var speaker: String = speaker_id(character, context.get("speakers", {}))
	if speaker.is_empty():
		return {"error": "%s: unknown speaker '%s' (use a catalog id or name)" % [where, character]}
	var text: String = String(line.get("text", ""))
	if not preload("res://scripts/dialogue_text.gd").valid_markup(text):
		return {"error": "%s: inline markup is not supported in '%s'" % [where, text]}
	var step: Dictionary = {"op": "say", "speaker": speaker, "text": text}
	for tag: String in line.get("tags", []):
		if tag == "thought":
			step["thought"] = true
		elif tag == "offscreen":
			step["offscreen"] = true
		elif tag.begins_with("source:"):
			step["source_id"] = tag.substr(7)
		elif EXPRESSIONS.has(tag):
			step["expression"] = tag
		else:
			return {"error": "%s: unknown tag [#%s]" % [where, tag]}
	return step


static func _choice(prompt: Dictionary, first_response: Dictionary, lines: Dictionary, start_of: Dictionary, where: String) -> Dictionary:
	if not String(prompt.get("character", "")).is_empty():
		return {"error": "%s: the line before responses is the choice prompt and must be narration" % where}
	var options: Array = []
	for response_id: String in first_response.get("responses", []):
		var response: Dictionary = lines[response_id]
		var label: String = String(response.get("text", "")).strip_edges()
		var option_id: String = String(response.get("static_id", ""))
		if option_id.is_empty():
			return {"error": "%s: response '%s' needs [ID:option_id]" % [where, label]}
		if label.contains("[if"):
			return {"error": "%s: write the condition of '%s' as [if has(\"item\") /]" % [where, label]}
		var option: Dictionary = {"id": option_id, "label": label}
		for tag: String in response.get("tags", []):
			if not TONES.has(tag):
				return {"error": "%s: response '%s' has unknown tag [#%s] (the tone tags are %s)" % [where, option_id, tag, ", ".join(TONES)]}
			if option.has("tone"):
				return {"error": "%s: response '%s' has more than one tone tag" % [where, option_id]}
			option["tone"] = tag
		var condition: Dictionary = response.get("condition", {})
		if not condition.is_empty():
			var item: String = has_item(condition.get("expression", []))
			if item.is_empty():
				return {"error": "%s: response '%s' condition must be has(\"item_id\")" % [where, option_id]}
			option["require"] = item
		var body: Dictionary = _response_body(String(response.get("next_id", "")), lines, start_of)
		if body.has("error"):
			return {"error": "%s: response '%s' %s" % [where, option_id, body["error"]]}
		option["next"] = body["next"]
		if not (body["set_flags"] as Dictionary).is_empty():
			option["set_flags"] = body["set_flags"]
		options.append(option)
	return {"op": "choice", "prompt": String(prompt.get("text", "")), "options": options}


static func _response_body(line_id: String, lines: Dictionary, start_of: Dictionary) -> Dictionary:
	var set_flags: Dictionary = {}
	while true:
		if start_of.has(line_id):
			return {"next": start_of[line_id], "set_flags": set_flags}
		var line: Dictionary = lines.get(line_id, {})
		match String(line.get("type", "")):
			"mutation":
				var assignment: Dictionary = _assignment(line.get("mutation", {}).get("expression", []))
				if assignment.is_empty():
					return {"error": "body may only contain `set key = value` lines and one => jump"}
				set_flags[assignment["key"]] = assignment["value"]
				line_id = String(line.get("next_id", ""))
			"goto":
				var target: String = String(line.get("next_id", ""))
				if not start_of.has(target):
					return {"error": "must jump to a `~ title`"}
				return {"next": start_of[target], "set_flags": set_flags}
			_:
				return {"error": "must end with one => jump"}
	return {}


static func _condition(line: Dictionary, lines: Dictionary, start_of: Dictionary, where: String) -> Dictionary:
	var test: Dictionary = flag_equals(line.get("condition", {}).get("expression", []))
	if test.is_empty():
		return {"error": "%s: conditions must be `if key == value`" % where}
	var else_line: Dictionary = lines.get(String(line.get("next_sibling_id", "")), {})
	if String(else_line.get("type", "")) != "condition" or not (else_line.get("condition", {}) as Dictionary).is_empty():
		return {"error": "%s: `if` needs an `else` branch" % where}
	var then_target: String = _single_jump(String(line.get("next_id", "")), lines, start_of)
	var else_target: String = _single_jump(String(else_line.get("next_id", "")), lines, start_of)
	if then_target.is_empty() or else_target.is_empty():
		return {"error": "%s: each `if`/`else` branch must hold exactly one => jump" % where}
	return {"op": "condition", "flag": test["flag"], "equals": test["equals"], "then": then_target, "else": else_target}


static func _single_jump(line_id: String, lines: Dictionary, start_of: Dictionary) -> String:
	var line: Dictionary = lines.get(line_id, {})
	if String(line.get("type", "")) != "goto":
		return ""
	return String(start_of.get(String(line.get("next_id", "")), ""))


static func _mutation(line: Dictionary, where: String) -> Dictionary:
	var tokens: Array = line.get("mutation", {}).get("expression", [])
	var assignment: Dictionary = _assignment(tokens)
	if not assignment.is_empty():
		return {"op": "flag", "key": assignment["key"], "value": assignment["value"]}
	if tokens.size() != 1 or tokens[0]["type"] != "function":
		return {"error": "%s: only `set key = value` and `do op(...)` are supported" % where}
	var name: String = tokens[0]["function"]
	var args: Array = _literal_args(tokens[0]["value"])
	if args.has(null):
		return {"error": "%s: %s() arguments must be literals" % [where, name]}
	match [name, args.size()]:
		["bg", 1]:
			return {"op": "bg", "id": args[0]}
		["char", 1], ["char", 2], ["char", 3]:
			var step: Dictionary = {"op": "char", "id": args[0], "visible": true}
			if args.size() > 1:
				step["expression"] = args[1]
			if args.size() > 2:
				step["position"] = args[2]
			return step
		["hide", 1]:
			return {"op": "char", "id": args[0], "visible": false}
		["enter", 1], ["enter", 2], ["enter", 3]:
			var entrance: Dictionary = {"op": "char", "id": args[0], "visible": true, "enter": true}
			if args.size() > 1:
				entrance["expression"] = args[1]
			if args.size() > 2:
				entrance["position"] = args[2]
			return entrance
		["placard", 1]:
			return {"op": "placard", "text": args[0]}
		["offscreen", 0]:
			return {"op": "offscreen"}  # folded into the next line by story_builder.gd
		["pov", 1]:
			return {"op": "pov", "id": args[0]}  # folded into the choice right after it by story_builder.gd
		["director", 0]:
			return {"op": "director"}
		["director", 1]:
			return {"op": "director", "note": args[0]}
		["tone", 1]:
			return {"op": "tone", "tone": args[0]}  # after a Parley option; parley_source.gd folds it into that option
		["item", 1]:
			return {"op": "item", "id": args[0]}
		["shake", 0]:
			return {"op": "shake"}
		["shake", 1]:
			return {"op": "shake", "strength": args[0]}
		["flash", 0]:
			return {"op": "flash"}
		["flash", 1]:
			return {"op": "flash", "color": args[0]}
		["cutin", 1]:
			return {"op": "cutin", "text": args[0]}
		["cutin", 2]:
			return {"op": "cutin", "text": args[0], "speaker": args[1]}
		["comedy", 3], ["comedy", 4]:
			var comedy: Dictionary = {"op": "comedy", "preset": args[0], "speaker": args[1], "text": args[2]}
			if args.size() > 3:
				comedy["expression"] = args[3]
			return comedy
		["beam", 0]:
			return {"op": name}
		["beam", 1]:
			return {"op": name, "duration": args[0]}
		["fade", 1]:
			return {"op": "fade", "direction": args[0]}
		["fade", 2]:
			return {"op": "fade", "direction": args[0], "duration": args[1]}
		["freeze", 0]:
			return {"op": "freeze"}
		["freeze", 1]:
			return {"op": "freeze", "duration": args[0]}
		["bgm", 1], ["se", 1]:
			return {"op": name, "id": args[0]}
		["profile", 1]:
			return {"op": "profile", "id": args[0]}
		["investigate", 1], ["boke_round", 1], ["result", 1]:
			return {"op": name, "block": args[0]}
		["end", 1]:
			return {"op": "end", "text": args[0]}
	return {"error": "%s: unsupported `do %s(%s)`" % [where, name, ", ".join(args.map(func(a: Variant) -> String: return str(a)))]}


static func _assignment(tokens: Array) -> Dictionary:
	if tokens.size() == 3 and tokens[0]["type"] == "variable" and tokens[1]["type"] == "assignment" \
			and tokens[1]["value"] == "=" and _is_literal(tokens[2]):
		return {"key": tokens[0]["value"], "value": _literal_value(tokens[2])}
	return {}


static func has_item(tokens: Array) -> String:
	if tokens.size() == 1 and tokens[0]["type"] == "function" and tokens[0]["function"] == "has":
		var args: Array = _literal_args(tokens[0]["value"])
		if args.size() == 1 and args[0] is String:
			return args[0]
	return ""


## DM stores call arguments as one token list per argument, closed by `)`.
static func _literal_args(raw_args: Array) -> Array:
	var args: Array = []
	for arg_tokens: Array in raw_args:
		var literals: Array = arg_tokens.filter(func(t: Dictionary) -> bool:
			return t["type"] != "parens_close" and t["type"] != "comma")
		if literals.is_empty():
			continue
		args.append(_literal_value(literals[0]) if literals.size() == 1 and _is_literal(literals[0]) else null)
	return args


static func _is_literal(token: Dictionary) -> bool:
	return ["string", "number", "bool"].has(String(token.get("type", ""))) or _is_bool_word(token)


## Dialogue Manager's tokenizer tries its variable pattern before its bool one, so `true` and `false`
## arrive as variables named "true" and "false".
static func _is_bool_word(token: Dictionary) -> bool:
	return String(token.get("type", "")) == "variable" and ["true", "false"].has(String(token.get("value", "")))


static func _literal_value(token: Dictionary) -> Variant:
	return String(token["value"]) == "true" if _is_bool_word(token) else token["value"]


static func _fail(message: String) -> Dictionary:
	return {"entry": "", "nodes": {}, "error": message}
