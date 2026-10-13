extends Sprite2D
## A street prop, anchored at its foot so it depth-sorts with the hero and enemies.
## Solid props push walkers out of `solid_rect`; breakable ones (`hp` > 0) take weapon hits and drop loot.
## Map owns the queries; Street applies damage and drops.
## Blocking area around the foot point, in the prop's own coordinates; zero size = walk-through.
@export var solid_rect := Rect2()
## Hits needed to break, as weapon damage; 0 = cannot break.
@export var hp: float = 0.0
## Radius around the foot point that weapons must touch to hit it.
@export var hit_radius: float = 20.0
@export_group("Drops")
@export var xp: float = 0.0
@export var coins: int = 0
@export_range(0.0, 1.0) var food_chance: float = 0.0
@export_range(0.0, 1.0) var magnet_chance: float = 0.0
## Set by Map: identifies this prop in its chunk so a broken prop stays broken when the chunk is rebuilt.
var key: String = ""
var _hurt_left: float = 0.0
var _flash: Tween

func breakable() -> bool:
	return hp > 0.0

func solid() -> bool:
	return solid_rect.has_area()

## Applies a hit unless one landed in the last 0.25 s. True when this hit breaks the prop.
func damage(amount: float) -> bool:
	if hp <= 0.0 or _hurt_left > 0.0:
		return false
	_hurt_left = 0.25
	hp -= amount
	if _flash != null and _flash.is_valid():
		_flash.kill()
	modulate = Color(2.0, 1.8, 1.4)
	scale = Vector2(1.12, 0.9)
	_flash = create_tween().set_parallel(true)
	_flash.tween_property(self, "modulate", Color.WHITE, 0.15)
	_flash.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return hp <= 0.0

func tick(delta: float) -> void:
	_hurt_left = maxf(0.0, _hurt_left - delta)
