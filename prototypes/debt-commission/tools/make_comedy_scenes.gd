extends SceneTree
## Writes scenes/comedy/{tsukkomi_impact,small_reaction,full_manga_panel}.tscn once, with
## PackedScene.pack() + ResourceSaver.save():
##   godot --headless --path . --script res://tools/make_comedy_scenes.gd [-- --force]
## The saved scenes are the source files from then on: edit them in the editor. The game and the tests
## never run this, and it refuses to overwrite a scene unless --force is given; check `git diff` first,
## since a rewrite drops hand edits. Each scene's node count and owners are checked before it is packed
## and after it is read back.

const PresetScript: Script = preload("res://scripts/comedy_preset.gd")
const SpeedLinesScript: Script = preload("res://scripts/speed_lines.gd")
const BurstScript: Script = preload("res://scripts/burst_shape.gd")
const FONT_PATH: String = "res://assets/fonts/story-cjk.ttc"
const OUT_DIR: String = "res://scenes/comedy/"
## The editor preview: Shinpachi's `shout` face and a line of the episode.
const PREVIEW_FACE: String = "res://assets/image/expressions/shinpachi_shout.png"
const PREVIEW_LINE: String = "現在是工作時間吧！！！"
const PRESETS: Array[String] = ["tsukkomi_impact", "small_reaction", "full_manga_panel"]
## The game area the previews are laid out for (1080 wide; the real height is 1920 or more).
const DESIGN_SIZE: Vector2 = Vector2(1080.0, 1920.0)

var _font: Font = null
var _bold: FontVariation = null


func _init() -> void:
	var force: bool = OS.get_cmdline_user_args().has("--force")
	for preset: String in PRESETS:
		if FileAccess.file_exists(OUT_DIR + preset + ".tscn") and not force:
			printerr("%s%s.tscn exists; it is the source now. Check git diff, then rerun with -- --force." % [OUT_DIR, preset])
			quit(1)
			return
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_font = load(FONT_PATH) as Font
	_bold = FontVariation.new()
	_bold.base_font = _font
	_bold.variation_embolden = 0.9
	var failed: bool = false
	for preset: String in PRESETS:
		failed = not _write(preset) or failed
	quit(1 if failed else 0)


