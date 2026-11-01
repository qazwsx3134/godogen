extends Control
## Developer asset browser: choose a ready scene, inspect its source, replay.
const TrailDemo = preload("res://addons/proto_kit/vfx/3d/00gamedevs/weapon_demo.tscn")
const ImpactDemo = preload("res://addons/proto_kit/vfx/3d/00gamedevs/impact_demo.tscn")
const Library = preload("res://addons/proto_kit/vfx/library.gd")
@export_enum("2d", "3d") var dimension: String = "2d"
@onready var list: ItemList = %EffectsList
@onready var source_choice: OptionButton = %SourceChoice
@onready var holder: Node = %Effects
@onready var info: Label = %Info
@onready var replay: Timer = %Replay
@onready var viewport: SubViewport = %Preview
var effect_ids := PackedStringArray()
var selected: String = ""
var current_effect: Node
var _manual_stop: bool = false

func _ready() -> void:
	list.item_selected.connect(_select)
	source_choice.item_selected.connect(_filter_source)
	if dimension == "2d":
		source_choice.set_item_disabled(2, true)
	%ReplayButton.pressed.connect(_play)
	%StopButton.pressed.connect(_stop)
	%HitButton.pressed.connect(_hit)
	%SpeedControl.value_changed.connect(_speed)
	replay.timeout.connect(_play)
	_filter_source(source_choice.selected)

func _filter_source(index: int) -> void:
	effect_ids.clear()
	list.clear()
	for id: String in Library.ids(dimension):
		var source_name: String = Library.DETAILS[id].source
		if index == 1 and source_name != "Scenario":
			continue
		if index == 2 and source_name != "00GameDevs":
			continue
		effect_ids.append(id)
		list.add_item(Library.DETAILS[id].name)
	if not effect_ids.is_empty():
		list.select(0)
		_select(0)

func _select(index: int) -> void:
	selected = effect_ids[index]
	var data: Dictionary = Library.DETAILS[selected]
	info.text = "%s\n%s · %s\n%s · %.2f s\n%s" % [data.name, data.source, dimension.to_upper(),
		"Loop" if data.loop else "One shot", data.duration, selected]
	_play()

func _play() -> void:
	replay.stop()
	_manual_stop = false
	for child: Node in holder.get_children():
		holder.remove_child(child)
		child.queue_free()
	if selected.is_empty():
		return
	var effect: Node
	if selected == "weapon-smear":
		effect = TrailDemo.instantiate()
	elif selected == "impact-frame":
		effect = ImpactDemo.instantiate()
	else:
		effect = Library.get_scene(selected, dimension).instantiate()
	holder.add_child(effect)
	current_effect = effect.get_node("Trail") if selected == "weapon-smear" else (effect.get_node("Impact") if selected == "impact-frame" else effect)
	%StopButton.disabled = "burst" in current_effect and current_effect.burst
	%HitButton.disabled = not ("kind" in current_effect and current_effect.kind == 0)
	%SpeedControl.editable = "speed" in current_effect or "speed_scale" in current_effect
	_speed(%SpeedControl.value)
	if effect is Node2D:
		effect.position = Vector2(viewport.size) * 0.5
		effect.scale = Vector2(2, 2)
	var data: Dictionary = Library.DETAILS[selected]
	if effect is Node3D:
		effect.position.y = data.get("preview_height", 0.0)

func _stop() -> void:
	_manual_stop = true
	if not is_instance_valid(current_effect):
		return
	if current_effect.has_method("stop"):
		current_effect.stop()
	elif current_effect.has_method("reset"):
		current_effect.reset()
	replay.stop()

func _hit() -> void:
	if is_instance_valid(current_effect) and current_effect.has_method("hit"):
		current_effect.hit()

func _speed(value: float) -> void:
	%SpeedLabel.text = "Speed %.2fx" % value
	if not is_instance_valid(current_effect):
		return
	if "speed" in current_effect:
		current_effect.speed = value
	elif "speed_scale" in current_effect:
		current_effect.speed_scale = value
	_schedule_replay()

func _schedule_replay() -> void:
	replay.stop()
	if _manual_stop or selected.is_empty() or not is_instance_valid(current_effect):
		return
	var data: Dictionary = Library.DETAILS[selected]
	if data.loop:
		return
	var visual_elapsed: float = 0.0
	if "elapsed" in current_effect:
		visual_elapsed = current_effect.elapsed
	elif current_effect is AnimatedSprite2D or current_effect is AnimatedSprite3D:
		visual_elapsed = (current_effect.frame + current_effect.frame_progress) / current_effect.sprite_frames.get_animation_speed(current_effect.animation)
	var rate: float = %SpeedControl.value if %SpeedControl.editable else 1.0
	replay.start(maxf(0.02, float(data.duration) - visual_elapsed) / rate + 0.35)
