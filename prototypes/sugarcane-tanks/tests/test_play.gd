extends "res://addons/proto_kit/test_kit.gd"
## Plays the real main scene. Run with --fixed-fps 60 so game time runs faster than
## the real-time timeouts:
##   godot --headless --path . --fixed-fps 60 --script res://tests/test_play.gd
##
## 1. Joystick drag moves the hero, and the hero does not throw while moving. The throw is drawn from
##    hero_throw.png: ready pose (frame 0) while moving, raise (1, 2) before a throw, frame 3 at the moment
##    the cane is created, back to frame 0 after about 0.25 s; the thrown cane spins. Rapid throws
##    (fast attack speed, multishot) restart the pose from frame 3 and never stick.
## 2. The bot clears room 1; a real button press picks a card; the door opens;
##    walking in loads room 2.
## 3. Starting at the boss room, the boss bar appears, the final boss opens with its red circles
##    (one under the hero, spread over the floor), and killing the boss ends the chapter.
## 4. A tank winds up, dashes and runs the hero over (crushed).
## 5. Without god mode the hero gets hurt, dies, and "再來一次" reloads a fresh run.
## 6. A red circle hurts a hero whose centre is inside it when it blows up, not one just outside;
##    the bot walks out of a circle in time. Below half HP the boss drops more circles, filling faster.
## 7. HUD: the joystick is hidden until a finger presses, appears under the finger (half transparent) and hides
##    again on release, also when the game was paused meanwhile; clearing a room adds
##    coins and the HUD count matches; the boss room swaps the HUD layout; HP follows damage; the
##    defeat screen shows the run's coins and a restart starts at 0.
## 8. Game feel (game/juice.gd): camera trauma drains to nothing and leaves the camera at rest; shake_scale 0
##    never shakes; sprite squashes come back to the resting scale however often they are hit; a killed
##    enemy stops colliding at once, lies down and is freed; hit stop gives the time back (and can be forced);
##    each event plays its sound name (dropped-in files replace the synth); the HUD flashes and pops, the
##    HP bar keeps a white trail, the hero flickers while invulnerable; effects free themselves.

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1080, 1920)
	await _joystick_and_room_flow()
	await _rapid_throws()
	await _game_feel()
	await _music()
	await _boss_room()
	await _tank_crush()
	await _aoe_damage()
	await _aoe_enraged()
	await _boss_rage()
	await _bot_dodges_bullets()
	await _death_and_restart()
	OS.delay_msec(300)   # the audio thread lets go of the music players freed above; otherwise the exit reports them as leaked
	_finish("PLAY TESTS")

func _spawn_main(room_number: int) -> Node:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	main.room_index = room_number - 1
	root.add_child(main)
	main.get_node("%Hero").god_mode = true
	await _frames(2)
	return main

