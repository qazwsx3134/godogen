extends SceneTree
## Explicit scene authoring only. Keeps existing scene positions and reusable references.
const B = preload("res://addons/proto_kit/scene_builder.gd")
func _initialize() -> void:
	# Preserve existing mixing edits on repeat runs.
	if not ResourceLoader.exists("res://default_bus_layout.tres"):
		AudioServer.set_bus_volume_db(0,-3.0)
		var limiter := AudioEffectLimiter.new()
		limiter.ceiling_db=-0.5
		limiter.threshold_db=-1.0
		AudioServer.add_bus_effect(0,limiter)
		for entry: Array in [["Movement",-7.0],["Weapons",-3.0],["Impacts",-2.0],["Voice",-3.0]]:
			AudioServer.add_bus()
			var i := AudioServer.bus_count-1
			AudioServer.set_bus_name(i,entry[0])
			AudioServer.set_bus_send(i,"Master")
			AudioServer.set_bus_volume_db(i,entry[1])
		ResourceSaver.save(AudioServer.generate_bus_layout(),"res://default_bus_layout.tres")
	var ok := true
	var opened := B.open_scene("res://scenes/walker.tscn")
	var root: Node = opened.root
	root.get_node("StepSound").bus="Movement"
	root.get_node("StepSound").max_polyphony=3
	root.get_node("StepSound").stream=load("res://assets/sound/runtime/mech_contact.ogg")
	if not root.has_node("MovementSound"):
		var sound := AudioStreamPlayer3D.new()
		sound.bus="Movement"
		sound.stream=load("res://assets/sound/runtime/mech_servo.ogg")
		sound.unit_size=8
		sound.max_distance=50
		B.add(root,B.unique(sound),"MovementSound")
	ok=save(opened,"res://scenes/walker.tscn") and ok
	opened=B.open_scene("res://scenes/walker_combat.tscn")
	opened.root.get_node("ShotSound").bus="Weapons"
	ok=save(opened,"res://scenes/walker_combat.tscn") and ok
	opened=B.open_scene("res://scenes/auto_blades.tscn")
	opened.root.get_node("Sound").bus="Weapons"
	opened.root.get_node("Sound").volume_db=-6
	ok=save(opened,"res://scenes/auto_blades.tscn") and ok
	opened=B.open_scene("res://scenes/combat_impact.tscn")
	opened.root.get_node("Sound").bus="Impacts"
	opened.root.get_node("Sound").max_distance=95
	opened.root.get_node("Sound").unit_size=12
	opened.root.get_node("Sound").stream=load("res://assets/sound/runtime/hit_heavy.ogg")
	ok=save(opened,"res://scenes/combat_impact.tscn") and ok
	opened=B.open_scene("res://scenes/scout.tscn")
	if not opened.root.has_node("GunSound"):
		var sound := AudioStreamPlayer3D.new()
		sound.bus="Weapons"
		sound.stream=load("res://assets/sound/runtime/scout_gun_a.ogg")
		sound.unit_size=12
		sound.max_distance=95
		sound.max_polyphony=2
		sound.position=Vector3(0,1.65,0.6)
		B.add(opened.root,sound,"GunSound")
	ok=save(opened,"res://scenes/scout.tscn") and ok
	opened=B.open_scene("res://scenes/battlefield.tscn")
	if not opened.root.has_node("Radio"):
		var radio := AudioStreamPlayer.new()
		radio.bus="Voice"
		radio.stream=load("res://assets/sound/runtime/ai_boot.ogg")
		B.add(opened.root,radio,"Radio")
	ok=save(opened,"res://scenes/battlefield.tscn") and ok
	quit(0 if ok else 1)
func save(opened: Dictionary,path: String) -> bool:
	return B.save_scene(opened.root,path,{"overwrite":true,"expected_refs":opened.refs}).ok
