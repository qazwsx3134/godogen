extends "res://addons/proto_kit/test_kit.gd"
const AudioMix := preload("res://addons/audio_tuner/mix.gd")

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
	var scout: Node = main.get_node("Enemies").get_child(0)
	for i in 60: scout._play_walk(Vector3(2.5, 0, 0))
	_expect(scout.get_node("StepSound").playing and scout.get_node("StepSound").pitch_scale > 1.2, "a walking scout crunches, pitched up")
	_expect(walker.get_node("Combat").get_node("ShotSound").max_polyphony >= 4 and walker.get_node("Combat").SHOT_SOUNDS[0].resource_path.ends_with("cannon_shot.ogg"), "the walker cannon uses the supplied gun shot")
	var shot_sound: AudioStreamPlayer3D = walker.get_node("Combat/ShotSound")
	shot_sound.stream = walker.get_node("Combat").SHOT_SOUNDS[0]
	var saved := AudioMix._clips
	AudioMix._clips = {shot_sound.stream.resource_path: {"pitch": 1.2, "gain_db": -6.0}}
	AudioMix.play(shot_sound, 0.75, 3.0)
	_expect(is_equal_approx(shot_sound.pitch_scale, 0.9) and is_equal_approx(shot_sound.volume_db, -3.0),
		"clip tuning combines with authored gameplay pitch and gain")
	AudioMix.play(shot_sound, 0.75, 3.0)
	_expect(is_equal_approx(shot_sound.pitch_scale, 0.9) and is_equal_approx(shot_sound.volume_db, -3.0),
		"repeated shots do not accumulate clip tuning")
	AudioMix._clips = saved
	# Repeated shots and steps vary a little in pitch and volume around the centre value.
	var pitches := {}
	var gains := {}
	var tuned := AudioMix._clips
	AudioMix._clips = {}  # no per-clip mix offsets: check the spread alone
	for i in 12:
		AudioMix.play_varied(shot_sound, 1.0, 0.0, 0.05, 1.5)
		pitches[snappedf(shot_sound.pitch_scale, 0.001)] = true
		gains[snappedf(shot_sound.volume_db, 0.01)] = true
		_expect(absf(shot_sound.pitch_scale - 1.0) <= 0.051 and absf(shot_sound.volume_db) <= 1.51, "variation stays small")
	AudioMix._clips = tuned
	_expect(pitches.size() > 6 and gains.size() > 6, "each play gets its own random pitch and volume")
	shot_sound.stop()
	shot_sound.stop()
	var round := load("res://scenes/combat_projectile.tscn").instantiate() as Node
	_expect(round.get_node("Whiz").stream.resource_path.ends_with("bullet_whiz.ogg") and not round.get_node("Whiz").autoplay, "near misses whiz with the supplied clip")
	round.free()
	var explosion := load("res://scenes/combat_impact.tscn").instantiate() as Node3D
	explosion.radius=3
	main.get_node("Projectiles").add_child(explosion)
	await _frames(30)
	_expect(is_instance_valid(explosion) and explosion.get_node("Sound").stream.resource_path.ends_with("explosion.ogg"),"explosion audio survives short flash duration")
	for enemy: Node in main.get_node("Enemies").get_children(): enemy.apply_damage(1000)
	await _frames(2)
	_expect(main.match_state=="victory" and is_instance_valid(explosion),"last-kill audio tail survives round end")
	OS.delay_msec(300)  # the kill hit stop runs on the wall clock; let it end before counting frames
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
