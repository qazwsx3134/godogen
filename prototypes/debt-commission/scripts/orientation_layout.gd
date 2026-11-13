extends RefCounted
## Portrait overrides kept in the scene itself: a node's `metadata/portrait_layout` is a Dictionary of
## the properties it takes in portrait (anchors, offsets, custom_minimum_size, visible, columns ...).
## The scene's own values are the landscape layout; they are remembered the first time portrait is
## applied and put back when a landscape story loads.

const KEY: StringName = &"portrait_layout"
const SAVED: StringName = &"_landscape_layout"


static func apply_tree(root: Node, portrait: bool) -> void:
	apply(root, portrait)
	for node: Node in root.find_children("*", "", true, false):
		apply(node, portrait)


static func apply(node: Node, portrait: bool) -> void:
	if not node.has_meta(KEY):
		return
	var wanted: Dictionary = node.get_meta(KEY) as Dictionary
	if not node.has_meta(SAVED):
		if not portrait:
			return  # still as authored
		var saved: Dictionary = {}
		for key: Variant in wanted.keys():
			saved[key] = node.get(StringName(key))
		node.set_meta(SAVED, saved)
	var values: Dictionary = wanted if portrait else node.get_meta(SAVED) as Dictionary
	for key: Variant in values.keys():
		node.set(StringName(key), values[key])
