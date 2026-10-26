extends RefCounted
## Permanent upgrades from {id, max_level, cost_base, cost_growth, adj, effect} nodes.
## `const UpgradeTree = preload("res://addons/proto_kit/upgrade_tree.gd")`
## Edges are undirected; a graph requires an explicit root. Costs may override each level.

var _nodes: Dictionary = {}
var _levels: Dictionary = {}
var _root: String
var configuration_error: String = ""

func _init(nodes: Array[Dictionary], options: Dictionary = {}) -> void:
	_root = str(options.get("root", ""))
	for node: Dictionary in nodes:
		_nodes[str(node.id)] = node.duplicate(true)
		if _root.is_empty() and not node.get("adj", []).is_empty() and configuration_error.is_empty():
			configuration_error = "UpgradeTree: adjacency requires an explicit root"
			push_error(configuration_error)

func _level(id: String) -> int:
	return int(_levels.get(id, 0))

func _price(id: String, at_level: int) -> int:
	var node: Dictionary = _nodes[id]
	var costs: Array = node.get("costs", [])
	if at_level < costs.size():
		return int(costs[at_level])
	return int(round(float(node.get("cost_base", 0.0)) * pow(float(node.get("cost_growth", 1.0)), at_level)))

func cost(id: String) -> int:
	if not _nodes.has(id) or _level(id) >= int(_nodes[id].get("max_level", 1)):
		return -1
	return _price(id, _level(id))

func is_available(id: String) -> bool:
	if not _nodes.has(id):
		return false
	var neighbors: Array = _nodes[id].get("adj", []).duplicate()
	for other: String in _nodes:
		if id in _nodes[other].get("adj", []) and other not in neighbors:
			neighbors.append(other)
	if neighbors.is_empty() and _root.is_empty():
		return true
	if id == _root:
		return true
	for neighbor: Variant in neighbors:
		if (not _root.is_empty() and str(neighbor) == _root) or _level(str(neighbor)) > 0:
			return true
	return false

func can_buy(id: String, currency: int) -> bool:
	return cost(id) >= 0 and is_available(id) and currency >= cost(id)

func buy(id: String, currency: int) -> Dictionary:
	var reason: String = ""
	if cost(id) < 0:
		reason = "maxed"
	elif not is_available(id):
		reason = "locked"
	elif currency < cost(id):
		reason = "short"
	if not reason.is_empty():
		return {"ok": false, "spent": 0, "remaining": currency, "reason": reason}
	var spent: int = cost(id)
	_levels[id] = _level(id) + 1
	return {"ok": true, "spent": spent, "remaining": currency - spent, "reason": ""}

func _effects(id: String, at_level: int) -> Dictionary:
	var result: Dictionary = {}
	for stat: String in _nodes.get(id, {}).get("effect", {}):
		result[stat] = float(_nodes[id].effect[stat]) * at_level
	return result

func preview(id: String, currency: int) -> Dictionary:
	var price: int = cost(id)
	return {"level": _level(id), "max": int(_nodes.get(id, {}).get("max_level", 0)), "cost": price, "short_by": maxi(0, price - currency), "now": _effects(id, _level(id)), "after": _effects(id, _level(id) + int(price >= 0))}

func totals() -> Dictionary:
	var result: Dictionary = {}
	for id: String in _nodes:
		var effects: Dictionary = _effects(id, _level(id))
		for stat: String in effects:
			result[stat] = float(result.get(stat, 0.0)) + float(effects[stat])
	return result

func count_bought() -> int:
	var count: int = 0
	for id: String in _levels:
		count += _level(id)
	return count

func respec() -> int:
	var refund: int = 0
	for id: String in _levels:
		for at_level: int in range(_level(id)):
			refund += _price(id, at_level)
	_levels.clear()
	return refund

func to_dict() -> Dictionary:
	return {"levels": _levels.duplicate()}

func from_dict(data: Dictionary) -> void:
	_levels.clear()
	for id: String in data.get("levels", {}):
		if _nodes.has(id):
			_levels[id] = clampi(int(data.levels[id]), 0, int(_nodes[id].get("max_level", 1)))
