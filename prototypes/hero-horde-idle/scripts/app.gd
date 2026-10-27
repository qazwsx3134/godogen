extends "res://addons/proto_kit/scene_router.gd"
## App (autoload scenes/app.tscn): what lives across screens. Moving between screens with a fade is godot-kit's
## scene_router (go(path, hand) fades out, changes the scene, fades in; the next screen asks for `hand` with take()
## in its _ready, e.g. the stage to push). Added here: the player's settings (domain/settings.gd, applied at start and
## whenever they change) and the progress save every screen shares.
## Screens also work without it (tests instantiate them directly): they fall back to their own defaults.

const Settings = preload("res://domain/settings.gd")
const Progression = preload("res://domain/progression.gd")
const PixelUi = preload("res://scripts/pixel_ui.gd")
const PUSH := "res://scenes/main.tscn"
const HOME := "res://scenes/home.tscn"

## Saved at settings_path; screens read it (haptics) and change it through the settings panel.
var settings: RefCounted
var settings_path: String = Settings.PATH
## The progress save every screen loads and saves (tests point it elsewhere so the player's save is never touched).
var progress_path: String = Progression.SAVE_PATH
var _progress: RefCounted = null


func _enter_tree() -> void:
	# Every screen's framed and textured nodes draw their pixel art with even-width pixels (scripts/pixel_ui.gd).
	get_tree().node_added.connect(PixelUi.apply)


func _ready() -> void:
	super()
	# `-- --save=<name>` plays on user://<name>.json instead of the player's save (trial runs; on macOS Godot keeps
	# user:// in ~/Library/Application Support whatever XDG_DATA_HOME says).
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--save="):
			progress_path = "user://%s.json" % arg.trim_prefix("--save=")
	settings = Settings.load_from(settings_path)
	settings.apply()


## The player's progress, loaded once from progress_path and shared by every screen (each saves it after a change).
func progress() -> RefCounted:
	if _progress == null:
		_progress = Progression.load_from(progress_path)
	return _progress


## Forgets the loaded progress so the next progress() reads the save again (tests that edit the file).
func reload_progress() -> void:
	_progress = null


## Called by the settings panel after a change: applies and saves.
func settings_changed() -> void:
	settings.apply()
	settings.save(settings_path)
