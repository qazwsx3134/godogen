extends RefCounted
## Presentation geometry only. Story progression and rewards stay with StoryRunner.

static func hit_rect(spot: Control, minimum_side: float) -> Rect2:
	var rect: Rect2 = spot.get_global_rect()
	var grow: Vector2 = (Vector2(minimum_side, minimum_side) - rect.size).max(Vector2.ZERO) * 0.5
	return rect.grow_individual(grow.x, grow.y, grow.x, grow.y)


## Objects beat portraits, smaller object targets beat larger ones, front portraits beat back ones.
## Already found targets only remain interactive when they have repeatable lines.
static func pick(at: Vector2, spots: Dictionary, definitions: Dictionary, sprites: Dictionary, minimum_side: float) -> String:
	var selected := ""
	var selected_rank := INF
	for id: String in spots:
		var spot: Control = spots[id] as Control
		if not spot.is_visible_in_tree():
			continue
		var data: Dictionary = definitions.get(id, {})
		if bool(spot.get("found")) and not data.has("lines"):
			continue
		var rect := hit_rect(spot, minimum_side)
		var rank: float = rect.get_area() if not data.has("character") else 1.0e9 - sprites[data["character"]].get_index()
		if rect.has_point(at) and rank < selected_rank:
			selected = id
			selected_rank = rank
	return selected
