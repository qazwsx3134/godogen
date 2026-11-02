class_name StoryData
extends RefCounted
## Lines and result comments, from data/story.json.

static var _data := {}


static func lines(key: String) -> Array:
	return _load().get(key, [])


static func comment(level: String, rank: StringName) -> Array:
	return _load().comments.get(level, {}).get(String(rank), ["", ""])


static func _load() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/story.json"))
	return _data