func _joystick_and_room_flow() -> void:
	var main: Node = await _spawn_main(1)
	var hero: CharacterBody2D = main.get_node("%Hero")
	var start: Vector2 = hero.global_position
	var stick: Control = main.get_node("%Hud").get_node("%Joystick")
	var base: Control = stick.get_node("%Base")
	_expect(not base.visible, "the joystick is not on screen before any touch")
	_expect(is_equal_approx(base.modulate.a, 0.5), "and it is half transparent (alpha %.2f)" % base.modulate.a)
	var steps: Array[StringName] = []   # the sound events heard
	main.get_node("%Sfx").played.connect(func(sound: StringName) -> void: steps.append(sound))
	await _mouse(Vector2(540, 1500), true)
	_expect(base.visible, "the joystick appears the moment a finger goes down")
	await _move(Vector2(540, 1380))
	await _frames(3)
	_expect(base.visible and base.global_position.distance_to(Vector2(540, 1500) - base.size * 0.5) < 2.0, "the joystick base is under the finger")
	var thrown_while_moving: int = main.volleys_thrown
	await create_timer(0.4).timeout
	_expect(hero.global_position.y < start.y - 40.0, "dragging the joystick up moves the hero up")
	_expect(main.volleys_thrown == thrown_while_moving, "no throwing while moving")
	_expect(steps.has(&"step"), "walking plays `step` every so often (and leaves a puff of dust)")
	var hero_sprite: Sprite2D = hero.get_node("%Sprite")
	_expect(hero_sprite.frame == 0, "moving: the hero is in the ready pose (frame 0)")
	var spawn_frames: Array[int] = []   # the throw frame at the moment each cane is created
	main.get_node("%Shots").child_entered_tree.connect(func(_cane: Node) -> void: spawn_frames.append(hero_sprite.frame))
	await _mouse(Vector2(540, 1380), false)
	_expect(not base.visible and stick.vector == Vector2.ZERO, "letting go hides the joystick again")
	await _frames(2)
	_expect(not hero_sprite.scale.is_equal_approx(Vector2.ONE), "stopping squashes the hero a little")
	var seen: Dictionary = {}   # throw frame -> process frames shown before the first throw
	await _until(func() -> bool:
		seen[hero_sprite.frame] = int(seen.get(hero_sprite.frame, 0)) + 1
		return main.volleys_thrown > thrown_while_moving, "releasing the stick starts throwing", 3.0)
	_expect(seen.has(1) or seen.has(2), "standing, the hero raises the cane (frame 1 or 2) before the first throw")
	_expect(int(seen.get(1, 0)) + int(seen.get(2, 0)) <= 12, "the wind-up is short (windup_time, about 0.15 s)")
	_expect(spawn_frames.size() > 0 and spawn_frames[0] == 3, "the cane is created while the hero shows frame 3 (release)")
	_expect(steps.has(&"throw") and main.get_node("%Juice").trauma == 0.0, "throwing plays `throw` but does not shake the camera")
	var canes: Array[Node] = main.get_node("%Shots").get_children()
	_expect(not canes.is_empty(), "a thrown cane is in flight")
	if not canes.is_empty():
		var cane: Node = canes[0]
		var turn_before: float = cane.get_node("%Visual").rotation
		await _frames(3)
		if is_instance_valid(cane):
			_expect(absf(angle_difference(cane.rotation, cane.direction.angle())) < 0.01, "the cane points where it flies")
			_expect(absf(angle_difference(cane.get_node("%Visual").rotation, turn_before)) > 0.2, "the cane spins while it flies")
	await create_timer(0.3).timeout
	_expect(hero_sprite.frame == 0, "about 0.3 s after the throw the hero is back in the ready pose (frame 0)")
	# Moving cancels the throw pose at once.
	var second_throw: int = main.volleys_thrown
	await _until(func() -> bool: return main.volleys_thrown > second_throw, "the hero keeps throwing while standing", 3.0)
	await _mouse(Vector2(250, 1250), true)
	await _move(Vector2(250, 1130))
	await _frames(3)
	_expect(hero_sprite.frame == 0, "moving right after a throw drops the pose straight back to frame 0")
	_expect(base.visible and base.global_position.distance_to(Vector2(250, 1250) - base.size * 0.5) < 2.0, "pressing somewhere else puts the joystick there")
	await _mouse(Vector2(250, 1130), false)
	_expect(not base.visible, "and it is gone again")
	# Letting go while the game is paused (the level-up panel opened under the finger) hides it too.
	await _mouse(Vector2(540, 1500), true)
	await _move(Vector2(540, 1380))
	main.get_tree().paused = true
	await _frames(2)
	await _mouse(Vector2(540, 1380), false)
	main.get_tree().paused = false
	_expect(not base.visible and stick.vector == Vector2.ZERO, "letting go while the game is paused hides the joystick too")

	main.autoplay = true
	var panel: Control = main.get_node("%ChoicePanel")
	await _until(func() -> bool: return panel.visible, "room 1 clear opens the level-up panel", 40.0)
	_expect(main.coins > 0, "clearing the room collects coins")
	_expect(main.get_node("%Hud").get_node("%CoinLabel").text == str(main.coins), "the HUD coin count matches")
	_expect(main.get_tree().paused, "the game pauses while choosing")
	_expect(main.stats.level >= 2, "room 1 EXP reaches level 2")
	_expect(main.state == main.State.REWARD, "door stays locked while choosing")
	var card: Button = panel.cards()[0]
	await _frames(2)
	for shown: Button in panel.cards():
		var frame: Rect2 = shown.get_global_rect().grow(-16.0)
		_expect(shown.get_node("%Icon").visible and shown.get_node("%Icon").texture != null, "each level-up card shows its ability's picture")
		for part: String in ["%Title", "%Description", "%Stack", "%Icon"]:
			_expect(frame.encloses(shown.get_node(part).get_global_rect()), "%s stays inside the frame of a level-up card (16 px in)" % part)
	await _press(card)
	await _until(func() -> bool: return not panel.visible, "pressing a card closes the panel", 3.0)
	var picked: int = 0
	for id: StringName in main.stats.stacks:
		picked += main.stats.count(id)
	_expect(picked == 1, "the pressed card was taken")
	_expect(main.get_node("%Hud").get_node("%AbilityChips").get_child_count() == 1, "HUD shows the picked ability")
	await _until(func() -> bool: return main.state == main.State.DOOR, "door opens after the pick", 10.0)
	await _until(func() -> bool: return main.room_index == 1 and main.state == main.State.FIGHT, "walking into the door loads room 2", 15.0)
	_expect(main.get_node("%RoomHolder").get_child_count() == 1, "only the current room is loaded")
	_expect(main.get_node("%Music").track == main.get_node("%Music").room_track, "the room track plays in room 2 too (not restarted)")
	main.queue_free()
	root.get_tree().paused = false
	await _frames(2)

## Fast attack speed and a multishot: the throw pose starts again from frame 3 for every volley and never sticks.
func _rapid_throws() -> void:
	var main: Node = await _spawn_main(10)   # the boss has HP to spare, so there is always a target
	for i: int in 5:
		main.stats.add_ability(&"attack_speed")
	for i: int in 2:
		main.stats.add_ability(&"multishot")
	var sprite: Sprite2D = main.get_node("%Hero").get_node("%Sprite")
	await create_timer(1.2).timeout   # the boss fades in and becomes a target
	var thrown_before: int = main.volleys_thrown
	var last: int = sprite.frame
	var run: int = 0
	var longest: int = 0
	var restarts: int = 0
	var frames_seen: Dictionary = {}
	for i: int in 150:
		await _frames(1)
		var frame: int = sprite.frame
		frames_seen[frame] = true
		run = run + 1 if frame == last else 1
		if frame != 0:
			longest = maxi(longest, run)
		if frame == 3 and last != 3:
			restarts += 1
		last = frame
	_expect(main.volleys_thrown - thrown_before >= 12, "fast attack speed and multishot keep throwing (%d volleys in 2.5 s)" % (main.volleys_thrown - thrown_before))
	_expect(restarts >= 6, "the release frame comes round again for every volley (%d times)" % restarts)
	_expect(longest <= 12, "no throw frame sticks for more than 0.2 s (longest run: %d frames)" % longest)
	_expect(frames_seen.has(3) and frames_seen.has(4), "the follow-through is still seen between fast throws")
	main.queue_free()
	await _frames(2)

