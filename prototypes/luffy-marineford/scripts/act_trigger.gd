@tool
class_name ActTrigger
extends Marker3D
## A place on the route where story happens: when the player reaches it (its Z along the act's heading), its Beat
## children run in order. `on_start` runs at the act's start instead. `goal_name` shows in the HUD goal bar while
## it is the next trigger ahead (empty = not a goal, e.g. a mid-route shout).

@export var on_start: bool = false
@export var goal_name: String = ""

var fired: bool = false


func beats() -> Array[Beat]:
	var out: Array[Beat] = []
	for child: Node in get_children():
		if child is Beat:
			out.append(child)
	return out
