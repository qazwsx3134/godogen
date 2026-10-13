extends SceneTree
## One-off effects pass: adds the PixelFx node to street.tscn and turns the vector projectiles into small pixel
## sprites (assets/pixel/fx/, from tools/make_fx_sprites.py and pixelize.py --src) with their PixelFx palette,
## trail and ground shadow. The old vector shapes stay in each Visual, hidden.
##   godot --headless --path . -s tools/build_pixel_fx_scenes.gd
## Applied 2026-10-14; it refuses to run again (street.tscn has Fx). Edit the scenes directly.

const WP := 2.0 / 0.72
## id: [palette, trail, shadow radius]. Weapon sprites are about 0.7 of the old vector shapes (WEAPON_SCALE).
const SHOTS := {
	"slipper": ["slipper", "", 9.0],
	"pearl": ["pearl", "", 6.0],
	"firecracker": ["firecracker", "spark", 7.0],
	"incense": ["incense", "ember", 5.0],
	"lantern": ["lantern", "ember", 8.0],
	"wave": ["wave", "spark", 12.0],
}

func _init() -> void:
	var street: Node = _open("res://scenes/street.tscn")
	if street.has_node("Fx"):
		push_error("pixel fx pass already applied; edit the scenes directly")
		street.free()
		quit(1)
		return
	var fx := Node2D.new()
	fx.name = "Fx"
	fx.z_index = 8
	fx.set_script(load("res://scripts/pixel_fx.gd"))
	street.add_child(fx)
	street.move_child(fx, street.get_node("Effects").get_index() + 1)
	fx.owner = street
	fx.unique_name_in_owner = true
	_save(street, "res://scenes/street.tscn")
	for id: String in SHOTS:
		var root: Node2D = _open("res://scenes/%s.tscn" % id)
		var visual: Node2D = root.get_node("Visual")
		for child: Node in visual.get_children():
			if child is CanvasItem:
				child.visible = false
		var art := Sprite2D.new()
		art.name = "Art"
		art.texture = load("res://assets/pixel/fx/%s.png" % id)
		art.scale = Vector2.ONE * WP
		visual.add_child(art)
		art.owner = root
		root.palette = StringName(SHOTS[id][0])
		root.trail = StringName(SHOTS[id][1])
		root.shadow_size = SHOTS[id][2]
		_save(root, "res://scenes/%s.tscn" % id)
	var cane: Node2D = _open("res://scenes/cane.tscn")
	var hand: Sprite2D = cane.get_node("Visual/Hand")
	hand.texture = load("res://assets/pixel/fx/cane.png")
	hand.scale = Vector2.ONE * WP * signf(hand.scale.x)
	cane.palette = &"cane"
	_save(cane, "res://scenes/cane.tscn")
	for pair: Array in [["tofu", "stink"], ["ring", "gold"], ["rider", "kick"]]:
		var root: Node2D = _open("res://scenes/%s.tscn" % pair[0])
		root.palette = StringName(pair[1])
		_save(root, "res://scenes/%s.tscn" % pair[0])
	quit()

func _open(path: String) -> Node:
	return (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)

func _save(root: Node, path: String) -> void:
	var nodes: int = _count(root)
	var packed := PackedScene.new()
	assert(packed.pack(root) == OK)
	assert(ResourceSaver.save(packed, path) == OK)
	root.free()
	var check: Node = (load(path) as PackedScene).instantiate()
	assert(_count(check) == nodes, "%s lost nodes" % path)
	check.free()
	print("fx: ", path)

func _count(node: Node) -> int:
	var total: int = 1
	for child: Node in node.get_children():
		total += _count(child)
	return total
