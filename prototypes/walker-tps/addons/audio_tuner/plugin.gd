@tool
extends EditorPlugin

const Mix := preload("mix.gd")
const AUDIO_EXTENSIONS := ["wav", "ogg", "mp3"]
const SOURCE_EXTENSIONS := ["gd", "cs", "tscn", "tres"]

var _panel: VBoxContainer
var _search: LineEdit
var _all: CheckBox
var _list: ItemList
var _source: Label
var _status: Label
var _pitch: SpinBox
var _gain: SpinBox
var _preview: AudioStreamPlayer
var _apply_delay: Timer
var _clips: Dictionary
var _references: Dictionary = {}
var _paths := PackedStringArray()
var _path := ""
var _updating := false
var _dirty := false


func _enter_tree() -> void:
	var config := ConfigFile.new()
	var error := config.load(Mix.CONFIG_PATH)
	_clips = Mix.decode(config) if error == OK else Mix.read_legacy()
	_panel = VBoxContainer.new()
	_panel.custom_minimum_size.y = 260
	_search = LineEdit.new()
	_search.placeholder_text = "Filter by filename or path"
	_panel.add_child(_search)
	_search.text_changed.connect(func(_text: String) -> void: _refresh_list())
	var toolbar := HBoxContainer.new()
	_panel.add_child(toolbar)
	_all = CheckBox.new()
	_all.text = "Include unreferenced"
	toolbar.add_child(_all)
	_all.toggled.connect(func(_on: bool) -> void: _refresh_list())
	_button(toolbar, "Rescan", _scan)

	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.add_child(_list)
	_list.item_selected.connect(_select)
	_source = Label.new()
	_source.clip_text = true
	_panel.add_child(_source)

	var controls := HBoxContainer.new()
	_panel.add_child(controls)
	_pitch = _number(controls, "Pitch ×", 0.25, 4.0, 1.0)
	_gain = _number(controls, "Gain dB", -60.0, 12.0, 0.0)
	_pitch.value_changed.connect(_change)
	_gain.value_changed.connect(_change)
	_button(controls, "Play", _play)
	_button(controls, "Stop", func() -> void: _preview.stop())
	_button(controls, "Reset clip", _reset_clip)
	_button(controls, "Apply to game", _save_mix)
	_status = Label.new()
	_panel.add_child(_status)

	_preview = AudioStreamPlayer.new()
	_panel.add_child(_preview)
	_apply_delay = Timer.new()
	_apply_delay.one_shot = true
	_apply_delay.wait_time = 0.35
	_panel.add_child(_apply_delay)
	_apply_delay.timeout.connect(_save_mix)
	add_control_to_bottom_panel(_panel, "Audio Tuner")
	_scan()
	get_editor_interface().get_resource_filesystem().filesystem_changed.connect(_scan, CONNECT_ONE_SHOT)


func _exit_tree() -> void:
	if _dirty:
		_save_mix()
	remove_control_from_bottom_panel(_panel)
	_panel.queue_free()


