extends Node2D
## Erwin on horseback. main.gd calls step(); jump()/slash() return false when the input is refused.
## Origin = hooves on the ground line.

signal landed

const JUMP_V := -560.0
const GRAVITY := 1700.0
const SLASH_ACTIVE := 0.2     # seconds the blade can cut / parry
const SLASH_RECOVER := 0.24   # after that, no new slash: an early swing leaves you open
const IFRAMES := 1.3

@onready var body: Node2D = %Body
@onready var gallop: Sprite2D = %Gallop
@onready var action: Sprite2D = %Action
@onready var shout_label: Label = %Shout

var ground_y := 0.0
var vy := 0.0
var air := false
var slash_t := -1.0
var hurt_t := 99.0
var anim_t := 0.0
var gait := 1.0       # gallop animation speed factor (slows to a halt in cutscenes)
var alive := true
var squash := 0.0
var _shout_tween: Tween


func _ready() -> void:
	ground_y = position.y


func reset() -> void:
	position.y = ground_y
	vy = 0.0
	air = false
	slash_t = -1.0
	hurt_t = 99.0
	alive = true
	gait = 1.0
	rotation = 0.0
	modulate = Color.WHITE
	body.scale = Vector2.ONE
	if _shout_tween:
		_shout_tween.kill()
	shout_label.visible = false


## A battle cry over Erwin's head: pops in, shakes, then fades.
func shout(text: String, seconds: float = 1.3) -> void:
	if _shout_tween:
		_shout_tween.kill()
	shout_label.text = text
	shout_label.visible = true
	shout_label.modulate.a = 1.0
	shout_label.scale = Vector2(0.3, 0.3)
	_shout_tween = create_tween()
	_shout_tween.tween_property(shout_label, "scale", Vector2(1.15, 1.15), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in 4:
		_shout_tween.tween_property(shout_label, "rotation", 0.06 if i % 2 == 0 else -0.06, 0.05)
	_shout_tween.tween_property(shout_label, "rotation", 0.0, 0.05)
	_shout_tween.tween_property(shout_label, "scale", Vector2.ONE, 0.1)
	_shout_tween.tween_interval(seconds)
	_shout_tween.tween_property(shout_label, "modulate:a", 0.0, 0.3)
	_shout_tween.tween_callback(shout_label.hide)


func jump() -> bool:
	if air or not alive:
		return false
	vy = JUMP_V
	air = true
	squash = -0.12
	return true


func slash() -> bool:
	if not alive or (slash_t >= 0.0 and slash_t < SLASH_ACTIVE + SLASH_RECOVER):
		return false
	slash_t = 0.0
	return true


func slash_active() -> bool:
	return slash_t >= 0.0 and slash_t < SLASH_ACTIVE


func invulnerable() -> bool:
	return hurt_t < IFRAMES


func hurt() -> void:
	hurt_t = 0.0


## Where Erwin can be hit (rider + horse body, a little forgiving).
func hurtbox() -> Rect2:
	return Rect2(position + Vector2(-30.0, -72.0), Vector2(60.0, 66.0))


## Where the blade reaches during an active slash.
func slash_zone() -> Rect2:
	return Rect2(position + Vector2(6.0, -128.0), Vector2(116.0, 136.0))


func blade_tip() -> Vector2:
	return position + Vector2(44.0, -62.0)


func step(delta: float) -> void:
	if air:
		vy += GRAVITY * delta
		position.y += vy * delta
		if position.y >= ground_y:
			position.y = ground_y
			air = false
			vy = 0.0
			squash = 0.16
			landed.emit()
	if slash_t >= 0.0:
		slash_t += delta
		if slash_t > SLASH_ACTIVE + SLASH_RECOVER:
			slash_t = -1.0
	hurt_t += delta
	anim_t += delta * gait
	squash = move_toward(squash, 0.0, delta * 1.2)
	_show()


func _show() -> void:
	var pose := -1
	if not alive or hurt_t < 0.32:
		pose = 2
	elif slash_t >= 0.0 and slash_t < 0.3:
		pose = 1
	elif air:
		pose = 0
	action.visible = pose >= 0
	gallop.visible = pose < 0
	if pose >= 0:
		action.frame = pose
	else:
		gallop.frame = int(anim_t * 13.0) % gallop.hframes
	body.scale = Vector2(1.0 + squash, 1.0 - squash)
	var blink := invulnerable() and alive and int(hurt_t * 14.0) % 2 == 0
	body.modulate.a = 0.35 if blink else 1.0
