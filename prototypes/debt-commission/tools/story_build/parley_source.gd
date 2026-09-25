extends RefCounted
## Parley `.ds` (a JSON graph) -> StoryRunner nodes.
##
## Each GROUP is one StoryRunner node; its `name` is the node id. Inside a group, nodes chain
## from the one member nothing in the group points at:
##   DIALOGUE                      say; `character` is `<uid>::Name` (the name part is looked up
##                                 like a .dialogue speaker; empty = narrator)
##   DIALOGUE -> DIALOGUE_OPTION   choice; that DIALOGUE is the prompt (narration). Option id =
##                                 its `text_translation_key`. A CONDITION `has("item")` between
##                                 prompt and option makes it require that item. After an option,
##                                 ACTION `set k = v` nodes become set_flags, then one edge to
##                                 another group
##   ACTION                        `description` holds one command in the .dialogue grammar
##                                 without `do `: bg(...), char(...), end("text"), set k = v, ...
##   CONDITION `key == value`      condition; true slot (0) and false slot (1) each lead to a group
##   edge into another group       that group comes next; it must point at the group's first node
##   END                           allowed only right after `end("text")`
## START points at the first group. JUMP, MATCH and nodes outside groups are errors.

const DmSource = preload("res://tools/story_build/dm_source.gd")
const CONDITION_TRUE_SLOT: int = 0   # addons/parley/models/dialogue_sequence_ast.gd:427
const CONDITION_FALSE_SLOT: int = 1


static func parse(text: String, context: Dictionary) -> Dictionary:
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary or not (data as Dictionary).get("nodes") is Array or not (data as Dictionary).get("edges") is Array:
		return _fail("not a Parley graph (needs nodes and edges arrays)")
	var graph: Dictionary = {"nodes": {}, "out": {}, "group_of": {}, "groups": {}, "speakers": context.get("speakers", {})}
	var start_ids: Array[String] = []
	for raw: Dictionary in data["nodes"]:
		var node_id: String = String(raw.get("id", ""))
		graph["nodes"][node_id] = raw
		graph["out"][node_id] = []
		match String(raw.get("type", "")):
			"GROUP":
				var name: String = String(raw.get("name", ""))
				if name.is_empty() or graph["groups"].has(name):
					return _fail("group '%s': group names must be unique and non-empty" % name)
				graph["groups"][name] = raw.get("node_ids", [])
				for member: Variant in raw.get("node_ids", []):
					if graph["group_of"].has(String(member)):
						return _fail("node %s is in two groups" % member)
					graph["group_of"][String(member)] = name
			"START":
				start_ids.append(node_id)
	for edge: Dictionary in data["edges"]:
		var from_id: String = String(edge.get("from_node", ""))
		if not graph["out"].has(from_id) or not graph["nodes"].has(String(edge.get("to_node", ""))):
			return _fail("edge %s connects a missing node" % edge.get("id", "?"))
		graph["out"][from_id].append(edge)
	for node_id: String in graph["nodes"].keys():
		var type: String = String(graph["nodes"][node_id].get("type", ""))
		if not ["GROUP", "START", "END"].has(type) and not graph["group_of"].has(node_id):
			return _fail("%s node %s is not inside a group" % [type, node_id])

	if start_ids.size() != 1 or (graph["out"][start_ids[0]] as Array).size() != 1:
		return _fail("needs exactly one START with one edge to the first group")
	var first: Dictionary = _group_target(graph, String(graph["out"][start_ids[0]][0]["to_node"]))
	if first.has("error"):
		return _fail("START: %s" % first["error"])

	var nodes: Dictionary = {}
	for group_name: String in graph["groups"].keys():
		var node: Dictionary = _parse_group(graph, group_name)
		if node.has("error"):
			return _fail(node["error"])
		nodes[group_name] = node
	return {"entry": first["group"], "nodes": nodes, "error": ""}


