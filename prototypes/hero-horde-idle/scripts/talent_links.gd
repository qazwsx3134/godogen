extends Control
## The 天賦 star map's edges (scenes/pages/train.tscn, %TalentTree): a line from each node to every node it opens
## (domain/talents.gd `need`), gold once the need is met, grey before. The nodes are this control's children named
## Node<k>; move them in the editor and the lines follow. `levels` is set by the page before queue_redraw().

const Talents = preload("res://domain/talents.gd")
const LIT := Color("e8b850")
const DARK := Color(0.45, 0.4, 0.34, 0.6)
const WIDTH := 6.0

var levels := PackedInt32Array()


func _draw() -> void:
	for k: int in Talents.count():
		var to: Control = get_node_or_null("Node%d" % k)
		if to == null:
			continue
		var need: Dictionary = Talents.ROWS[k].need
		for r: int in need:
			var from: Control = get_node_or_null("Node%d" % r)
			if from == null:
				continue
			var met: bool = levels.size() > r and levels[r] >= need[r]
			draw_line(_center(from), _center(to), LIT if met else DARK, WIDTH, true)


func _center(c: Control) -> Vector2:
	return c.position + Vector2(c.size.x * 0.5, c.size.x * 0.45)
