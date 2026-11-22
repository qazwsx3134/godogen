extends Control

const OPEN := preload("res://assets/sfx/open.ogg")
const CLOSE := preload("res://assets/sfx/close.ogg")

var _count := 0


func _ready() -> void:
	%Plus.pressed.connect(func():
		_count += 1
		%Counter.text = str(_count))
	%MenuToggle.pressed.connect(_set_overlay.bind(%Overlay, true))
	%Back.pressed.connect(_set_overlay.bind(%Overlay, false))
	%Bag.pressed.connect(_set_overlay.bind(%BagOverlay, true))
	%Inventory.closed.connect(_set_overlay.bind(%BagOverlay, false))
	for ov: Control in [%Overlay, %BagOverlay]:
		ov.get_node("Dim").gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed:
				_set_overlay(ov, false))
	var n := 0
	for i in 5:
		n += 1
		%Hand.add_card(str(n))
	%Draw.pressed.connect(func():
		n += 1
		%Hand.add_card(str(n)))


func _set_overlay(ov: Control, open: bool) -> void:
	if ov.visible == open:
		return
	ov.visible = open
	UiAnim.play_sfx(self, OPEN if open else CLOSE, 1.0, 0.05)
	if open:  # 背景淡入；面板內容由 ContainerTween／AutoTween 依 visibility 自己播
		var dim: Control = ov.get_node("Dim")
		dim.create_tween().tween_property(dim, "modulate:a", 1.0, 0.12).from(0.0)
