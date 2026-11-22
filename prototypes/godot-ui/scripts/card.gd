extends Button
## hover 抬起放大。只動自己的 offset_transform，扇形在 slot 上，兩者疊加。

var _tween: Tween
const HOVER := preload("res://assets/sfx/hover.ogg")
const UNHOVER := preload("res://assets/sfx/unhover.ogg")


func _ready() -> void:
	mouse_entered.connect(_lift.bind(true))
	mouse_exited.connect(_lift.bind(false))


func _lift(up: bool) -> void:
	if disabled:
		return
	UiAnim.enable(self)
	z_index = 1 if up else 0
	UiAnim.play_sfx(self, HOVER if up else UNHOVER)
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "offset_transform_position:y", -28.0 if up else 0.0, 0.1)
	_tween.tween_property(self, "offset_transform_scale", Vector2.ONE * (1.12 if up else 1.0), 0.1)