func _boss_room() -> void:
	var main: Node = await _spawn_main(10)
	main.autoplay = true
	main.auto_pick = true
	for i: int in 5:
		main.stats.add_ability(&"attack_boost")
		main.stats.add_ability(&"attack_speed")
	var hud: Control = main.get_node("%Hud")
	var boss_panel: Control = hud.get_node("%BossPanel")
	await _until(func() -> bool: return boss_panel.visible, "boss bar appears in the boss room", 5.0)
	_expect(main.get_node("%Music").track == main.get_node("%Music").boss_track, "the boss room plays the boss track")
	_expect(main.get_node("%Juice").trauma > 0.15, "the boss's arrival shakes the camera (medium tier)")
	_expect(hud.get_node("%BossBar").value < hud.get_node("%BossBar").max_value * 0.6, "the boss bar fills up from empty")
	_expect(not hud.get_node("%PlayerPanel").visible and hud.get_node("%BottomHeroPanel").visible and not hud.get_node("%AbilityChips").visible,
		"the boss room hides the player block and ability slots, and shows the hero's HP at the bottom")
	_expect(hud.get_node("%HpLabel").text == "%d / %d" % [main.stats.hp, main.stats.max_hp], "the HUD starts with the hero's HP")
	await _until(func() -> bool: return not _circles(main).is_empty(), "the final boss drops red circles", 15.0)
	var circles: Array = _circles(main)
	var boss: Node2D = main.room.get_node("%Enemies").get_child(0)
	var hero: Node2D = main.get_node("%Hero")
	_expect(boss.portrait != null and hud.get_node("%BossPortrait").texture == boss.portrait, "the boss bar shows the boss's portrait")
	_expect(circles.size() == boss.aoe_count, "the first round drops %d circles" % boss.aoe_count)
	_expect(circles.any(func(c: Node2D) -> bool: return c.global_position.distance_to(hero.global_position) < 60.0), "one circle is under the hero")
	var apart: bool = true
	for i: int in circles.size():
		_expect(Rect2(60, 260, 960, 1500).has_point(circles[i].global_position), "circle %d is on the floor" % i)
		for j: int in range(i + 1, circles.size()):
			apart = apart and circles[i].global_position.distance_to(circles[j].global_position) >= circles[i].radius * boss.aoe_spacing - 0.01
	_expect(apart, "no two circles are closer than aoe_spacing radii (they do not pile up)")
	# The art faces right and flips to the hero's side; the pistol follows the hero and is mirrored when aimed left.
	var arm: Node2D = boss.get_node("%GunArm")
	var aimed := func() -> bool:
		return absf(angle_difference(arm.rotation, (hero.global_position - arm.global_position).angle())) < 0.3
	hero.global_position = boss.global_position + Vector2(-300.0, 40.0)
	await _until(func() -> bool: return boss.get_node("%Body").scale.x < 0.0 and arm.scale.y < 0.0 and aimed.call(),
		"hero on its left: the boss turns left and the pistol, mirrored, points at the hero", 3.0)
	hero.global_position = boss.global_position + Vector2(300.0, 40.0)
	await _until(func() -> bool: return boss.get_node("%Body").scale.x > 0.0 and arm.scale.y > 0.0 and aimed.call(),
		"hero on its right: the boss turns right and the pistol is upright again", 3.0)
	await _until(func() -> bool: return main.state == main.State.WON, "killing the boss clears the chapter", 90.0)
	_expect(main.get_node("%ResultPanel").visible, "chapter clear screen shows")
	_expect(main.get_node("%Music").track == null, "winning fades the music out")
	_expect(not boss_panel.visible, "boss bar hides after the kill")
	_expect(hud.get_node("%PlayerPanel").visible and not hud.get_node("%BottomHeroPanel").visible, "the room layout returns after the boss")
	main.queue_free()
	await _frames(2)

func _death_and_restart() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	main.room_index = 5   # room 6: plates and rats, the hero just stands there
	root.add_child(main)
	current_scene = main
	await _frames(2)
	var hero: CharacterBody2D = main.get_node("%Hero")
	var full: int = main.stats.hp
	await _until(func() -> bool: return main.stats.hp < full, "standing still, the hero gets hurt", 20.0)
	_expect(hero.get_node("%HpLabel").text == str(main.stats.hp), "HP label shows current HP")
	_expect(main.get_node("%Hud").get_node("%HpLabel").text == "%d / %d" % [main.stats.hp, main.stats.max_hp], "the HUD HP follows the damage")
	main.stats.take_damage(main.stats.hp - 1)
	hero.refresh_hp()
	main.coins = 12   # as if picked up during the run
	await _until(func() -> bool: return hero.dead, "the next hit kills the hero", 20.0)
	_expect(main.get_node("%Music").track == null, "dying fades the music out")
	var result: Control = main.get_node("%ResultPanel")
	await _until(func() -> bool: return result.visible, "defeat screen shows", 5.0)
	_expect(result.get_node("%CoinsLabel").text == "金幣 12", "the defeat screen shows the run's coins")
	var old_id: int = main.get_instance_id()
	await _press(result.get_node("%RestartButton"))
	await _until(func() -> bool:
		return current_scene != null and current_scene.get_instance_id() != old_id and current_scene.is_node_ready(),
		"restart loads a fresh main", 5.0)
	var fresh: Node = current_scene
	if fresh != null and fresh.get_instance_id() != old_id:
		_expect(fresh.room_index == 0 and fresh.stats.level == 1, "restart begins at room 1, level 1")
		_expect(fresh.coins == 0 and fresh.get_node("%Hud").get_node("%CoinLabel").text == "0", "restart starts with no coins")
		_expect(fresh.get_node("%Music").track == fresh.get_node("%Music").room_track, "restart starts the room music again")
		_expect(not paused and is_equal_approx(Engine.time_scale, 1.0), "restart is not paused or slowed")
		fresh.queue_free()
	await _frames(2)