static func _parse_group(graph: Dictionary, group_name: String) -> Dictionary:
	var entry_id: String = _group_entry(graph, group_name)
	if entry_id.is_empty():
		return {"error": "group '%s' needs exactly one first node (one member nothing in the group points at)" % group_name}
	var steps: Array = []
	var node: Dictionary = {}
	var visited: Dictionary = {}
	var current: String = entry_id
	while true:
		var where: String = "group '%s', step %d" % [group_name, steps.size()]
		if visited.has(current):
			return {"error": "%s: loops back inside the group; loop through another group instead" % where}
		visited[current] = true
		var raw: Dictionary = graph["nodes"][current]
		var edges: Array = graph["out"][current]
		match String(raw.get("type", "")):
			"DIALOGUE":
				if _leads_to_options(graph, edges):
					var choice: Dictionary = _choice(graph, raw, edges, visited, where)
					if choice.has("error"):
						return choice
					steps.append(choice)
					break
				var say: Dictionary = _say(graph, raw, where)
				if say.has("error"):
					return say
				steps.append(say)
			"ACTION":
				var step: Dictionary = DmSource.command_step(String(raw.get("description", "")), where)
				if step.has("error"):
					return step
				steps.append(step)
				if DmSource.TERMINAL_OPS.has(String(step["op"])):
					var extra: Array = edges.filter(func(e: Dictionary) -> bool:
						return String(graph["nodes"][String(e["to_node"])].get("type", "")) != "END")
					if not extra.is_empty():
						return {"error": "%s: nothing may follow %s (a tsukkomi round leaves through its block's gotos)" % [where, step["op"]]}
					break
			"CONDITION":
				var condition: Dictionary = _condition(graph, raw, edges, where)
				if condition.has("error"):
					return condition
				steps.append(condition)
				break
			"END":
				return {"error": "%s: END must come right after end(\"text\")" % where}
			var other:
				return {"error": "%s: %s nodes are not supported" % [where, other]}
		if edges.size() != 1:
			return {"error": "%s: needs exactly one outgoing edge (has %d)" % [where, edges.size()]}
		var next_id: String = String(edges[0]["to_node"])
		if graph["group_of"].get(next_id, "") != group_name:
			var target: Dictionary = _group_target(graph, next_id)
			if target.has("error"):
				return {"error": "%s: %s" % [where, target["error"]]}
			node["next"] = target["group"]
			break
		current = next_id
	for member: Variant in graph["groups"][group_name]:
		if not visited.has(String(member)):
			return {"error": "group '%s': node %s is not connected to the group's chain" % [group_name, member]}
	node["steps"] = steps
	return node


static func _say(graph: Dictionary, raw: Dictionary, where: String) -> Dictionary:
	var character: String = String(raw.get("character", "")).get_slice("::", String(raw.get("character", "")).get_slice_count("::") - 1)
	var speakers: Dictionary = graph["speakers"]
	if not speakers.has(character):
		return {"error": "%s: unknown speaker '%s' (use a catalog id or name)" % [where, character]}
	var text: String = String(raw.get("text", ""))
	if text.contains("{{") or text.contains("["):
		return {"error": "%s: inline markup is not supported in '%s'" % [where, text]}
	return {"op": "say", "speaker": speakers[character], "text": text}


static func _leads_to_options(graph: Dictionary, edges: Array) -> bool:
	for edge: Dictionary in edges:
		var target: Dictionary = graph["nodes"][String(edge["to_node"])]
		if String(target.get("type", "")) == "DIALOGUE_OPTION" or _guarded_option(graph, target) != "":
			return true
	return false


## The option id behind a `has("item")` guard CONDITION, or "".
static func _guarded_option(graph: Dictionary, raw: Dictionary) -> String:
	if String(raw.get("type", "")) != "CONDITION":
		return ""
	for edge: Dictionary in graph["out"][String(raw["id"])]:
		if int(edge.get("from_slot", 0)) == CONDITION_TRUE_SLOT and String(graph["nodes"][String(edge["to_node"])].get("type", "")) == "DIALOGUE_OPTION":
			return String(edge["to_node"])
	return ""


