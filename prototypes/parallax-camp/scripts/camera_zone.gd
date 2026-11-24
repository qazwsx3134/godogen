@tool
extends Area2D

@export var zone_priority := 0

@export_group("Framing")
@export var override_zoom := false
@export_range(0.8, 2.0, 0.01) var zoom := 1.0
@export var vertical_bias := 0.0
@export var override_limits := false
@export var limits := Rect2(0, -80, 2400, 400)
@export var lock_horizontal := false

@export_group("Fixed target")
@export var use_fixed_target := false
@export var fixed_target: Node2D

@export_group("Follow")
@export var override_look_ahead := false
@export_range(0, 220, 1) var look_ahead_distance := 110.0
@export var override_follow_speed := false
@export_range(0.1, 30.0, 0.1) var follow_speed := 6.0


func debug_rect() -> Rect2:
	var collider := %Bounds as CollisionShape2D
	var rectangle := collider.shape as RectangleShape2D
	return collider.global_transform * Rect2(-rectangle.size / 2.0, rectangle.size)
