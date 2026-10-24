extends RefCounted
## Saves a node tree built in code as a .tscn from a headless generator script, then proves the file by
## reloading it. `const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")`
##
## Why a script: PackedScene.pack() writes what the editor writes, so the result opens and edits like any
## scene. But pack() keeps only nodes whose `owner` is the scene root and silently drops the rest, so
## save_scene() sets owners itself and then checks that the saved file holds what was built.
##
## Owner rule: every node you built gets `owner = root`. A sub-scene instance (instance()) gets an owner on
## its root only: its inner nodes belong to the sub-scene, and owning them would save them a second time
## into this scene. So a node added *under* an instance is dropped by pack(); the node-count check reports it.
##
## A generator is a one-time authoring tool: once its scenes are hand-edited, re-running would erase the
## edits. save_scene() therefore skips files that already exist unless options.overwrite is true. Put a note
## in the header of every generator that has been applied, e.g.
##   ## Applied 2026-10-03. Re-running is rejected: the scenes exist and were edited by hand; do not overwrite.
##
## Mini generator (godot --headless --path . --script res://tools/build_menu.gd):
##   extends SceneTree
##   const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")
##   func _initialize() -> void:
##       _build.call_deferred()
##   func _build() -> void:
##       var menu := Control.new()
##       menu.name = "Menu"
##       SceneBuilder.add(menu, SceneBuilder.unique(Label.new()), "Title")   # reachable as %Title
##       SceneBuilder.add(menu, SceneBuilder.instance("res://ui/panel.tscn"), "Panel")
##       var result := SceneBuilder.save_scene(menu, "res://ui/menu.tscn", {"expected_refs": ["res://ui/panel.tscn"]})
##       quit(0 if result.ok else 1)

const UNIQUE_META: StringName = &"_scene_builder_unique"


## Gives `root` and everything under it the owner rule above, writes `path`, reloads it and checks it. Always
## frees `root`. Returns {"ok", "skipped", "nodes", "refs", "error"}: `nodes` is how many nodes were built
## (0 when skipped), `refs` the distinct sub-scene paths the saved file references, `error` empty on success.
## A failure also push_errors and deletes the file if this call created it, so a rerun does not skip a bad scene
## (an overwritten file is already replaced and stays).
##
## options:
##   "overwrite": true      replace an existing file (default: skip it and return ok + skipped)
##   "expected_refs": [..]  sub-scene paths that must appear in the saved scene
static func save_scene(root: Node, path: String, options: Dictionary = {}) -> Dictionary:
	var refs: Array[String] = []
	var result: Dictionary = {"ok": false, "skipped": false, "nodes": 0, "refs": refs, "error": ""}
	var existed: bool = FileAccess.file_exists(path)
	if existed and not options.get("overwrite", false):
		print("skip (exists): ", path)
		root.free()
		result.ok = true
		result.skipped = true
		return result

	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	own_nodes(root)
	var authored: int = count_nodes(root)
	var packed := PackedScene.new()
	var error: Error = packed.pack(root)
	if error == OK:
		error = ResourceSaver.save(packed, path)
	root.free()

	var problems: Array[String] = []
	if error != OK:
		problems.append("cannot save: " + error_string(error))
	else:
		problems = _verify(path, authored, options.get("expected_refs", []), refs)
	result.nodes = authored
	if problems.is_empty():
		print("saved: %s (%d nodes)" % [path, authored])
		result.ok = true
		return result
	result.error = "; ".join(problems)
	push_error("%s: %s" % [path, result.error])
	if not existed and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return result


## Sets `owner` on every node under `root` (not into sub-scene instances) and turns unique() marks into
## unique_name_in_owner. save_scene() calls this; call it yourself only to inspect the tree before saving.
static func own_nodes(root: Node) -> void:
	_own(root, root)


## Counts `node` and all its descendants, including the inner nodes of sub-scene instances.
static func count_nodes(node: Node) -> int:
	var total: int = 1
	for child: Node in node.get_children():
		total += count_nodes(child)
	return total


## Instantiates a saved scene with the editor's edit state. pack() then writes a clean reference to `path`
## plus only the properties you change; a plain instantiate() would copy the sub-scene root's position,
## modulate and so on into this scene as overrides, and later edits to the sub-scene would not show through.
static func instance(path: String) -> Node:
	return (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)


## Marks `node` to become a %UniqueName in the saved scene; returns `node` so it chains inside add().
static func unique(node: Node) -> Node:
	node.set_meta(UNIQUE_META, true)
	return node


## add_child with a readable name: `node_name` if given, else the node's own name or type, numbered on a
## clash. Returns `child`.
static func add(parent: Node, child: Node, node_name: String = "") -> Node:
	if not node_name.is_empty():
		child.name = node_name
	parent.add_child(child, true)
	return child


static func _own(node: Node, scene_root: Node) -> void:
	for child: Node in node.get_children():
		child.owner = scene_root
		if child.has_meta(UNIQUE_META):
			child.remove_meta(UNIQUE_META)  # a leftover meta would be saved into the scene
			child.unique_name_in_owner = true
		if child.scene_file_path.is_empty():
			_own(child, scene_root)


## Reloads `path` from disk and returns what is wrong with it; fills `refs` with its sub-scene paths.
static func _verify(path: String, authored: int, expected_refs: Array, refs: Array[String]) -> Array[String]:
	var problems: Array[String] = []
	var loaded := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if loaded == null:
		problems.append("cannot reload the saved scene")
		return problems
	var state: SceneState = loaded.get_state()
	for index: int in state.get_node_count():
		var sub_scene: PackedScene = state.get_node_instance(index)
		if sub_scene != null and not refs.has(sub_scene.resource_path):
			refs.append(sub_scene.resource_path)
	for expected_ref: String in expected_refs:
		if not refs.has(expected_ref):
			problems.append("scene reference missing: " + expected_ref)
	var check: Node = loaded.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	if check == null:
		problems.append("cannot instantiate the saved scene")
		return problems
	var actual: int = count_nodes(check)
	check.free()
	if actual != authored:
		problems.append("%d nodes built, %d after reload (a node added under a sub-scene instance, or one without an owner, is dropped)" % [authored, actual])
	return problems
