extends VBoxContainer
## One pulled hero on the 招募 page (scenes/pull_card.tscn: the 近期獲得 row and the results): the hero's card
## (hero_card.tscn: rarity as the background colour, no frame), the name, and what the pull brought.

const PushSim = preload("res://domain/push_sim.gd")
const Progression = preload("res://domain/progression.gd")

@onready var _card: Button = %Card
@onready var _name: Label = %HeroName
@onready var _note: Label = %Note


## i = -1 hides the card and leaves an empty place. `rarity` = the rarity it was pulled at (-1 = the hero's now).
func show_pull(i: int, hero_name: String, progress: RefCounted, note: String, rarity: int = -1) -> void:
	modulate.a = 1.0 if i >= 0 else 0.0
	if i < 0:
		return
	var r: int = rarity if rarity >= 0 else progress.rarity(i)
	_card.show_hero(i, Progression.base_class(i), hero_name, r, PushSim.RARITY_NAMES[r], progress.hero_level[i],
		progress.ascension[i], false, progress.is_captain(i))
	_name.text = hero_name
	_note.text = note
	_note.visible = note != ""
