extends SceneTree
## One-off (2026-10-14): moves the street's effects onto the kit's PixelVfx (addons/proto_kit/pixel_vfx.gd):
## the Fx node gets the kit script with this game's palettes, the smoke hazard loses its VFX 2D cloud (Street now
## spawns a PixelVfx "smoke" effect), and the VFX 2D credit leaves the menu. Refuses to run twice.
##   godot --headless --path . -s tools/use_kit_vfx.gd
const PALETTES := {
	"hit": ["#2a1a10", "#a4542a", "#ffb35c", "#ffe7a8", "#ffffff"],
	"heavy": ["#3a1406", "#b8400e", "#ff8a1f", "#ffd25c", "#fff6d0"],
	"kick": ["#14202e", "#3c6c96", "#7fc4ff", "#d4f0ff", "#ffffff"],
	"blast": ["#3a0a08", "#a8201a", "#ff5a2e", "#ffc24a", "#fff3c0"],
	"fart": ["#18300c", "#3e7020", "#86c040", "#d2f08a", "#f6ffe0"],
	"bounce": ["#102a40", "#2e6c9e", "#6fbaf0", "#c4e8ff", "#ffffff"],
	"gold": ["#3a2408", "#a8701a", "#ffc83e", "#ffe896", "#ffffff"],
	"slipper": ["#101c3a", "#2a4aa0", "#5c8cf0", "#c8dcff", "#ffffff"],
	"pearl": ["#1c0e06", "#5a3018", "#9a6236", "#e0b88a", "#fff0dc"],
	"firecracker": ["#300808", "#a01818", "#ff4a2a", "#ffcc4a", "#fff4c8"],
	"incense": ["#2a1206", "#8a3c10", "#e07a20", "#ffc060", "#fff0c8"],
	"lantern": ["#3a1606", "#b05010", "#ff9a2e", "#ffd88a", "#fffbe8"],
	"wave": ["#10243a", "#1f5d86", "#3fb4e0", "#9fe8ff", "#ffffff"],
	"cane": ["#3a0c24", "#a0306a", "#f070a8", "#ffc0dc", "#ffffff"],
	"stink": ["#14260a", "#3a6418", "#7cb83a", "#c8ec84", "#f4ffd8"],
	"smoke": ["#221c2c", "#5a5068", "#8a8098", "#bcb4c8", "#e8e4ee"],
}

func _init() -> void:
	var street: Node = _open("res://scenes/street.tscn")
	var fx: Node2D = street.get_node("Fx")
	if (fx.get_script() as Script).resource_path == "res://addons/proto_kit/pixel_vfx.gd":
		push_error("already applied; edit the scenes directly")
		street.free()
		quit(1)
		return
	fx.set_script(load("res://addons/proto_kit/pixel_vfx.gd"))
	fx.pixel = 2.0 / 0.72
	fx.font = (load("res://data/ui_theme.tres") as Theme).default_font
	fx.palettes = PALETTES
	_save(street, "res://scenes/street.tscn")
	var smoke: Node = _open("res://scenes/smoke.tscn")
	smoke.get_node("Cloud").free()
	_save(smoke, "res://scenes/smoke.tscn")
	var menu: Node = _open("res://scenes/menu.tscn")
	menu.get_node("Center/Box/Column/Credits").free()
	_save(menu, "res://scenes/menu.tscn")
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
	print("kit vfx: ", path)

func _count(node: Node) -> int:
	var total: int = 1
	for child: Node in node.get_children():
		total += _count(child)
	return total
