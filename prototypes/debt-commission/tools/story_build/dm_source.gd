extends RefCounted
## Dialogue Manager `.dialogue` -> StoryRunner nodes, parsed with Dialogue Manager's own compiler.
##
## Each `~ title` becomes a node with that id. Supported lines:
##   `Name: text` / plain text     say (Name is a catalog id or displayed name; plain = narrator)
##                                 tags: [#thought], [#<expression>]
##   narration + `- label [ID:x]`  choice; the narration line is the prompt. Options take
##                                 `[if has("item") /]` (require), `set k = v` lines (set_flags)
##                                 and one `=> title`
##   `set key = value`             flag
##   `if key == value` / `else`    condition; each branch holds exactly one `=> title`
##   `do bg("id")`, `do char("id", "expression", "position")`, `do hide("id")`,
##   `do item("id")`, `do profile("character_id")`, `do investigate("block")`,
##   `do boke_round("block")`, `do end("text")`
##   `=> title`                    jump; `=> END` only after `do end(...)`
## Anything else is an error that names the title and step, never silently dropped.

const EXPRESSIONS: Array[String] = ["neutral", "smile", "annoyed", "surprised", "thinking"]
const END_TARGETS: Array[String] = ["end", "end!"]
## A tsukkomi round leaves through its option gotos, so nothing may follow it in its title.
const TERMINAL_OPS: Array[String] = ["end", "boke_round"]
const EXPRESSION_SOURCE: String = "res://__story_build_expression.dialogue"


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
		return {"flag": tokens[0]["value"], "equals": tokens[2]["value"]}
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
	var speakers: Dictionary = context.get("speakers", {})
	var character: String = String(line.get("character", ""))
	if not speakers.has(character):
		return {"error": "%s: unknown speaker '%s' (use a catalog id or name)" % [where, character]}
	var text: String = String(line.get("text", ""))
	if text.contains("{{") or text.contains("["):
		return {"error": "%s: inline markup is not supported in '%s'" % [where, text]}
	var step: Dictionary = {"op": "say", "speaker": speakers[character], "text": text}
	for tag: String in line.get("tags", []):
		if tag == "thought":
			step["thought"] = true
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
		["item", 1]:
			return {"op": "item", "id": args[0]}
		["profile", 1]:
			return {"op": "profile", "id": args[0]}
		["investigate", 1], ["boke_round", 1]:
			return {"op": name, "block": args[0]}
		["end", 1]:
			return {"op": "end", "text": args[0]}
	return {"error": "%s: unsupported `do %s(%s)`" % [where, name, ", ".join(args.map(func(a: Variant) -> String: return str(a)))]}


static func _assignment(tokens: Array) -> Dictionary:
	if tokens.size() == 3 and tokens[0]["type"] == "variable" and tokens[1]["type"] == "assignment" \
			and tokens[1]["value"] == "=" and _is_literal(tokens[2]):
		return {"key": tokens[0]["value"], "value": tokens[2]["value"]}
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
		args.append(literals[0]["value"] if literals.size() == 1 and _is_literal(literals[0]) else null)
	return args


static func _is_literal(token: Dictionary) -> bool:
	return ["string", "number", "bool"].has(String(token.get("type", "")))


static func _fail(message: String) -> Dictionary:
	return {"entry": "", "nodes": {}, "error": message}