## Background music (game/music.gd): a looping track per kind of room, quieter than the sound effects, crossfaded
## when it changes, and unaffected by pausing or by a hit stop.
func _music() -> void:
	var main: Node = await _spawn_main(1)
	var music: Node = main.get_node("%Music")
	var sfx: Node = main.get_node("%Sfx")
	var players: Array[AudioStreamPlayer] = []
	for child: Node in music.get_children():
		players.append(child as AudioStreamPlayer)
	var playing := func() -> Array:
		return players.filter(func(player: AudioStreamPlayer) -> bool: return player.playing)
	var of_track := func(track: AudioStream) -> AudioStreamPlayer:
		return players.filter(func(player: AudioStreamPlayer) -> bool: return player.playing and player.stream == track).front()
	_expect(music.room_track != null and music.room_track.resource_path.ends_with("assets/music/battle.ogg"), "rooms play assets/music/battle.ogg")
	_expect(music.boss_track != null and music.boss_track.resource_path.ends_with("assets/music/boss_battle.wav"), "the boss room plays assets/music/boss_battle.wav")
	_expect(music.volume_db < sfx.volume_db, "the music (%.1f dB) is quieter than the sound effects (%.1f dB)" % [music.volume_db, sfx.volume_db])
	_expect(music.process_mode == Node.PROCESS_MODE_ALWAYS, "the music node keeps running while the game is paused")
	_expect(music.track == music.room_track and playing.call().size() == 1 and playing.call()[0].stream == music.room_track, "room 1 plays the room track")
	_expect(music.room_track.loop, "the room track loops")
	await create_timer(music.fade_time + 0.3).timeout
	var room_player: AudioStreamPlayer = playing.call()[0]
	_expect(is_equal_approx(room_player.volume_db, music.volume_db), "after the fade-in the track plays at its volume (%.1f dB)" % room_player.volume_db)

	# Another track: the old one fades out while the new one fades in, then only the new one is left.
	music.play(music.boss_track)
	await _frames(3)
	var boss_player: AudioStreamPlayer = of_track.call(music.boss_track)
	_expect(playing.call().size() == 2 and room_player.volume_db < music.volume_db and boss_player.volume_db < music.volume_db, "switching crossfades: both tracks play, both below full volume")
	await create_timer(music.fade_time + 0.3).timeout
	_expect(playing.call() == [boss_player] and is_equal_approx(boss_player.volume_db, music.volume_db), "then only the new track plays, at full volume")
	_expect(music.boss_track.loop_mode == AudioStreamWAV.LOOP_FORWARD and music.boss_track.loop_end > music.boss_track.mix_rate * 10, "the boss track loops over its whole length")
	music.play(music.boss_track)
	_expect(playing.call() == [boss_player], "asking for the track that already plays changes nothing")

	# Paused, the music keeps playing and keeps fading.
	music.play(music.room_track)
	room_player = of_track.call(music.room_track)
	var level_before: float = room_player.volume_db
	main.get_tree().paused = true
	await create_timer(0.3).timeout
	var level_paused: float = room_player.volume_db
	main.get_tree().paused = false
	_expect(room_player.playing and level_paused > level_before, "paused: the music keeps playing and its fade goes on (%.1f dB → %.1f dB)" % [level_before, level_paused])
	await create_timer(music.fade_time).timeout

	# A hit stop (time scale 0.05) does not stretch a fade: 0.4 s later the new track is well above silence.
	var time_control: Node = main.get_node("%TimeControl")
	time_control.hit_stop(10.0, true)   # long, so it is still on when the wait below is over
	music.play(music.boss_track)
	await create_timer(0.4, true, false, true).timeout   # 0.4 s of unscaled time
	var still_slow: bool = Engine.time_scale < 0.5
	time_control.reset()
	_expect(still_slow, "the hit stop was still on while the fade ran")
	boss_player = of_track.call(music.boss_track)
	_expect(boss_player.volume_db > music.volume_db - 12.0, "a fade runs in real time, not slowed by a hit stop (%.1f dB after 0.4 s)" % boss_player.volume_db)

	# Stopping fades everything out.
	music.stop()
	await create_timer(music.fade_time + 0.3).timeout
	_expect(music.track == null and playing.call().is_empty(), "stop() fades the music out")
	main.queue_free()
	await _frames(2)

