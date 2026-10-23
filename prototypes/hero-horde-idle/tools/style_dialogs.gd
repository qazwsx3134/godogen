extends SceneTree
## Gives the pop-up dialogs the framed look (ui/theme.tres's Dialog variation, tools/style_theme.gd) and a bronze
## rule with a diamond under their titles (scenes/ornament_rule.tscn, which this writes too). Each target scene is
## loaded, changed in those two places and saved again, so the rest of it stays as it was. Idempotent: run it again
## after a generator rebuilds one of these scenes (build_shell, build_recruit, build_hud). Applied 2026-10-22.
##   godot --headless --path prototypes/hero-horde-idle --script res://tools/style_dialogs.gd

const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")
const RULE := "res://scenes/ornament_rule.tscn"
const DIAMOND := "res://assets/ui/frame/rule_diamond.png"
const BRONZE := Color("a9875a")
## [scene, the dialog's PanelContainer, its title Label (relative to the panel)].
const TARGETS := [
	["res://scenes/camp.tscn", "OfflineReport/Center/Panel", "Column/OfflineTitle"],
	["res://scenes/settings_panel.tscn", ".", "Column/Title"],
	["res://scenes/recruit.tscn", "RatesOverlay/Center/Panel", "Column/Title"],
	["res://scenes/recruit.tscn", "ShopOverlay/Center/Panel", "Column/Title"],
	["res://scenes/recruit.tscn", "ResultsOverlay/Center/Panel", "Column/ResultsTitle"],
	["res://scenes/store.tscn", "AdOverlay/Center/Panel", "Column/AdTitle"],
	["res://scenes/hud.tscn", "Root/Result/Center/Panel", "PanelBox/ResultTitle"],
	["res://scenes/hud.tscn", "Root/PauseMenu/Center/PausePanel", "Column/Title"],
]


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var ok: bool = SceneBuilder.save_scene(_rule(), RULE, {"overwrite": true}).ok
	var by_scene: Dictionary = {}
	for t: Array in TARGETS:
		by_scene[t[0]] = by_scene.get(t[0], []) + [t]
	for path: String in by_scene:
		var opened: Dictionary = SceneBuilder.open_scene(path)
		var root: Node = opened.root
		var refs: Array = opened.refs
		if not refs.has(RULE):
			refs.append(RULE)
		for t: Array in by_scene[path]:
			var panel: PanelContainer = root.get_node(t[1])
			panel.theme_type_variation = &"Dialog"
			var title: Node = panel.get_node(t[2])
			var column: Node = title.get_parent()
			var old: Node = column.get_node_or_null(^"Rule")
			if old != null and old.scene_file_path == RULE:
				continue
			# Replaces a plain Rule in its place, or goes right under the title.
			SceneBuilder.put(column, SceneBuilder.instance(RULE), "Rule", -1 if old != null else title.get_index() + 1)
		ok = ok and SceneBuilder.save_scene(root, path, {"overwrite": true, "expected_refs": refs}).ok
	quit(0 if ok else 1)


## A bronze line either side of a diamond, for under a dialog title.
func _rule() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "OrnamentRule"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for key: String in ["Left", "Diamond", "Right"]:
		if key == "Diamond":
			var diamond := TextureRect.new()
			diamond.texture = load(DIAMOND)
			diamond.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			diamond.mouse_filter = Control.MOUSE_FILTER_IGNORE
			SceneBuilder.add(row, diamond, key)
		else:
			var line := ColorRect.new()
			line.color = BRONZE
			line.custom_minimum_size = Vector2(0, 2)
			line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			SceneBuilder.add(row, line, key)
	return row

