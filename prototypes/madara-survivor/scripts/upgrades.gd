class_name Upgrades
extends Node
## Level-up cards. Each card is one of:
##   {"jutsu": JutsuDef, "level": 1}        learn a new jutsu (needs a free slot)
##   {"jutsu": JutsuDef, "level": n}        raise a learned jutsu (the card shows what changes on screen)
##   {"passive": PassiveDef, "level": n}    a stat for every jutsu (chakra, speed...)
## Pacing (docs/naruto/skill-progression.md): at the player levels in `new_jutsu_levels` one card is always a new
## jutsu, so the first minutes hold at least two "I learned something" moments.

@export var jutsu: Jutsu
@export var jutsu_pool: Array[JutsuDef] = []
@export var pool: Array[PassiveDef] = []
@export var new_jutsu_levels: PackedInt32Array = PackedInt32Array([2, 4])

var owned: Array[PassiveDef] = []
var levels := PackedInt32Array()


func add(def: PassiveDef) -> void:
	var i: int = owned.find(def)
	if i >= 0:
		levels[i] = mini(levels[i] + 1, def.max_level)
	else:
		owned.append(def)
		levels.append(1)


func apply(option: Dictionary) -> void:
	if option.has("jutsu"):
		jutsu.learn(option.jutsu)
	else:
		add(option.passive)


func stat(which: PassiveDef.Stat) -> float:
	var total: float = 0.0
	for i: int in owned.size():
		if owned[i].stat == which:
			total += owned[i].per_level * levels[i]
	return total


func total_levels() -> int:
	var n: int = 0
	for l: int in levels:
		n += l
	for l: int in jutsu.levels:
		n += l
	return n


## Up to `n` cards for reaching `player_level`.
func roll(rng: RandomNumberGenerator, player_level: int, n: int = 3) -> Array[Dictionary]:
	var new_ones: Array[Dictionary] = []
	var others: Array[Dictionary] = []
	for def: JutsuDef in jutsu_pool:
		if def.min_player_level > player_level:
			continue
		var level: int = jutsu.level_of(def)
		if level == 0 and jutsu.has_free_slot():
			new_ones.append({"jutsu": def, "level": 1})
		elif level > 0 and level < def.max_level:
			others.append({"jutsu": def, "level": level + 1})
	for def: PassiveDef in pool:
		var i: int = owned.find(def)
		var level: int = levels[i] if i >= 0 else 0
		if level < def.max_level:
			others.append({"passive": def, "level": level + 1})
	var picked: Array[Dictionary] = []
	if player_level in new_jutsu_levels and not new_ones.is_empty():
		picked.append(new_ones.pop_at(rng.randi_range(0, new_ones.size() - 1)))
	others.append_array(new_ones)
	while picked.size() < n and not others.is_empty():
		picked.append(others.pop_at(rng.randi_range(0, others.size() - 1)))
	return picked
