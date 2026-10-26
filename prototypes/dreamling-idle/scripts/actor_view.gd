@tool
extends Node2D
## This node displays snapshots; it never resolves attacks, HP, or loot.
@export var species_id: String = "moss"
@export var friendly: bool = true
@export var display_name: String = "苔角"
@export var visual_scale: float = 0.36
var actor_uid: String = ""
var _actor: Dictionary = {}
var _last_hit_tick: int = -100
var _view_time: float = 0.0
var _last_action: int = -100
@onready var body: Sprite2D = %Body
@onready var health: ProgressBar = %Health
@onready var name_label: Label = %ActorName
@onready var hit_flash: Polygon2D = %HitFlash


func _ready() -> void:
	name_label.text = display_name
	if not Engine.is_editor_hint(): hit_flash.visible = false


func configure(definition: Dictionary, is_friendly: bool, boss: bool = false) -> void:
	species_id = definition.id
	friendly = is_friendly
	display_name = ("守望巨獸" if boss else definition.name) if not friendly else definition.name
	name_label.text = display_name
	body.texture = load("res://assets/sprites/%s.png" % definition.art)
	body.hframes = 5
	body.flip_h = not friendly
	body.modulate = Color(definition.color) if friendly else Color(1.0, 0.65, 0.72)
	body.scale = Vector2.ONE * visual_scale * (1.25 if boss else 1.0)
	name_label.modulate = Color("e8d491") if boss else (Color("c3edcf") if friendly else Color("f0acba"))


func apply(actor: Dictionary, tick: int) -> void:
	_actor = actor
	actor_uid = actor.uid
	health.max_value = float(actor.max_hp)
	health.value = float(actor.hp)
	var alive: bool = float(actor.hp) > 0.0
	modulate.a = 1.0 if alive else 0.32
	if not alive:
		body.frame = 4
	elif tick - int(actor.action_tick) < 5:
		body.frame = 3
	elif actor.moving:
		body.frame = 1 + (tick / 4) % 2
	else:
		body.frame = 0
	_last_action = int(actor.action_tick)


func flash(tick: int) -> void:
	_last_hit_tick = tick
	hit_flash.visible = true
	var tween: Tween = create_tween()
	hit_flash.modulate.a = 0.8
	tween.tween_property(hit_flash, "modulate:a", 0.0, 0.18)
	tween.tween_callback(func() -> void: hit_flash.visible = false)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _actor.is_empty(): return
	_view_time += delta
	if float(_actor.hp) > 0.0:
		body.position.y = sin(_view_time * 4.0 + float(get_instance_id() % 9)) * 2.0
