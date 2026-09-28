extends Node

const KNIGHT_PATH: String = "res://data/units/knight.tres"
const SLIME_PATH: String = "res://data/units/slime.tres"

var _knight: UnitData
var _slime: UnitData

func hero_by_id(unit_id: String) -> UnitData:
	var hero: UnitData = playable_hero()
	return hero if unit_id == hero.unit_id else null

func enemy_by_id(unit_id: String) -> UnitData:
	var enemy: UnitData = current_enemy()
	return enemy if unit_id == enemy.unit_id else null

func playable_hero() -> UnitData:
	if _knight == null:
		_knight = load(KNIGHT_PATH) as UnitData
	return _knight

func current_enemy() -> UnitData:
	if _slime == null:
		_slime = load(SLIME_PATH) as UnitData
	return _slime
