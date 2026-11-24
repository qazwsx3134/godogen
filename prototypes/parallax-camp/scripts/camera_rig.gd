extends Node2D

const CameraZone = preload("res://scripts/camera_zone.gd")

signal active_zone_changed(zone: CameraZone)

@export_group("Follow")
@export var framing_offset := Vector2(0, -50)
@export_range(0.1, 30.0, 0.1) var follow_speed := 6.0
@export_range(0, 120, 1) var dead_zone_x := 44.0
@export_range(0, 130, 1) var vertical_dead_zone := 90.0
@export_range(0.1, 30.0, 0.1) var ground_recenter_speed := 3.2
@export var limits := Rect2(0, -80, 2400, 400)

@export_group("Look ahead")
@export_range(0, 220, 1) var look_ahead_distance := 110.0
@export_range(0.1, 20.0, 0.1) var look_ahead_speed := 2.2
@export_range(0, 220, 1) var look_ahead_commit_speed := 26.0
@export_range(0, 130, 1) var fall_look_distance := 58.0
@export_range(1, 1000, 1) var fall_speed_reference := 450.0

@export_group("Impact")
@export var landing_threshold := 270.0
@export var landing_ceiling := 490.0
@export var land_offset := 5.0
@export var land_shake := 3.0

@onready var camera: Camera2D = %Camera

var target: CharacterBody2D
var tracked_position := Vector2.ZERO
var active_zone: CameraZone

var _zones: Array[CameraZone] = []
var _look_ahead := 0.0
var _fall_percentage := 0.0
var _locked_x := 0.0
var _punch := Vector2.ZERO
var _shake_dir := Vector2.ZERO
var _shake_strength := 0.0
var _shake_duration := 0.0
var _shake_elapsed := 0.0
var _shake_frequency := 0.0


func _ready() -> void:
	add_to_group(&"camera_rig")
	camera.position_smoothing_enabled = false
	camera.drag_horizontal_enabled = false
	camera.drag_vertical_enabled = false


func follow(body: CharacterBody2D) -> void:
	target = body
	reset_to_target()


func reset_to_target() -> void:
	tracked_position = target.global_position
	_look_ahead = 0.0
	_fall_percentage = 0.0
	_punch = Vector2.ZERO
	_shake_elapsed = _shake_duration
	camera.offset = Vector2.ZERO
	camera.zoom = Vector2.ONE * _zone_zoom()
	global_position = _clamp_center(tracked_position + framing_offset)
	camera.force_update_scroll()


func _process(delta: float) -> void:
	if is_instance_valid(target):
		update_framing(delta)


func update_framing(delta: float) -> void:
	var player_position := target.global_position
	var velocity := target.get_real_velocity()
	var on_floor := target.is_on_floor()
	_update_tracked(player_position, on_floor, delta)

	var lead_distance := look_ahead_distance
	var speed := follow_speed
	var desired := tracked_position + framing_offset
	if active_zone:
		if active_zone.override_look_ahead:
			lead_distance = active_zone.look_ahead_distance
		if active_zone.override_follow_speed:
			speed = active_zone.follow_speed
		desired.y += active_zone.vertical_bias

	var x_from_anchor := player_position.x - tracked_position.x
	var pushing_edge := absf(x_from_anchor) >= dead_zone_x - 0.01 and x_from_anchor * velocity.x >= 0.0
	var lead_goal := 0.0
	if pushing_edge and absf(velocity.x) > look_ahead_commit_speed:
		lead_goal = signf(velocity.x) * lead_distance
	_look_ahead = lerpf(_look_ahead, lead_goal, _weight(look_ahead_speed, delta))

	var fall_goal := 0.0
	if not on_floor and player_position.y > tracked_position.y + 4.0:
		fall_goal = clampf(velocity.y / fall_speed_reference, 0.0, 1.0)
	_fall_percentage = lerpf(_fall_percentage, fall_goal, _weight(6.0, delta))
	desired += Vector2(_look_ahead, _fall_percentage * fall_look_distance)

	if active_zone:
		if active_zone.use_fixed_target and is_instance_valid(active_zone.fixed_target):
			desired = active_zone.fixed_target.global_position + Vector2(0, active_zone.vertical_bias)
		if active_zone.lock_horizontal:
			desired.x = _locked_x

	var weight := _weight(speed, delta)
	camera.zoom = camera.zoom.lerp(Vector2.ONE * _zone_zoom(), weight)
	global_position = _clamp_center(global_position.lerp(_clamp_center(desired), weight))
	_update_effects(delta)
	camera.force_update_scroll()


