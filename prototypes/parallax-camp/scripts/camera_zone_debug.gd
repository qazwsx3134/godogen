extends Node2D

const CameraRig = preload("res://scripts/camera_rig.gd")
const CameraZone = preload("res://scripts/camera_zone.gd")

var rig: CameraRig
var zones: Array[CameraZone] = []


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if not is_instance_valid(rig):
		return
	for zone: CameraZone in zones:
		var rect := zone.debug_rect()
		var highlight := zone == rig.active_zone
		var line := Color("#ffce79") if highlight else Color("#78d1e5")
		draw_rect(rect, Color(line, 0.12 if highlight else 0.06))
		draw_rect(rect, line, false, 1.0)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(7, 16),
			"%s  [%d]" % [zone.name, zone.zone_priority], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, line)
	var half_size := Vector2(rig.dead_zone_x, rig.vertical_dead_zone)
	draw_rect(Rect2(rig.tracked_position - half_size, half_size * 2.0), Color("#c0fa97"), false, 1.0)
	draw_circle(rig.tracked_position, 2.0, Color("#c0fa97"))