func _write(preset: String) -> bool:
	var root: Control = call("_build_" + preset) as Control
	var expected: int = _count(root)
	for node: Node in _all(root):
		if node != root and node.owner != root:
			printerr("%s: %s has no owner" % [preset, node.get_path_to(root)])
			return false
	var packed: PackedScene = PackedScene.new()
	if packed.pack(root) != OK:
		printerr("%s: pack failed" % preset)
		return false
	var path: String = OUT_DIR + preset + ".tscn"
	if ResourceSaver.save(packed, path) != OK:
		printerr("%s: save failed" % path)
		return false
	root.free()
	var reloaded: Node = (ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate()
	var actual: int = _count(reloaded)
	reloaded.free()
	print("%s: %d nodes built, %d after reading it back" % [path, expected, actual])
	return expected == actual


func _count(node: Node) -> int:
	return _all(node).size()


func _all(node: Node) -> Array[Node]:
	var nodes: Array[Node] = [node]
	for child: Node in node.get_children():
		nodes.append_array(_all(child))
	return nodes


# ---------------------------------------------------------------- the three presets

func _build_tsukkomi_impact() -> Control:
	var root: Control = _root("TsukkomiImpact")
	var dim: ColorRect = _add(root, ColorRect.new(), "Dim", root, true)
	_full(dim)
	dim.color = Color(0.0, 0.0, 0.03, 0.58)
	var lines: Control = _add(root, Control.new(), "SpeedLines", root, true)
	_full(lines)
	lines.set_script(SpeedLinesScript)
	lines.set("line_count", 72)
	lines.set("ink", Color(1, 1, 1, 0.4))
	lines.set("clear_radius", 0.3)
	lines.set("center_ratio", Vector2(0.5, 0.46))
	_cutin(root, Vector4(0.0, 0.06, 0.82, 0.37), -40.0, -4.0)
	_burst(root, Vector4(0.02, 0.36, 0.98, 0.72), Color("#fff3b0"), 18, 0.8, 150)
	return root


func _build_full_manga_panel() -> Control:
	var root: Control = _root("FullMangaPanel")
	root.set("dim_in", 0.08)
	root.set("cutin_at", 0.1)
	root.set("cutin_slide", 0.16)
	root.set("shake_at", 0.18)
	root.set("sound_at", 0.2)
	root.set("burst_at", 0.35)
	root.set("hold_until", 1.45)
	root.set("fade_at", 1.55)
	root.set("end_at", 1.8)
	root.set("stage_zoom", 1.0)
	root.set("font_max", 170)
	var dim: Control = _add(root, Control.new(), "Dim", root, true)
	_full(dim)
	var shade: ColorRect = _add(dim, ColorRect.new(), "Shade", root)
	_full(shade)
	shade.color = Color(0.0, 0.0, 0.03, 0.5)
	var page: Panel = _add(dim, Panel.new(), "Page", root)
	_anchor(page, Vector4(0.03, 0.035, 0.97, 0.965))
	page.add_theme_stylebox_override("panel", _frame(Color.WHITE, 20, 18.0))
	var lines: Control = _add(page, Control.new(), "SpeedLines", root, true)
	_full(lines)
	lines.clip_contents = true
	lines.set_script(SpeedLinesScript)
	lines.set("line_count", 84)
	lines.set("ink", Color(0.06, 0.06, 0.06, 0.5))
	lines.set("clear_radius", 0.27)
	lines.set("center_ratio", Vector2(0.5, 0.52))
	_cutin(root, Vector4(0.07, 0.08, 0.93, 0.5), 0.0, -3.0)
	_burst(root, Vector4(0.05, 0.5, 0.95, 0.9), Color("#fff3b0"), 20, 0.8, 170)
	return root


func _build_small_reaction() -> Control:
	var root: Control = _root("SmallReaction")
	root.set("cutin_at", 0.0)
	root.set("shake_strength", "none")
	root.set("sound_id", "comedy_pop")
	root.set("sound_at", 0.0)
	root.set("burst_at", 0.0)
	root.set("hold_until", 0.65)
	root.set("fade_at", 0.65)
	root.set("end_at", 0.9)
	root.set("stage_zoom", 1.0)
	root.set("font_max", 90)
	# Where the balloon hangs is set at play time (place_at); this is its place in the editor.
	var spot: Control = _add(root, Control.new(), "Spot", root, true)
	_anchor(spot, Vector4(0.5, 0.5, 0.5, 0.5))
	var burst: Control = _burst(spot, Vector4(0, 0, 0, 0), Color.WHITE, 10, 0.86, 90, root, "……嗶～")
	burst.offset_left = -300.0
	burst.offset_top = -330.0
	burst.offset_right = 300.0
	burst.offset_bottom = -20.0
	return root


# ---------------------------------------------------------------- pieces

func _root(node_name: String) -> Control:
	var root: Control = Control.new()
	root.name = node_name
	root.set_script(PresetScript)
	root.set("layout_mode", 3)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme: Theme = Theme.new()
	theme.default_font = _font
	root.theme = theme
	return root


## The tilted comic panel with the speaker's face (`anchors` = left, top, right, bottom shares).
func _cutin(root: Control, anchors: Vector4, bleed: float, tilt: float) -> void:
	var panel: Panel = _add(root, Panel.new(), "CutInPanel", root, true)
	_anchor(panel, anchors)
	panel.offset_left = bleed
	panel.rotation_degrees = tilt
	panel.pivot_offset_ratio = Vector2(0.5, 0.5)
	panel.add_theme_stylebox_override("panel", _frame(Color.WHITE, 16, 14.0))
	var face: TextureRect = _add(panel, TextureRect.new(), "Portrait", root, true)
	_full(face)
	face.offset_left = 16.0
	face.offset_top = 16.0
	face.offset_right = -16.0
	face.offset_bottom = -16.0
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var source: Texture2D = load(PREVIEW_FACE) as Texture2D
	var frame: Vector2 = Vector2((anchors.z - anchors.x) * DESIGN_SIZE.x - bleed, (anchors.w - anchors.y) * DESIGN_SIZE.y) - Vector2.ONE * 32.0
	var width: float = float(source.get_width()) * PresetScript.FACE_WIDTH
	var height: float = width * frame.y / frame.x
	var crop: AtlasTexture = AtlasTexture.new()
	crop.atlas = source
	crop.region = Rect2((float(source.get_width()) - width) * 0.5, 0.0, width, minf(height, float(source.get_height())))
	face.texture = crop


## The explosion balloon with its outlined, red-and-black line, centred in the balloon.
func _burst(parent: Control, anchors: Vector4, fill: Color, spikes: int, inner: float, font_size: int, root_node: Control = null,
		line: String = PREVIEW_LINE) -> Control:
	var root: Control = root_node if root_node != null else parent
	var burst: Control = _add(parent, Control.new(), "Burst", root, true)
	_anchor(burst, anchors)
	burst.set_script(BurstScript)
	burst.set("fill", fill)
	burst.set("spikes", spikes)
	burst.set("inner_ratio", inner)
	var area: Control = _add(burst, Control.new(), "TextArea", root, true)
	_anchor(area, Vector4(0.13, 0.17, 0.87, 0.83))
	# The line is centred in TextArea by its own offsets, which `_fit_text` of the preset script
	# sets for the line it plays; these are the editor's.
	var text: RichTextLabel = _add(area, RichTextLabel.new(), "Text", root, true)
	_anchor(text, Vector4(0.0, 0.5, 1.0, 0.5))
	text.offset_top = -font_size * 0.75
	text.offset_bottom = font_size * 0.75
	text.bbcode_enabled = true
	text.scroll_active = false
	text.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	text.add_theme_font_override("normal_font", _bold)
	text.add_theme_font_override("bold_font", _bold)
	text.add_theme_font_size_override("normal_font_size", int(font_size * 0.75))
	text.add_theme_font_size_override("bold_font_size", int(font_size * 0.75))
	text.add_theme_color_override("default_color", Color(PresetScript.INK))
	text.add_theme_color_override("font_outline_color", Color.WHITE)
	text.add_theme_constant_override("outline_size", 12)
	text.text = PresetScript.colored(line)
	return burst


func _frame(fill: Color, border: int, shadow: float) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.set_border_width_all(border)
	style.border_color = Color("#101010")
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 6
	style.shadow_offset = Vector2(shadow, shadow)
	return style


func _add(parent: Node, node: Node, node_name: String, owner_node: Node, unique: bool = false) -> Node:
	node.name = node_name
	parent.add_child(node)
	node.owner = owner_node
	node.unique_name_in_owner = unique
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		(node as Control).set("layout_mode", 1)
	return node


func _full(control: Control) -> void:
	_anchor(control, Vector4(0, 0, 1, 1))


func _anchor(control: Control, shares: Vector4) -> void:
	control.anchor_left = shares.x
	control.anchor_top = shares.y
	control.anchor_right = shares.z
	control.anchor_bottom = shares.w
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0