## Game feel. Room 2 has four rats and a tank; the hero stands still and does not throw.
func _game_feel() -> void:
	var main: Node = await _spawn_main(2)
	var hero: CharacterBody2D = main.get_node("%Hero")
	hero.active = false
	var juice: Node = main.get_node("%Juice")
	var camera: Camera2D = main.get_node("%Camera")
	var hud: Control = main.get_node("%Hud")
	var sfx: Node = main.get_node("%Sfx")
	var heard: Array[StringName] = []
	sfx.played.connect(func(sound: StringName) -> void: heard.append(sound))

	# Tiers get stronger, and the camera can roll (Camera2D.ignore_rotation is off).
	_expect(juice.small_trauma < juice.medium_trauma and juice.medium_trauma < juice.large_trauma, "the tiers' trauma grows: small < medium < large")
	_expect(juice.small_hit_stop <= juice.medium_hit_stop and juice.medium_hit_stop < juice.large_hit_stop, "and so does the hit stop")
	_expect(juice.small_particles < juice.medium_particles and juice.medium_particles < juice.large_particles, "and the particle count")
	_expect(not camera.ignore_rotation, "the camera is allowed to roll")

	# Trauma: added up, capped at 1, smooth, drains to nothing, camera back at rest.
	juice.add_trauma(0.6)
	juice.add_trauma(0.6)
	_expect(is_equal_approx(juice.trauma, 1.0), "trauma adds up and stops at 1")
	await _frames(2)
	_expect(camera.offset != Vector2.ZERO, "the camera shakes while there is trauma")
	# Smooth, not a fresh random number every frame: stepped at 240 Hz, the offset never jumps far between samples
	# (a random shake would jump across the whole range every sample).
	var last: Vector2 = camera.offset
	var biggest_step: float = 0.0
	for i: int in 60:
		juice._process(1.0 / 240.0)
		biggest_step = maxf(biggest_step, camera.offset.distance_to(last))
		last = camera.offset
	_expect(biggest_step < juice.max_offset.length() * 0.35, "the shake is a smooth wobble (largest step between samples %.1f px)" % biggest_step)
	_expect(juice.trauma < 1.0, "trauma drains")
	await _until(func() -> bool: return juice.trauma == 0.0, "trauma drains to nothing", 4.0)
	await _frames(2)
	_expect(camera.offset == Vector2.ZERO and is_zero_approx(camera.rotation), "the camera is back at rest")

	# Stacking: ten small events at once (four red circles in one frame, a run of crits) rumble at most stack_limit times one
	# small event; a medium event on top still adds its own shake; a small one on top of that changes nothing.
	for i: int in 10:
		juice.impact(juice.Tier.SMALL, true, false)
	var small_ceiling: float = juice.small_trauma * juice.stack_limit
	_expect(is_equal_approx(juice.trauma, small_ceiling), "ten small events pile up to %.2f, not into a big shake (trauma %.2f)" % [small_ceiling, juice.trauma])
	juice.impact(juice.Tier.MEDIUM, true, false)
	_expect(juice.trauma > small_ceiling and juice.trauma <= juice.medium_trauma * juice.stack_limit + 0.0001, "a medium event on top still adds its own shake, up to its own limit (trauma %.2f)" % juice.trauma)
	var piled: float = juice.trauma
	juice.impact(juice.Tier.SMALL, true, false)
	_expect(juice.trauma == piled, "and a small one on top of that does not change it")
	await _until(func() -> bool: return juice.trauma == 0.0, "the pile of events drains too", 4.0)
	await _frames(2)
	_expect(camera.offset == Vector2.ZERO and is_zero_approx(camera.rotation), "and the camera is at rest again")

	# shake_scale 0 turns the shake off completely.
	juice.shake_scale = 0.0
	juice.add_trauma(1.0)
	juice.impact(juice.Tier.LARGE, true, false)
	_expect(juice.trauma == 0.0, "shake_scale 0: no trauma is collected at all")
	await _frames(6)
	_expect(juice.trauma == 0.0 and camera.offset == Vector2.ZERO and camera.rotation == 0.0, "shake_scale 0: the camera never moves")
	juice.shake_scale = 1.0

	# Squash: ten hits in a row on one enemy, and a second after the last one its picture is back to its resting scale.
	var tank: Node2D = null
	var rats: Array[Node] = []
	await create_timer(0.8).timeout   # the enemies have faded in and are awake
	for enemy: Node in main.room.get_node("%Enemies").get_children():
		if enemy.scene_file_path.ends_with("tank.tscn"):
			tank = enemy
		else:
			rats.append(enemy)
		enemy.active = false   # stand still
	var picture: Sprite2D = tank.get_node("%Sprite")
	var rest: Vector2 = picture.scale
	var squashed: bool = false
	var effects_pre: int = main.get_node("%Effects").get_child_count()
	tank.take_hit(1.0, false, false, false, Vector2.RIGHT, tank.global_position)
	_expect(main.get_node("%Effects").get_children().any(func(c: Node) -> bool: return c is CPUParticles2D), "a hit throws pixel sparks from where it struck")
	for i: int in 10:
		tank.take_hit(1.0, i % 3 == 0, false, false, Vector2.RIGHT, tank.global_position)
		await _frames(2)
		squashed = squashed or not picture.scale.is_equal_approx(rest)
	_expect(squashed, "a hit squashes the enemy's picture")
	await create_timer(1.0).timeout
	_expect(picture.scale.is_equal_approx(rest), "ten hits in a row later, the picture is back at its resting scale")
	_expect(heard.has(&"hit") and heard.has(&"crit"), "hits play `hit`, crits play `crit`")
	# A crit's number pops up with an overshoot: it starts small, goes past its final size, then settles.
	main.show_damage(Vector2(540, 900), 60, true)
	var number: Node2D = main.get_node("%Effects").get_child(main.get_node("%Effects").get_child_count() - 1)
	var first: float = number.scale.x
	var biggest: float = first
	for i: int in 16:   # the number lives 0.7 s; the pop takes 0.2 s
		await _frames(1)
		biggest = maxf(biggest, number.scale.x)
	_expect(first < 1.0 and biggest > 1.45 * 1.03, "a crit's damage number pops with an overshoot (%.2f → %.2f)" % [first, biggest])
	await _frames(8)
	_expect(is_equal_approx(number.scale.x, 1.45), "and settles at its size")

	# A kill: collides no more at once, lies down, is freed; plays its event; leaves debris that frees itself.
	var rat: Node2D = rats[0]
	var effects: Node2D = main.get_node("%Effects")
	var effects_before: int = effects.get_child_count()
	var rat_picture: Sprite2D = rat.get_node("%Sprite")
	var rat_rest: Vector2 = rat_picture.scale
	heard.clear()
	rat.take_hit(99999.0, false, false, false, Vector2.RIGHT, rat.global_position)
	await _frames(2)
	_expect(rat.dead and rat.collision_layer == 0 and rat.collision_mask == 0, "a killed enemy stops colliding at once")
	_expect(heard.has(&"enemy_die"), "a kill plays `enemy_die`")
	_expect(effects.get_child_count() > effects_before, "a kill leaves an explosion and debris")
	await _frames(8)
	_expect(is_instance_valid(rat) and rat_picture.scale.y < rat_rest.y * 0.6, "the body lies flattened for a moment instead of vanishing")
	await create_timer(1.0).timeout
	_expect(not is_instance_valid(rat), "and is freed after its fade")
	_expect(effects.get_child_count() <= effects_before, "the effects free themselves")

	# A cane that carries on to the next enemy plays `ricochet`.
	var next_rat: Node2D = rats[1]
	next_rat.global_position = tank.global_position + Vector2(220.0, 0.0)
	heard.clear()
	var cane: Area2D = main.sugarcane_scene.instantiate() as Area2D
	cane.game = main
	cane.ricochets = 1
	cane.damage = 1.0
	cane.global_position = tank.global_position
	cane._on_body_entered(tank)
	_expect(heard.has(&"ricochet") and cane.ricochets == 0, "a cane that carries on to the next enemy plays `ricochet`")
	cane.free()

	# Hit stop: slows time, gives it back; throttled; forced stops skip the throttle.
	var time_control: Node = main.get_node("%TimeControl")
	await _until(func() -> bool: return is_equal_approx(Engine.time_scale, 1.0), "time is normal before the hit stop test", 2.0)
	time_control.hit_stop(0.08, true)
	_expect(Engine.time_scale < 1.0, "a hit stop slows time")
	await _until(func() -> bool: return is_equal_approx(Engine.time_scale, 1.0), "time returns to normal after the hit stop", 2.0)
	time_control.hit_stop(0.05)
	_expect(is_equal_approx(Engine.time_scale, 1.0), "a second hit stop right after the first is throttled")
	time_control.hit_stop(0.05, true)
	_expect(Engine.time_scale < 1.0, "unless it is forced")
	await _until(func() -> bool: return is_equal_approx(Engine.time_scale, 1.0), "and time returns again", 2.0)

	# The hero: hurt event, red edge flash, HP trail, flicker while invulnerable, then back to normal.
	hero.god_mode = false
	heard.clear()
	hero.take_hit(60, false)
	await _frames(1)
	_expect(heard.has(&"hurt") and not heard.has(&"crush"), "a plain hit plays `hurt`")
	_expect(hud.get_node("%Vignette").modulate.a > 0.2, "the screen edges flash red")
	_expect(hud.get_node("%HpGhost").value > hud.get_node("%HpBar").value, "the HP bar keeps a white trail where the HP was")
	var lowest: float = 1.0
	for i: int in 30:
		await _frames(1)
		lowest = minf(lowest, hero.get_node("%Sprite").modulate.a)
	_expect(lowest < 0.6, "the hero flickers while invulnerable")
	await create_timer(0.8).timeout
	_expect(is_equal_approx(hero.get_node("%Sprite").modulate.a, 1.0), "the flicker stops")
	_expect(is_zero_approx(hud.get_node("%Vignette").modulate.a), "the red edges fade away")
	_expect(is_equal_approx(hud.get_node("%HpGhost").value, hud.get_node("%HpBar").value), "and the trail catches up")
	hero.god_mode = true

	# Sounds. Every event the game plays finds the file named like it in assets/sfx/, except the ones kept without one
	# on purpose: `squeak` stays a synth (the Kenney set has no rat), the rest have no sound at all. And the other way
	# round: every file in the folder is played by some event.
	var events: Array[StringName] = [&"throw", &"step", &"hit", &"crit", &"enemy_die", &"boss_die", &"hurt", &"crush", &"hero_die",
		&"rev", &"dash", &"bump", &"aoe_blast", &"squeak", &"gun", &"drop", &"pickup", &"coin", &"heal", &"level_up", &"level",
		&"door", &"boss_intro", &"toss", &"ricochet", &"rage"]
	var kept_without_file: Array[StringName] = [&"squeak", &"bump", &"drop", &"heal", &"level_up", &"boss_intro"]
	var no_file: Array[StringName] = []
	var reached: Dictionary = {}
	for event: StringName in events:
		reached[event] = true
		if not sfx.source_of(event).begins_with("res://assets/sfx/") and not kept_without_file.has(event):
			no_file.append(event)
	_expect(no_file.is_empty(), "every event finds its sound file in assets/sfx/ (without one: %s)" % [no_file])
	_expect(sfx.source_of(&"squeak") == "synth", "`squeak` keeps its synth")
	for lender: StringName in sfx.fallback.values():
		reached[lender] = true   # heard whenever a borrower loses its own file
	var unplayed: Array[String] = []
	for file: String in DirAccess.get_files_at("res://assets/sfx"):
		if file.get_extension() in ["ogg", "wav"] and not file.begins_with("zz_") and not reached.has(StringName(file.get_basename())):
			unplayed.append(file)
	_expect(unplayed.is_empty(), "every sound file in assets/sfx/ is played by some event (not played: %s)" % [unplayed])
	# An event with no file and no synth of its own borrows another event's sound, else it is silent (never an error).
	sfx.fallback[&"zz_feel_borrow"] = &"hit"
	sfx.fallback[&"zz_feel_borrow_nothing"] = &"zz_feel_nothing"
	sfx.refresh()
	_expect(sfx.source_of(&"zz_feel_borrow") == "hit (borrowed)" and sfx.stream_for(&"zz_feel_borrow") == sfx.stream_for(&"hit"), "an event without a sound borrows another event's")
	_expect(sfx.stream_for(&"zz_feel_borrow_nothing") == null and sfx.source_of(&"zz_feel_nothing") == "", "an event nobody has a sound for is silent")
	sfx.play(&"zz_feel_nothing")
	sfx.fallback.erase(&"zz_feel_borrow")
	sfx.fallback.erase(&"zz_feel_borrow_nothing")
	# A file dropped into assets/sfx/ named like the event replaces its synth, and the synth is back without the file.
	var test_event: StringName = &"zz_feel_test"
	var test_file: String = "res://assets/sfx/%s.wav" % test_event
	sfx._streams[test_event] = sfx._streams[&"hit"]   # a synth of its own, until a file turns up
	sfx.refresh()
	_expect(sfx.source_of(test_event) == "synth", "before the file: the synth plays")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/sfx"))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var silence := PackedByteArray()
	silence.resize(882)   # 20 ms of 16-bit mono silence
	wav.data = silence
	_expect(wav.save_to_wav(test_file) == OK, "the test sound file is written")
	sfx.refresh()
	_expect(sfx.source_of(test_event) == test_file and sfx.stream_for(test_event) is AudioStreamWAV, "a file named like the event replaces its synth")
	heard.clear()
	sfx.play(test_event)
	_expect(heard == [test_event], "and playing it works")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_file))
	if FileAccess.file_exists(test_file + ".import"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_file + ".import"))
	sfx.refresh()
	_expect(sfx.source_of(test_event) == "synth" and not FileAccess.file_exists(test_file), "without the file the synth is back, and the test file is gone")
	sfx._streams.erase(test_event)
	sfx.refresh()

	# Level and door effects spawn and free themselves; every event goes through the sound interface.
	heard.clear()
	var effects_base: int = effects.get_child_count()
	juice.level_gained(hero)
	juice.door_opened(main.room.door().global_position)
	juice.boss_appeared()
	var coin: Node = _pickup_of(main, 2)
	main.collect_pickup(coin)
	coin.queue_free()
	_expect(heard.has(&"level_up") and heard.has(&"boss_intro") and heard.has(&"coin"), "level up, boss intro and coin pickup play their events")
	await _frames(2)
	_expect(effects.get_child_count() > effects_base, "the level ring and the gold burst are on screen")
	await create_timer(1.6).timeout
	_expect(effects.get_child_count() <= effects_base, "and free themselves")
	main.queue_free()
	await _frames(2)

