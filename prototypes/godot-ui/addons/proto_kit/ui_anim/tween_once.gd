class_name TweenOnce
extends Control
## 數值一變就彈一下。用 _set 攔截 tracked_property 的寫入（含 label.text = x）。
## 也可手動呼叫 punch()。

@export var tracked_property: StringName = &"text"
@export var punch_scale := Vector2(1.35, 0.8)
@export var duration := 0.15

var _tween: Tween


func _set(property: StringName, value: Variant) -> bool:
	if property == tracked_property and is_node_ready():
		punch.call_deferred()
	return false  # 交回原生 setter 真正寫入


func punch() -> void:
	UiAnim.enable(self)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "offset_transform_scale", Vector2.ONE, duration).from(punch_scale) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
