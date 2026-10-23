extends SceneTree
## Reworks the push's 結算 panel in scenes/hud.tscn so it fits a 16:9 phone: what the push paid becomes a list of
## reward_row.tscn lines in two columns (RewardGrid, under the 獲得 heading that the Rewards label turns into) instead
## of one long line that pushed the panel wider than the screen, and 再來一場, 前往養成 and 回營地 share one row
## (MoreButtons) under 挑戰下一關. Loads the scene and changes only that panel; idempotent. Applied 2026-10-22; run it
## again after build_hud / build_report / build_growth rebuild hud.tscn (then tools/style_dialogs.gd).
##   godot --headless --path prototypes/hero-horde-idle --script res://tools/restyle_result.gd

const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")
const HUD := "res://scenes/hud.tscn"
const BOX := "Root/Result/Center/Panel/PanelBox"


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var opened: Dictionary = SceneBuilder.open_scene(HUD)
	var root: Node = opened.root
	var refs: Array = opened.refs
	var box: VBoxContainer = root.get_node(BOX)
	(root.get_node("Root/Result/Center/Panel") as Control).custom_minimum_size = Vector2(640, 0)
	box.add_theme_constant_override(&"separation", 12)
	var rewards: Label = box.get_node(^"Rewards")
	rewards.text = "獲得"
	rewards.theme_type_variation = &"Dim"
	rewards.remove_theme_color_override(&"font_color")
	rewards.add_theme_font_size_override(&"font_size", 22)
	rewards.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if box.get_node_or_null(^"RewardGrid") == null:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override(&"h_separation", 12)
		grid.add_theme_constant_override(&"v_separation", 4)
		SceneBuilder.add(box, SceneBuilder.unique(grid), "RewardGrid")
		box.move_child(grid, rewards.get_index() + 1)
		for k: int in 2:
			var preview: Control = SceneBuilder.instance("res://scenes/reward_row.tscn")
			preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			SceneBuilder.add(grid, preview, "Preview_%d" % k)
		if not refs.has("res://scenes/reward_row.tscn"):
			refs.append("res://scenes/reward_row.tscn")
	if box.get_node_or_null(^"MoreButtons") == null:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 10)
		SceneBuilder.add(box, row, "MoreButtons")
		for key: String in ["Retry", "GoGrow", "ResultCamp"]:
			var button: Button = box.get_node(key)
			box.remove_child(button)
			row.add_child(button)
			button.custom_minimum_size = Vector2(0, 80)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.add_theme_font_size_override(&"font_size", 26)
			if key == "ResultCamp":
				button.theme_type_variation = &""
	var ok: bool = SceneBuilder.save_scene(root, HUD, {"overwrite": true, "expected_refs": refs}).ok
	quit(0 if ok else 1)
