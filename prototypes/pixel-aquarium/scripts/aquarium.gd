extends Control

const Fish = preload("res://scripts/fish.gd")
const MIN_ZOOM := 0.82
const MAX_ZOOM := 2.0
const ZOOM_STEP := 1.17
const DEFAULT_ASPECT := 16.0 / 9.0
const MIN_FRAME_ASPECT := 0.75
const PICKABLE_LAYERS := 3
const DRAG_THRESHOLD := 8.0

@onready var _tank: SubViewport = %TankView
@onready var _camera: Camera3D = _tank.get_node("Tank/ViewingCamera")
@onready var _panel: PanelContainer = %FishPanel
@onready var _fish_name: Label = %FishName
@onready var _traits: Label = %Traits
@onready var _marker: Control = %SelectionMarker
@onready var _stored_menu: MenuButton = %StoredFish
@onready var _zoom_out: Button = %ZoomOut
@onready var _zoom_reset: Button = %ZoomReset
@onready var _zoom_in: Button = %ZoomIn

var _zoom := 1.0
var _base_fov: float
var _pan := Vector2.ZERO
var _water_down := false
var _dragging := false
var _touch_index := -1
var _water_start := Vector2.ZERO
var _pan_start := Vector2.ZERO
var _pending_pick := Vector2(-1.0, -1.0)
var _selected: Fish
var _stored: Array[Fish] = []


