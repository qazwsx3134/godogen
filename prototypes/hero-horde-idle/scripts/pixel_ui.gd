extends RefCounted
## Even-width pixels for the UI's pixel art on any phone (shaders/pixel_sharp.gdshader). App calls apply() for every
## node that enters the tree, so every screen gets it without each scene carrying the material: buttons and panels
## (their 9-slice frames, assets/ui/frame) and texture rects (icons, backgrounds). A node with its own material
## keeps it; scripts that swap an icon's material (hero portraits) put material() back for a plain icon. The editor
## and tests without the App draw plain nearest, which looks the same at whole-number scales.

const MATERIAL: ShaderMaterial = preload("res://ui/pixel_sharp.tres")


static func material() -> ShaderMaterial:
	return MATERIAL


## Screens drawn as authored, nearest-filtered (the home screen's Taskbar Hero pages, whose panels are 9-slices of
## the reference art with the centre left out) put their root in this group; nothing under it gets the material.
const PLAIN := &"plain_pixels"


static func _plain(node: Node) -> bool:
	var n: Node = node
	while n != null:
		if n.is_in_group(PLAIN):
			return true
		n = n.get_parent()
	return false


static func apply(node: Node) -> void:
	if not (node is Button or node is PanelContainer or node is Panel or node is TextureRect or node is TextureButton
			or node is NinePatchRect):
		return
	var item := node as CanvasItem
	if _plain(node):
		return
	if item.material == null and not item.use_parent_material:
		item.material = material()
