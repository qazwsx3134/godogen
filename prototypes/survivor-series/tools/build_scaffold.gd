extends SceneTree
## One-time authoring tool. Existing scenes are skipped to preserve editor changes.
const Builder = preload("res://addons/proto_kit/scene_builder.gd")

func _initialize() -> void:
	build.call_deferred()

func build() -> void:
	var actor := Node2D.new()
	actor.name = "ActorPlaceholder"
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([Vector2(0, -22), Vector2(18, 16), Vector2(-18, 16)])
	body.color = Color(0.3, 0.8, 0.7)
	Builder.add(actor, body, "Visual")
	if not Builder.save_scene(actor, "res://scenes/actor_placeholder.tscn").ok:
		quit(1)
		return
	var arena := Node2D.new()
	arena.name = "Arena"
	var floor := Polygon2D.new()
	floor.polygon = PackedVector2Array([Vector2(-400, -230), Vector2(400, -230), Vector2(400, 230), Vector2(-400, 230)])
	floor.color = Color(0.1, 0.15, 0.2)
	Builder.add(arena, floor, "Floor")
	for group_name: String in ["Actors", "Projectiles", "Pickups", "Effects"]:
		Builder.add(arena, Node2D.new(), group_name)
	var player := Builder.instance("res://scenes/actor_placeholder.tscn") as Node2D
	Builder.add(arena.get_node("Actors"), player, "PlayerPreview")
	var enemy := Builder.instance("res://scenes/actor_placeholder.tscn") as Node2D
	enemy.position = Vector2(180, -100)
	enemy.modulate = Color(1.0, 0.4, 0.4)
	Builder.add(arena.get_node("Actors"), enemy, "EnemyPreview")
	var camera := Camera2D.new()
	Builder.add(arena, camera, "Camera")
	if not Builder.save_scene(arena, "res://scenes/arena.tscn", {"expected_refs": ["res://scenes/actor_placeholder.tscn"]}).ok:
		quit(1)
		return
	var main := Node.new()
	main.name = "SurvivorSeries"
	main.set_script(load("res://scripts/main.gd"))
	arena = Builder.instance("res://scenes/arena.tscn") as Node2D
	arena.visible = false
	Builder.add(main, Builder.unique(arena), "Arena")
	var services := Node.new()
	Builder.add(main, services, "Services")
	var time_control := Node.new()
	time_control.set_script(load("res://addons/proto_kit/time_control.gd"))
	time_control.process_mode = Node.PROCESS_MODE_ALWAYS
	Builder.add(services, time_control, "TimeControl")
	var music := Node.new()
	music.set_script(load("res://addons/proto_kit/music.gd"))
	music.process_mode = Node.PROCESS_MODE_ALWAYS
	Builder.add(services, music, "Music")
	Builder.add(music, AudioStreamPlayer.new(), "VoiceA")
	Builder.add(music, AudioStreamPlayer.new(), "VoiceB")
	var layer := CanvasLayer.new()
	Builder.add(main, layer, "Interface")
	var menu := Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Builder.add(layer, Builder.unique(menu), "Menu")
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Builder.add(menu, center, "Center")
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	Builder.add(center, column, "Column")
	label(column, "Survivor Series", "Title", 36)
	label(column, "Scene scaffold / gameplay decisions pending", "Subtitle", 18)
	var open_button := Button.new()
	open_button.text = "Open arena scaffold"
	open_button.custom_minimum_size = Vector2(300, 52)
	Builder.add(column, Builder.unique(open_button), "OpenArena")
	var hud := MarginContainer.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hud.add_theme_constant_override("margin_left", 24)
	hud.add_theme_constant_override("margin_right", 24)
	hud.add_theme_constant_override("margin_top", 20)
	hud.visible = false
	Builder.add(layer, Builder.unique(hud), "PreviewHud")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	Builder.add(hud, row, "Row")
	label(row, "Arena preview", "Status", 20)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Builder.add(row, spacer, "Spacer")
	var back := Button.new()
	back.text = "Return to menu"
	Builder.add(row, Builder.unique(back), "ReturnToMenu")
	var result: Dictionary = Builder.save_scene(main, "res://scenes/main.tscn", {"expected_refs": ["res://scenes/arena.tscn"]})
	quit(0 if result.ok else 1)

func label(parent: Node, content: String, node_name: String, font_size: int) -> void:
	var item := Label.new()
	item.text = content
	item.add_theme_font_size_override("font_size", font_size)
	Builder.add(parent, item, node_name)
