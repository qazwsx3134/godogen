extends "res://addons/proto_kit/test_kit.gd"

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var main := scene.instantiate()
	# Edit a static property before _ready, as an editor-authored change.
	var title := main.get_node("Interface/Menu/Center/Column/Title") as Label
	title.text = "Editor custom title"
	var column := title.get_parent() as VBoxContainer
	column.add_theme_constant_override("separation", 31)
	root.add_child(main)
	await _frames(2)
	var menu := main.get_node("Interface/Menu") as Control
	var hud := main.get_node("Interface/PreviewHud") as Control
	var arena := main.get_node("Arena") as Node2D
	_expect(menu.visible and not arena.visible and not hud.visible, "starts in menu")
	main.get_node("Interface/Menu/Center/Column/OpenArena").pressed.emit()
	_expect(not menu.visible and arena.visible and hud.visible, "button opens arena")
	main.get_node("Interface/PreviewHud/Row/ReturnToMenu").pressed.emit()
	_expect(menu.visible and not arena.visible and not hud.visible, "button returns to menu")
	_expect(title.text == "Editor custom title", "runtime preserves authored text")
	_expect(column.get_theme_constant("separation") == 31, "runtime preserves authored spacing")
	_expect(arena.get_node("Actors/PlayerPreview").scene_file_path == "res://scenes/actor_placeholder.tscn", "actor remains a sub-scene instance")
	arena.get_node("Actors/PlayerPreview").position = Vector2(17, 33)
	var fresh := (load("res://scenes/arena.tscn") as PackedScene).instantiate()
	_expect(fresh.get_node("Actors/PlayerPreview").position == Vector2.ZERO, "runtime position does not contaminate scene")
	fresh.free()
	main.queue_free()
	await _frames(2)
	_finish("SURVIVOR SCAFFOLD")
