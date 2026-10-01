extends CanvasLayer
## On-screen controls and the spot's title card. bind() connects them to a Viewer.

@export var telescope_fov := 24.0

var viewer: Node3D
var _fov_tween: Tween


func bind(spot: Node3D, target_viewer: Node3D) -> void:
	viewer = target_viewer
	%TitleLabel.text = spot.display_name
	%CardTitle.text = spot.display_name
	%CardSubtitle.text = spot.subtitle
	%CardIntro.text = spot.intro
	%CardSource.text = spot.source_note
	%MoveStick.changed.connect(func(v: Vector2) -> void: viewer.move_input = v)
	%LookPad.look.connect(viewer.look)
	%LookPad.zoom.connect(viewer.zoom)
	%ZoomButton.pressed.connect(_toggle_telescope)
	%ResetButton.pressed.connect(_reset)
	%InfoButton.pressed.connect(func() -> void: %InfoCard.visible = not %InfoCard.visible)
	%EnterButton.pressed.connect(func() -> void: %InfoCard.visible = false)


func _toggle_telescope() -> void:
	var target: float = viewer.fov_default if viewer.is_zoomed() else telescope_fov
	_tween_fov(target)


func _reset() -> void:
	viewer.reset_view()


func _tween_fov(target: float) -> void:
	if _fov_tween:
		_fov_tween.kill()
	_fov_tween = create_tween()
	_fov_tween.tween_method(viewer.set_fov, viewer.camera.fov, target, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