## A pickup of this kind (0 EXP, 1 heart, 2 coin) for collect_pickup.
func _pickup_of(main: Node, kind: int) -> Node:
	var scene: PackedScene = main.exp_gem_scene if kind == 0 else (main.heart_scene if kind == 1 else main.coin_scene)
	var pickup: Node2D = scene.instantiate() as Node2D
	pickup.game = main
	main.get_node("%Pickups").add_child(pickup)
	return pickup

## Red circles that have not blown up yet.
func _circles(main: Node) -> Array:
	return main.get_node("%EnemyShots").get_children().filter(func(c: Node) -> bool: return c.has_method(&"is_aoe") and c.is_aoe())

## Drops a circle centred `radii` radii to the right of the hero.
func _drop_circle(main: Node, hero: Node2D, radii: float, time: float) -> Node2D:
	var circle: Node2D = (load("res://effects/aoe_circle.tscn") as PackedScene).instantiate() as Node2D
	circle.game = main
	circle.telegraph_time = time
	circle.position = hero.global_position + Vector2.RIGHT * circle.radius * radii
	main.get_node("%EnemyShots").add_child(circle)
	return circle

## Drops a circle and waits until it has blown up.
func _blow_up(main: Node, hero: Node2D, radii: float, time: float = 0.3) -> Node2D:
	var circle: Node2D = _drop_circle(main, hero, radii, time)
	await _until(func() -> bool: return circle.exploded, "a red circle blows up", 5.0)
	await _frames(2)
	return circle

