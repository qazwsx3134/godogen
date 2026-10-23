extends SceneTree
## One-off authoring tool: the game has one UI look, so the style switches go — the title's hidden
## style buttons, 目錄's A–D rows and 設定's 介面風格 row. After it runs the scenes are the source.
##   godot --headless --path . --script res://tools/remove_style_switches.gd

const REMOVALS: Dictionary = {
	"res://scenes/ui/title_screen_gintama.tscn": ["StylesGap", "Styles"],
	"res://scenes/ui/menu_panel_gintama.tscn": ["Styles"],
	"res://scenes/ui/settings_panel_gintama.tscn": ["UiStyleRule", "UiStyleLabel", "UiStyle"],
}


func _init() -> void:
	for path: String in REMOVALS:
		if not _remove(path, REMOVALS[path]):
			quit(1)
			return
	quit()


func _remove(path: String, names: Array) -> bool:
	var root: Node = (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var before: int = _count(root)
	var removed: int = 0
	for node_name: String in names:
		var node: Node = root.find_child(node_name, true, false)
		if node == null:
			continue
		removed += _count(node)
		node.get_parent().remove_child(node)
		node.free()
	if removed == 0:
		print("%s has no style switches" % path)
		root.free()
		return true
	var packed: PackedScene = PackedScene.new()
	if packed.pack(root) != OK:
		push_error("pack " + path)
		return false
	var check: Node = packed.instantiate()
	var after: int = _count(check)
	check.free()
	root.free()
	if after != before - removed:
		push_error("%s: node count %d -> %d, expected -%d" % [path, before, after, removed])
		return false
	if ResourceSaver.save(packed, path) != OK:
		push_error("save " + path)
		return false
	print("%s: %d -> %d nodes" % [path, before, after])
	return true


func _count(node: Node) -> int:
	var total: int = 1
	for child: Node in node.get_children():
		total += _count(child)
	return total
