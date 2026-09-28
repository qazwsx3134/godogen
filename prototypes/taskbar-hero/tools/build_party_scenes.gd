extends SceneTree
## One-shot party scene authoring. Never called at normal startup.
func _init() -> void:
	build.call_deferred()

func own(root_node: Node, node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = root_node
		own(root_node,child)

func pack(node: Node, path: String) -> void:
	var scene := PackedScene.new()
	assert(scene.pack(node) == OK)
	assert(ResourceSaver.save(scene,path) == OK)
	print("SAVED ",path)
	node.free()

func shape(parent: Node, name_text: String, region: Rect2, points: Array) -> void:
	var polygon := Polygon2D.new()
	polygon.name = name_text
	polygon.texture = load("res://assets/reference/monster.png")
	polygon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var positions := PackedVector2Array()
	var uvs := PackedVector2Array()
	for p: Array in points:
		positions.append(Vector2(p[0],p[1]))
		uvs.append(Vector2(p[0],p[1])+region.position)
	polygon.polygon = positions
	polygon.uv = uvs
	polygon.position = Vector2(-region.size.x/2,-region.size.y)
	parent.add_child(polygon)

func build() -> void:
	var unit: Node2D = load("res://scenes/combat/reference_unit.tscn").instantiate()
	unit.scene_file_path = ""
	var visuals := unit.get_node("Visuals")
	var pet: Polygon2D = unit.get_node("Visuals/KnightVisual/PetAtlas").duplicate()
	unit.get_node("Visuals/KnightVisual/PetAtlas").free()
	unit.get_node("Visuals/KnightVisual/KnightAtlas").position = Vector2(-93,-125)
	for id in ["PetVisual","FoxVisual","AquaVisual","MushroomVisual","SoldierVisual","DummyVisual"]:
		var v := Node2D.new()
		v.name = id
		v.visible = false
		visuals.add_child(v)
	pet.position = Vector2(-60,-108)
	visuals.get_node("PetVisual").add_child(pet)
	var soldier: Node = visuals.get_node("KnightVisual/KnightAtlas").duplicate()
	visuals.get_node("SoldierVisual").add_child(soldier)
	visuals.get_node("SoldierVisual").scale.x = -1
	visuals.get_node("SoldierVisual").modulate = Color(0.65,0.8,1.0)
	var dummy: Node = visuals.get_node("SlimeVisual/DummyAtlas").duplicate()
	dummy.visible = true
	visuals.get_node("DummyVisual").add_child(dummy)
	visuals.get_node("SlimeVisual/DummyAtlas").free()
	shape(visuals.get_node("FoxVisual"),"Fox",Rect2(304,1309,129,108),[[0,105],[7,76],[0,53],[15,29],[29,50],[39,43],[45,0],[65,15],[69,27],[85,23],[104,0],[112,12],[111,37],[127,45],[127,75],[101,87],[110,106],[78,107],[71,96],[56,107]])
	shape(visuals.get_node("AquaVisual"),"Aqua",Rect2(531,1340,112,77),[[0,73],[0,54],[12,35],[27,14],[42,4],[61,0],[80,8],[88,27],[108,47],[111,69],[95,76],[18,76]])
	shape(visuals.get_node("MushroomVisual"),"Mushroom",Rect2(744,1310,121,108),[[0,47],[14,29],[35,10],[55,0],[74,1],[84,17],[112,37],[120,53],[116,65],[87,63],[92,84],[90,96],[72,105],[50,107],[29,101],[19,86],[19,65],[2,65]])
	visuals.scale = Vector2(0.72,0.72)
	unit.appearance = "KnightVisual"
	for name_text in ["HealthFill","HealthBackground"]:
		unit.get_node(name_text).position = Vector2(0,-40)
		unit.get_node(name_text).scale = Vector2(1.3,1.1)
	unit.get_node("DamageFeedback").offset_top = -155
	unit.get_node("DamageFeedback").offset_bottom = -95
	own(unit,unit)
	pack(unit,"res://scenes/combat/party_unit.tscn")
	var arena := Node2D.new()
	arena.name = "CombatArena"
	arena.set_script(load("res://scripts/wave_arena.gd"))
	var ids := ["knight","sprout","fox","aqua","mushroom","enemy_0","enemy_1","enemy_2"]
	var appearances := ["KnightVisual","PetVisual","FoxVisual","AquaVisual","MushroomVisual","SlimeVisual","SlimeVisual","SlimeVisual"]
	var positions := [95,235,350,460,555,750,835,910]
	for i in ids.size():
		var actor: Node2D = load("res://scenes/combat/party_unit.tscn").instantiate()
		actor.name = "KnightUnit" if i == 0 else ("SlimeUnit" if i == 5 else str(ids[i]).capitalize()+"Unit")
		actor.unique_name_in_owner = true
		actor.position = Vector2(positions[i],0)
		var data := UnitData.new()
		data.unit_id = ids[i]
		data.display_name = ["主角","小芽龍","火狐獸","水史萊姆","菇菇怪","史萊姆","史萊姆","史萊姆"][i]
		data.faction = "hero" if i < 5 else "enemy"
		data.max_health = 96 if i < 5 else 130
		data.attack = 16 if i < 5 else 10
		data.defense = 5
		data.attack_speed = 1.25 if i == 0 else 1.0
		data.attack_range = [65,115,185,255,315,65,65,65][i]
		data.move_speed = 95 if i < 5 else 35
		data.gold_reward = 14 if i >= 5 else 0
		actor.unit_data = data
		actor.faction = data.faction
		actor.appearance = appearances[i]
		actor.automatic_respawn = i < 5
		for visual: Node in actor.get_node("Visuals").get_children():
			visual.visible = str(visual.name) == appearances[i]
		actor.get_node("HealthFill").color = Color("99d77e") if i < 5 else Color("f27e69")
		arena.add_child(actor)
		actor.owner = arena
		arena.set_editable_instance(actor,true)
	var label := Label.new()
	label.name = "WaveLabel"
	label.unique_name_in_owner = true
	label.position = Vector2(20,-355)
	label.size = Vector2(900,45)
	label.text = "1-1  ·  第 1 / 3 波"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",26)
	label.add_theme_color_override("font_color",Color.WHITE)
	label.add_theme_color_override("font_outline_color",Color("253145"))
	label.add_theme_constant_override("outline_size",5)
	label.add_theme_font_override("font",load("res://fonts/NotoSansCJKtc-Medium.otf"))
	arena.add_child(label)
	label.owner = arena
	pack(arena,"res://scenes/combat/reference_arena.tscn")
	quit()