## Only the hero's centre counts: 13 px outside the rim (its body reaches in) is safe, 13 px inside hurts.
## Outside is tested first: a hit starts the hero's invulnerability, which would hide a false hit after it.
func _aoe_damage() -> void:
	var main: Node = await _spawn_main(10)
	var hero: CharacterBody2D = main.get_node("%Hero")
	hero.god_mode = false
	hero.active = false   # stand still and do not throw
	main.room.process_mode = Node.PROCESS_MODE_DISABLED   # the boss never wakes up, only the circles act
	var hp_before: int = main.stats.hp
	var heard: Array[StringName] = []
	main.get_node("%Sfx").played.connect(func(sound: StringName) -> void: heard.append(sound))
	await _blow_up(main, hero, 1.1)
	_expect(main.stats.hp == hp_before, "a hero just outside a red circle takes no damage")
	_expect(heard.has(&"aoe_blast") and not heard.has(&"hurt"), "a miss plays `aoe_blast` only")
	_expect(main.get_node("%Juice").trauma > 0.05, "a blast that misses still shakes the camera a little (small tier)")
	var inside: Node2D = await _blow_up(main, hero, 0.9)
	_expect(hp_before - main.stats.hp == inside.damage, "a hero inside a red circle takes its damage")
	_expect(heard.has(&"hurt"), "and a hero that is hit plays `hurt`")
	hp_before = main.stats.hp
	main.autoplay = true
	hero.active = true
	var under: Node2D = await _blow_up(main, hero, 0.0, 1.0)
	_expect(main.stats.hp == hp_before, "the bot walks out of a red circle before it blows up")
	_expect(hero.global_position.distance_to(under.global_position) > under.radius, "the bot ends outside the circle")
	# The hero dying stops EnemyShots: a circle that is still filling freezes like a bullet and never blows up.
	var pending: Node2D = _drop_circle(main, hero, 3.0, 0.6)
	hero.take_hit(9999)
	await create_timer(1.2).timeout
	_expect(hero.dead and is_instance_valid(pending) and not pending.exploded, "a dead hero freezes red circles like bullets")
	main.queue_free()
	await _frames(2)

func _aoe_enraged() -> void:
	var main: Node = await _spawn_main(10)
	var boss: Node2D = main.room.get_node("%Enemies").get_child(0)
	# The hit that takes a boss below half HP plays `rage`, once.
	var heard: Array[StringName] = []
	main.get_node("%Sfx").played.connect(func(sound: StringName) -> void: heard.append(sound))
	boss.hp = boss.max_hp / 2 + 30
	boss.take_hit(1.0)
	_expect(not heard.has(&"rage"), "a boss above half HP is calm")
	boss.take_hit(60.0)
	_expect(heard.count(&"rage") == 1, "the hit that takes a boss below half HP plays `rage`")
	boss.take_hit(5.0)
	_expect(heard.count(&"rage") == 1, "and it only roars once")
	boss.hp = boss.max_hp / 4
	await _until(func() -> bool: return not _circles(main).is_empty(), "the wounded boss drops red circles", 15.0)
	var circles: Array = _circles(main)
	_expect(circles.size() == boss.aoe_count_enraged and boss.aoe_count_enraged > boss.aoe_count, "below half HP the boss drops more circles")
	_expect(circles[0].telegraph_time == boss.aoe_telegraph_time_enraged and boss.aoe_telegraph_time_enraged < boss.aoe_telegraph_time, "and they fill faster")
	main.queue_free()
	await _frames(2)

