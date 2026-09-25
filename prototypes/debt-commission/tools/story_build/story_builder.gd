extends RefCounted
## Builds StoryRunner JSON from an authoring source (.dialogue or .ds) plus its blocks file.
##
## Adapters turn a source into {entry, nodes}; this file adds what both formats share: story
## metadata and gameplay blocks from `<name>.blocks.json` (optional: without it the story id
## and title are the file name and no gameplay blocks exist), the reachability check, the
## structural `version`, and a final StoryRunner.load_story() so the output passes the same
## validation the game runs. Every problem is returned as an error with its location.

const DmSource = preload("res://tools/story_build/dm_source.gd")
const ParleySource = preload("res://tools/story_build/parley_source.gd")
const StoryRunner = preload("res://scripts/story_runner.gd")
const AtomicFile = preload("res://addons/proto_kit/atomic_file.gd")
const CATALOG_PATH: String = "res://data/asset_catalog.json"
const CHECK_PATH: String = "user://story_build_check.json"
const BLOCK_OPS: Array[String] = ["investigate", "boke_round"]


## Where a source's story goes: story_src/<name>.ds -> data/<name>_story.json.
static func output_path_for(source_path: String) -> String:
	return "res://data/%s_story.json" % source_path.get_file().get_basename()


## Builds source_path and writes it to output_path (default: output_path_for). Returns
## {"output": path, "version": String, "error": String}.
static func build_and_write(source_path: String, output_path: String = "") -> Dictionary:
	var output: String = output_path if not output_path.is_empty() else output_path_for(source_path)
	var built: Dictionary = build(source_path)
	if not String(built["error"]).is_empty():
		return {"output": output, "version": "", "error": built["error"]}
	if AtomicFile.write_text(output, to_json(built["story"])) != OK:
		return {"output": output, "version": "", "error": "cannot write %s" % output}
	return {"output": output, "version": built["story"]["version"], "error": ""}


## Returns {"story": Dictionary, "error": String}; exactly one of them is empty.
static func build(source_path: String) -> Dictionary:
	if not FileAccess.file_exists(source_path):
		return _fail("%s: file not found" % source_path)
	return build_text(FileAccess.get_file_as_string(source_path), source_path)


## Builds `text` as if it were the content of `source_path` (the blocks file is found from
## that path). Dialogue Manager registers [ID:...] per path, so edited variants of a source
## must be compiled under the same path.
static func build_text(text: String, source_path: String) -> Dictionary:
	var blocks_path: String = source_path.get_basename() + ".blocks.json"
	var name: String = source_path.get_file().get_basename()
	var blocks_file: Variant = {"story": {"id": name, "title": name}}
	if FileAccess.file_exists(blocks_path):
		blocks_file = _read_json(blocks_path)
	if not blocks_file is Dictionary:
		return _fail("%s: not valid JSON" % blocks_path)
	var meta: Dictionary = (blocks_file as Dictionary).get("story", {}) as Dictionary
	var blocks: Dictionary = (blocks_file as Dictionary).get("blocks", {}) as Dictionary
	var titles: Dictionary = (blocks_file as Dictionary).get("titles", {}) as Dictionary
	for key: String in ["id", "title"]:
		if not meta.get(key, null) is String or String(meta[key]).is_empty():
			return _fail("%s: story.%s must be a non-empty string" % [blocks_path, key])

	var catalog: Variant = _read_json(CATALOG_PATH)
	if not catalog is Dictionary:
		return _fail("cannot read %s" % CATALOG_PATH)
	var context: Dictionary = {"speakers": _speaker_table(catalog as Dictionary), "source": source_path}

	var parsed: Dictionary
	match source_path.get_extension():
		"dialogue":
			parsed = DmSource.parse(text, context)
		"ds":
			parsed = ParleySource.parse(text, context)
		_:
			return _fail("%s: unsupported source type (use .dialogue or .ds)" % source_path)
	if not String(parsed.get("error", "")).is_empty():
		return _fail("%s: %s" % [source_path, parsed["error"]])

	var nodes: Dictionary = parsed["nodes"]
	var block_error: String = _resolve_blocks(nodes, blocks)
	if not block_error.is_empty():
		return _fail("%s: %s" % [source_path, block_error])
	for node_id: String in nodes.keys():
		(nodes[node_id] as Dictionary)["title"] = String(titles.get(node_id, node_id))

	var entry: String = String(meta.get("entry", parsed["entry"]))
	var unreachable: Array[String] = _unreachable(entry, nodes)
	if not unreachable.is_empty():
		return _fail("%s: unreachable from '%s': %s" % [source_path, entry, ", ".join(unreachable)])

	var story: Dictionary = {
		"id": meta["id"],
		"title": meta["title"],
		"entry": entry,
		"initial_flags": meta.get("initial_flags", {}),
		"nodes": nodes,
		"generated_from": source_path.trim_prefix("res://"),
	}
	if meta.has("note"):
		story["note"] = meta["note"]
	story["version"] = fingerprint(story)

	var runner_error: String = _validate_with_runner(story)
	if not runner_error.is_empty():
		return _fail("%s: StoryRunner rejects the output: %s" % [source_path, runner_error])
	return {"story": story, "error": ""}


