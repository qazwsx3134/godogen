extends SceneTree
## Run in a temporary Godot 4.7 project containing melee.glb and tank.glb.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var errors: Array[String] = []
	for model_name in ["melee", "tank"]:
		var packed := load("res://%s.glb" % model_name) as PackedScene
		if packed == null:
			errors.append(model_name + " failed to load")
			continue
		var instance := packed.instantiate()
		root.add_child(instance)
		await process_frame
		var meshes := instance.find_children("*", "MeshInstance3D", true, false)
		var rigs := instance.find_children("*", "Skeleton3D", true, false)
		var players := instance.find_children("*", "AnimationPlayer", true, false)
		if meshes.size() != 1 or rigs.size() != 1 or players.size() != 1:
			errors.append("%s unexpected tree meshes=%d rigs=%d players=%d" % [model_name, meshes.size(), rigs.size(), players.size()])
			instance.queue_free()
			continue
		var mesh_node := meshes[0] as MeshInstance3D
		var mesh := mesh_node.mesh
		var skeleton := rigs[0] as Skeleton3D
		var player := players[0] as AnimationPlayer
		var surfaces := mesh.get_surface_count()
		var arrays := mesh.surface_get_arrays(0)
		var triangles: int = arrays[Mesh.ARRAY_INDEX].size() / 3
		var animation_names := player.get_animation_list()
		print("MODEL %s tris=%d surfaces=%d bones=%d animations=%s AABB=%s" % [model_name, triangles, surfaces, skeleton.get_bone_count(), animation_names, mesh.get_aabb()])
		if surfaces != 1 or triangles > 1800 or skeleton.get_bone_count() != 19:
			errors.append(model_name + " violated geometry budget")
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		if vertices.size() != uvs.size() or vertices.size() != normals.size():
			errors.append(model_name + " is missing UVs or normals")
		else:
			for i in vertices.size():
				if not is_finite(uvs[i].x) or not is_finite(uvs[i].y) or uvs[i].x < -0.001 or uvs[i].x > 1.001 or uvs[i].y < -0.001 or uvs[i].y > 1.001 or normals[i].length_squared() < 0.9:
					errors.append(model_name + " contains invalid UVs or normals")
					break
		for i in range(0, indices.size(), 3):
			var a := vertices[indices[i]]
			var b := vertices[indices[i+1]]
			var c := vertices[indices[i+2]]
			if (b-a).cross(c-a).length_squared() < 0.000000000001:
				errors.append(model_name + " contains a degenerate triangle")
				break
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		if weights.size() != arrays[Mesh.ARRAY_VERTEX].size() * 4:
			errors.append(model_name + " has unexpected skin weights")
		else:
			for i in range(0, weights.size(), 4):
				var weight_sum := weights[i] + weights[i+1] + weights[i+2] + weights[i+3]
				var max_weight := maxf(maxf(weights[i], weights[i+1]), maxf(weights[i+2], weights[i+3]))
				if not is_equal_approx(weight_sum, 1.0) or not is_equal_approx(max_weight, 1.0):
					errors.append(model_name + " has a non-rigid or unweighted vertex")
					break
		if absf(mesh.get_aabb().position.y) > 0.01:
			errors.append(model_name + " rest-pose ground origin is incorrect")
		for expected in ["walk", "idle", "attack" if model_name == "melee" else "fire"]:
			if not player.has_animation(expected):
				errors.append("%s missing animation %s" % [model_name, expected])
		var leg := skeleton.find_bone("L1_Upper")
		if leg < 0:
			errors.append(model_name + " missing L1_Upper bone")
		elif player.has_animation("walk") and player.has_animation("idle"):
			var walk := player.get_animation("walk")
			if walk.loop_mode != Animation.LOOP_LINEAR or not is_equal_approx(walk.length, 0.8):
				errors.append(model_name + " walk cycle duration/loop invalid")
			player.play("idle")
			player.seek(0.0, true)
			var idle_leg := skeleton.get_bone_pose_rotation(leg)
			player.play("walk")
			player.seek(0.0, true)
			var initial_leg := skeleton.get_bone_pose_rotation(leg)
			player.seek(0.2, true)
			var next_leg := skeleton.get_bone_pose_rotation(leg)
			print("  walk L1 quaternion change=", initial_leg.angle_to(next_leg))
			if initial_leg.angle_to(next_leg) < 0.05:
				errors.append(model_name + " walk bone did not move")
			player.play("idle")
			player.seek(0.0, true)
			if idle_leg.angle_to(skeleton.get_bone_pose_rotation(leg)) > 0.001:
				errors.append(model_name + " leg did not reset on interrupted walk")
		var action := "attack" if model_name == "melee" else "fire"
		var bone_idx := skeleton.find_bone("L_Blade" if model_name == "melee" else "Cannon")
		if bone_idx < 0:
			errors.append(model_name + " missing weapon bone")
		elif player.has_animation(action) and player.has_animation("walk"):
			player.play(action)
			player.seek(0, true)
			var first_rotation := skeleton.get_bone_pose_rotation(bone_idx)
			var first_position := skeleton.get_bone_pose_position(bone_idx)
			player.seek(0.3 if model_name == "melee" else 2.0/30.0, true)
			var angle := first_rotation.angle_to(skeleton.get_bone_pose_rotation(bone_idx))
			var travel := first_position.distance_to(skeleton.get_bone_pose_position(bone_idx))
			print("  %s bone angle=%.4f travel=%.4f" % [action, angle, travel])
			if (model_name == "melee" and angle < 0.05) or (model_name == "tank" and travel < 0.05):
				errors.append(model_name + " action bone did not move")
			player.play("walk")
			player.seek(0.0, true)
			if first_rotation.angle_to(skeleton.get_bone_pose_rotation(bone_idx)) > 0.001 or first_position.distance_to(skeleton.get_bone_pose_position(bone_idx)) > 0.001:
				errors.append(model_name + " weapon did not reset on interrupted action")
		instance.queue_free()
		await process_frame
	if errors.is_empty():
		print("ENEMY_MODELS PASSED")
		quit(0)
	else:
		for error in errors:
			printerr("FAILED: ", error)
		quit(1)