static func _choice(graph: Dictionary, prompt: Dictionary, edges: Array, visited: Dictionary, where: String) -> Dictionary:
	if not String(prompt.get("character", "")).is_empty():
		return {"error": "%s: the DIALOGUE before options is the choice prompt and must be narration" % where}
	var entries: Array = []
	for edge: Dictionary in edges:
		var target_id: String = String(edge["to_node"])
		var target: Dictionary = graph["nodes"][target_id]
		var requirement: String = ""
		if String(target.get("type", "")) == "CONDITION":
			requirement = DmSource.has_item(DmSource.expression_tokens(String(target.get("description", ""))))
			var guarded: String = _guarded_option(graph, target)
			if requirement.is_empty() or guarded.is_empty() or (graph["out"][target_id] as Array).size() != 1:
				return {"error": "%s: a CONDITION before an option must be `has(\"item\")` with only its true slot connected" % where}
			visited[target_id] = true
			target_id = guarded
			target = graph["nodes"][target_id]
		if String(target.get("type", "")) != "DIALOGUE_OPTION":
			return {"error": "%s: a choice prompt may only lead to options" % where}
		entries.append({"id": target_id, "require": requirement, "position": _position(target)})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["position"].y < b["position"].y or (a["position"].y == b["position"].y and a["position"].x < b["position"].x))

	var options: Array = []
	for entry: Dictionary in entries:
		var raw: Dictionary = graph["nodes"][entry["id"]]
		visited[entry["id"]] = true
		var option_id: String = String(raw.get("text_translation_key", ""))
		var label: String = String(raw.get("text", "")).strip_edges()
		if option_id.is_empty():
			return {"error": "%s: option '%s' needs a text_translation_key (it becomes the option id)" % [where, label]}
		var option: Dictionary = {"id": option_id, "label": label}
		if not String(entry["require"]).is_empty():
			option["require"] = entry["require"]
		var set_flags: Dictionary = {}
		var current: String = String(entry["id"])
		while true:
			var out: Array = graph["out"][current]
			if out.size() != 1:
				return {"error": "%s: option '%s' needs exactly one outgoing edge at each node" % [where, option_id]}
			var next_id: String = String(out[0]["to_node"])
			var next_raw: Dictionary = graph["nodes"][next_id]
			if graph["group_of"].get(next_id, "") != graph["group_of"].get(String(entry["id"]), ""):
				var target: Dictionary = _group_target(graph, next_id)
				if target.has("error"):
					return {"error": "%s: option '%s' %s" % [where, option_id, target["error"]]}
				option["next"] = target["group"]
				break
			var step: Dictionary = DmSource.command_step(String(next_raw.get("description", "")), where) \
				if String(next_raw.get("type", "")) == "ACTION" else {}
			if String(step.get("op", "")) != "flag":
				return {"error": "%s: after option '%s' only ACTION `set key = value` nodes may come before the next group" % [where, option_id]}
			set_flags[step["key"]] = step["value"]
			visited[next_id] = true
			current = next_id
		if not set_flags.is_empty():
			option["set_flags"] = set_flags
		options.append(option)
	return {"op": "choice", "prompt": String(prompt.get("text", "")), "options": options}


static func _condition(graph: Dictionary, raw: Dictionary, edges: Array, where: String) -> Dictionary:
	var test: Dictionary = DmSource.flag_equals(DmSource.expression_tokens(String(raw.get("description", ""))))
	if test.is_empty():
		return {"error": "%s: a CONDITION's description must be `key == value`" % where}
	var targets: Dictionary = {}
	for edge: Dictionary in edges:
		var slot: int = int(edge.get("from_slot", -1))
		var target: Dictionary = _group_target(graph, String(edge["to_node"]))
		if target.has("error") or targets.has(slot):
			return {"error": "%s: each CONDITION slot must lead to exactly one group" % where}
		targets[slot] = target["group"]
	if not targets.has(CONDITION_TRUE_SLOT) or not targets.has(CONDITION_FALSE_SLOT):
		return {"error": "%s: connect both the true and false slots of the CONDITION" % where}
	return {"op": "condition", "flag": test["flag"], "equals": test["equals"],
		"then": targets[CONDITION_TRUE_SLOT], "else": targets[CONDITION_FALSE_SLOT]}


## {"group": name} when node_id is the first node of its group, else {"error": ...}.
static func _group_target(graph: Dictionary, node_id: String) -> Dictionary:
	var group_name: String = String(graph["group_of"].get(node_id, ""))
	if group_name.is_empty():
		return {"error": "leads to node %s outside any group" % node_id}
	if _group_entry(graph, group_name) != node_id:
		return {"error": "must connect to the first node of group '%s'" % group_name}
	return {"group": group_name}


static func _group_entry(graph: Dictionary, group_name: String) -> String:
	var members: Array = graph["groups"][group_name]
	var pointed: Dictionary = {}
	for member: Variant in members:
		for edge: Dictionary in graph["out"].get(String(member), []):
			pointed[String(edge["to_node"])] = true
	var entries: Array = members.filter(func(m: Variant) -> bool: return not pointed.has(String(m)))
	return String(entries[0]) if entries.size() == 1 else ""


static func _position(raw: Dictionary) -> Vector2:
	var parts: PackedStringArray = String(raw.get("position", "(0, 0)")).trim_prefix("(").trim_suffix(")").split(",")
	return Vector2(float(parts[0]), float(parts[1])) if parts.size() == 2 else Vector2.ZERO


static func _fail(message: String) -> Dictionary:
	return {"entry": "", "nodes": {}, "error": message}
