extends Resource
## One level-up choice. The effect itself lives in domain/hero_stats.gd, keyed by `id`;
## this resource only carries what the card shows and how often it can stack.

@export var id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = ""
@export var color: Color = Color(0.8, 0.8, 0.8)
## Picture for the HUD ability slot (the art carries its own rounded frame). While empty, the
## slot shows a square in `color` with the first letter of `title`.
@export var icon: Texture2D
@export_range(1, 99, 1) var max_stacks: int = 1
## Offered only while the hero is hurt (the heal card).
@export var needs_missing_hp: bool = false
