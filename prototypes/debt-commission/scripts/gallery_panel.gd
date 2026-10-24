extends Panel
## 鑑賞 (scenes/ui/gallery_panel.tscn), opened from 章節選擇: 畫廊 shows every background with a
## picture, 音樂 every track with a recording; what has not been met in play yet is ？？？. A seen
## picture opens full screen (tap to close); a heard track plays here (tap again to stop). Items are
## gallery_picture.tscn and gallery_track.tscn; colours come from ui_styles.gd via main.gd.

signal closed
## A track started (true) or the last one stopped (false); main.gd quiets the story music meanwhile.
signal previewing(active: bool)
## The shown tab changed; main.gd restyles the tab buttons.
signal tab_changed

const PICTURE_SCENE: PackedScene = preload("res://scenes/ui/gallery_picture.tscn")
const TRACK_SCENE: PackedScene = preload("res://scenes/ui/gallery_track.tscn")
const LOCKED: String = "？？？"

var tab: String = "pictures"
var playing_id: String = ""

@onready var close_button: Button = %Close
@onready var pictures_tab: Button = %PicturesTab
@onready var music_tab: Button = %MusicTab
@onready var _pictures: GridContainer = %Pictures
@onready var _music: VBoxContainer = %Music
@onready var _progress: Label = %Progress
@onready var _viewer: Control = %Viewer
@onready var _viewer_picture: TextureRect = %ViewerPicture
@onready var _player: AudioStreamPlayer = %Player

var _counts: Dictionary = {}


func _ready() -> void:
	visible = false
	_viewer.visible = false
	close_button.pressed.connect(close)
	pictures_tab.pressed.connect(show_tab.bind("pictures"))
	music_tab.pressed.connect(show_tab.bind("music"))
	_viewer.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			close_viewer())
	_player.finished.connect(_stop_track)


## pictures, music: [{id, label, path, seen}] in catalog order. volume_db: the 音樂 setting.
func open(pictures: Array, music: Array, volume_db: float) -> void:
	_player.volume_db = volume_db
	for list: Container in [_pictures, _music]:
		for item: Node in list.get_children():
			list.remove_child(item)
			item.queue_free()
	for entry: Dictionary in pictures:
		var item: Button = PICTURE_SCENE.instantiate() as Button
		item.name = "Picture_" + str(entry["id"])
		var seen: bool = bool(entry["seen"])
		(item.get_node("%Caption") as Label).text = str(entry["label"]) if seen else LOCKED
		var thumb: TextureRect = item.get_node("%Thumb") as TextureRect
		thumb.texture = load(str(entry["path"])) as Texture2D if seen else null
		item.disabled = not seen
		if seen:
			item.pressed.connect(open_viewer.bind(str(entry["path"])))
		_pictures.add_child(item)
	for entry: Dictionary in music:
		var row: Button = TRACK_SCENE.instantiate() as Button
		row.name = "Track_" + str(entry["id"])
		var seen: bool = bool(entry["seen"])
		row.set_meta("label", str(entry["label"]))
		row.text = "♪ " + str(entry["label"]) if seen else LOCKED
		row.disabled = not seen
		if seen:
			row.pressed.connect(toggle_track.bind(str(entry["id"]), str(entry["path"])))
		_music.add_child(row)
	_counts = {"pictures": [pictures.filter(func(e: Dictionary) -> bool: return e["seen"]).size(), pictures.size()],
		"music": [music.filter(func(e: Dictionary) -> bool: return e["seen"]).size(), music.size()]}
	show_tab(tab)
	visible = true


func show_tab(which: String) -> void:
	tab = which
	_pictures.visible = which == "pictures"
	_music.visible = which == "music"
	pictures_tab.set_meta("ui_style_active", which == "pictures")
	music_tab.set_meta("ui_style_active", which == "music")
	var count: Array = _counts.get(which, [0, 0])
	_progress.text = "%s %d/%d" % ["已看過" if which == "pictures" else "已聽過", count[0], count[1]]
	tab_changed.emit()


func open_viewer(path: String) -> void:
	_viewer_picture.texture = load(path) as Texture2D
	_viewer.visible = true


func close_viewer() -> void:
	_viewer.visible = false


func toggle_track(id: String, path: String) -> void:
	var stopping: bool = playing_id == id
	_stop_track()
	if stopping:
		return
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		return
	_player.stream = stream
	_player.play()
	playing_id = id
	_paint_tracks()
	previewing.emit(true)


func close() -> void:
	_stop_track()
	close_viewer()
	visible = false
	closed.emit()


## Item nodes by "picture_<id>"／"track_<id>", for QA.
func items() -> Dictionary:
	var found: Dictionary = {}
	for item: Node in _pictures.get_children():
		found["picture_" + str(item.name).trim_prefix("Picture_")] = item
	for item: Node in _music.get_children():
		found["track_" + str(item.name).trim_prefix("Track_")] = item
	return found


## After the edition's colours are applied: each card's name takes its card's ink, as the text
## of a button would.
func match_captions() -> void:
	for item: Node in _pictures.get_children():
		var card: Button = item as Button
		(card.get_node("%Caption") as Label).add_theme_color_override("font_color",
			card.get_theme_color("font_disabled_color" if card.disabled else "font_color"))


func viewer_open() -> bool:
	return _viewer.visible


func _stop_track() -> void:
	var was_playing: bool = not playing_id.is_empty()
	_player.stop()
	playing_id = ""
	_paint_tracks()
	if was_playing:
		previewing.emit(false)


func _paint_tracks() -> void:
	for row: Node in _music.get_children():
		if (row as Button).disabled:
			continue
		var id: String = str(row.name).trim_prefix("Track_")
		(row as Button).text = ("■ " if id == playing_id else "♪ ") + str(row.get_meta("label"))
