extends Control
## The 招牌技 callout: when an SSR casts its move, a card slides in from the left under the banner (portrait, the
## move's name, who cast it, what it does), holds, and slides back out. Layout lives in scenes/skill_callout.tscn;
## a new cast replaces the one on screen.

const HOLD := 1.5
const SLIDE := 0.18

@onready var _portrait: TextureRect = %Portrait
@onready var _skill: Label = %SkillName
@onready var _hero: Label = %HeroLine
@onready var _desc: Label = %Desc

var _home_x: float = 0.0
var _tween: Tween


func _ready() -> void:
	_home_x = position.x
	visible = false


## face: the hero's portrait (scripts/portraits.gd).
func show_skill(face: Texture2D, skill_name: String, hero_line: String, desc: String) -> void:
	_portrait.texture = face
	_skill.text = "「%s」" % skill_name
	_hero.text = hero_line
	_desc.text = desc
	visible = true
	if _tween != null:
		_tween.kill()
	position.x = -size.x
	_tween = create_tween()
	_tween.tween_property(self, ^"position:x", _home_x, SLIDE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(HOLD)
	_tween.tween_property(self, ^"position:x", -size.x, SLIDE).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func() -> void: visible = false)


func hide_now() -> void:
	if _tween != null:
		_tween.kill()
	position.x = _home_x
	visible = false