func _button(row: BoxContainer, label: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.pressed.connect(callback)
	row.add_child(button)


func _number(row: HBoxContainer, title: String, low: float, high: float, initial: float) -> SpinBox:
	var label := Label.new()
	label.text = title
	row.add_child(label)
	var field := SpinBox.new()
	field.min_value = low
	field.max_value = high
	field.step = 0.01
	field.update_on_text_changed = true
	field.value = initial
	field.custom_minimum_size.x = 96
	row.add_child(field)
	return field


func _scan() -> void:
	_paths.clear()
	_references.clear()
	var pattern := RegEx.create_from_string(r"res://[^\x22\x27\r\n]+?\.(?:wav|ogg|mp3)(?=[\x22\x27])")
	_scan_folder("res://", pattern)
	_paths.sort()
	_refresh_list()


func _scan_folder(folder: String, pattern: RegEx) -> void:
	var dir := DirAccess.open(folder)
	if dir == null:
		return
	for file: String in dir.get_files():
		var path := folder.path_join(file)
		var extension := file.get_extension().to_lower()
		if extension in AUDIO_EXTENSIONS:
			if ResourceLoader.exists(path):
				_paths.append(path)
		elif extension in SOURCE_EXTENSIONS:
			for result: RegExMatch in pattern.search_all(FileAccess.get_file_as_string(path)):
				var clip := result.get_string()
				var references: PackedStringArray = _references.get(clip, PackedStringArray())
				if not path in references:
					references.append(path)
					_references[clip] = references
	for child: String in dir.get_directories():
		if not child.begins_with("."):
			var subfolder := folder.path_join(child)
			if not FileAccess.file_exists(subfolder.path_join(".gdignore")):
				_scan_folder(subfolder, pattern)


func _refresh_list() -> void:
	_list.clear()
	var selection := -1
	var query := _search.text.strip_edges().to_lower()
	for path: String in _paths:
		if (not _all.button_pressed and not _references.has(path)) or (not query.is_empty() and not path.to_lower().contains(query)):
			continue
		var index := _list.add_item(path.trim_prefix("res://"))
		_list.set_item_metadata(index, path)
		var references: PackedStringArray = _references.get(path, PackedStringArray())
		_list.set_item_tooltip(index, "\n".join(references))
		if path == _path:
			selection = index
	if selection < 0 and _list.item_count > 0:
		selection = 0
	if selection >= 0:
		_list.select(selection)
		_select(selection)
	else:
		_path = ""
		_source.text = "No matching audio clips"
	_status.text = "%d clips shown%s" % [_list.item_count, " · unsaved changes" if _dirty else ""]


func _select(index: int) -> void:
	var path: String = _list.get_item_metadata(index)
	if path != _path:
		_preview.stop()
	_path = path
	var tuning: Dictionary = _clips.get(_path, {})
	_updating = true
	_pitch.value = tuning.get("pitch", 1.0)
	_gain.value = tuning.get("gain_db", 0.0)
	_updating = false
	var references: PackedStringArray = _references.get(_path, PackedStringArray())
	_source.text = "%s · %d reference files" % [_path.get_file(), references.size()]
	_source.tooltip_text = "\n".join(references)


func _change(_value: float) -> void:
	if _updating or _path.is_empty():
		return
	_capture_selected()
	_dirty = true
	_status.text = "Applying changes…"
	_apply_delay.start()


func _capture_selected() -> void:
	if _path.is_empty():
		return
	if is_equal_approx(_pitch.value, 1.0) and is_zero_approx(_gain.value):
		_clips.erase(_path)
	else:
		_clips[_path] = {"pitch": _pitch.value, "gain_db": _gain.value}
	_preview.pitch_scale = _pitch.value
	_preview.volume_db = _gain.value


func _play() -> void:
	if _path.is_empty():
		return
	_preview.stream = load(_path) as AudioStream
	_preview.pitch_scale = _pitch.value
	_preview.volume_db = _gain.value
	_preview.play()


func _reset_clip() -> void:
	_pitch.value = 1.0
	_gain.value = 0.0


func _save_mix() -> void:
	_pitch.apply()
	_gain.apply()
	_apply_delay.stop()
	_capture_selected()
	var config := ConfigFile.new()
	config.set_value("mix", "version", 1)
	for path: String in _clips:
		var tuning: Dictionary = _clips[path]
		config.set_value(path, "pitch", tuning["pitch"])
		config.set_value(path, "gain_db", tuning["gain_db"])
	var error := config.save(Mix.CONFIG_PATH)
	if error != OK:
		_status.text = "Save failed: %s" % error_string(error)
		return
	_dirty = false
	if _path.is_empty():
		_status.text = "Applied to game · audio_mix.cfg"
	else:
		_status.text = "Applied · %s · ×%.2f / %+.2f dB · next playback" % [
			_path.get_file(), _pitch.value, _gain.value]