func _update_tracked(at: Vector2, on_floor: bool, delta: float) -> void:
	tracked_position.x = clampf(tracked_position.x, at.x - dead_zone_x, at.x + dead_zone_x)
	tracked_position.y = clampf(tracked_position.y, at.y - vertical_dead_zone, at.y + vertical_dead_zone)
	if on_floor:
		tracked_position.y = lerpf(tracked_position.y, at.y, _weight(ground_recenter_speed, delta))


func _weight(speed: float, delta: float) -> float:
	return 1.0 - exp(-speed * delta)


func _zone_zoom() -> float:
	return active_zone.zoom if active_zone and active_zone.override_zoom else 1.0


func _clamp_center(center: Vector2) -> Vector2:
	var half_view := get_viewport_rect().size / (2.0 * camera.zoom)
	if active_zone and active_zone.override_limits:
		center = _clamp_to_rect(center, active_zone.limits, half_view)
	return _clamp_to_rect(center, limits, half_view)


func _clamp_to_rect(center: Vector2, bounds: Rect2, half_view: Vector2) -> Vector2:
	# A room smaller than the viewport stays centered on that axis.
	var min_center := (bounds.position + half_view).min(bounds.get_center())
	var max_center := (bounds.end - half_view).max(bounds.get_center())
	return center.clamp(min_center, max_center)


func push_zone(zone: CameraZone) -> void:
	if not _zones.has(zone):
		_zones.append(zone)
		_update_active_zone()


func pop_zone(zone: CameraZone) -> void:
	_zones.erase(zone)
	_update_active_zone()


func _update_active_zone() -> void:
	var highest: CameraZone
	# Ties use the most recently entered zone.
	for zone: CameraZone in _zones:
		if highest == null or zone.zone_priority >= highest.zone_priority:
			highest = zone
	if highest != active_zone:
		active_zone = highest
		_locked_x = global_position.x
		active_zone_changed.emit(active_zone)


func on_landed(impact_speed: float) -> void:
	var strength := clampf(inverse_lerp(landing_threshold, maxf(landing_ceiling, landing_threshold + 1.0), impact_speed), 0.0, 1.0)
	if strength > 0.0:
		punch(Vector2.DOWN * land_offset * strength)
		shake(Vector2.DOWN, land_shake * strength, 0.18, 20.0)


func play_recoil(direction: float) -> void:
	shake(Vector2.LEFT * signf(direction), 3.0, 0.13, 26.0)


func punch(amount: Vector2) -> void:
	_punch += amount


func shake(direction: Vector2, strength: float, duration: float, frequency: float) -> void:
	_shake_dir = direction.normalized()
	_shake_strength = strength
	_shake_duration = duration
	_shake_elapsed = 0.0
	_shake_frequency = frequency


func _update_effects(delta: float) -> void:
	var shake_offset := Vector2.ZERO
	if _shake_elapsed < _shake_duration:
		_shake_elapsed += delta
		var falloff := maxf(0.0, 1.0 - _shake_elapsed / _shake_duration)
		var wave := sin(_shake_elapsed * _shake_frequency * TAU)
		shake_offset = _shake_dir * wave * _shake_strength * falloff
	_punch = _punch.lerp(Vector2.ZERO, _weight(10.0, delta))
	camera.offset = _clamp_center(global_position + shake_offset + _punch) - global_position
