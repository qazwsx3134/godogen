extends MeshInstance3D
## One telegraph shape on the ground (a pooled quad under main.tscn's TeleMarkers): a circle, or the band in front
## of the boss. Filled from the centre as the countdown runs; materials/ground_mark.tres is shared by every mark.

const PushSim = preload("res://domain/push_sim.gd")
const M_PER_TEXEL := 0.05
## The band reaches from its edge to just under the boss, over the whole field's depth.
const BAND_END := PushSim.BOSS_FRONT + 0.4
const BAND_Z := Vector2(PushSim.FIELD_MIN.y - 0.6, PushSim.FIELD_MAX.y + 0.6)


## `warn` is the countdown's progress 0..1.
func show_shape(shape: Dictionary, warn: float, pulse: float) -> void:
	var center: Vector2
	var size: Vector2
	if shape.kind == &"band":
		center = Vector2((shape.x + BAND_END) * 0.5, (BAND_Z.x + BAND_Z.y) * 0.5)
		size = Vector2(BAND_END - shape.x, BAND_Z.y - BAND_Z.x)
	else:
		center = shape.c
		size = Vector2.ONE * shape.r * 2.0
	visible = true
	position = Vector3(center.x, 0.03, center.y)
	scale = Vector3(size.x, 1.0, size.y)
	set_instance_shader_parameter(&"shape", 1.0 if shape.kind == &"band" else 0.0)
	set_instance_shader_parameter(&"fill", warn)
	set_instance_shader_parameter(&"pulse", pulse)
	set_instance_shader_parameter(&"texels", (size / M_PER_TEXEL).round())


func off() -> void:
	visible = false
