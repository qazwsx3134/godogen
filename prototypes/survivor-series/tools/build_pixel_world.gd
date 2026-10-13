extends SceneTree
## One-off pixel pass for UI that lives in the world (docs/pixel-ui-plan.md P6): head HP bars get a dark pixel
## frame sized in art pixels, the bike warning gets a lane that fills up during the countdown, pickups get a
## ground shadow. Run: godot --headless --path . -s tools/build_pixel_world.gd
## Applied 2026-10-14; it refuses to run again (scenes/player.tscn has HpFrame). Edit the scenes directly.

## World px per art px: 2 screen px through the camera's 0.72 zoom.
const WP := 2.0 / 0.72

func _init() -> void:
	var player: Node = _open("res://scenes/player.tscn")
	if player.get_node("HpTrail").has_node("HpFrame"):
		push_error("pixel world pass already applied; edit the scenes directly")
		player.free()
		quit(1)
		return
	_bars(player, player.get_node("HpTrail"), [player.get_node("HpTrail"), player.get_node("HpBar")])
	_save(player, "res://scenes/player.tscn")
	for scene: String in ["bike", "car", "fatty", "smoker"]:
		var root: Node = _open("res://scenes/%s.tscn" % scene)
		_bars(root, root.get_node("HpBar"), [root.get_node("HpBar")])
		if scene == "bike":
			_warning_fill(root)
		_save(root, "res://scenes/%s.tscn" % scene)
	var pickup: Node = _open("res://scenes/pickup.tscn")
	var shadow := Polygon2D.new()
	shadow.name = "Shadow"
	shadow.color = Color(0, 0, 0, 0.3)
	var ring := PackedVector2Array()
	for i: int in 16:
		ring.append(Vector2(cos(TAU * i / 16.0) * 8.0, sin(TAU * i / 16.0) * 3.0))
	shadow.polygon = ring
	pickup.add_child(shadow)
	pickup.move_child(shadow, 0)
	shadow.owner = pickup
	_save(pickup, "res://scenes/pickup.tscn")
	quit()

## Resizes the bars to whole art pixels (2 high, scaled so 2 texture px = 1 art px) and puts a frame behind
## `holder`, the bottom-most bar, so the frame shows and hides with it.
func _bars(root: Node, holder: ProgressBar, bars: Array) -> void:
	var world := Rect2(holder.position, holder.size)
	var art_width: int = maxi(8, roundi(world.size.x / WP))
	var scale: float = WP / 2.0
	var top_left := Vector2(world.get_center().x - art_width * WP * 0.5, world.position.y)
	for bar: ProgressBar in bars:
		bar.scale = Vector2.ONE * scale
		bar.position = top_left
		bar.custom_minimum_size = Vector2(art_width * 2, 4)
		bar.size = bar.custom_minimum_size
		bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	var back := StyleBoxTexture.new()
	back.texture = load("res://assets/ui/bar_back.png")
	for side: int in 4:
		back.set_texture_margin(side, 4)
	var frame := Panel.new()
	frame.name = "HpFrame"
	frame.show_behind_parent = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", back)
	holder.add_child(frame)
	frame.owner = root
	frame.position = Vector2(-2, -2)
	frame.size = Vector2(art_width * 2 + 4, 8)

## A second, brighter lane that Enemy grows along the warning lane as the countdown runs.
func _warning_fill(root: Node) -> void:
	var lane: Line2D = root.get_node("%WarningLane")
	var fill := Line2D.new()
	fill.name = "WarningFill"
	fill.width = lane.width
	fill.default_color = Color(1, 0.4, 0.2, 0.3)
	fill.points = PackedVector2Array([Vector2.ZERO, Vector2(0, 60)])
	lane.get_parent().add_child(fill)
	lane.get_parent().move_child(fill, lane.get_index() + 1)
	fill.owner = root
	fill.unique_name_in_owner = true

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
	print("world: ", path)

func _count(node: Node) -> int:
	var total: int = 1
	for child: Node in node.get_children():
		total += _count(child)
	return total
