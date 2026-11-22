extends RefCounted
## Bake one mesh surface on an isolated rig using a rendering-enabled Godot process.
## Rows are successive poses, columns follow the original surface vertex buffer.
static func bake(player: AnimationPlayer, mesh: MeshInstance3D, clips: Array[StringName], fps := 24) -> Dictionary:
	if fps <= 0 or clips.is_empty() or not mesh.mesh or mesh.mesh.get_surface_count() != 1:
		return {}
	var skeleton := mesh.get_node_or_null(mesh.skeleton) as Skeleton3D
	if skeleton == null:
		return {}
	var ranges := {}
	var height := 0
	for clip in clips:
		if not player.has_animation(clip) or ranges.has(clip):
			return {}
		var count := maxi(1, ceili(player.get_animation(clip).length * fps))
		ranges[clip] = Vector2i(height, count)
		height += count
	var width: int = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	if width < 1 or width > 4096 or height > 4096:
		return {}
	var positions := Image.create_empty(width, height, false, Image.FORMAT_RGBAH)
	var normals := Image.create_empty(width, height, false, Image.FORMAT_RGBAH)
	var bounds := AABB()
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for clip in clips:
		player.play(clip, 0.0)
		var rows: Vector2i = ranges[clip]
		for frame in rows.y:
			player.seek(frame * player.get_animation(clip).length / rows.y, true)
			skeleton.force_update_all_bone_transforms()
			await RenderingServer.frame_post_draw
			var pose := mesh.bake_mesh_from_current_skeleton_pose()
			if pose == null or pose.get_surface_count() != 1:
				return {}
			var arrays := pose.surface_get_arrays(0)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var directions: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			if points.size() != width or directions.size() != width:
				return {}
			for i in width:
				var p := points[i]
				var n := directions[i]
				var row := rows.x + frame
				positions.set_pixel(i, row, Color(p.x, p.y, p.z, 1))
				normals.set_pixel(i, row, Color(n.x, n.y, n.z, 1))
				bounds = AABB(p, Vector3.ZERO) if row == 0 and i == 0 else bounds.expand(p)
	return {"positions": ImageTexture.create_from_image(positions), "normals": ImageTexture.create_from_image(normals), "clips": ranges, "bounds": bounds}

## One animated instance. Phase is an offset in cycles.
static func set_actor(batch: MultiMesh, index: int, pose: Transform3D, rows: Vector2i, phase: float, flash: float) -> void:
	batch.set_instance_transform(index, pose)
	batch.set_instance_custom_data(index, Color(phase, rows.x, rows.y, clampf(flash, 0.0, 1.0)))
