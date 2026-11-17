extends SceneTree
## Adds the user-supplied enemy sounds to the saved scenes (one-time authoring tool; rerunning
## replaces these nodes by name):
##   scout.tscn  StepSound (enemy_step, pitched up in scout.gd)
##   boss.tscn   StepSound -> enemy_step (pitched down in boss.gd), Voice (boss_talk / boss_angry)
## godot --headless --path . --script res://tools/build_enemy_audio.gd

const Builder = preload("res://addons/proto_kit/scene_builder.gd")
const STEP := "res://assets/sound/runtime/enemy_step.ogg"

func _initialize() -> void:
	quit(0 if _run() else 1)

func _player(stream: String, bus: String, unit_size: float, volume: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = load(stream)
	p.bus = bus
	p.unit_size = unit_size
	p.volume_db = volume
	return p

func _run() -> bool:
	var ok := true
	var scout := Builder.open_scene("res://scenes/scout.tscn")
	var step := _player(STEP, "Movement", 6.0, -4.0)
	step.max_polyphony = 2
	Builder.put(scout.root, step, "StepSound")
	ok = Builder.save_scene(scout.root, "res://scenes/scout.tscn", {"overwrite": true, "expected_refs": scout.refs}).ok and ok
	var boss := Builder.open_scene("res://scenes/boss.tscn")
	var boss_step := _player(STEP, "Movement", 22.0, 2.0)
	boss_step.pitch_scale = 0.55
	boss_step.max_polyphony = 3
	Builder.put(boss.root, boss_step, "StepSound")
	var voice := _player("res://assets/sound/runtime/boss_talk.ogg", "Voice", 30.0, 2.0)
	voice.position = Vector3(0, 6, 4)
	Builder.put(boss.root, voice, "Voice")
	ok = Builder.save_scene(boss.root, "res://scenes/boss.tscn", {"overwrite": true, "expected_refs": boss.refs}).ok and ok
	return ok
