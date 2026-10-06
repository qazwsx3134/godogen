extends Node
## Scene-owned visual nodes; this controller only manages cancellable transient animation.
var ghost: TextureRect
var veil: ColorRect
var _background_tween: Tween
var _fade_tween: Tween
var _characters: Dictionary = {}

func setup(background_ghost: TextureRect, scene_fade: ColorRect) -> void:
	ghost = background_ghost
	veil = scene_fade
	reset()

func capture_background(frame: TextureRect) -> void:
	if _background_tween != null and _background_tween.is_valid():
		_background_tween.kill()
	ghost.texture = frame.texture
	ghost.material = frame.material
	ghost.position = (ghost.get_parent() as Control).get_global_transform().affine_inverse() * frame.global_position
	ghost.size = frame.size
	ghost.stretch_mode = frame.stretch_mode
	ghost.expand_mode = frame.expand_mode
	ghost.modulate = Color.WHITE
	ghost.visible = true

func crossfade(duration: float = 0.28) -> void:
	_background_tween = create_tween()
	_background_tween.tween_property(ghost, "modulate:a", 0.0, duration)
	_background_tween.tween_callback(func() -> void: ghost.visible = false)

func fade(direction: String, duration: float, skipping: bool) -> float:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if skipping:
		veil.modulate.a = 0.0
		return 0.0
	_fade_tween = create_tween()
	_fade_tween.tween_property(veil, "modulate:a", 1.0 if direction == "out" else 0.0, duration)
	return duration

func character(sprite: Control, kind: String, skipping: bool) -> void:
	_cancel_character(sprite)
	var art: Control = sprite.get_node_or_null("Art") as Control
	if art == null or skipping:
		if kind == "leave":
			sprite.visible = false
		return
	var original: Vector2 = art.position
	var tween: Tween = create_tween()
	var alpha: float = art.modulate.a
	_characters[sprite] = {"tween": tween, "art": art, "position": original, "alpha": alpha}
	match kind:
		"enter":
			art.modulate.a = 0.0
			tween.tween_property(art, "modulate:a", alpha, 0.22)
		"leave":
			tween.tween_property(art, "modulate:a", 0.0, 0.18)
			tween.tween_callback(func() -> void: sprite.visible = false)
		"speak":
			tween.set_trans(Tween.TRANS_SINE)
			tween.tween_property(art, "position:y", original.y - 16.0, 0.07)
			tween.tween_property(art, "position:y", original.y, 0.12)
	# Never let a delayed callback from an old line hide the new line's character.
	tween.tween_callback(_finish_character.bind(sprite))

func _finish_character(sprite: Control) -> void:
	if not _characters.has(sprite):
		return
	var state: Dictionary = _characters[sprite]
	if is_instance_valid(state["art"]):
		state["art"].position = state["position"]
		state["art"].modulate.a = state["alpha"]
	_characters.erase(sprite)

func _cancel_character(sprite: Control) -> void:
	if _characters.has(sprite):
		var tween: Tween = _characters[sprite]["tween"]
		if tween != null and tween.is_valid():
			tween.kill()
		_finish_character(sprite)

func cancel_characters() -> void:
	for sprite: Control in _characters.keys():
		_cancel_character(sprite)

func reset() -> void:
	for tween: Tween in [_background_tween, _fade_tween]:
		if tween != null and tween.is_valid():
			tween.kill()
	cancel_characters()
	if ghost != null:
		ghost.visible = false
	if veil != null:
		veil.modulate.a = 0.0
