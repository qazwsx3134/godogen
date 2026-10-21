@tool
extends MeshInstance3D
## One stage prop (tree, rock, pillar, gate...): a pixel-art card standing on the ground, sized from its texture at
## the stage's pixel density, leaned back toward the fixed camera, casting a real shadow from the sun (alpha scissor,
## so the shadow has the art's outline). Unshaded: the art is painted lit; `tint` grades it into the dusk.
## Place, scale and tint instances of scenes/prop.tscn in stage.tscn's Props; the origin is the base of the art.

const M_PER_PX := 0.025

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


func _rebuild() -> void:
	if texture == null:
		mesh = null
		return
	var size := Vector2(texture.get_width(), texture.get_height()) * M_PER_PX
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
