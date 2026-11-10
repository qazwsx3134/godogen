extends SceneTree
## Adds the touch JUMP / BOOST buttons to scenes/hud.tscn (opens the saved scene, puts the nodes, saves it back).
## Safe to re-run: put() replaces the Buttons node it added before. Hand edits elsewhere in hud.tscn are kept.
##   godot --headless --path . --script res://tools/add_action_buttons.gd
## Applied 2026-11-10.

const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")
const HUD := "res://scenes/hud.tscn"

func _initialize() -> void:
	_run.call_deferred()

func _circle(px: int, rim: Color, fill: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.86, 0.9, 0.97, 1.0])
	g.colors = PackedColorArray([fill, fill, rim, rim, Color(rim, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = px
	t.height = px
	return t

func _button(parent: Node, name: String, action: String, text: String, px: int, at: Vector2) -> void:
	var b := TouchScreenButton.new()
	b.action = action
	b.position = at
	b.texture_normal = _circle(px, Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.1))
	b.texture_pressed = _circle(px, Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.3))
	b.visibility_mode = TouchScreenButton.VISIBILITY_TOUCHSCREEN_ONLY
	SceneBuilder.add(parent, b, name)
	var label := Label.new()
	label.text = text
	label.position = Vector2(0, px * 0.5 - 14)
	label.size = Vector2(px, 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(b, label, "Label")

func _run() -> void:
	var opened := SceneBuilder.open_scene(HUD)
	var hud: Node = opened.root
	if hud == null:
		push_error("cannot open " + HUD)
		quit(1)
		return
	var zone := Control.new()  # bottom-right corner; touch_input does not turn the camera from in here
	zone.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	zone.offset_left = -330
	zone.offset_top = -300
	zone.offset_right = -20
	zone.offset_bottom = -20
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.put(hud, SceneBuilder.unique(zone), "Buttons")
	_button(zone, "Jump", "jump", "JUMP", 150, Vector2(150, 120))
	_button(zone, "Boost", "sprint", "BOOST", 110, Vector2(10, 165))
	var r := SceneBuilder.save_scene(hud, HUD, {"overwrite": true, "expected_refs": opened.refs})
	print("%s: %s" % [HUD, "ok, %d nodes" % r.nodes if r.ok else r.error])
	quit(0 if r.ok else 1)
