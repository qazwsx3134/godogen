@tool
class_name JuicyButton
extends Button
## hover 擠壓拉伸＋隨機小旋轉，回到 0 度。陰影是 show_behind_parent 的子 node「%Shadow」。
## 動畫只改 visual-only 的 offset_transform：Container 不重排、點擊範圍不跟著縮放抖動。

enum ShadowDir { BOTTOM_RIGHT, BOTTOM_LEFT, BOTTOM }

@export var shadow_dir: ShadowDir = ShadowDir.BOTTOM_RIGHT:
	set(v):
		shadow_dir = v
		_place_shadow()
@export var shadow_offset := 6.0:
	set(v):
		shadow_offset = v
		_place_shadow()
@export var squash := Vector2(0.2, 0.35)  ## x、y 分開的拉伸量
@export var rot_degrees := 5.0            ## 旋轉幅度；方向每次隨機
@export var width_full_rot := 120.0       ## 寬度 ≤ 此值時動畫全幅，越寬越收斂
@export_range(0.75, 1.0, 0.01) var press_scale := 0.88  ## 按住時的縮放比例
@export var pitch_jitter := 0.08          ## 每次 hover 音高隨機 ±此比例，避免聲音死板
@export var hover_sound: AudioStream = preload("res://assets/sfx/hover.ogg")
@export var unhover_sound: AudioStream = preload("res://assets/sfx/unhover.ogg")
@export var press_sound: AudioStream = preload("res://assets/sfx/press.ogg")

var _tween: Tween
var _hover_active := false
var _pressing := false
var last_sfx: AudioStreamPlayer  ## 測試用：最近一次播放的音效


func _ready() -> void:
	_place_shadow()
	UiAnim.enable(self)
	if Engine.is_editor_hint():
		return
	pressed.connect(func(): last_sfx = UiAnim.play_sfx(self, press_sound, 1.0, pitch_jitter))
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	focus_entered.connect(_on_hover.bind(true))
	focus_exited.connect(_on_hover.bind(false))


func scale_ratio() -> float:
	return clampf(width_full_rot / maxf(size.x, 1.0), 0.5, 1.0)


func _on_hover(entered: bool) -> void:
	_hover_active = entered
	if disabled:
		return
	last_sfx = UiAnim.play_sfx(self, hover_sound if entered else unhover_sound, 1.0, pitch_jitter)
	if _pressing:
		return
	var r := scale_ratio()
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if entered:
		# 先拉長 y、壓扁 x，再彈回略大
		_tween.tween_property(self, "offset_transform_scale:x", 1.0 + squash.x * r * 0.5, 0.12).from(1.0 - squash.x * r * 0.5)
		_tween.tween_property(self, "offset_transform_scale:y", 1.0 + squash.y * r * 0.3, 0.12).from(1.0 + squash.y * r)
		_tween.tween_property(self, "offset_transform_rotation", deg_to_rad(rot_degrees * r * [-1.0, 1.0].pick_random()), 0.1)
		_tween.chain().tween_property(self, "offset_transform_rotation", 0.0, 0.12)
	else:
		_tween.tween_property(self, "offset_transform_scale", Vector2.ONE, 0.1)
		_tween.tween_property(self, "offset_transform_rotation", 0.0, 0.1)


func _on_button_down() -> void:
	_pressing = true
	if _tween:
		_tween.kill()
	offset_transform_scale = Vector2.ONE * press_scale
	offset_transform_rotation = 0.0


func _on_button_up() -> void:
	if not _pressing:
		return
	_pressing = false
	var rest := Vector2.ONE
	if _hover_active and not disabled:
		rest += squash * Vector2(0.5, 0.3) * scale_ratio()
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "offset_transform_scale", rest, 0.15)


func _place_shadow() -> void:
	var s := get_node_or_null("%Shadow") as Control
	if s == null:
		return
	var dx: float = {ShadowDir.BOTTOM_RIGHT: 1.0, ShadowDir.BOTTOM_LEFT: -1.0, ShadowDir.BOTTOM: 0.0}[shadow_dir]
	s.offset_left = dx * shadow_offset
	s.offset_right = dx * shadow_offset
	s.offset_top = shadow_offset
	s.offset_bottom = shadow_offset
