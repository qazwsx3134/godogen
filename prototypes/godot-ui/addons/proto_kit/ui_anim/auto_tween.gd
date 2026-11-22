class_name AutoTween
extends Node
## 掛在任一 Control 底下當子 node，替「父 node」加出場動畫。
## trigger=VISIBILITY：父或祖先 visible 變 true 時播放（只有顯示切換的選單直接適用）。

@export var trigger: ContainerTween.Trigger = ContainerTween.Trigger.VISIBILITY
@export var anim_type: UiAnim.Type = UiAnim.Type.SCALE
@export var duration := 0.18
@export var delay := 0.0

@export var appear_sound: AudioStream

@onready var target := get_parent() as Control


func _ready() -> void:
	if trigger == ContainerTween.Trigger.VISIBILITY:
		target.visibility_changed.connect(func(): if target.is_visible_in_tree(): play())
	if trigger != ContainerTween.Trigger.MANUAL and target.is_visible_in_tree():
		play()


func play() -> void:
	UiAnim.hide_for_anim(target)
	var t := target.create_tween().set_parallel()
	UiAnim.appear(t, target, anim_type, duration, delay)
	if appear_sound:
		t.tween_callback(UiAnim.play_sfx.bind(target, appear_sound)).set_delay(delay)
