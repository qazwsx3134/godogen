extends RefCounted
## Turns a screen tap into "this actor" or "this ground point" for a 3D view.
## `const TapPicker3D = preload("res://addons/proto_kit/tap_picker_3d.gd")`
##
## Actors are picked on screen, not by physics: the nearest aim point within `radius_px` wins,
## so small or overlapping sprites stay tappable with a finger. Read taps in _unhandled_input,
## so Controls with mouse_filter STOP (HUD buttons) swallow them first.


## `candidates`: Node3D list. `aim`: Callable(node) -> Vector3 world point to measure from
## (default: the node's origin). Nodes behind the camera are skipped. Returns null when none.
static func pick_actor(camera: Camera3D, screen: Vector2, candidates: Array, radius_px: float,
		aim: Callable = Callable()) -> Node3D:
	var best: Node3D = null
	var best_d: float = radius_px
	for node: Node3D in candidates:
		var p: Vector3 = aim.call(node) if aim.is_valid() else node.global_position
		if camera.is_position_behind(p):
			continue
		var d: float = camera.unproject_position(p).distance_to(screen)
		if d < best_d:
			best = node
			best_d = d
	return best


## Ray from the tap into the physics world. Returns the hit position, or null.
static func ground(camera: Camera3D, screen: Vector2, mask: int = 1, length: float = 400.0) -> Variant:
	var from: Vector3 = camera.project_ray_origin(screen)
	var query := PhysicsRayQueryParameters3D.create(from, from + camera.project_ray_normal(screen) * length, mask)
	var hit: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query)
	return null if hit.is_empty() else hit.position
