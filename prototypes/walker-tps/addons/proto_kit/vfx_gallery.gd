extends SceneTree
## Renders every PixelVfx effect (built-in shapes and every shader in `shaders`) on a plain background and saves
## one PNG of four moments side by side (0.05, 0.2, 0.5 and 0.9 s), for judging effects without a game.
## Renders, so run it on a virtual display, never on the user's desktop:
##   env -u WAYLAND_DISPLAY xvfb-run -a -s "-screen 0 1600x1600x24" godot --path <project> --resolution 480x480 \
##     -s res://addons/proto_kit/vfx_gallery.gd -- /tmp/vfx.png [extra shader effect names to show: name=res://x.gdshader]
const PixelVfx = preload("res://addons/proto_kit/pixel_vfx.gd")
const MOMENTS := [0.05, 0.2, 0.5, 0.9]
var fx: Node2D
var out: String
var time: float = 0.0
var shots: Array[Image] = []
var started: bool = false

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	out = args[0] if not args.is_empty() else "user://vfx_gallery.png"
	var back := ColorRect.new()
	back.z_index = -20
	back.color = Color("5a524c")
	back.size = Vector2(4096, 4096)
	root.add_child(back)
	fx = PixelVfx.new()
	fx.pixel = 3.0
	for arg: String in args.slice(1):
		var pair: PackedStringArray = arg.split("=")
		fx.shaders[pair[0]] = load(pair[1])
	root.add_child(fx)

## Lays the effects out on a 3×3 grid once the window has its real size.
func _spawn() -> void:
	var size: Vector2 = root.get_visible_rect().size
	var cell := size / 3.0
	var spot := func(i: int) -> Vector2: return Vector2(i % 3 + 0.5, i / 3 + 0.5) * cell
	fx.burst(spot.call(0), &"hit", 14)
	fx.spark(spot.call(0) + Vector2(0, 30), Vector2.RIGHT, &"ice", 6)
	fx.ring(spot.call(1), 10.0, cell.x * 0.4, &"ice", 0.6, 2)
	fx.slash(spot.call(2), 0.0, cell.x * 0.35, 1.7, &"fire", true)
	fx.pop(spot.call(3), &"gold", cell.x * 0.25, 0.4)
	fx.star(spot.call(3) + Vector2(cell.x * 0.3, 0), &"gold", true)
	fx.caption(spot.call(4), "BAM!", &"magic", 1.0)
	var i: int = 5
	for name: StringName in fx.shaders:
		if i >= 9:
			break
		var palette: StringName = &"smoke" if name == &"smoke" else (&"poison" if i % 2 == 0 else &"fire")
		fx.effect(name, spot.call(i), cell * 0.95, 1.0, palette)
		i += 1

func _process(delta: float) -> bool:
	if not started:
		started = true
		_spawn()
		return false
	time += delta
	if shots.size() < MOMENTS.size() and time >= MOMENTS[shots.size()]:
		shots.append(root.get_texture().get_image())
	if shots.size() < MOMENTS.size():
		return false
	var w: int = shots[0].get_width()
	var sheet := Image.create(w * shots.size(), shots[0].get_height(), false, shots[0].get_format())
	for k: int in shots.size():
		sheet.blit_rect(shots[k], Rect2i(Vector2i.ZERO, shots[k].get_size()), Vector2i(w * k, 0))
	sheet.save_png(out)
	print("vfx gallery: ", out)
	return true
