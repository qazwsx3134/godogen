extends Node3D
## Wires the field: clicks pick a monster (nearest on screen) or a ground point, the HUD follows the player.

@export var pick_radius_px: float = 70.0

@onready var player: Node3D = %Player
@onready var rig: Node3D = %CameraRig
@onready var hud: CanvasLayer = %HUD
@onready var meadow: Node3D = %Meadow
@onready var click_marker: MeshInstance3D = %ClickMarker

var _holding: bool = false
var _repeat: float = 0.0
var _marker_left: float = 0.0


func _ready() -> void:
	var blockers: Array[Vector3] = meadow.blockers()
	player.blockers = blockers
	for m: Node3D in get_tree().get_nodes_in_group("monster"):
		m.blockers = blockers
	hud.bind(player)
	click_marker.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_holding = event.pressed
		if event.pressed:
			_click(event.position, true)
	elif event.is_action_pressed("attack"):
		player.attack_nearest()
	elif event.is_action_pressed("toggle_time"):
		meadow.toggle_time()


func _process(delta: float) -> void:
	player.cam_yaw = rig.yaw
	for m: Node3D in get_tree().get_nodes_in_group("monster"):
		m.actor.targeted = m == player.target
	if _holding and player.target == null:  # hold the button to keep walking toward the cursor
		_repeat -= delta
		if _repeat <= 0.0:
			_repeat = 0.12
			_click(get_viewport().get_mouse_position(), false)
	_marker_left = maxf(0.0, _marker_left - delta)
	click_marker.visible = _marker_left > 0.0
	click_marker.scale = Vector3.ONE * (0.6 + _marker_left)
	click_marker.rotate_y(delta * 3.0)


func _click(screen: Vector2, allow_monster: bool) -> void:
	var cam: Camera3D = rig.camera
	if allow_monster:
		var best: Node3D = null
		var best_d := pick_radius_px
		for m: Node3D in get_tree().get_nodes_in_group("monster"):
			var p: Vector3 = m.global_position + Vector3.UP * m.actor.head_height * 0.5
			if not m.is_alive() or cam.is_position_behind(p):
				continue
			var d := cam.unproject_position(p).distance_to(screen)
			if d < best_d:
				best = m
				best_d = d
		if best != null:
			player.set_target(best)
			return
	var from := cam.project_ray_origin(screen)
	var query := PhysicsRayQueryParameters3D.create(from, from + cam.project_ray_normal(screen) * 400.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	player.move_to(hit.position)
	if allow_monster:
		click_marker.global_position = hit.position + Vector3.UP * 0.05
		_marker_left = 0.5
