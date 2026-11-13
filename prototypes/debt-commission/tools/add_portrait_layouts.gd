extends SceneTree
## One-off authoring tool: writes `metadata/portrait_layout` (scripts/orientation_layout.gd) on the nodes whose
## landscape anchors do not fit a 1080×1920 portrait canvas. Saved scenes are the source afterwards; edit the
## metadata in the Inspector. Re-running only replaces the listed nodes' portrait_layout.
##   godot --headless --path . --script res://tools/add_portrait_layouts.gd

const LAYOUTS: Dictionary = {
	"res://scenes/stage.tscn": {
		# Three slots across the narrow stage; feet behind the reading box as in landscape.
		"StageArea/left": {"anchor_left": 0.2, "anchor_right": 0.2, "anchor_top": 0.3, "anchor_bottom": 0.88,
			"offset_top": 0.0, "offset_bottom": 0.0},
		"StageArea/center": {"anchor_left": 0.5, "anchor_right": 0.5, "anchor_top": 0.3, "anchor_bottom": 0.88,
			"offset_top": 0.0, "offset_bottom": 0.0},
		"StageArea/right": {"anchor_left": 0.8, "anchor_right": 0.8, "anchor_top": 0.3, "anchor_bottom": 0.88,
			"offset_top": 0.0, "offset_bottom": 0.0},
	},
	"res://scenes/ui/title_screen_gintama.tscn": {
		# The card sits under the picture instead of beside it.
		"CardArea": {"anchor_left": 0.08, "anchor_top": 0.4, "anchor_right": 0.92, "anchor_bottom": 0.96},
	},
	"res://scenes/comedy/tsukkomi_impact.tscn": {
		# A wider picture under the burst instead of beside it.
		"CutInPanel": {"anchor_top": 0.3, "anchor_right": 0.64, "anchor_bottom": 0.76},
		"Burst": {"anchor_left": 0.3, "anchor_top": 0.07, "anchor_right": 0.99, "anchor_bottom": 0.31},
	},
	"res://scenes/comedy/tsukkomi_impact_right.tscn": {
		"CutInPanel": {"anchor_left": 0.36, "anchor_top": 0.3, "anchor_bottom": 0.76},
		"Burst": {"anchor_left": 0.01, "anchor_top": 0.07, "anchor_right": 0.7, "anchor_bottom": 0.31},
	},
	"res://scenes/ui/round_hud.tscn": {
		# Full width, below the place name.
		".": {"anchor_left": 0.01, "anchor_right": 0.99, "anchor_top": 0.03, "anchor_bottom": 0.03},
	},
}


func _initialize() -> void:
	var failed: bool = false
	for path: String in LAYOUTS.keys():
		var scene: Node = (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		var before: int = scene.find_children("*", "", true, true).size()
		var nodes: Dictionary = LAYOUTS[path]
		for node_path: String in nodes.keys():
			var node: Node = scene.get_node_or_null(node_path)
			if node == null:
				printerr("%s: no node %s" % [path, node_path])
				failed = true
				continue
			node.set_meta(&"portrait_layout", nodes[node_path])
		var packed: PackedScene = PackedScene.new()
		packed.pack(scene)
		var after: int = packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE).find_children("*", "", true, true).size()
		if after != before:
			printerr("%s: %d nodes before packing, %d after" % [path, before, after])
			failed = true
			continue
		ResourceSaver.save(packed, path)
		print("portrait layout: ", path)
		scene.free()
	quit(1 if failed else 0)
