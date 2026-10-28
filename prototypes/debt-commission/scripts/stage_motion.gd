extends Node
## Scene-owned visual nodes; this controller only manages cancellable transient animation.
var ghost: TextureRect
var veil: ColorRect
var _background_tween: Tween
var _fade_tween: Tween
var _characters: Dictionary = {}
var reduce_motion: bool = false

func setup(background_ghost: TextureRect, scene_fade: ColorRect) -> void:
	ghost = background_ghost
	veil = scene_fade
	reset()


func set_reduce_motion(reduced: bool) -> void:
	reduce_motion = reduced
	if reduced:
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
	if reduce_motion:
		ghost.visible = false
		return
	_background_tween = create_tween()
	_background_tween.tween_property(ghost, "modulate:a", 0.0, duration)
	_background_tween.tween_callback(func() -> void: ghost.visible = false)

func fade(direction: String, duration: float, skipping: bool) -> float:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if skipping:
		veil.modulate.a = 0.0
		return 0.0
	if reduce_motion:
		veil.modulate.a = 1.0 if direction == "out" else 0.0
		return 0.0
	_fade_tween = create_tween()
	_fade_tween.tween_property(veil, "modulate:a", 1.0 if direction == "out" else 0.0, duration)
	return duration

## Animations affect only the Art node; the authored standing position stays in its scene.
func character(sprite: Control, kind: String, skipping: bool, transition: String = "fade") -> void:
	_cancel_character(sprite)
	var art: Control = sprite.get_node_or_null("Art") as Control
	if art == null or skipping or reduce_motion or transition == "instant":
		if kind == "leave":
			sprite.visible = false
		return
	var original: Vector2 = art.position
	var tween: Tween = create_tween()
	var alpha: float = art.modulate.a
	_characters[sprite] = {"tween": tween, "art": art, "position": original, "alpha": alpha,
		"kind": kind, "transition": transition, "queued": ""}
	var slide: float = -120.0 if transition == "slide_left" else 120.0 if transition == "slide_right" else 0.0
	match kind:
		"enter":
			art.modulate.a = 0.0
			art.position.x = original.x + slide
			tween.set_parallel(true)
			tween.tween_property(art, "modulate:a", alpha, 0.25)
			tween.tween_property(art, "position:x", original.x, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.chain()
		"leave":
			tween.set_parallel(true)
			tween.tween_property(art, "modulate:a", 0.0, 0.22)
			tween.tween_property(art, "position:x", original.x + slide, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			tween.chain()
			tween.tween_callback(func() -> void: sprite.visible = false)
		"speak":
			tween.set_trans(Tween.TRANS_SINE)
			tween.tween_property(art, "position:y", original.y - 10.0, 0.07)
			tween.tween_property(art, "position:y", original.y, 0.12)
		"shake":
			for shift: float in [24.0, -18.0, 12.0, -6.0, 0.0]:
				tween.tween_property(art, "position:x", original.x + shift, 0.055).set_trans(Tween.TRANS_SINE)
		"bounce":
			tween.tween_property(art, "position:y", original.y - 65.0, 0.11).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(art, "position:y", original.y, 0.19).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	# Never let a delayed callback from an old line hide the new line's character.
	tween.tween_callback(_finish_character.bind(sprite))

## If a reaction follows an entrance in the same beat, play it after the entrance settles.
func reaction(sprite: Control, kind: String, skipping: bool) -> void:
	if not sprite.visible or character_kind(sprite) == "leave":
		return
	if character_kind(sprite) == "enter" and not skipping and not reduce_motion:
		_characters[sprite]["queued"] = kind
		return
	character(sprite, kind, skipping)


func character_kind(sprite: Control) -> String:
	return str((_characters.get(sprite, {}) as Dictionary).get("kind", ""))


func character_state(sprite: Control) -> Dictionary:
	var state: Dictionary = _characters.get(sprite, {}) as Dictionary
	return {"kind": state.get("kind", ""), "transition": state.get("transition", "fade"), "queued": state.get("queued", "")}


func _finish_character(sprite: Control, play_queued: bool = true) -> void:
	if not _characters.has(sprite):
		return
	var state: Dictionary = _characters[sprite]
	if is_instance_valid(state["art"]):
		state["art"].position = state["position"]
		state["art"].modulate.a = state["alpha"]
	_characters.erase(sprite)
	var queued: String = str(state.get("queued", ""))
	if play_queued and not queued.is_empty() and is_instance_valid(sprite) and sprite.visible and not reduce_motion:
		character(sprite, queued, false)

func _cancel_character(sprite: Control) -> void:
	if _characters.has(sprite):
		var tween: Tween = _characters[sprite]["tween"]
		if tween != null and tween.is_valid():
			tween.kill()
		_finish_character(sprite, false)

func cancel_character(sprite: Control) -> void:
	_cancel_character(sprite)

func cancel_characters(finish_exits: bool = false) -> void:
	for sprite: Control in _characters.keys():
		var leaving: bool = character_kind(sprite) == "leave"
		_cancel_character(sprite)
		if finish_exits and leaving and is_instance_valid(sprite):
			sprite.visible = false

func reset() -> void:
	for tween: Tween in [_background_tween, _fade_tween]:
		if tween != null and tween.is_valid():
			tween.kill()
	cancel_characters(true)
	if ghost != null:
		ghost.visible = false
	if veil != null:
		veil.modulate.a = 0.0
