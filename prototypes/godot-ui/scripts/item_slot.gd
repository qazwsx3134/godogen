class_name ItemSlot
extends Button
## 背包一格：icon＋右下數量。動畫都用 visual-only offset_transform，不動 GridContainer 排版。

const UNHOVER := preload("res://assets/sfx/unhover.ogg")

@export var hover_sound: AudioStream = preload("res://assets/sfx/rollover2.ogg")

var item: Texture2D
var count := 0
var _tween: Tween
var _selected := false


func _ready() -> void:
	UiAnim.enable(self)
	mouse_entered.connect(_hover.bind(true))
	mouse_exited.connect(_hover.bind(false))


func is_empty() -> bool:
	return item == null


func set_item(tex: Texture2D, n: int) -> void:
	var was := item
	item = tex if n > 0 else null
	count = n if item else 0
	icon = item
	%Count.text = str(count) if count > 1 else ""  # TweenOnce 追蹤 text，變了就彈
	if item and item != was:  # 新放進來的東西彈一下
		_kick(Vector2(1.25, 0.8), 0.0)


func set_selected(on: bool) -> void:
	_selected = on
	self_modulate = Color(1.0, 0.85, 0.55) if on else Color.WHITE
	_kick(Vector2.ONE * (1.1 if on else 1.0), -6.0 if on else 0.0)


func _hover(entered: bool) -> void:
	UiAnim.play_sfx(self, hover_sound if entered else UNHOVER)
	if not _selected:
		_kick(Vector2.ONE * (1.08 if entered else 1.0), 0.0)


func _kick(to_scale: Vector2, to_y: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if to_scale != Vector2.ONE and to_y == 0.0 and not _selected and to_scale.x != to_scale.y:
		offset_transform_scale = to_scale  # 擠壓後彈回
		to_scale = Vector2.ONE
	_tween.tween_property(self, "offset_transform_scale", to_scale, 0.12)
	_tween.tween_property(self, "offset_transform_position:y", to_y, 0.12)
