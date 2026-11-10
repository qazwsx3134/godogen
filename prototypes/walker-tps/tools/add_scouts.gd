extends SceneTree
## Creates scenes/scout.tscn (skipped if it exists) and puts an "Enemies" node with 12 scout instances into
## scenes/main.tscn (open_scene + put, so the rest of main.tscn and its hand edits are kept). Re-running replaces
## only the Enemies node. After that, move the scouts in the editor.
##   godot --headless --path . --script res://tools/add_scouts.gd
## Applied 2026-11-10.

const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")
const MAIN := "res://scenes/main.tscn"
const SCOUT := "res://scenes/scout.tscn"

func _initialize() -> void:
	_run.call_deferred()

func _scout() -> Node:
	var s := CharacterBody3D.new()
	s.name = "Scout"
	s.set_script(load("res://scripts/scout.gd"))
	s.floor_snap_length = 0.5
	s.floor_max_angle = deg_to_rad(40.0)
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.9
	cap.height = 2.2
	col.shape = cap
	col.position = Vector3(0, 1.1, 0)
	SceneBuilder.add(s, col, "Body")
	SceneBuilder.add(s, SceneBuilder.instance("res://assets/scout/scout.glb"), "Model")
	return s

func _run() -> void:
	var r := SceneBuilder.save_scene(_scout(), SCOUT, {"expected_refs": ["res://assets/scout/scout.glb"]})
	print("%s: %s" % [SCOUT, "skipped (exists)" if r.skipped else ("ok, %d nodes" % r.nodes if r.ok else r.error)])
	if not r.ok:
		quit(1)
		return

	var opened := SceneBuilder.open_scene(MAIN)
	var main: Node = opened.root
	var enemies := Node3D.new()
	SceneBuilder.put(main, enemies, "Enemies")
	var rng := RandomNumberGenerator.new()
	rng.seed = 86
	var i := 0
	for z: float in [26.0, 32.0, 38.0]:  # open ground north of the spawn, clear of the ramp and the crates
		for x: float in [-17.0, -11.0, -5.0, 1.0]:
			var s := SceneBuilder.instance(SCOUT) as Node3D
			s.position = Vector3(x, 0.05, z)
			s.rotation.y = rng.randf() * TAU
			SceneBuilder.add(enemies, s, "Scout%02d" % i)
			i += 1
	var refs: Array = opened.refs.duplicate()
	if not refs.has(SCOUT):
		refs.append(SCOUT)
	var m := SceneBuilder.save_scene(main, MAIN, {"overwrite": true, "expected_refs": refs})
	print("%s: %s" % [MAIN, "ok, %d nodes" % m.nodes if m.ok else m.error])
	quit(0 if m.ok else 1)