## Below half HP the final boss is angry: a banner, steam, an anger mark and a red pulse appear, and the bullets
## he fires from then on bounce off the wall (once by default). Before that none of it is there, and a bullet
## dies at the first wall. A bean of the chefs never bounces.
func _boss_rage() -> void:
	var main: Node = await _spawn_main(10)
	var boss: Node2D = main.room.get_node("%Enemies").get_child(0)
	var steam: CPUParticles2D = boss.get_node("%RageSteam")
	var mark: Node2D = boss.get_node("%RageMark")
	var banner: Label = main.get_node("%Hud").get_node("%Banner")
	var shots: Node = main.get_node("%EnemyShots")
	await _until(func() -> bool: return boss.active, "the final boss wakes up", 5.0)
	await _frames(3)
	_expect(not boss.raging and not steam.emitting and not mark.visible and boss.sprite.modulate.is_equal_approx(Color.WHITE), "a healthy boss shows no rage")
	_expect(not banner.text.contains("生氣"), "and no rage banner")
	boss.active = false   # from here he only fires when the test tells him to
	boss.global_position = Vector2(800, 800)
	for old: Node in shots.get_children():
		old.queue_free()
	await _frames(2)
	boss._fire(0.0)
	var calm: Area2D = shots.get_child(shots.get_child_count() - 1)
	_expect(calm.bounces == 0 and calm.modulate.is_equal_approx(Color.WHITE), "a bullet of the calm boss does not bounce")
	await _until(func() -> bool: return not is_instance_valid(calm) or calm.is_queued_for_deletion(), "the calm bullet dies at the wall", 3.0)

	boss.hp = boss.max_hp / 4
	boss.active = true
	await _until(func() -> bool: return boss.raging, "the boss gets angry below half HP", 3.0)
	await _frames(3)
	_expect(steam.emitting and mark.visible, "the steam rises and the anger mark shows")
	_expect(banner.text.contains("生氣"), "the banner says he is angry: %s" % banner.text)
	await create_timer(1.0).timeout
	_expect(not boss.sprite.modulate.is_equal_approx(Color.WHITE) and boss.sprite.modulate.r > boss.sprite.modulate.g + 0.1, "his body is tinted red")
	boss.active = false
	boss.global_position = Vector2(800, 800)
	for old: Node in shots.get_children():
		old.queue_free()
	await _frames(2)
	boss._fire(0.0)
	var angry: Area2D = shots.get_child(shots.get_child_count() - 1)
	_expect(angry.bounces == boss.rage_bounces and boss.rage_bounces >= 1, "a bullet of the angry boss can bounce (%d times)" % boss.rage_bounces)
	_expect(not angry.modulate.is_equal_approx(Color.WHITE), "and is tinted so it can be told apart")
	await _until(func() -> bool: return is_instance_valid(angry) and angry.direction.x < 0.0, "the angry bullet turns back at the wall", 3.0)
	if is_instance_valid(angry):
		_expect(absf(angry.direction.y) < 0.05 and angry.bounces == boss.rage_bounces - 1, "it is thrown straight back and has one bounce fewer")
	await _until(func() -> bool: return is_instance_valid(angry) and angry.modulate.a < 0.99, "a bullet that has bounced starts to fade", 3.0)
	await _until(func() -> bool: return not is_instance_valid(angry) or angry.is_queued_for_deletion(), "and is gone `rage_bounce_life` seconds after its first bounce", 3.0)
	var bean: Node = (load("res://enemies/pea.tscn") as PackedScene).instantiate()
	_expect(bean.bounces == 0, "a chef's bean never bounces")
	bean.free()
	main.queue_free()
	await _frames(2)

## The bot steps out of the way of a bullet that is flying straight at it; the same bullet hurts a hero that stands still.
func _bot_dodges_bullets() -> void:
	var main: Node = await _spawn_main(10)
	var hero: CharacterBody2D = main.get_node("%Hero")
	hero.god_mode = false
	main.autoplay = true
	main.room.process_mode = Node.PROCESS_MODE_DISABLED   # the boss never wakes up
	var bullet_scene: PackedScene = load("res://enemies/bullet.tscn")
	var hp_before: int = main.stats.hp
	main.spawn_projectile(bullet_scene, hero.global_position + Vector2(0, -420), Vector2.DOWN, 420.0, 70)
	await create_timer(1.5).timeout
	_expect(main.stats.hp == hp_before, "the bot steps out of the way of a bullet flying at it")
	main.autoplay = false
	main.spawn_projectile(bullet_scene, hero.global_position + Vector2(0, -420), Vector2.DOWN, 420.0, 70)
	await create_timer(1.5).timeout
	_expect(main.stats.hp < hp_before, "without the bot's dodge the same bullet does hit")
	main.queue_free()
	await _frames(2)

func _tank_crush() -> void:
	var main: Node = await _spawn_main(2)   # room 2: four rats and one tank
	var hero: CharacterBody2D = main.get_node("%Hero")
	hero.god_mode = false
	hero.active = false   # stand still and do not throw
	var tank: Node2D = null
	for enemy: Node in main.room.get_node("%Enemies").get_children():
		if enemy.scene_file_path.ends_with("tank.tscn"):
			tank = enemy
		else:
			enemy.queue_free()
	_expect(tank != null, "room 2 has a tank")
	await _until(func() -> bool: return tank.phase == tank.Phase.WINDUP, "the tank winds up before dashing", 15.0)
	_expect(tank.get_node("%DashLine").visible, "a red line warns where it will dash")
	await _frames(3)
	var picture: Sprite2D = tank.get_node("%Sprite")
	_expect(picture.position != tank._sprite_home and tank.velocity == Vector2.ZERO, "the windup shudders the picture while the body stays put")
	var heard: Array[StringName] = []
	main.get_node("%Sfx").played.connect(func(sound: StringName) -> void: heard.append(sound))
	var hp_before: int = main.stats.hp
	await _until(func() -> bool: return main.stats.hp < hp_before, "the dash runs the hero over", 10.0)
	_expect(picture.position == tank._sprite_home, "the picture is back in place once the dash starts")
	_expect(hero.last_hit_crushed, "the hit counts as crushed (hero flattens)")
	_expect(heard.has(&"dash") and heard.has(&"crush") and not heard.has(&"hurt"), "a crush plays `crush` (large), not `hurt`")
	_expect(main.get_node("%Juice").trauma > 0.3, "a crush shakes the camera hard (large tier)")
	_expect(main.get_node("%Hud").get_node("%Vignette").modulate.a > 0.2, "a crush flashes the screen edges red")
	_expect(hp_before - main.stats.hp == tank.crush_damage, "crush does crush_damage")
	_expect(main.get_node("%Hud").get_node("%HpLabel").text == "%d / %d" % [main.stats.hp, main.stats.max_hp], "the HUD HP follows the crush")
	main.queue_free()
	await _frames(2)
