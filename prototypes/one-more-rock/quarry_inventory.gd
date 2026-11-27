extends RefCounted

const PACK_CAPACITY := 5
const CART_CAPACITY := 20
const STORAGE_CAPACITY := 30

var pack: Array[int] = []
var cart: Array[int] = []
var storage: Array[int] = []
var next_id := 0
var pack_capacity := PACK_CAPACITY
var cart_capacity := CART_CAPACITY
var storage_capacity := STORAGE_CAPACITY
var reserved_pack := 0
var reserved_cart := 0
var reserved_storage := 0
var rare_ids: Dictionary[int, bool] = {}
var known_minerals: Dictionary[int, int] = {}


func collect(using_cart: bool, rare := false) -> bool:
	if not reserve_collection(using_cart):
		return false
	finish_collection(using_cart, rare)
	return true


func reserve_collection(using_cart: bool) -> bool:
	if not has_room(using_cart):
		return false
	if using_cart:
		reserved_cart += 1
	else:
		reserved_pack += 1
	return true


func finish_collection(using_cart: bool, rare: bool, mineral := -1) -> void:
	if using_cart:
		reserved_cart -= 1
	else:
		reserved_pack -= 1
	var destination := cart if using_cart else pack
	var id := _new_ore(rare and mineral != 2)
	if mineral >= 2:
		known_minerals[id] = mineral
	destination.append(id)


func _new_ore(rare: bool) -> int:
	var id := next_id
	if rare:
		rare_ids[id] = true
	next_id += 1
	return id


func has_room(using_cart: bool) -> bool:
	return cart.size() + reserved_cart < cart_capacity if using_cart else pack.size() + reserved_pack < pack_capacity


func unload(cart_present: bool) -> int:
	var before := storage.size()
	_store(pack)
	if cart_present:
		_store(cart)
	return storage.size() - before


func _store(source: Array[int]) -> void:
	while not source.is_empty() and has_storage_room():
		storage.append(source.pop_front())


func has_storage_room() -> bool:
	return storage.size() + reserved_storage < storage_capacity


func reserve_storage_slot() -> bool:
	if not has_storage_room():
		return false
	reserved_storage += 1
	return true


func deliver_reserved_ore() -> void:
	reserved_storage -= 1
	storage.append(_new_ore(false))


func stone_hardness(id: int) -> int:
	if known_minerals.has(id):
		return known_minerals[id]
	if rare_ids.has(id):
		return 3
	return 2 if id % 5 == 4 else 1


func take_known_mineral(id: int) -> int:
	var mineral: int = known_minerals.get(id, 3 if rare_ids.has(id) else -1)
	known_minerals.erase(id)
	rare_ids.erase(id)
	return mineral


func take_stored(max_hardness: int) -> int:
	for index in storage.size():
		var id := storage[index]
		if stone_hardness(id) <= max_hardness:
			storage.remove_at(index)
			return id
	return -1
