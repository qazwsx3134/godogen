extends Node3D
## 滑鼠（或觸控）投影到地面 y=0，洞跟過去。

@export var follow_mouse := true  ## 測試與自動擷取關掉

@onready var _cam: Camera3D = %Camera
@onready var _hole: HoleBody = %Hole


func _ready() -> void:
	%Abyss.body_entered.connect(_hole._on_kill)
	_hole.ate.connect(func(_b): %Score.text = "Eaten: %d" % _hole.eaten)


func _process(_d: float) -> void:
	if not follow_mouse:
		return
	var m := get_viewport().get_mouse_position()
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(_cam.project_ray_origin(m), _cam.project_ray_normal(m))
	if hit != null:
		_hole.target = hit
