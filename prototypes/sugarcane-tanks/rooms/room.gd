extends Node2D
## One room of the chapter. Layout is authored in the scene: crates under Obstacles,
## enemies under Enemies (dormant until activate), the hero's start under PlayerStart.

@export var boss_room: bool = false
## Multiplies every enemy's HP in this room, so later rooms can reuse the same enemies.
@export var hp_scale: float = 1.0
## Shown as a banner when the chapter enters a new area (宮廟 → 天安門廣場 → 中正紀念堂).
@export var area_name: String = ""

@onready var arena: Node2D = %Arena
@onready var enemies_root: Node2D = %Enemies
@onready var player_start: Marker2D = %PlayerStart

func door() -> Area2D:
	return arena.get_node("%Door") as Area2D

func activate(game: Node, hero: Node2D) -> void:
	for enemy: Node in enemies_root.get_children():
		if enemy.has_method("activate"):
			enemy.activate(game, hero, hp_scale)

## Adds an enemy mid-fight (the boss calling rats) and wakes it up right away.
func add_enemy(enemy: Node2D, at: Vector2, game: Node, hero: Node2D) -> void:
	enemy.position = at
	enemies_root.add_child(enemy)
	enemy.activate(game, hero, hp_scale)

func living_enemies() -> Array[Node2D]:
	var alive: Array[Node2D] = []
	for enemy: Node in enemies_root.get_children():
		if enemy.has_method("activate") and not enemy.dead:
			alive.append(enemy as Node2D)
	return alive