static func to_json(story: Dictionary) -> String:
	return JSON.stringify(story, "  ", true) + "\n"


## Saves store node ids and step indexes, so the version changes exactly when those can
## shift: node ids, op sequences, and choice/hotspot/tsukkomi ids with their targets.
## Text is left out, so fixing a typo keeps existing saves valid.
static func fingerprint(story: Dictionary) -> String:
	var shape: Array = [story.get("entry", "")]
	var nodes: Dictionary = story.get("nodes", {}) as Dictionary
	var node_ids: Array = nodes.keys()
	node_ids.sort()
	for node_id: Variant in node_ids:
		var node: Dictionary = nodes[node_id] as Dictionary
		var steps: Array = []
		for step: Dictionary in node.get("steps", []):
			steps.append(_step_shape(step))
		shape.append([node_id, node.get("next", ""), steps])
	return "s-" + JSON.stringify(shape, "", true).sha256_text().substr(0, 12)


static func _step_shape(step: Dictionary) -> Array:
	var op: String = String(step.get("op", ""))
	var shape: Array = [op]
	for key: String in ["id", "key", "flag", "equals", "then", "else", "target", "game_over"]:
		if step.has(key):
			shape.append([key, step[key]])
	for option: Dictionary in step.get("options", []):
		shape.append([option.get("id", ""), option.get("next", ""), option.get("require", "")])
	for hotspot: Dictionary in step.get("hotspots", []):
		shape.append([hotspot.get("id", ""), hotspot.get("item", "")])
	var tsukkomi: Dictionary = step.get("tsukkomi", {}) as Dictionary
	for option: Dictionary in tsukkomi.get("options", []):
		shape.append([option.get("id", ""), option.get("goto", ""), option.get("require", "")])
	if tsukkomi.has("timeout"):
		shape.append(["timeout", (tsukkomi["timeout"] as Dictionary).get("goto", "")])
	for line: Dictionary in step.get("lines", []):
		shape.append(line.get("id", ""))
	return shape


static func _resolve_blocks(nodes: Dictionary, blocks: Dictionary) -> String:
	for node_id: String in nodes.keys():
		var steps: Array = (nodes[node_id] as Dictionary)["steps"]
		for index: int in range(steps.size()):
			var step: Dictionary = steps[index]
			if not step.has("block"):
				continue
			var block_id: String = String(step["block"])
			var block: Variant = blocks.get(block_id, null)
			if not block is Dictionary:
				return "node '%s' step %d uses unknown block '%s'" % [node_id, index, block_id]
			if String((block as Dictionary).get("op", "")) != String(step["op"]):
				return "node '%s' step %d: block '%s' is not a %s block" % [node_id, index, block_id, step["op"]]
			var resolved: Dictionary = (block as Dictionary).duplicate(true)
			resolved["id"] = block_id
			steps[index] = resolved
	return ""


static func _unreachable(entry: String, nodes: Dictionary) -> Array[String]:
	var seen: Dictionary = {}
	var queue: Array[String] = [entry]
	while not queue.is_empty():
		var node_id: String = queue.pop_back()
		if seen.has(node_id) or not nodes.has(node_id):
			continue
		seen[node_id] = true
		var node: Dictionary = nodes[node_id]
		if node.has("next"):
			queue.append(String(node["next"]))
		for step: Dictionary in node["steps"]:
			for key: String in ["then", "else", "target", "game_over"]:
				if step.has(key):
					queue.append(String(step[key]))
			for option: Dictionary in step.get("options", []):
				queue.append(String(option.get("next", "")))
			var tsukkomi: Dictionary = step.get("tsukkomi", {}) as Dictionary
			for option: Dictionary in tsukkomi.get("options", []):
				queue.append(String(option.get("goto", "")))
			if tsukkomi.has("timeout"):
				queue.append(String((tsukkomi["timeout"] as Dictionary).get("goto", "")))
	var missing: Array[String] = []
	for node_id: String in nodes.keys():
		if not seen.has(node_id):
			missing.append(node_id)
	missing.sort()
	return missing


static func _validate_with_runner(story: Dictionary) -> String:
	if AtomicFile.write_text(CHECK_PATH, to_json(story)) != OK:
		return "cannot write %s" % CHECK_PATH
	var runner: RefCounted = StoryRunner.new()
	var ok: bool = runner.call("load_story", CHECK_PATH)
	DirAccess.remove_absolute(CHECK_PATH)
	return "" if ok else String(runner.get("error_message"))


## Authors may write a catalog id or the displayed name; lines without a speaker are narration.
static func _speaker_table(catalog: Dictionary) -> Dictionary:
	var table: Dictionary = {"": "narrator", "narrator": "narrator"}
	var characters: Dictionary = catalog.get("characters", {}) as Dictionary
	for character_id: String in characters.keys():
		table[character_id] = character_id
		table[String((characters[character_id] as Dictionary).get("name", character_id))] = character_id
	return table


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


static func _fail(message: String) -> Dictionary:
	return {"story": {}, "error": message}
