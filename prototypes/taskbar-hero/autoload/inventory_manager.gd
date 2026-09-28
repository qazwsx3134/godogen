extends Node

signal inventory_changed(item_count: int)

var _items_by_uid: Dictionary = {}

func add_item(item_uid: String, item_id: String, properties: Dictionary = {}) -> bool:
	if item_uid.is_empty() or item_id.is_empty() or _items_by_uid.has(item_uid):
		return false
	_items_by_uid[item_uid] = {
		"uid": item_uid,
		"item_id": item_id,
		"properties": properties.duplicate(true),
	}
	inventory_changed.emit(_items_by_uid.size())
	return true

func remove_item(item_uid: String) -> bool:
	if not _items_by_uid.has(item_uid):
		return false
	_items_by_uid.erase(item_uid)
	inventory_changed.emit(_items_by_uid.size())
	return true

func contains(item_uid: String) -> bool:
	return _items_by_uid.has(item_uid)

func item_count() -> int:
	return _items_by_uid.size()

func items_snapshot() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for item: Dictionary in _items_by_uid.values():
		snapshot.append(item.duplicate(true))
	return snapshot