func _ready() -> void:
	get_window().min_size = Vector2i(360, 360)
	_base_fov = _camera.fov
	resized.connect(_fit_tank)
	%CloseFish.pressed.connect(_select.bind(null))
	%StoreFish.pressed.connect(_store_selected)
	_stored_menu.get_popup().id_pressed.connect(_restore)
	_zoom_out.pressed.connect(_step_zoom.bind(-1))
	_zoom_reset.pressed.connect(_reset_view)
	_zoom_in.pressed.connect(_step_zoom.bind(1))
	_fit_tank()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenDrag and event.index == _touch_index:
		_move_water_pointer((make_input_local(event) as InputEventScreenDrag).position)
	elif event is InputEventMouseMotion and _touch_index == -1:
		_move_water_pointer((make_input_local(event) as InputEventMouseMotion).position)
	elif event is InputEventScreenTouch and event.index == _touch_index and not event.pressed:
		if event.canceled or _dragging:
			_end_drag()
		else:
			_end_water_pointer((make_input_local(event) as InputEventScreenTouch).position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and _touch_index == -1:
		if event.pressed:
			_water_down = false
		elif _dragging:
			_end_drag()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _panel.visible:
		_select(null)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
			_begin_water_pointer((make_input_local(event) as InputEventScreenTouch).position)
		else:
			return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and _touch_index == -1:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				var point := (make_input_local(event) as InputEventMouseButton).position
				if event.pressed:
					_begin_water_pointer(point)
				else:
					_end_water_pointer(point)
			MOUSE_BUTTON_WHEEL_UP:
				_step_zoom(1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_step_zoom(-1)
			_:
				return
		get_viewport().set_input_as_handled()


func _begin_water_pointer(point: Vector2) -> void:
	_water_down = true
	_dragging = false
	_water_start = point
	_pan_start = _pan


func _move_water_pointer(point: Vector2) -> void:
	if not _water_down:
		return
	var delta := point - _water_start
	if not _dragging and delta.length_squared() < DRAG_THRESHOLD * DRAG_THRESHOLD:
		return
	_dragging = true
	if _zoom > 1.0 or size.aspect() < MIN_FRAME_ASPECT:
		var depth := _camera.position.length()
		var units_per_pixel := 2.0 * depth * tan(deg_to_rad(_camera.fov * 0.5)) / maxf(size.y, 1.0)
		_pan = _pan_start + Vector2(-delta.x, delta.y) * units_per_pixel
		_apply_pan()
	get_viewport().set_input_as_handled()


func _end_drag() -> void:
	_water_down = false
	_dragging = false
	_touch_index = -1
	get_viewport().set_input_as_handled()


func _end_water_pointer(point: Vector2) -> void:
	var tapped := _water_down and not _dragging and point.distance_to(_water_start) < DRAG_THRESHOLD
	_end_drag()
	if tapped:
		_tap_water(point)


func _tap_water(point: Vector2) -> void:
	_pending_pick = point


func _physics_process(_delta: float) -> void:
	if _pending_pick.x < 0.0:
		return
	var point := _pending_pick * Vector2(_tank.size) / size
	_pending_pick = Vector2(-1.0, -1.0)
	var origin := _camera.project_ray_origin(point)
	var end := origin + _camera.project_ray_normal(point) * _camera.far
	var query := PhysicsRayQueryParameters3D.create(origin, end, PICKABLE_LAYERS)
	query.collide_with_areas = true
	var hit := _camera.get_world_3d().direct_space_state.intersect_ray(query)
	var area := hit.get("collider") as Area3D
	var fish: Fish = area.owner as Fish if area else null
	_select(fish if fish and fish.visible else null)


func _process(_delta: float) -> void:
	if not is_instance_valid(_selected):
		_marker.hide()
		return
	var anchor := _selected.global_position + Vector3.DOWN * _selected.marker_drop
	var point := _camera.unproject_position(anchor) * size / Vector2(_tank.size)
	_marker.position = point.round() - Vector2(_marker.size.x * 0.5, 0.0)
	_marker.visible = Rect2(Vector2.ZERO, size).has_point(point)


func _fit_tank() -> void:
	# Keep one low-resolution render pixel per canvas unit at normal window sizes.
	var render_scale := minf(1.0, 1024.0 / maxf(size.x, size.y))
	_tank.size = Vector2i((size * render_scale).round()).max(Vector2i(2, 2))
	_set_zoom(_zoom)


func _step_zoom(direction: int) -> void:
	_set_zoom(_zoom * pow(ZOOM_STEP, direction))


func _reset_view() -> void:
	_pan = Vector2.ZERO
	_set_zoom(1.0)


func _set_zoom(amount: float) -> void:
	_zoom = clampf(amount, MIN_ZOOM, MAX_ZOOM)
	var aspect := float(_tank.size.x) / _tank.size.y
	var fit := clampf(aspect, MIN_FRAME_ASPECT, DEFAULT_ASPECT) / DEFAULT_ASPECT
	var half_angle := tan(deg_to_rad(_base_fov * 0.5)) / (_zoom * fit)
	_camera.fov = rad_to_deg(atan(half_angle)) * 2.0
	_apply_pan()
	_zoom_reset.text = "%d%%" % roundi(_zoom * 100.0)
	_zoom_out.disabled = is_equal_approx(_zoom, MIN_ZOOM)
	_zoom_in.disabled = is_equal_approx(_zoom, MAX_ZOOM)


func _apply_pan() -> void:
	var depth := _camera.position.length()
	var half_height := depth * tan(deg_to_rad(_base_fov * 0.5))
	var visible_half_width := depth * tan(deg_to_rad(_camera.fov * 0.5)) * size.aspect()
	var limits := Vector2(
		maxf(0.0, half_height * maxf(DEFAULT_ASPECT, size.aspect()) - visible_half_width),
		half_height * maxf(0.0, 1.0 - 1.0 / _zoom))
	_pan = _pan.clamp(-limits, limits)
	_camera.h_offset = _pan.x
	_camera.v_offset = _pan.y


func _select(fish: Fish) -> void:
	_selected = fish
	_panel.visible = is_instance_valid(fish)
	if not _panel.visible:
		_marker.hide()
		return
	_fish_name.text = fish.display_name()
	_traits.text = fish.display_traits()


func _store_selected() -> void:
	if not is_instance_valid(_selected):
		return
	_stored.append(_selected)
	_selected.set_in_tank(false)
	_select(null)
	_refresh_storage()


func _restore(index: int) -> void:
	var fish := _stored[index]
	_stored.remove_at(index)
	fish.set_in_tank(true)
	_refresh_storage()
	_select(fish)


func _refresh_storage() -> void:
	var popup := _stored_menu.get_popup()
	popup.clear()
	for index in _stored.size():
		popup.add_item("放回 %s" % _stored[index].display_name(), index)
	_stored_menu.visible = not _stored.is_empty()
	_stored_menu.text = "收起的魚 (%d)" % _stored.size()
