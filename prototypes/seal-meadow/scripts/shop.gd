extends RefCounted
## Town shop rules. Each call changes gold and bag together or not at all.
## Returns "" on success, else why not: not_sold, gold, bag_full, none, cant_sell.

const Items = preload("res://scripts/items.gd")


static func buy(player: Node, id: String, amount: int = 1) -> String:
	if not Items.SHOP.has(id) or amount <= 0:
		return "not_sold"
	var cost: int = Items.ALL[id].buy * amount
	if player.gold < cost:
		return "gold"
	if not player.bag.add(id, amount):
		return "bag_full"
	player.gold -= cost
	return ""


static func sell(player: Node, id: String, amount: int = 1) -> String:
	if not Items.ALL.has(id) or not Items.ALL[id].has("sell"):
		return "cant_sell"
	if not player.bag.remove(id, amount):
		return "none"
	player.gold += Items.ALL[id].sell * amount
	return ""


## Sells every stack whose item is a material (no slot, no heal). Returns the gold earned.
static func sell_materials(player: Node) -> int:
	var earned := 0
	for s: Dictionary in player.bag.slots.duplicate(true):
		var def: Dictionary = Items.ALL[s.id]
		if not def.has("slot") and not def.has("heal"):
			var before: int = player.gold
			if sell(player, s.id, s.count) == "":
				earned += player.gold - before
	return earned
