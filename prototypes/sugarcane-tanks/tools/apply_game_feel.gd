extends SceneTree
## One-off authoring tool for the game-feel pass (.claude/tasks/sugarcane-art/feel-brief.md).
## Creates the effect scenes (effects/spark, dust, debris, gold_burst, level_ring) and adds the HUD's
## feedback nodes to ui/hud.tscn: a white "ghost" bar behind each HP bar, the red edge vignette and
## the white flash over the screen.
##
##   godot --headless --path . --script res://tools/apply_game_feel.gd
##
## It has been applied. From here on the saved .tscn files are the source: edit them in the editor.
## Running it again is refused (hud.tscn already has %HpGhost), because a second pass would duplicate
## nodes and overwrite hand edits. `-- --effects` only rebuilds the five effect scenes from the numbers
## below (it overwrites any edit made to them in the editor). main.tscn (the %Juice node, the effect
## scenes it hands to Main, Camera2D.ignore_rotation) was edited as text afterwards.

var _failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if OS.get_cmdline_user_args().has("--effects"):
		_effects()
		print("APPLY FAILED" if _failed else "EFFECTS OK")
		quit(1 if _failed else 0)
		return
	var probe: Node = (load("res://ui/hud.tscn") as PackedScene).instantiate()
	var done: bool = probe.get_node_or_null("%HpGhost") != null
	probe.free()
	if done:
		print("already applied (hud.tscn has %HpGhost): nothing to do")
		quit(0)
		return
	_effects()
	_save(_hud(), "res://ui/hud.tscn", ["HpGhost", "BottomHpGhost", "Vignette", "WhiteFlash", "HpBar", "BottomHpBar"])
	print("APPLY FAILED" if _failed else "APPLY OK")
	quit(1 if _failed else 0)

func _effects() -> void:
	_save(_spark(), "res://effects/spark.tscn", [])
	_save(_dust(), "res://effects/dust.tscn", [])
	_save(_debris(), "res://effects/debris.tscn", [])
	_save(_gold_burst(), "res://effects/gold_burst.tscn", [])
	_save(_level_ring(), "res://effects/level_ring.tscn", ["Ring", "Rays"])

# --- particle bursts (square pixels; effects/burst.gd decides count, direction and colour) ----

func _burst(node_name: String) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.name = node_name
	particles.set_script(load("res://effects/burst.gd"))
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.local_coords = false   # they stay where they were born while the node would move
	particles.angle_min = 0.0
	particles.angle_max = 0.0
	return particles

func _ramp(offsets: Array, colors: Array) -> Gradient:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array(offsets)
	gradient.colors = PackedColorArray(colors)
	return gradient

func _curve(from: float, to: float) -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, from))
	curve.add_point(Vector2(1.0, to))
	return curve

## Hit sparks and little flashes: fast, short, shrinking, white-hot to orange.
func _spark() -> Node:
	var p: CPUParticles2D = _burst("Spark")
	p.amount = 10
	p.lifetime = 0.38
	p.randomness = 0.4
	p.direction = Vector2.RIGHT
	p.spread = 50.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 450.0
	p.initial_velocity_max = 900.0
	p.damping_min = 700.0
	p.damping_max = 1100.0
	p.scale_amount_min = 8.0
	p.scale_amount_max = 14.0
	p.scale_amount_curve = _curve(1.0, 0.3)
	p.color_ramp = _ramp([0.0, 0.5, 1.0], [Color(1.0, 1.0, 0.85, 1.0), Color(1.0, 0.65, 0.2, 0.9), Color(1.0, 0.4, 0.1, 0.0)])
	return p

