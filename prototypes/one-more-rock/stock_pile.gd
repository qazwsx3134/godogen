extends Node3D

const ROCK := preload("res://scenes/pile_rock.tscn")
const MIDDLE_LIMIT := 64

@export var desktop_budget := 200
@export var mobile_budget := 60

@onready var middle: MultiMeshInstance3D = %Middle
@onready var bulk: Node3D = %Bulk

var near: Array[RigidBody3D] = []
var shards: Array[RigidBody3D] = []
var middle_count := 0
var visible_stock := 0
var body_budget := 200
var rng := RandomNumberGenerator.new()
var flights: Array[Vector3] = []
var landings: Array[Vector3] = []
var middle_elapsed := 0.0


func _ready() -> void:
	body_budget = desktop_budget
	rng.seed = 19841
	# Instance transforms belong to this pile. Keep the editor mesh and give each pile its own buffer.
	middle.multimesh = middle.multimesh.duplicate()
	middle.multimesh.instance_count = MIDDLE_LIMIT
	middle.multimesh.visible_instance_count = 0
	middle.hide()
	bulk.hide()


func set_mobile(enabled: bool) -> void:
	var budget := mobile_budget if enabled else desktop_budget
	if budget != body_budget:
		body_budget = budget
		set_count(visible_stock)


func set_count(count: int, pack_origin := Vector3.INF, cart_origin := Vector3.INF, cart_count := 0) -> void:
	var previous := visible_stock
	visible_stock = maxi(0, count)
	var near_count := mini(visible_stock, body_budget)
	while near_count + shards.size() > body_budget:
		var shard := shards.pop_front() as RigidBody3D
		_remove_body(shard)
	while near.size() > near_count:
		var rock := _take_top() if near.size() - near_count < 5 else near.pop_back() as RigidBody3D
		_remove_body(rock)
	if near.size() < near_count:
		for index in range(near.size(), near_count):
			var origin := cart_origin if index >= visible_stock - cart_count else pack_origin
			_add_rock(origin, index - mini(previous, near_count))
	_refresh_middle(previous, pack_origin, cart_origin, cart_count)
	var excess := maxi(0, visible_stock - near.size() - middle_count)
	bulk.visible = excess > 0
	if bulk.visible:
		bulk.scale.y = clampf(0.3 + log(1.0 + excess) * 0.23, 0.3, 2.8)


func _remove_body(rock: RigidBody3D) -> void:
	rock.hide()
	rock.freeze = true
	rock.collision_layer = 0
	rock.queue_free()


func scatter_fragments(impact: Vector3) -> void:
	for index in mini(3, body_budget - near.size() - shards.size()):
		var shard := ROCK.instantiate() as RigidBody3D
		var shape := SphereShape3D.new()
		shape.radius = 0.065
		(shard.get_node("Hull") as CollisionShape3D).shape = shape
		(shard.get_node("Shell") as Node3D).scale = Vector3.ONE * 0.53
		shard.position = to_local(impact) + Vector3(0.06 * index, 0.11, 0.15)
		shard.collision_layer = 0
		shard.collision_mask = 64
		add_child(shard)
		shard.freeze = false
		shard.linear_velocity = Vector3(rng.randf_range(0.4, 1.3), rng.randf_range(1.3, 2.2), rng.randf_range(-1.0, 1.1))
		shard.angular_velocity = Vector3(3.2, rng.randf_range(-5.0, 5.0), 2.2)
		shards.append(shard)
		var life := shard.create_tween()
		life.tween_interval(1.8)
		life.tween_callback(func():
			shards.erase(shard)
			_remove_body(shard)
		)


func _take_top() -> RigidBody3D:
	var top := near.size() - 1
	for index in near.size():
		if near[index].freeze:
			continue
		if near[top].freeze or near[index].position.y > near[top].position.y:
			top = index
	var rock := near[top]
	near.remove_at(top)
	for neighbor in near:
		if not neighbor.freeze and neighbor.position.distance_squared_to(rock.position) < 0.12:
			var kick := (neighbor.position - rock.position).normalized() * 0.024
			neighbor.apply_central_impulse(kick + Vector3.UP * 0.012)
	return rock


func _landing() -> Vector3:
	return Vector3(rng.randf_range(-0.55, 0.55), 0.26, rng.randf_range(-0.42, 0.42))


func _add_rock(origin: Vector3, index: int) -> void:
	var rock := ROCK.instantiate() as RigidBody3D
	var landing := _landing()
	var entrance := landing + Vector3.UP * (0.34 + (index % 5) * 0.12)
	rock.position = entrance if origin == Vector3.INF else to_local(origin)
	rock.rotation = Vector3(rng.randf_range(-PI, PI), rng.randf_range(-PI, PI), rng.randf_range(-PI, PI))
	add_child(rock)
	near.append(rock)
	if origin == Vector3.INF:
		_drop(rock)
		return
	var start := rock.position
	var flight := rock.create_tween()
	flight.tween_method(func(t: float):
		rock.position = start.lerp(entrance, t) + Vector3.UP * (4.0 * t * (1.0 - t) * 0.48)
	, 0.0, 1.0, 0.34).set_delay(maxi(index, 0) * 0.024)
	flight.tween_callback(_drop.bind(rock))


func _drop(rock: RigidBody3D) -> void:
	rock.freeze = false
	rock.sleeping = false
	rock.collision_layer = 16
	rock.linear_velocity = Vector3(rng.randf_range(-0.59, 0.59), -0.9, rng.randf_range(-0.53, 0.53))
	rock.angular_velocity = Vector3(rng.randf_range(-4.0, 4.0), 1.2, rng.randf_range(-4.0, 4.0))


func _refresh_middle(previous: int, pack_origin: Vector3, cart_origin: Vector3, cart_count: int) -> void:
	var count := mini(visible_stock - near.size(), MIDDLE_LIMIT)
	if count == middle_count:
		return
	for index in mini(middle_count, count):
		flights[index] = landings[index]
	while landings.size() < count:
		var index := landings.size()
		var point := _landing() - Vector3.UP * 0.19
		point.y += rng.randf_range(0.0, 0.24)
		landings.append(point)
		var ordinal := near.size() + index
		var origin := cart_origin if ordinal >= visible_stock - cart_count else pack_origin
		flights.append(to_local(origin) if ordinal >= previous and origin != Vector3.INF else point)
	landings.resize(count)
	flights.resize(count)
	middle_count = count
	middle_elapsed = 0.0
	middle.visible = count > 0
	middle.multimesh.visible_instance_count = count
	_update_middle(0.0)


func _update_middle(t: float) -> void:
	for index in middle_count:
		var from := flights[index]
		var point := landings[index]
		if from != point:
			point = from.lerp(point, t) + Vector3.UP * (2.1 * t * (1.0 - t))
		middle.multimesh.set_instance_transform(index, Transform3D(Basis(Vector3.UP, index * 2.4), point))


func _physics_process(delta: float) -> void:
	if middle_count > 0 and middle_elapsed < 0.48:
		middle_elapsed += delta
		_update_middle(minf(1.0, middle_elapsed / 0.48))
	for rock in near:
		if rock.freeze:
			continue
		var point := rock.position
		if absf(point.x) > 1.15 or absf(point.z) > 0.95 or point.y < -0.25 or point.y > 2.2:
			rock.position = _landing() + Vector3.UP * 0.55
			_drop(rock)
