class_name CardHand
extends HBoxContainer
## Slay the Spire 式手牌。每張卡放在一個 dummy slot（純 Control）裡：
## Container 只排 slot，slot 的 custom_minimum_size.x 用 tween 展開／收起，
## 扇形旋轉與弧度用 slot 的 visual-only offset_transform，不影響排版也不縮小點擊範圍。

signal card_played(card: Button)

@export var card_scene: PackedScene
@export var slot_width := 84.0   ## 小於卡寬即重疊
@export var fan_deg := 5.0       ## 每張相對中心的旋轉
@export var arc := 6.0           ## 離中心越遠越往下
@export var duration := 0.15
@export var draw_sound: AudioStream = preload("res://assets/sfx/card_draw.ogg")
@export var play_sound: AudioStream = preload("res://assets/sfx/card_play.ogg")


func add_card(text: String) -> Button:
	var card: Button = card_scene.instantiate()
	card.text = text
	var slot := Control.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.custom_minimum_size.y = card.size.y
	UiAnim.enable(slot)
	slot.offset_transform_pivot_ratio = Vector2(0.5, 1.0)
	slot.add_child(card)
	card.position.x = (slot_width - card.size.x) / 2.0
	add_child(slot)
	card.pressed.connect(remove_card.bind(card))
	UiAnim.play_sfx(self, draw_sound)
	create_tween().tween_property(slot, "custom_minimum_size:x", slot_width, duration).from(0.0)
	card.modulate.a = 0.0
	UiAnim.enable(card)
	var t := card.create_tween().set_parallel()
	t.tween_property(card, "offset_transform_position", Vector2.ZERO, duration).from(Vector2(0, 120)) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(card, "modulate:a", 1.0, 0.01)
	_fan()
	return card


func remove_card(card: Button) -> void:
	var slot := card.get_parent() as Control
	if slot.has_meta(&"removing"):
		return
	slot.set_meta(&"removing", true)
	card.disabled = true
	card_played.emit(card)
	UiAnim.play_sfx(self, play_sound)
	var t := create_tween().set_parallel()
	t.tween_property(slot, "custom_minimum_size:x", 0.0, duration)
	t.tween_property(card, "offset_transform_position:y", -90.0, duration)
	t.tween_property(card, "modulate:a", 0.0, duration)
	t.chain().tween_callback(slot.queue_free)
	_fan()


func live_slots() -> Array[Control]:
	var out: Array[Control] = []
	for s in get_children():
		if not s.has_meta(&"removing"):
			out.append(s)
	return out


func _fan() -> void:
	var slots := live_slots()
	var mid := (slots.size() - 1) / 2.0
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in slots.size():
		var d := i - mid
		t.tween_property(slots[i], "offset_transform_rotation", deg_to_rad(d * fan_deg), duration)
		t.tween_property(slots[i], "offset_transform_position", Vector2(0, d * d * arc), duration)
