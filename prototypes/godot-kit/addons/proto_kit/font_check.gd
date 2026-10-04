extends RefCounted
## Test helper: does the shipped font have a glyph for every character the game can write?
##
## A trimmed font (tools/subset_font.py) drops what the game does not use. On a desktop the editor and the
## player's system fonts hide a missing glyph, but a web build has no system font and shows a blank box.
## This scans the game's own scripts, scenes, resources and data files, so a test can say so before a player does.
##
##   const FontCheck = preload("res://addons/proto_kit/font_check.gd")
##   var missing: String = FontCheck.missing_characters(load("res://ui/fonts/MyFont.ttf"))
##   _expect(missing.is_empty(), "the font has every character the game writes (missing: %s; run tools/subset_font.py)" % missing)
##
## Keep the extensions and skipped folders in step with subset_font.py (same defaults). A project whose text
## lives in a file type that is not listed passes `extensions` explicitly.

const EXTENSIONS: PackedStringArray = ["gd", "tscn", "tres", "json", "txt", "cfg", "csv", "ds", "dialogue", "yaml", "yml", "ini", "toml"]
## Folders that never ship text to the player (`publishing` = the store page's text and pictures). Hidden folders (".godot", ".git") are always skipped.
const SKIP_DIRS: PackedStringArray = ["addons", "art_src", "tests", "tools", "build", "docs", "publishing", "node_modules", "test-results"]

## {character: path of the first file that writes it} for every non-ASCII character under `root`.
static func scanned_characters(root: String = "res://", extensions: PackedStringArray = EXTENSIONS, skip_dirs: PackedStringArray = SKIP_DIRS) -> Dictionary:
	var found: Dictionary = {}
	_scan(root, extensions, skip_dirs, found)
	return found

## {character: path} for the characters `font` has no glyph for.
static func missing_report(font: Font, root: String = "res://", extensions: PackedStringArray = EXTENSIONS, skip_dirs: PackedStringArray = SKIP_DIRS) -> Dictionary:
	var missing: Dictionary = {}
	var scanned: Dictionary = scanned_characters(root, extensions, skip_dirs)
	for character: String in scanned:
		if not font.has_char(character.unicode_at(0)):
			missing[character] = scanned[character]
	return missing

## The missing characters as one string, sorted by code point ("" when the font covers everything).
static func missing_characters(font: Font, root: String = "res://", extensions: PackedStringArray = EXTENSIONS, skip_dirs: PackedStringArray = SKIP_DIRS) -> String:
	var codes: Array = []
	for character: String in missing_report(font, root, extensions, skip_dirs):
		codes.append(character.unicode_at(0))
	codes.sort()
	var text: String = ""
	for code: int in codes:
		text += char(code)
	return text

static func _scan(dir: String, extensions: PackedStringArray, skip_dirs: PackedStringArray, found: Dictionary) -> void:
	for sub: String in DirAccess.get_directories_at(dir):
		if not skip_dirs.has(sub) and not sub.begins_with("."):
			_scan(dir.path_join(sub), extensions, skip_dirs, found)
	for file: String in DirAccess.get_files_at(dir):
		if not extensions.has(file.get_extension()):
			continue
		var path: String = dir.path_join(file)
		for character: String in FileAccess.get_file_as_string(path):
			var code: int = character.unicode_at(0)
			if code > 0x7E and code != 0xFEFF and not found.has(character):
				found[character] = path
