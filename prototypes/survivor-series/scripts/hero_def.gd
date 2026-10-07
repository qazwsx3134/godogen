extends Resource
## One playable hero: opening weapon, stat personality and swing feel. Looks live in player.tscn (Body<id>).
@export var id: StringName = &"man"
@export var display_name: String = ""
@export var tagline: String = ""
@export var start_weapon: StringName = &"punch"
@export_range(0.5, 2.0, 0.05) var hp_scale: float = 1.0
@export_range(0.5, 2.0, 0.05) var speed_scale: float = 1.0
## How far the fist travels on a swing, and whether it overshoots and snaps back.
@export var swing_reach: float = 27.0
@export var swing_overshoot: bool = true
