extends SkeletonModifier3D
## Applied after the imported animation: lays both tails down so they drag on the ground behind
## the hull (sweeping sideways with boss.tail_angle), and swings the head cannon onto its aim.
var boss: Node3D

func _process_modification() -> void:
	if not is_instance_valid(boss): return
	var skeleton := get_skeleton()
	for side: String in ["L", "R"]:
		_drag_tail(skeleton, side)
	var cannon := skeleton.find_bone("Cannon")
	if cannon < 0: return
	# The Cannon bone's local +Y runs along the barrel; swing it onto boss.cannon_dir.
	var pose := skeleton.get_bone_global_pose(cannon)
	var current := (pose.basis * Vector3.UP).normalized()
	var wanted: Vector3 = (skeleton.global_basis.inverse() * (boss.get("cannon_dir") as Vector3)).normalized()
	if current.dot(wanted) > 0.9999: return
	skeleton.set_bone_global_pose(cannon, Transform3D(Basis(Quaternion(current, wanted)) * pose.basis, pose.origin))


## Tail_<side>_1..4: the first two segments slope down from the hull to the ground, the last
## two lie flat on it. tail_angle swings the whole tail sideways (the sweep attack).
func _drag_tail(skeleton: Skeleton3D, side: String) -> void:
	var bones: Array[int] = []
	for i in range(1, 5):
		var index := skeleton.find_bone("Tail_%s_%d" % [side, i])
		if index < 0: return
		bones.append(index)
	var ground := (skeleton.global_transform.affine_inverse() * boss.global_position).y + 0.35
	var origin := skeleton.get_bone_global_pose(bones[0]).origin
	var rest_dir := (skeleton.get_bone_global_rest(bones[0]).basis * Vector3.UP).normalized()
	var length := skeleton.get_bone_global_rest(bones[0]).origin.distance_to(skeleton.get_bone_global_rest(bones[1]).origin)
	var back := Vector3(rest_dir.x, 0.0, rest_dir.z).normalized().rotated(Vector3.UP, boss.tail_angle)
	var drop := asin(clampf((origin.y - ground) / (2.0 * length), 0.0, 1.0))
	var sloped := (back * cos(drop) + Vector3.DOWN * sin(drop)).normalized()
	for i in bones.size():
		var dir := sloped if i < 2 else back.rotated(Vector3.UP, boss.tail_angle * 0.4 * (i - 1))  # the tip lags the sweep
		var rest := skeleton.get_bone_global_rest(bones[i])
		var rest_axis := (rest.basis * Vector3.UP).normalized()
		skeleton.set_bone_global_pose(bones[i], Transform3D(Basis(Quaternion(rest_axis, dir)) * rest.basis, origin))
		origin += dir * length