## Dust at the feet and behind a dashing tank: slow, soft, growing while it fades.
func _dust() -> Node:
	var p: CPUParticles2D = _burst("Dust")
	p.amount = 5
	p.lifetime = 0.55
	p.randomness = 0.5
	p.explosiveness = 0.9
	p.direction = Vector2.UP
	p.spread = 180.0
	p.gravity = Vector2(0.0, -40.0)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 110.0
	p.damping_min = 60.0
	p.damping_max = 120.0
	p.scale_amount_min = 12.0
	p.scale_amount_max = 20.0
	p.scale_amount_curve = _curve(0.6, 1.3)
	p.color_ramp = _ramp([0.0, 1.0], [Color(0.95, 0.91, 0.82, 0.95), Color(0.85, 0.8, 0.72, 0.0)])
	return p

## Pieces of a dead enemy: they fly out and fall; each takes a colour out of the enemy's picture
## (set at runtime from juice.palette_of), white until then.
func _debris() -> Node:
	var p: CPUParticles2D = _burst("Debris")
	p.amount = 16
	p.lifetime = 0.85
	p.randomness = 0.5
	p.direction = Vector2.UP
	p.spread = 180.0
	p.gravity = Vector2(0.0, 1500.0)
	p.initial_velocity_min = 350.0
	p.initial_velocity_max = 800.0
	p.damping_min = 30.0
	p.damping_max = 90.0
	p.scale_amount_min = 9.0
	p.scale_amount_max = 17.0
	p.color_ramp = _ramp([0.0, 0.65, 1.0], [Color.WHITE, Color.WHITE, Color(1.0, 1.0, 1.0, 0.0)])
	return p

## The doorway bursting open: gold flecks thrown up and out.
func _gold_burst() -> Node:
	var p: CPUParticles2D = _burst("GoldBurst")
	p.amount = 30
	p.lifetime = 1.0
	p.randomness = 0.5
	p.direction = Vector2.UP
	p.spread = 110.0
	p.gravity = Vector2(0.0, 380.0)
	p.initial_velocity_min = 260.0
	p.initial_velocity_max = 640.0
	p.damping_min = 60.0
	p.damping_max = 120.0
	p.scale_amount_min = 9.0
	p.scale_amount_max = 16.0
	p.color_ramp = _ramp([0.0, 0.5, 1.0], [Color(1.0, 0.97, 0.6, 1.0), Color(1.0, 0.8, 0.2, 1.0), Color(1.0, 0.6, 0.1, 0.0)])
	return p

## A ring of light with rays, drawn at the size it has when the burst starts; level_ring.gd grows it.
func _level_ring() -> Node:
	var root := Node2D.new()
	root.name = "LevelRing"
	root.set_script(load("res://effects/level_ring.gd"))
	var ring := Line2D.new()
	ring.name = "Ring"
	ring.width = 7.0
	ring.default_color = Color(1.0, 0.9, 0.4, 1.0)
	ring.closed = true
	var points := PackedVector2Array()
	for i: int in 40:
		points.append(Vector2.from_angle(TAU * i / 40.0) * 60.0)
	ring.points = points
	root.add_child(_unique(ring))
	var rays := Node2D.new()
	rays.name = "Rays"
	root.add_child(_unique(rays))
	for i: int in 12:
		var ray := Line2D.new()
		ray.name = "Ray%d" % i
		ray.width = 5.0
		ray.default_color = Color(1.0, 0.95, 0.65, 1.0)
		var dir: Vector2 = Vector2.from_angle(TAU * i / 12.0)
		ray.points = PackedVector2Array([dir * 74.0, dir * (118.0 if i % 2 == 0 else 100.0)])
		rays.add_child(ray)
	return root

# --- HUD -------------------------------------------------------------------------

