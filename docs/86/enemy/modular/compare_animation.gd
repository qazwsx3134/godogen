extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var errors: Array[String] = []
	for name in ["melee", "tank"]:
		var a := (load("res://%s_original.glb" % name) as PackedScene).instantiate()
		var b := (load("res://%s.glb" % name) as PackedScene).instantiate()
		root.add_child(a)
		root.add_child(b)
		await process_frame
		var sk_a := a.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var sk_b := b.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var pl_a := a.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var pl_b := b.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var worst_angle := 0.0
		var worst_distance := 0.0
		var actions := ["walk", "idle", "attack" if name == "melee" else "fire"]
		for action in actions:
			var anim_a := pl_a.get_animation(action)
			var anim_b := pl_b.get_animation(action)
			if absf(anim_a.length - anim_b.length) > 0.0001:
				errors.append(name + " " + action + " length changed")
			for i in 9:
				var t := anim_a.length * float(i) / 9.0
				pl_a.play(action)
				pl_b.play(action)
				pl_a.seek(t, true)
				pl_b.seek(t, true)
				for bone_idx in sk_a.get_bone_count():
					var b_idx := sk_b.find_bone(sk_a.get_bone_name(bone_idx))
					if b_idx < 0:
						errors.append(name + " missing bone")
						continue
					var angle := sk_a.get_bone_pose_rotation(bone_idx).angle_to(sk_b.get_bone_pose_rotation(b_idx))
					var distance := sk_a.get_bone_pose_position(bone_idx).distance_to(sk_b.get_bone_pose_position(b_idx))
					worst_angle = maxf(worst_angle, absf(angle))
					worst_distance = maxf(worst_distance, distance)
		print("COMPARE ",name," max_angle_rad=",worst_angle," max_position_m=",worst_distance)
		if worst_angle > 0.002 or worst_distance > 0.0001:
			errors.append(name + " animation changed")
		a.queue_free()
		b.queue_free()
		await process_frame
	if errors.is_empty():
		print("ANIMATION_COMPARE PASSED")
		quit(0)
	else:
		for error in errors: printerr("FAILED: ", error)
		quit(1)
