extends SceneTree
## Sets the unit sizes (2026-11-18, melee = 1 by longest ground length, about 5.5 m):
## walker and tank 2 (about 11 m), scout 0.8 (about 4.4 m), Boss 40 (about 218 m).
## Writes the scale on each unit scene's root AND on every placed instance (an instance's
## transform override would otherwise drop it), so the editor shows the real size.
## godot --headless --path . --script res://tools/apply_unit_scales.gd
const Builder = preload("res://addons/proto_kit/scene_builder.gd")
const SCALES := {
	"res://scenes/walker.tscn": 1.9,
	"res://scenes/tank_display.tscn": 1.67,
	"res://scenes/scout.tscn": 0.91,
	"res://scenes/boss.tscn": 5.45,
	"res://scenes/melee_display.tscn": 1.0,
}
const PLACED := ["res://scenes/battlefield.tscn", "res://scenes/boss_battlefield.tscn", "res://scenes/main.tscn"]

func _initialize() -> void:
	quit(0 if _run() else 1)

func _run() -> bool:
	var ok := true
	for path: String in SCALES:
		var s := Builder.open_scene(path)
		(s.root as Node3D).scale = Vector3.ONE * float(SCALES[path])
		ok = Builder.save_scene(s.root, path, {"overwrite": true, "expected_refs": s.refs}).ok and ok
	for path: String in PLACED:
		var s := Builder.open_scene(path)
		for node: Node in s.root.find_children("*", "Node3D", true, false):
			if SCALES.has(node.scene_file_path):
				(node as Node3D).scale = Vector3.ONE * float(SCALES[node.scene_file_path])
		ok = Builder.save_scene(s.root, path, {"overwrite": true, "expected_refs": s.refs}).ok and ok
	return ok