func _hud() -> Node:
	var root: Control = (load("res://ui/hud.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN) as Control
	_ghost(root, "HpBar", "HpBack", "HpGhost")
	_ghost(root, "BottomHpBar", "BottomHpBack", "BottomHpGhost")

	# Red edges that flash when the hero is hurt: a radial gradient from clear in the middle to red at the rim.
	var gradient := _ramp([0.6, 0.86, 1.0], [Color(1.0, 0.05, 0.05, 0.0), Color(0.95, 0.05, 0.05, 0.3), Color(0.8, 0.0, 0.0, 0.75)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256
	var vignette := TextureRect.new()
	vignette.name = "Vignette"
	vignette.texture = texture
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.modulate.a = 0.0
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_unique(vignette))
	root.move_child(vignette, 0)   # under the rest of the HUD

	var flash := ColorRect.new()
	flash.name = "WhiteFlash"
	flash.color = Color(1.0, 1.0, 1.0, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_unique(flash))
	root.move_child(flash, root.get_node("%PauseOverlay").get_index())   # over the HUD, under the pause screen and the fade
	return root

## The HP bar's dark frame moves to a panel of its own (HpBack) behind the bar, and a white ProgressBar
## (the ghost) goes between them: the bar's fill is drawn over the ghost, so the ghost shows only the
## part of the HP that was just lost. Order afterwards: back, ghost, bar (the bar keeps its name and children).
func _ghost(root: Control, bar_name: String, back_name: String, ghost_name: String) -> void:
	var bar: ProgressBar = root.get_node("%" + bar_name) as ProgressBar
	var parent: Node = bar.get_parent()
	var frame: StyleBox = bar.get_theme_stylebox(&"background")
	var fill: StyleBoxFlat = (bar.get_theme_stylebox(&"fill") as StyleBoxFlat).duplicate() as StyleBoxFlat
	fill.bg_color = Color(1.0, 0.96, 0.9, 0.95)
	fill.set_border_width_all(0)
	var back := Panel.new()
	back.name = back_name
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_theme_stylebox_override(&"panel", frame)
	var ghost := ProgressBar.new()
	ghost.name = ghost_name
	ghost.show_percentage = false
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.max_value = 100.0
	ghost.value = 100.0
	ghost.add_theme_stylebox_override(&"background", StyleBoxEmpty.new())
	ghost.add_theme_stylebox_override(&"fill", fill)
	for control: Control in [back, ghost]:
		control.anchor_left = bar.anchor_left
		control.anchor_top = bar.anchor_top
		control.anchor_right = bar.anchor_right
		control.anchor_bottom = bar.anchor_bottom
		control.offset_left = bar.offset_left
		control.offset_top = bar.offset_top
		control.offset_right = bar.offset_right
		control.offset_bottom = bar.offset_bottom
	bar.add_theme_stylebox_override(&"background", StyleBoxEmpty.new())
	var index: int = bar.get_index()
	parent.add_child(back)
	parent.add_child(_unique(ghost))
	parent.move_child(back, index)
	parent.move_child(ghost, index + 1)

# --- helpers ---------------------------------------------------------------------

func _unique(node: Node) -> Node:
	node.set_meta(&"_unique", true)
	return node

func _fail(message: String) -> void:
	push_error(message)
	_failed = true

func _save(root: Node, path: String, required: Array) -> void:
	_own(root, root)
	var expected: int = _count(root)
	var packed := PackedScene.new()
	var error: Error = packed.pack(root)
	if error == OK:
		error = ResourceSaver.save(packed, path)
	root.free()
	if error != OK:
		_fail("cannot save %s: %s" % [path, error_string(error)])
		return
	var reloaded: PackedScene = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var check: Node = reloaded.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	var actual: int = _count(check)
	if actual != expected:
		_fail("%s: %d nodes before pack, %d after reload" % [path, expected, actual])
	for node_name: String in required:
		if check.get_node_or_null("%" + node_name) == null:
			_fail("%s: missing %%%s after reload" % [path, node_name])
	print("saved: %s (%d nodes)" % [path, actual])
	check.free()

## Owner on every authored node (a node without one is silently dropped by pack()); sub-scene
## instances get an owner on their root only. The owner is set before the unique-name flag.
func _own(node: Node, owner: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner
		if child.has_meta(&"_unique"):
			child.remove_meta(&"_unique")
			child.unique_name_in_owner = true
		if child.scene_file_path.is_empty():
			_own(child, owner)

func _count(node: Node) -> int:
	var total: int = 1
	for child: Node in node.get_children():
		total += _count(child)
	return total
