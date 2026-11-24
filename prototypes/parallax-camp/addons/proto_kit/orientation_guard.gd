extends CanvasLayer
## Covers the game and asks the player to rotate when a phone is held the wrong way (the game is laid out for one
## orientation). Blocks input while shown. Touch devices only by default: desktop windows of any shape are left alone.
## Instance orientation_guard.tscn at the root of the main scene; set `message` / `want_landscape` there.
## Does not pause the game: a running round keeps going behind the cover.
## Extracted from kagura-dango (2026-11-04).

@export var want_landscape := true
@export_multiline var message := "請把手機轉成橫向\n才能遊玩"
## false: also cover on desktop when the window has the wrong shape.
@export var touch_only := true


func _ready() -> void:
	visible = false
	%Message.text = message
	if touch_only and not is_touch_device():
		return
	get_viewport().size_changed.connect(_refresh)
	_refresh()


static func is_touch_device() -> bool:
	return OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile")


## True when a viewport of this size has the wrong orientation.
func wrong_way(size: Vector2) -> bool:
	return size.y > size.x if want_landscape else size.x > size.y


func _refresh() -> void:
	visible = wrong_way(get_viewport().get_visible_rect().size)
