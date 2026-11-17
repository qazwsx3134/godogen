extends SceneTree
## Verify the exported skinned Boss and actual Godot animation playback.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var errors: Array[String] = []
	var packed := load("res://boss_animated.glb") as PackedScene
	if packed == null:
		printerr("FAILED: could not load animated Boss")
		quit(1)
		return
	var instance := packed.instantiate()
	root.add_child(instance)
	await process_frame
	var meshes := instance.find_children("*", "MeshInstance3D", true, false)
	var rigs := instance.find_children("*", "Skeleton3D", true, false)
	var players := instance.find_children("*", "AnimationPlayer", true, false)
	if meshes.size() != 1 or rigs.size() != 1 or players.size() != 1:
		printerr("FAILED: unexpected hierarchy mesh=%d skeleton=%d player=%d" % [meshes.size(), rigs.size(), players.size()])
		quit(1)
		return
	var mesh_node := meshes[0] as MeshInstance3D
	var mesh := mesh_node.mesh
	var rig := rigs[0] as Skeleton3D
	var player := players[0] as AnimationPlayer
	if mesh == null or mesh.get_surface_count() != 1 or rig.get_bone_count() != 55:
		printerr("FAILED: wrong mesh surfaces or bone count")
		quit(1)
		return
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var tris: int = indices.size() / 3
	if tris != 24728:
		errors.append("unexpected triangle count %d" % tris)
	if vertices.size() != uvs.size() or vertices.size() != normals.size():
		errors.append("missing UVs or normals")
	else:
		for i in vertices.size():
			if not is_finite(uvs[i].x) or not is_finite(uvs[i].y) or uvs[i].x < -0.001 or uvs[i].x > 1.001 or uvs[i].y < -0.001 or uvs[i].y > 1.001 or absf(normals[i].length() - 1.0) > 0.02:
				errors.append("invalid UV or normal")
				break
	if weights.size() != vertices.size()*4 or bones.size() != vertices.size()*4:
		errors.append("unexpected bone weight array size")
	else:
		var blended := 0
		for i in range(0, weights.size(), 4):
			var total := 0.0
			var active := 0
			for j in range(4):
				var w := weights[i+j]
				if not is_finite(w) or w < 0 or w > 1:
					errors.append("invalid bone weight")
					break
				total += w
				if w > 0.001:
					active += 1
					if bones[i+j] < 0 or bones[i+j] >= rig.get_bone_count():
						errors.append("bone index outside skeleton")
			if absf(total-1.0) > 0.001:
				errors.append("unweighted or incorrectly normalized vertex")
				break
			if active > 1:
				blended += 1
		print("SKIN vertices=%d blended_vertices=%d" % [vertices.size(), blended])
		if blended == 0:
			errors.append("tail cores have no blended weights")
	var expected_bones := ["Hull", "Cannon", "CoreRotor", "Tail_L_1", "Tail_L_2", "Tail_L_3", "Tail_L_4", "Tail_R_1", "Tail_R_2", "Tail_R_3", "Tail_R_4"]
	for name in expected_bones:
		if rig.find_bone(name) < 0:
			errors.append("missing bone " + name)
	for name in ["idle", "fly", "fire", "walk"]:
		if not player.has_animation(name):
			errors.append("missing clip " + name)
	print("MODEL triangles=%d vertices=%d bones=%d clips=%s aabb=%s" % [tris, vertices.size(), rig.get_bone_count(), player.get_animation_list(), mesh.get_aabb()])
	if player.has_animation("idle") and player.has_animation("fly") and player.has_animation("fire"):
		for clip in ["idle", "fly"]:
			if player.get_animation(clip).loop_mode != Animation.LOOP_LINEAR:
				errors.append(clip + " is not looping")
		if player.get_animation("fire").loop_mode != Animation.LOOP_NONE:
			errors.append("fire should play once")
		var expected_lengths := {"idle": 3.0, "fly": 1.8, "fire": 1.2}
		for clip in expected_lengths:
			if absf(player.get_animation(clip).length - expected_lengths[clip]) > 0.04:
				errors.append(clip + " has an unexpected duration")
		var left := rig.find_bone("Tail_L_2")
		var right := rig.find_bone("Tail_R_2")
		var rotor := rig.find_bone("CoreRotor")
		var cannon := rig.find_bone("Cannon")
		if min(left, right, rotor, cannon) >= 0:
			for clip in ["idle", "fly"]:
				player.play(clip)
				player.seek(0.0, true)
				var tail_start := rig.get_bone_pose_rotation(left)
				var rotor_start_loop := rig.get_bone_pose_rotation(rotor)
				player.seek(player.get_animation(clip).length - 0.0001, true)
				if tail_start.angle_to(rig.get_bone_pose_rotation(left)) > .01 or rotor_start_loop.angle_to(rig.get_bone_pose_rotation(rotor)) > .01:
					errors.append(clip + " does not return to its opening pose")
			player.play("fly")
			player.seek(0.0, true)
			var left_start := rig.get_bone_pose_rotation(left)
			var right_start := rig.get_bone_pose_rotation(right)
			player.seek(0.45, true)
			var left_angle := left_start.angle_to(rig.get_bone_pose_rotation(left))
			var right_angle := right_start.angle_to(rig.get_bone_pose_rotation(right))
			print("FLY tail_left=%.5f tail_right=%.5f" % [left_angle, right_angle])
			if left_angle < 0.01 or right_angle < 0.01:
				errors.append("one or both tails did not move")
			player.play("idle")
			player.seek(0.0, true)
			var rotor_start := rig.get_bone_pose_rotation(rotor)
			var cannon_rest := rig.get_bone_pose_position(cannon)
			player.seek(0.75, true)
			var rotor_angle := rotor_start.angle_to(rig.get_bone_pose_rotation(rotor))
			print("IDLE rotor_angle=%.4f" % rotor_angle)
			if rotor_angle < 1.0:
				errors.append("rotor did not rotate")
			player.play("fire")
			player.seek(10.0/30.0, true)
			var recoil := cannon_rest.distance_to(rig.get_bone_pose_position(cannon))
			print("FIRE cannon_recoil=%.3f" % recoil)
			if recoil < .5:
				errors.append("cannon did not recoil")
			player.play("idle")
			player.seek(0.0, true)
			if cannon_rest.distance_to(rig.get_bone_pose_position(cannon)) > .001:
				errors.append("cannon did not reset after interrupted fire")
	var mat := mesh.surface_get_material(0) as BaseMaterial3D
	if mat == null or mat.albedo_texture == null or mat.albedo_texture.get_size() != Vector2(2048,2048):
		errors.append("missing 2048 albedo")
	var bounds := mesh.get_aabb()
	if absf(bounds.size.z-40.0) > .1 or absf(bounds.position.y) > .1:
		errors.append("unexpected rest bounds")
	if errors.is_empty():
		print("BOSS_ANIMATED_GODOT_VALIDATION_PASS")
		quit(0)
	else:
		for error in errors:
			printerr("FAILED: ", error)
		quit(1)
