extends Node3D

signal inventory_changed
signal ore_delivered
signal ore_crushed(hardness: int, mineral: int)

const Inventory := preload("res://quarry_inventory.gd")
const Excavation := preload("res://excavation.gd")
const Debris := preload("res://excavation_debris.gd")
const StockPile := preload("res://stock_pile.gd")
const FLIGHT_SPEED := 11.0
const SEARCH_DELAY := 0.45
const CRUSH_DELAY := 3.0

@onready var collector: Node3D = %WorkshopRobot
@onready var crusher: Node3D = %OreCrusher
@onready var collector_status: Label3D = collector.get_node("Status")
@onready var crusher_status: Label3D = crusher.get_node("Status")
@onready var collector_load: Node3D = collector.get_node("CarriedOre")
@onready var crusher_load: Node3D = crusher.get_node("CarriedOre")
@onready var press_head: Node3D = crusher.get_node("PressHead")
@onready var press_rest := press_head.position.y
@onready var press_sound: AudioStreamPlayer3D = crusher.get_node("PressSound")
@onready var dock := collector.global_position
@onready var carry_offset := collector_load.position

var inventory: Inventory
var excavation: Excavation
var stock_pile: StockPile
var collector_enabled := false
var crusher_enabled := false
var crusher_level := 0
var collector_busy := false
var crusher_busy := false
var search_in := 0.0
var crush_in := 0.0


func _physics_process(delta: float) -> void:
	if inventory == null:
		return
	if collector_enabled and not collector_busy:
		search_in -= delta
		if search_in <= 0.0:
			search_in = SEARCH_DELAY
			_find_ore()
	if crusher_enabled and not crusher_busy:
		crush_in -= delta
		if crush_in <= 0.0:
			crush_in = SEARCH_DELAY
			_start_crush()


func enable_collector(enabled: bool) -> void:
	collector_enabled = enabled
	if not collector_busy:
		collector_status.text = "拾運待命" if enabled else "拾運暫停"


func enable_crusher(enabled: bool) -> void:
	crusher_enabled = enabled
	if not crusher_busy:
		crusher_status.text = "破石待命" if enabled else "破石暫停"


func unlock_crusher(level: int) -> void:
	crusher_level = level
	crusher.show()
	crusher.get_node("CollisionShape3D").set_deferred("disabled", false)
	if level == 1:
		enable_crusher(true)


func _find_ore() -> void:
	if not inventory.has_storage_room():
		collector_status.text = "料斗已滿"
		return
	var nearest := INF
	var target: Debris
	var landing := Vector3.ZERO
	var lane := 0.0
	for piece in excavation.loose:
		if piece.rare or not piece.usable():
			continue
		var distance := dock.distance_squared_to(piece.global_position)
		if distance >= nearest:
			continue
		var pickup := piece.global_position + Vector3.UP * 0.70
		var altitude := _clear_lane(pickup)
		if altitude >= 0.0:
			target = piece
			landing = pickup
			lane = altitude
			nearest = distance
	if target == null:
		collector_status.text = "等待散落原石"
		return
	collector_busy = true
	collector_status.text = "前往拾取"
	var flight := create_tween()
	_add_leg(flight, dock, _at_height(dock, lane))
	_add_leg(flight, _at_height(dock, lane), _at_height(landing, lane))
	_add_leg(flight, _at_height(landing, lane), landing)
	flight.tween_callback(_pick_up.bind(weakref(target), landing, lane))


func _clear_lane(pickup: Vector3) -> float:
	var base := maxf(pickup.y + 1.0, dock.y + 1.0)
	for height in [base, base + 3.0, base + 8.0]:
		var above_ore := _at_height(pickup, height)
		var above_dock := _at_height(dock, height)
		if _clear(pickup, above_ore) and _clear(dock, above_dock) and _clear(above_dock, above_ore):
			return height
	return -1.0


func _clear(from: Vector3, to: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(from, to, 4)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func _at_height(point: Vector3, height: float) -> Vector3:
	return Vector3(point.x, height, point.z)


func _add_leg(flight: Tween, from: Vector3, to: Vector3) -> void:
	flight.tween_property(collector, "global_position", to, maxf(0.06, from.distance_to(to) / FLIGHT_SPEED))


func _pick_up(target_ref: WeakRef, landing: Vector3, lane: float) -> void:
	var piece := target_ref.get_ref() as Debris
	var loaded := piece != null and not piece.rare and piece.usable() and landing.distance_squared_to(piece.global_position) < 1.4
	loaded = loaded and inventory.reserve_storage_slot()
	var flight := create_tween()
	if loaded:
		collector_load.global_position = piece.global_position
		excavation.retire(piece)
		collector_load.show()
		flight.tween_property(collector_load, "position", carry_offset, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	collector_status.text = "運回料斗" if loaded else "返回工坊"
	_add_leg(flight, landing, _at_height(landing, lane))
	_add_leg(flight, _at_height(landing, lane), _at_height(dock, lane))
	_add_leg(flight, _at_height(dock, lane), dock)
	flight.tween_callback(_arrive.bind(loaded))


func _arrive(loaded: bool) -> void:
	if loaded:
		inventory.deliver_reserved_ore()
		stock_pile.set_count(inventory.storage.size(), collector_load.global_position)
		# Give the ore time to reach the pile before a waiting crusher starts the next order.
		crush_in = maxf(crush_in, 0.37)
		collector_load.hide()
		inventory_changed.emit()
		ore_delivered.emit()
	collector_busy = false
	enable_collector(collector_enabled)


func _start_crush() -> void:
	var id := inventory.take_stored(crusher_level)
	if id < 0:
		crusher_status.text = "等候原石" if inventory.storage.is_empty() else "原石太硬"
		return
	var hardness := inventory.stone_hardness(id)
	var mineral := inventory.take_known_mineral(id)
	crusher_busy = true
	crusher_status.text = "加工中 %d" % hardness
	crusher_load.show()
	inventory_changed.emit()
	var work := create_tween()
	for strike in hardness + 1:
		work.tween_property(press_head, "position:y", press_rest - 0.22 - strike * 0.03, 0.13).set_ease(Tween.EASE_IN)
		work.tween_callback(press_sound.play)
		work.tween_property(crusher_load, "scale:y", maxf(0.34, 0.86 - strike * 0.14), 0.10)
		work.parallel().tween_property(press_head, "position:y", press_rest, 0.18).set_ease(Tween.EASE_OUT)
	work.tween_callback(_finish_crush.bind(hardness, mineral))


func _finish_crush(hardness: int, mineral: int) -> void:
	crusher_load.hide()
	crusher_load.scale = Vector3.ONE
	crusher_busy = false
	crush_in = CRUSH_DELAY
	enable_crusher(crusher_enabled)
	ore_crushed.emit(hardness, mineral)
