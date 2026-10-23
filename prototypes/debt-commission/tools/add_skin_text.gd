extends SceneTree
## One-off authoring tool: tags the static words of the UI scenes with `skin_text` metadata (the key
## of the skin's `texts`, IMPLEMENTATION.md「外觀包」), so a skin supplies them. The scenes keep
## their base-skin words for the editor. After it runs the scenes are the source files.
##   godot --headless --path . --script res://tools/add_skin_text.gd

const TAGS: Dictionary = {
	"res://scenes/ui/title_screen_gintama.tscn": {"Logo": "title_logo", "Tagline": "tagline"},
	"res://scenes/ui/menu_panel_gintama.tscn": {"Kicker": "menu_kicker", "Area/Center/Panel/Padding/Column/Heading/HeadingText/Heading": "menu_heading"},
	"res://scenes/ui/round_hud.tscn": {"PowerCaption": "power_caption"},
	"res://scenes/ui/settings_panel_gintama.tscn": {"AssistLabel": "assist_label"},
	"res://scenes/ui/case_file_panel.tscn": {"CaseFileTab_materials": "materials_tab", "CaseFileUse": "use_material",
		"CaseFileUseHead": "use_material_head"},
	"res://scenes/ui/chapter_result_gintama.tscn": {"CaughtCaption": "result_caught", "GradeCaption": "result_grade",
		"GlassesLeftCaption": "result_life"},
	"res://scenes/ui/game_over_gintama.tscn": {"Message": "game_over_message"},
}


func _init() -> void:
	for path: String in TAGS:
		var root: Node = (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
		var before: int = _count(root)
		for node_name: String in TAGS[path]:
			# A path when the name is shared (目錄's Heading row and Heading label), else a name.
			var node: Node = root.get_node_or_null(node_name) if node_name.contains("/") else root.find_child(node_name, true, false)
			if node == null:
				push_error("%s has no %s" % [path, node_name])
				quit(1)
				return
			if not (node is Label or node is Button):
				push_error("%s: %s is a %s, not a Label or Button" % [path, node_name, node.get_class()])
				quit(1)
				return
			node.set_meta("skin_text", TAGS[path][node_name])
		var packed: PackedScene = PackedScene.new()
		if packed.pack(root) != OK:
			push_error("pack " + path)
			quit(1)
			return
		var check: Node = packed.instantiate()
		var after: int = _count(check)
		check.free()
		root.free()
		if after != before or ResourceSaver.save(packed, path) != OK:
			push_error("%s: node count %d -> %d, or save failed" % [path, before, after])
			quit(1)
			return
		print("%s: tagged %d" % [path, (TAGS[path] as Dictionary).size()])
	quit()


func _count(node: Node) -> int:
	var total: int = 1
	for child: Node in node.get_children():
		total += _count(child)
	return total
