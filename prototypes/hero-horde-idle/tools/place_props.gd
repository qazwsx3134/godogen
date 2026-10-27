extends SceneTree
## Authoring tool: fills stage.tscn's Props with prop.tscn instances from LAYOUT (only props whose packed texture
## exists in assets/stage/props/).
##   godot --headless --path prototypes/hero-horde-idle --script res://tools/place_props.gd
## It replaces every child of Props, so once props are moved by hand in the editor, stop running it.

const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")
const STAGE := "res://scenes/stage.tscn"
const PROP := "res://scenes/prop.tscn"

## [texture name, x, z, scale, flip, tint]. The field is x -3.5..2.1, z -4..4; the boss stands at x 3.7.
const DUSK := Color(0.92, 0.88, 0.95)
const FAR := Color(0.78, 0.76, 0.9)
const LAYOUT := [
	["gate", 3.9, -8.2, 1.0, false, FAR],
	["brazier", 1.1, -4.6, 1.0, false, DUSK],
	["brazier", 6.3, -4.6, 1.0, true, DUSK],
	["pillar", -2.6, -6.4, 1.0, false, DUSK],
	["pillar", 0.4, -7.4, 0.8, true, FAR],
	["pillar", 7.6, -6.6, 0.9, true, DUSK],
	["banner", -4.4, -5.6, 1.0, false, DUSK],
	["banner", 8.4, -4.8, 1.0, true, DUSK],
	["pine", -6.0, -9.6, 1.1, false, FAR],
	["oak", -2.4, -10.2, 1.0, false, FAR],
	["pine", 9.6, -9.4, 1.0, true, FAR],
	["pine", 11.0, -7.6, 0.9, false, FAR],
	["oak", -7.6, -6.2, 0.9, true, DUSK],
	["boulder", -5.4, -3.6, 1.0, false, DUSK],
	["boulder", 7.4, -2.2, 1.3, true, DUSK],
	["boulder", 6.8, 4.2, 0.9, false, DUSK],
	["boulder", -4.6, 4.8, 0.8, true, DUSK],
	["fern", -4.8, 3.4, 1.0, false, DUSK],
	["fern", -1.2, 5.2, 1.0, true, DUSK],
	["fern", 2.8, 5.0, 1.0, false, DUSK],
	["fern", 5.6, 4.6, 1.0, true, DUSK],
	["fern", 8.2, 1.2, 1.0, false, DUSK],
	["fern", -6.0, 0.8, 1.0, true, DUSK],
]


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var item := MeshInstance3D.new()
	item.name = "Prop"
	item.set_script(load("res://scripts/prop.gd"))
	if not SceneBuilder.save_scene(item, PROP).ok:
		quit(1)
		return
	var stage: Node = (load(STAGE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var props: Node = stage.get_node("Props")
	for child: Node in props.get_children():
		props.remove_child(child)
		child.free()
	var count := {}
	for entry: Array in LAYOUT:
		var path: String = "res://assets/stage/props/%s.png" % entry[0]
		if not ResourceLoader.exists(path):
			continue
		var prop: Node3D = SceneBuilder.instance(PROP)
		prop.set("texture", load(path))
		prop.set("flip", entry[4])
		prop.set("tint", entry[5])
		prop.position = Vector3(entry[1], 0.0, entry[2])
		prop.scale = Vector3.ONE * entry[3]
		count[entry[0]] = count.get(entry[0], 0) + 1
		SceneBuilder.add(props, prop, "%s_%d" % [String(entry[0]).capitalize(), count[entry[0]]])
	var result: Dictionary = SceneBuilder.save_scene(stage, STAGE, {"overwrite": true, "expected_refs": [PROP]})
	quit(0 if result.ok else 1)
