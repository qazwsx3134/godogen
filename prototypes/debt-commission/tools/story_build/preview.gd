extends Node
## Plays main.tscn with the story the Story Tools menu just built, on a separate save file so
## previews never touch the real game's saves. Editor-only (tools/ is excluded from export).

const MAIN_SCENE: PackedScene = preload("res://main.tscn")
const PREVIEW_STORY_FILE: String = "user://story_preview_path.txt"
const PREVIEW_SAVE: String = "user://story_preview.save"


func _ready() -> void:
	var game: Control = MAIN_SCENE.instantiate() as Control
	game.story_path = FileAccess.get_file_as_string(PREVIEW_STORY_FILE).strip_edges()
	game.save_path = PREVIEW_SAVE
	add_child(game)
