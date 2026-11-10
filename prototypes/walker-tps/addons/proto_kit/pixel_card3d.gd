@tool
extends MeshInstance3D
## A pixel-art card standing on the ground of an HD-2D diorama: trees, rocks, pillars, gates, banners. Sized from its
## texture at the stage's pixel density (m_per_px: the same for every card, sprite and ground texel, so all art shares
## one pixel grid), leaned back toward a fixed camera so art drawn from ~45° above is not squashed, and casting a real
## shadow from the sun with the art's outline (alpha scissor). Unshaded: the art is painted lit; `tint` grades it
## into the scene's light. The node's origin is the base of the art (it stands on y = 0).
##   extends "res://addons/proto_kit/pixel_card3d.gd"    # scripts/prop.gd, scenes/prop.tscn; repeat @tool in it
## Place instances under the stage scene and set texture / tint / flip in the inspector; it rebuilds in the editor.
## For a crowd of moving characters use sprite3d (MultiMesh) instead: one card is one draw call.

## Metres per art pixel. Keep one value per game (stage art, props, sprite cells).
@export var m_per_px: float = 0.025:
	set(value):
		m_per_px = value
		_rebuild()
@export var texture: Texture2D:
	set(value):
		texture = value
		_rebuild()
@export var tint := Color(1.0, 1.0, 1.0):
	set(value):
		tint = value
		_rebuild()
## Tilt back toward the camera (degrees), so art drawn from ~45° above is not squashed by the view.
@export_range(0.0, 40.0) var lean_deg: float = 14.0:
	set(value):
		lean_deg = value
		_rebuild()
@export var flip: bool = false:
	set(value):
		flip = value
		_rebuild()


func _ready() -> void:
	_rebuild()


## Size of the card in metres (texture size x m_per_px); zero without a texture.
func card_size() -> Vector2:
	if texture == null:
		return Vector2.ZERO
	return Vector2(texture.get_width(), texture.get_height()) * m_per_px


func _rebuild() -> void:
	if texture == null:
		mesh = null
		return
	var size := card_size()
	var quad := QuadMesh.new()
	quad.size = size
	quad.center_offset = Vector3(0.0, size.y * 0.5, 0.0)
	quad.orientation = PlaneMesh.FACE_Z
	mesh = quad
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.albedo_texture = texture
	m.albedo_color = tint
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if flip:
		m.uv1_scale = Vector3(-1.0, 1.0, 1.0)
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	rotation.x = -deg_to_rad(lean_deg)
