extends RefCounted

static func add_services(tree_root: Window) -> void:
	var services: Array[Array] = [
		["Game", "res://autoload/game.gd"],
		["EventBus", "res://autoload/event_bus.gd"],
		["DataRegistry", "res://autoload/data_registry.gd"],
		["SaveManager", "res://autoload/save_manager.gd"],
		["InventoryManager", "res://autoload/inventory_manager.gd"],
		["ProgressionManager", "res://autoload/progression_manager.gd"],
	]
	for service: Array in services:
		var service_name: String = str(service[0])
		if tree_root.has_node(service_name):
			continue
		var service_script: Script = load(str(service[1])) as Script
		var instance: Node = service_script.new() as Node
		instance.name = service_name
		tree_root.add_child(instance)
