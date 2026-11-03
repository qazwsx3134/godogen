extends SceneTree
## Loads a scene, packs and saves it back through Godot (normalises a hand-edited .tscn) and checks the node count.
## godot --headless --path . -s tools/resave_scene.gd -- res://scenes/x.tscn


func _initialize() -> void:
	var path: String = OS.get_cmdline_user_args()[0]
	# Edit state keeps instanced sub-scenes as instances (a plain instantiate() would write type/script overrides).
	var root := (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	var before := _count(root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, path)
	var after := _count((load(path) as PackedScene).instantiate()) if err == OK else -1
	print("RESAVE %s err=%d nodes %d → %d" % [path, err, before, after])
	root.free()
	quit(0 if err == OK and before == after else 1)


func _count(n: Node) -> int:
	var c := 1
	for k in n.get_children():
		c += _count(k)
	return c
