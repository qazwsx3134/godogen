class_name EnemyDef
extends Resource
## One enemy type of the horde. Enemies are not nodes: Horde keeps them in arrays and draws them with one
## MultiMesh, so everything that differs between types lives here.

@export var id: StringName
## Cell index in assets/sprites/atlas.png (row * 4 + col).
@export var frame: int = 1
@export var hp: float = 12.0
## Meters per second.
@export var speed: float = 3.0
## Sprite height in meters; the shadow and the hit radius scale with it.
@export var size: float = 1.4
@export var radius: float = 0.45
## Damage per touch (the player is then invulnerable for a moment).
@export var damage: float = 6.0
@export var xp: int = 1
## 0 = full knockback, 1 = cannot be pushed.
@export_range(0.0, 1.0) var knockback_resist: float = 0.0
@export var tint: Color = Color.WHITE
## Seconds into the run before this type joins the spawn mix, and its share of the mix after that.
@export var appears_at: float = 0.0
@export var weight: float = 1.0
## Elites are spawned on a schedule, never by the random mix.
@export var elite: bool = false
