extends Node2D
## One fighter on the 行軍 strip (scenes/march_unit.tscn; Taskbar Hero's party unit). A hero shows %HeroSprite, a
## cell of assets/heroes/heroes.png (the same pixel art as in the push); a monster shows one of the Visuals cut from
## the reference art (Polygon2D outlines). The bar over the head is its HP; pop() floats a damage or reward number.
## scripts/march_arena.gd moves and animates it from domain/march_sim.gd; nothing here reads the simulation.

const LOOKS := ["KnightVisual", "SlimeVisual", "PetVisual", "FoxVisual", "AquaVisual", "MushroomVisual", "SoldierVisual",
	"DummyVisual"]
const CELL := 48
const POP_TIME := 0.7
const BAR_SCALE := Vector2(1.3, 1.1)
const BAR_HALF := 24.0

## "Hero" or one of LOOKS.
@export var appearance: String = "Hero"
var _pop_t: float = -1.0

@onready var _sprite: Sprite2D = %HeroSprite
@onready var _fill: Polygon2D = %HealthFill
@onready var _feedback: Label = $DamageFeedback


func _ready() -> void:
	set_appearance(appearance)


func set_appearance(look: String) -> void:
	appearance = look
	for name: String in LOOKS:
		var node: Node2D = get_node_or_null(NodePath("Visuals/" + name))
		if node != null:
			node.visible = name == look
	_sprite.visible = look == "Hero"


## Shows heroes.png cell `cell` (column) of `row`, tinted.
func set_hero_cell(row: int, cell: int, tint: Color) -> void:
	_sprite.region_rect = Rect2(cell * CELL, row * CELL, CELL, CELL)
	_sprite.self_modulate = tint


func set_health(ratio: float) -> void:
	var r: float = clampf(ratio, 0.0, 1.0)
	_fill.scale = Vector2(BAR_SCALE.x * r, BAR_SCALE.y)
	_fill.position.x = -BAR_HALF * BAR_SCALE.x * (1.0 - r)


func pop(text: String, color: Color) -> void:
	_feedback.text = text
	_feedback.add_theme_color_override(&"font_color", color)
	_feedback.visible = true
	_pop_t = 0.0


func _process(delta: float) -> void:
	if _pop_t < 0.0:
		return
	_pop_t += delta
	_feedback.modulate.a = 1.0 - _pop_t / POP_TIME
	_feedback.position.y = -155.0 - _pop_t * 40.0
	if _pop_t >= POP_TIME:
		_pop_t = -1.0
		_feedback.visible = false
