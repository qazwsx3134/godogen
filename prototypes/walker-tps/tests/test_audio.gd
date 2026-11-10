extends "res://addons/proto_kit/test_kit.gd"
func _init() -> void: _run.call_deferred()
func _run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sound/manifest.json"))
	for record: Dictionary in manifest.files:
		var stream: AudioStream = load("res://assets/sound/"+record.output)
		_expect(stream is AudioStreamOggVorbis,"processed audio imports as Vorbis: "+record.name)
		_expect(stream.get_length()>0 and absf(stream.get_length()-float(record.duration_seconds))<0.05,"imported duration matches processing report: "+record.name)
		_expect(not stream.loop,"one-shot has no accidental loop: "+record.name)
	for bus: String in ["Movement","Weapons","Impacts","Voice"]:
		_expect(AudioServer.get_bus_index(bus)>0,"saved audio bus is loaded: "+bus)
	_expect(AudioServer.get_bus_effect(0,0) is AudioEffectLimiter,"master limiter is present")
	var main: Node = load("res://scenes/battlefield.tscn").instantiate()
	root.add_child(main)
	current_scene=main
	main.start_match()
	for enemy: Node in main.get_node("Enemies").get_children(): enemy.ai_enabled=false
	await _frames(3)
	_expect(main.radio_count==1 and main.get_node("Radio").stream.resource_path.ends_with("ai_boot.ogg"),"deployment plays provided boot sound")
	_expect(not main.play_radio(),"radio cooldown prevents overlapping communication")
	var walker: Node = main.get_node("Walker")
	_expect(walker.get_node("StepSound").bus=="Movement" and walker.get_node("StepSound").max_polyphony==3,"steps routed with bounded polyphony")
	walker._on_stepped(walker.global_position)
	var clip: AudioStream = walker.get_node("StepSound").stream
	walker._on_stepped(walker.global_position)
	_expect(walker.get_node("StepSound").stream==clip,"simultaneous foot contacts are coalesced")
	walker._on_landed(6.0)
	_expect(walker.get_node("StepSound").stream.resource_path.ends_with("mech_land.ogg"),"landing uses processed contact sound")
	var explosion := load("res://scenes/combat_impact.tscn").instantiate() as Node3D
	explosion.radius=3
	main.get_node("Projectiles").add_child(explosion)
	await _frames(30)
	_expect(is_instance_valid(explosion) and explosion.get_node("Sound").stream.resource_path.ends_with("explosion.ogg"),"explosion audio survives short flash duration")
	for enemy: Node in main.get_node("Enemies").get_children(): enemy.apply_damage(1000)
	await _frames(2)
	_expect(main.match_state=="victory" and is_instance_valid(explosion),"last-kill audio tail survives round end")
	await _frames(150)
	_expect(not is_instance_valid(explosion),"audio effect has bounded lifetime")
	for player: Node in main.find_children("*","AudioStreamPlayer3D",true,false): player.stop()
	main.get_node("Radio").stop()
	clip=null
	main.queue_free()
	current_scene=null
	await _frames(8)
	# Let the dummy audio driver consume queued playback removals before shutdown.
	OS.delay_msec(50)
	await _frames(2)
	_finish("AUDIO")
