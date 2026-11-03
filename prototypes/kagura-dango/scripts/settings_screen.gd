extends Control
## Settings: a volume slider per audio bus (each slider's `bus` metadata names it) and the phone-vibration switch.
## Changes apply at once (the dialogue BGM plays here so the music level can be heard; letting go of the sound or
## voice slider plays a sample) and are saved on 返回.

signal back_requested

const Haptics := preload("res://addons/proto_kit/haptics.gd")
## Played when the slider of that bus is let go.
const SAMPLES := {&"SFX": "res://assets/sfx/hit.ogg", &"Voice": "res://assets/voice/kagura_rice.wav"}


func _ready() -> void:
	for s: Range in [%Music, %Sfx, %Voice]:
		var bus: StringName = s.get_meta("bus")
		s.set_value_no_signal(Settings.volumes[bus])
		s.value_changed.connect(func(v: float):
			Settings.volumes[bus] = v
			Settings.apply())
		s.drag_ended.connect(func(_changed: bool): _sample(bus))
	var can_buzz := Haptics.new().supported()
	%Haptics.disabled = not can_buzz
	%Haptics.set_pressed_no_signal(Settings.haptics and can_buzz)
	%HapticsNote.visible = not can_buzz
	%Haptics.toggled.connect(func(on: bool):
		Settings.haptics = on
		if on:
			Haptics.new().buzz(1))
	%Back.pressed.connect(func():
		Settings.save_all()
		back_requested.emit())


func _sample(bus: StringName) -> void:
	var path: String = SAMPLES.get(bus, "")
	if path == "" or not ResourceLoader.exists(path):
		return
	%Sample.stream = load(path)
	%Sample.bus = bus
	%Sample.play()
