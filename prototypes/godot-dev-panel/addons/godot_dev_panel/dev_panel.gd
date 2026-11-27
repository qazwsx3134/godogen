extends CanvasLayer

signal opened
signal closed

const SECTION_ORDER := [
	"Run", "Engine & Display", "Army", "Enemies", "Stress Tests", "Hero",
	"Camera", "Rewards", "Health Bars", "Debug View", "Terrain", "Music",
	"Audio", "Sound Test",
]
const SECTION_SCENE := preload("section.tscn")
const ROW_SCENE := preload("row.tscn")

@onready var overlay: Control = %Overlay
@onready var sections: VBoxContainer = %Sections
@onready var preview: AudioStreamPlayer = %Preview

var _groups: Dictionary[String, VBoxContainer] = {}
var _refresh_fields: Array[Callable] = []
var _refresh_readouts: Array[Callable] = []
var _readout_delay := 0.0
var _was_paused := false
var _mouse_mode := Input.MOUSE_MODE_VISIBLE


## Debug exports must opt in using the custom feature "developer".
static func available() -> bool:
	return OS.is_debug_build() and (OS.has_feature("editor") or OS.has_feature("developer"))


func _ready() -> void:
	set_process_input(available())
	set_process(false)
	if not available():
		return
	%Close.pressed.connect(close)
	add_action("Run", "重新載入目前場景", _restart_scene)
	bind_number("Run", "遊戲速率", Engine, &"time_scale", 0.1, 3.0, 0.05)
	bind_number("Engine & Display", "FPS 上限（0 為不限）", Engine, &"max_fps", 0, 240, 1.0)
	if not OS.has_feature("web") and DisplayServer.get_name() != "headless":
		add_toggle("Engine & Display", "全螢幕",
			func() -> bool: return get_window().mode == Window.MODE_FULLSCREEN,
			func(enabled: bool): get_window().mode = Window.MODE_FULLSCREEN if enabled else Window.MODE_WINDOWED)
		add_toggle("Engine & Display", "垂直同步",
			func() -> bool: return DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED,
			func(enabled: bool): DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED))
	add_readout("Engine & Display", "FPS", func(): return Engine.get_frames_per_second())
	add_readout("Debug View", "繪製呼叫", func(): return Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	add_readout("Debug View", "活躍 3D 物理體", func(): return Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS))
	add_number("Audio", "主音量（dB）",
		func(): return AudioServer.get_bus_volume_db(0),
		func(value: float): AudioServer.set_bus_volume_db(0, value), -60, 6, 0.5)
	add_toggle("Audio", "主音量靜音",
		func(): return AudioServer.is_bus_mute(0),
		func(enabled: bool): AudioServer.set_bus_mute(0, enabled))


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F1 or event.keycode == KEY_F1:
			if is_open():
				close()
			else:
				open()
			get_viewport().set_input_as_handled()
		elif is_open() and event.is_action_pressed("ui_cancel"):
			close()
			get_viewport().set_input_as_handled()


func is_open() -> bool:
	return is_node_ready() and overlay.visible


func open() -> void:
	if not available() or not is_node_ready() or is_open():
		return
	_was_paused = get_tree().paused
	_mouse_mode = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for refresh: Callable in _refresh_fields + _refresh_readouts:
		refresh.call()
	overlay.show()
	%Close.grab_focus()
	_readout_delay = 0.25
	set_process(true)
	opened.emit()


func close() -> void:
	if not is_open():
		return
	overlay.hide()
	preview.stop()
	set_process(false)
	get_tree().paused = _was_paused
	Input.mouse_mode = _mouse_mode
	closed.emit()


func _exit_tree() -> void:
	if is_open():
		get_tree().paused = _was_paused
		Input.mouse_mode = _mouse_mode


func _process(delta: float) -> void:
	_readout_delay -= delta / maxf(0.001, Engine.time_scale)
	if _readout_delay > 0.0:
		return
	_readout_delay = 0.25
	for refresh: Callable in _refresh_readouts:
		refresh.call()


func bind_number(section: String, label: String, target: Object, property: StringName,
		minimum: float, maximum: float, step: float) -> void:
	add_number(section, label, target.get.bind(property),
		func(value: float):
			target.set(property, roundi(value) if typeof(target.get(property)) == TYPE_INT else value),
		minimum, maximum, step)


func bind_toggle(section: String, label: String, target: Object, property: StringName) -> void:
	add_toggle(section, label, target.get.bind(property),
		func(value: bool): target.set(property, value))


func add_number(section: String, label: String, getter: Callable, setter: Callable,
		minimum: float, maximum: float, step: float) -> void:
	var row := _add_row(section, label)
	var field: SpinBox = row.get_node("%Number")
	field.min_value = minimum
	field.max_value = maximum
	field.step = step
	field.show()
	field.value_changed.connect(setter)
	_refresh_fields.append(func(): field.set_value_no_signal(float(getter.call())))


func add_toggle(section: String, label: String, getter: Callable, setter: Callable) -> void:
	var row := _add_row(section, label)
	var field: CheckButton = row.get_node("%Toggle")
	field.show()
	field.toggled.connect(setter)
	_refresh_fields.append(func(): field.set_pressed_no_signal(bool(getter.call())))


func add_action(section: String, label: String, command: Callable) -> void:
	var row := _add_row(section, "")
	var button: Button = row.get_node("%Command")
	button.text = label
	button.show()
	button.pressed.connect(command)


func add_readout(section: String, label: String, getter: Callable) -> void:
	var row := _add_row(section, label)
	var field: Label = row.get_node("%Value")
	field.show()
	_refresh_readouts.append(func(): field.text = str(getter.call()))


func preview_sound(source: AudioStreamPlayer) -> void:
	preview.stream = source.stream
	preview.bus = source.bus
	preview.volume_db = source.volume_db
	preview.pitch_scale = source.pitch_scale
	preview.play()


func _add_row(section: String, label: String) -> Control:
	if not _groups.has(section):
		var group := SECTION_SCENE.instantiate()
		sections.add_child(group)
		var title: Button = group.get_node("%SectionTitle")
		var fields: VBoxContainer = group.get_node("%Fields")
		title.button_pressed = section == "Run"
		title.text = ("▾  " if title.button_pressed else "▸  ") + section
		fields.visible = title.button_pressed
		title.toggled.connect(func(expanded: bool):
			fields.visible = expanded
			title.text = ("▾  " if expanded else "▸  ") + section
		)
		var order := _section_rank(section)
		group.set_meta(&"section_rank", order)
		for sibling in sections.get_children():
			if int(sibling.get_meta(&"section_rank")) > order:
				sections.move_child(group, sibling.get_index())
				break
		_groups[section] = fields
	var row := ROW_SCENE.instantiate() as Control
	_groups[section].add_child(row)
	var caption: Label = row.get_node("%Caption")
	caption.text = label
	caption.visible = not label.is_empty()
	return row


func _section_rank(section: String) -> int:
	var rank := SECTION_ORDER.find(section)
	return SECTION_ORDER.size() if rank == -1 else rank


func _restart_scene() -> void:
	close()
	get_tree().reload_current_scene.call_deferred()
