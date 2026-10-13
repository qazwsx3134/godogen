extends Control
## Run HUD: Game writes the numbers into the labels; this keeps the weapon and passive slots and the elite bar.
@export var slot_scene: PackedScene
@export var passive_slot_scene: PackedScene
@onready var weapons: HBoxContainer = %Weapons
@onready var passives: HBoxContainer = %Passives
@onready var elite_bar: ProgressBar = %EliteBar
var _shown: Dictionary = {}

## Rebuilds the slots when the build gained an item or a level; changed slots pop.
func show_build(build: RefCounted) -> void:
	var now: Dictionary = {}
	for id: StringName in build.weapons + build.passives:
		now[id] = build.count(id)
	if now == _shown:
		return
	_fill(weapons, slot_scene, build, build.weapons, now)
	_fill(passives, passive_slot_scene, build, build.passives, now)
	_shown = now

func clear_build() -> void:
	_shown = {}
	for row: Node in [weapons, passives]:
		for child: Node in row.get_children():
			child.queue_free()

func _fill(row: HBoxContainer, scene: PackedScene, build: RefCounted, ids: Array[StringName], now: Dictionary) -> void:
	for child: Node in row.get_children():
		row.remove_child(child)
		child.queue_free()
	for id: StringName in ids:
		var slot := scene.instantiate() as Control
		row.add_child(slot)
		slot.setup(build.definition(id), now[id])
		if not _shown.is_empty() and int(_shown.get(id, 0)) != now[id]:
			slot.flash()

## Elite health across the top while one is alive; `elite` null hides it.
func show_elite(elite: Node2D) -> void:
	elite_bar.visible = elite != null
	if elite != null:
		elite_bar.max_value = elite.max_hp
		elite_bar.value = elite.hp
