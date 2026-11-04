extends RefCounted
## The 流程圖 of a story: its nodes folded into scene boxes, laid out left to right.
## Only the story's own routes count: `next`, choice options, `condition` then/else, `goto`, and a
## round's `clear`. In-scene detours (a spot's reaction, a wrong retort, a hint, a retry, Game Over)
## come back or restart, so they stay inside their box. A chain of nodes with one way in and one way
## out is one box, broken where a node changes the background or starts a search or a round.

const SCENE_OPS: Array[String] = ["bg", "investigate", "boke_round"]


## [{id, nodes, title, ending, column, row, to}] in reading order. `id` is the box's first node,
## `nodes` every node folded into it, `ending` the ending title when the box ends the story ("" for
## none), `to` the ids of the boxes it leads to. Columns count from 0 at the entry.
static func boxes(story: Dictionary) -> Array[Dictionary]:
	var nodes: Dictionary = story.get("nodes", {}) as Dictionary
	var entry: String = String(story.get("entry", ""))
	var result: Array[Dictionary] = []
	if not nodes.has(entry):
		return result
	var order: Array[String] = [entry]
	var seen: Dictionary = {entry: true}
	var cursor: int = 0
	while cursor < order.size():
		for target: String in routes(nodes, order[cursor]):
			if not seen.has(target):
				seen[target] = true
				order.append(target)
		cursor += 1
	var into: Dictionary = {}
	for node_id: String in order:
		for target: String in routes(nodes, node_id):
			into[target] = int(into.get(target, 0)) + 1
	var box_of: Dictionary = {}
	for node_id: String in order:
		if box_of.has(node_id):
			continue
		var chain: Array[String] = [node_id]
		box_of[node_id] = node_id
		while true:
			var out: Array[String] = routes(nodes, chain[-1])
			if out.size() != 1:
				break
			var next_id: String = out[0]
			if int(into.get(next_id, 0)) != 1 or box_of.has(next_id) or _starts_scene(nodes[next_id] as Dictionary):
				break
			box_of[next_id] = node_id
			chain.append(next_id)
		var last: Dictionary = nodes[chain[-1]] as Dictionary
		result.append({"id": node_id, "nodes": chain, "title": String((nodes[node_id] as Dictionary).get("title", node_id)),
			"ending": _ending_title(last), "column": 0, "row": 0, "to": []})
	var index: Dictionary = {}
	for i: int in result.size():
		index[result[i]["id"]] = i
	for box: Dictionary in result:
		var to: Array[String] = []
		for target: String in routes(nodes, (box["nodes"] as Array)[-1]):
			if not to.has(String(box_of[target])):
				to.append(String(box_of[target]))
		box["to"] = to
	# Columns: breadth-first from the entry, so a loop back to an earlier box does not push it right.
	var placed: Dictionary = {result[0]["id"]: true}
	var queue: Array[Dictionary] = [result[0]]
	var rows: Dictionary = {}
	while not queue.is_empty():
		var box: Dictionary = queue.pop_front()
		box["row"] = int(rows.get(box["column"], 0))
		rows[box["column"]] = int(box["row"]) + 1
		for target: String in box["to"]:
			if placed.has(target):
				continue
			placed[target] = true
			var next_box: Dictionary = result[index[target]]
			next_box["column"] = int(box["column"]) + 1
			queue.append(next_box)
	return result


## The node ids `node_id` can go on to by the story's own routes, in step order, each once.
static func routes(nodes: Dictionary, node_id: String) -> Array[String]:
	var out: Array[String] = []
	var node: Dictionary = nodes.get(node_id, {}) as Dictionary
	for raw: Variant in node.get("steps", []):
		if not raw is Dictionary:
			continue
		var step: Dictionary = raw
		var targets: Array = []
		match String(step.get("op", "")):
			"choice":
				for option: Variant in step.get("options", []):
					if option is Dictionary:
						targets.append((option as Dictionary).get("next", ""))
			"condition":
				targets = [step.get("then", ""), step.get("else", "")]
			"goto":
				targets = [step.get("target", "")]
			"boke_round":
				targets = [step.get("clear", "")]
		for target: Variant in targets:
			if target is String and nodes.has(target) and not out.has(target):
				out.append(target)
	var next_id: Variant = node.get("next", "")
	if next_id is String and nodes.has(next_id) and not out.has(next_id):
		out.append(next_id)
	return out


static func _starts_scene(node: Dictionary) -> bool:
	for step: Variant in node.get("steps", []):
		if step is Dictionary and String((step as Dictionary).get("op", "")) in SCENE_OPS:
			return true
	return false


static func _ending_title(node: Dictionary) -> String:
	for step: Variant in node.get("steps", []):
		if step is Dictionary and String((step as Dictionary).get("op", "")) in ["end", "result"]:
			# The same title 結局收集 shows (StoryRunner.endings_of).
			var fallback: String = String(step.get("text", step.get("title", node.get("title", ""))))
			return String(step.get("ending_title", fallback))
	return ""
