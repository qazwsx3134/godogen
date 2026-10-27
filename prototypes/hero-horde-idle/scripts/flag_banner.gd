@tool
extends MeshInstance3D
## A squad's banner: a pixel-art card cut from assets/flags/<squad>.png (frames side by side, the pole's foot at the
## bottom centre of each), standing on that foot and leaned back toward the fixed camera like the stage props, casting
## a real shadow. `frame` picks the cell, so squad_flag.gd can swing the cloth.

const M_PER_PX := 0.025

@export var texture: Texture2D:
	set(value):
		texture = value
		_rebuild()
@export_range(1, 8) var frames: int = 2:
	set(value):
		frames = value
		_rebuild()
@export var frame: int = 0:
	set(value):
		frame = value
		if _material != null:
			_material.uv1_offset = Vector3(float(frame % frames) / frames, 0.0, 0.0)
## Tilt back toward the camera (degrees), so art drawn from ~45° above is not squashed by the view.
@export_range(0.0, 40.0) var lean_deg: float = 14.0:
	set(value):
		lean_deg = value
		_rebuild()

var _material: StandardMaterial3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if texture == null:
		mesh = null
		return
	var size := Vector2(texture.get_width() / float(frames), texture.get_height()) * M_PER_PX
	var quad := QuadMesh.new()
	quad.size = size
	quad.center_offset = Vector3(0.0, size.y * 0.5, 0.0)
	mesh = quad
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_material.alpha_scissor_threshold = 0.5
	_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_material.albedo_texture = texture
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.uv1_scale = Vector3(1.0 / frames, 1.0, 1.0)
	_material.uv1_offset = Vector3(float(frame % frames) / frames, 0.0, 0.0)
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	rotation.x = -deg_to_rad(lean_deg)
