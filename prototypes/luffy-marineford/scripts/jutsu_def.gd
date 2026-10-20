class_name JutsuDef
extends Resource
## One of Luffy's moves (docs/one-piece-marineford/README.md 魯夫的招式). Its numbers live in jutsu.gd per kind; this
## holds what the cards say: each level's text describes what CHANGES on screen, never only "+20%".
## The ints are saved in data/jutsu/*.tres: append new kinds, never reorder.

enum Kind { PISTOL, GATLING, BAZOOKA, GIGANT, WHIP, HAKI, GEAR2 }

@export var id: StringName
@export var title: String
@export var kind: Kind = Kind.PISTOL
## Card text for learning it (level 1).
@export_multiline var summary: String
## Card text for reaching level 2, 3, 4, 5 (index 0 = level 2).
@export var level_texts: PackedStringArray = PackedStringArray()
@export var max_level: int = 5
## The card is only offered from this player level on (99: never a card, e.g. the story's Haki).
@export var min_player_level: int = 0


func text_for(level: int) -> String:
	if level <= 1:
		return summary
	var i: int = level - 2
	return level_texts[i] if i < level_texts.size() else summary
