class_name ContainerTween
extends Container
## 子 node 依序出場。Ready 時只把子 node 設透明（不改 visible），再逐一動畫。

enum Trigger { READY, VISIBILITY, MANUAL }

@export var trigger: Trigger = Trigger.READY
@export var anim_type: UiAnim.Type = UiAnim.Type.SCALE
@export var duration := 0.18
@export var delay_between_element := 0.04
@export var appear_sound: AudioStream  ## 每個元素出場時播一次
@export var pitch_step := 0.05        ## 後出場的音高逐步升高

var _tween: Tween


func _ready() -> void:
	if trigger == Trigger.MANUAL:
		return
	if trigger == Trigger.VISIBILITY:
		visibility_changed.connect(func(): if is_visible_in_tree(): play())
	if is_visible_in_tree():
		play()


func play() -> void:
	var kids: Array[Control] = []
	for c in get_children():
		if c is Control and c.visible:
			kids.append(c)
			UiAnim.hide_for_anim(c)
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel()
	for idx in kids.size():
		UiAnim.appear(_tween, kids[idx], anim_type, duration, delay_between_element * idx)
		if appear_sound:
			_tween.tween_callback(UiAnim.play_sfx.bind(self, appear_sound, 1.0 + pitch_step * idx)) \
				.set_delay(delay_between_element * idx)
