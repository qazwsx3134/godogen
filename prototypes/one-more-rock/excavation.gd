extends Node3D

signal ore_landed(at: Vector3, count: int)
signal section_unstable(at: Vector3, normal: Vector3)

const Debris = preload("res://excavation_debris.gd")
const OreBody := preload("res://scenes/excavated_ore.tscn")
const FallingBody := preload("res://scenes/falling_rock.tscn")
const INSTABILITY_TIME := 0.48
const HULL_DIRECTIONS: Array[Vector3] = [
	Vector3.LEFT, Vector3.RIGHT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK,
	Vector3(-1, -1, -1), Vector3(-1, -1, 1), Vector3(-1, 1, -1), Vector3(-1, 1, 1),
	Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(1, 1, -1), Vector3(1, 1, 1),
]

var rng := RandomNumberGenerator.new()
var loose: Array[Debris] = []
var falling: Array[Debris] = []
var body_budget := 90
var falling_budget := 8
var unstable: Array[Dictionary] = []
var clock := 0.0
var collapse_ore_ready := 0.0


func _physics_process(delta: float) -> void:
	clock += delta
	if unstable.is_empty() or falling.size() >= falling_budget or clock < unstable[0].release_at:
		return
	# Build at most one collision shape per tick when a whole ledge gives way.
	var pending: Dictionary = unstable.pop_front()
	_release_section(pending.preview, pending.cells, pending.normal)


func spawn_ore(point: Vector3, normal: Vector3, amount: int, mineral := -1) -> void:
	for index in amount:
		var piece := OreBody.instantiate() as Debris
		piece.position = to_local(point + normal * 0.18 + Vector3(rng.randf_range(-0.14, 0.14), index * 0.16, rng.randf_range(-0.18, 0.18)))
		piece.position.y = maxf(piece.position.y, 0.18)
		piece.rotation = Vector3(rng.randf(), rng.randf() * TAU, rng.randf() * 2.5)
		piece.mineral = mineral
		piece.rare = mineral >= 2
		if piece.rare:
			piece.collision_layer |= 2
			piece.get_node("ShapeMesh").material_overlay = preload("res://assets/mined_glint.tres")
		add_child(piece)
		loose.append(piece)
		piece.linear_velocity = normal * rng.randf_range(0.75, 1.7) + Vector3(rng.randf_range(-0.44, 0.44), rng.randf_range(0.54, 1.3), rng.randf_range(-0.58, 0.58))
		piece.angular_velocity = Vector3(rng.randf_range(-5, 5), rng.randf_range(-7, 7), rng.randf_range(-5, 5))
	_manage_budget()


func spawn_section(mesh: ArrayMesh, point: Vector3, cells: int, normal: Vector3) -> void:
	if mesh.get_surface_count() == 0:
		return
	var preview := MeshInstance3D.new()
	preview.mesh = mesh
	preview.position = to_local(point)
	add_child(preview)
	var tilt := Vector3.UP.cross(normal)
	if tilt.length_squared() < 0.1:
		tilt = Vector3.RIGHT
	var motion := preview.create_tween().set_parallel()
	motion.tween_property(preview, "position", preview.position + normal * 0.045 + Vector3.DOWN * 0.055,
		INSTABILITY_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	motion.tween_property(preview, "basis", Basis(tilt.normalized(), 0.065), INSTABILITY_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	unstable.append({"preview": preview, "cells": cells, "normal": normal, "release_at": clock + INSTABILITY_TIME})
	section_unstable.emit(point + normal * minf(0.75, mesh.get_aabb().size.length() * 0.25), normal)


func _release_section(preview: MeshInstance3D, cells: int, normal: Vector3) -> void:
	var section := FallingBody.instantiate() as Debris
	section.transform = preview.transform
	section.lands_as_ore = false
	section.mass = minf(210.0, maxf(1.2, cells * 1.7))
	section.ore_count = 2 if cells >= 42 else 1
	section.get_node("ShapeMesh").mesh = preview.mesh
	section.get_node("HitShape").shape = _section_hull(preview.mesh)
	preview.queue_free()
	add_child(section)
	falling.append(section)
	section.linear_velocity = normal * 0.27 + Vector3.DOWN * 0.18
	section.angular_velocity = Vector3.UP.cross(normal) * 0.34
	section.shattered.connect(_crumble.bind(section))


func _section_hull(mesh: ArrayMesh) -> ConvexPolygonShape3D:
	# Sample extreme vertices to keep the solver's hull small even for a tall ledge.
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var center := mesh.get_aabb().get_center()
	var points := PackedVector3Array()
	for direction in HULL_DIRECTIONS:
		var extreme := vertices[0]
		var projection := extreme.dot(direction)
		for vertex in vertices:
			var distance := vertex.dot(direction)
			if distance > projection:
				projection = distance
				extreme = vertex
		points.append(center.lerp(extreme, 0.93))
	var hull := ConvexPolygonShape3D.new()
	hull.points = points
	return hull


func _crumble(point: Vector3, count: int, section: Debris) -> void:
	falling.erase(section)
	var dropped := 0
	if clock >= collapse_ore_ready:
		spawn_ore(point, Vector3.UP, count)
		dropped = count
		collapse_ore_ready = clock + 0.25
	ore_landed.emit(point, dropped)


func retire(piece: Debris) -> void:
	piece.spent = true
	loose.erase(piece)
	piece.hide()
	piece.queue_free()


func _manage_budget() -> void:
	var awake := 0
	for index in range(loose.size() - 1, -1, -1):
		var piece := loose[index]
		if piece.freeze or piece.sleeping:
			continue
		awake += 1
		if awake > body_budget and piece.usable():
			piece.freeze = true
