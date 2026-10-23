extends Label3D
## A captain's nameplate (pooled under main.tscn's CaptainPlates): 隊長‧name with a ▼ down to their head, following
## them;
## greyed once they fall. The colour set in the scene is the living captain's colour.

const DOWN := Color(0.55, 0.55, 0.55)

var _color := Color.WHITE


func _ready() -> void:
	_color = modulate


func show_captain(at: Vector3, hero_name: String, alive: bool) -> void:
	text = "隊長‧%s\n▼" % hero_name
	position = at
	modulate = _color if alive else _color * DOWN
	visible = true
