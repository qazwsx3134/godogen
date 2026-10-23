extends "res://addons/proto_kit/test_kit.gd"
## 投稿檢查 and 素材授權: what a story uses (with the faces the game sets itself), what is still to
## draw, ART-SPEC.md sizes, broken pictures, assets without a license; 製作名單 adds the makers.

const AssetUsage = preload("res://scripts/asset_usage.gd")
const ArtCheck = preload("res://tools/art_check/art_check.gd")
const Library = preload("res://scripts/story_library.gd")
const Runner = preload("res://scripts/story_runner.gd")
const SHAPES: String = "res://tests/fixtures/art_check/shapes/"
const BROKEN: String = "res://tests/fixtures/art_check/broken/"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_usage()
	_shapes()
	_broken_and_shipped()
	_credits()
	_finish("ART CHECK TESTS")


func _usage() -> void:
	var catalog: Dictionary = {"backgrounds": {"room": {}, "yard": {}}, "characters": {"a": {}, "b": {}}, "items": {"key": {}},
		"sounds": {}, "music": {"song": {}}}
	var story: Dictionary = {"nodes": {
		"n1": {"steps": [{"op": "investigate", "places": [{"bg": "yard", "hotspots": [{"item": "key", "character": "b"}]}]},
			{"op": "say", "speaker": "a+b", "text": "", "expression": "smile"}, {"op": "bgm", "id": "song"},
			{"op": "say", "speaker": "nobody", "text": ""}, {"op": "bg", "id": "room"}]},
		"n2": {"steps": [{"op": "boke_round", "lines": [{"speaker": "b", "text": ""}]},
			{"op": "choice", "options": [{"text": "x", "require": "key", "next": "n1"}]}]}}}
	var used: Dictionary = AssetUsage.used(story, catalog, "a")
	_expect(used["backgrounds"] == {"room": ["n1"], "yard": ["n1"]} and used["investigation"] == {"yard": true},
		"backgrounds from bg steps and investigation places: %s" % [used["backgrounds"]])
	_expect(used["items"] == {"key": ["n1", "n2"]} and used["music"] == {"song": ["n1"]}, "items (hotspot, require) and music")
	_expect(used["characters"]["a"]["expressions"] == {"smile": ["n1"], "thinking": ["（選項時）"]}
		and used["characters"]["b"]["expressions"] == {"neutral": ["n1"], "smile": ["n1"], "annoyed": ["n2"]},
		"faces: a line's, a round speaker's annoyed, the POV's thinking at a choice: %s / %s"
		% [used["characters"]["a"]["expressions"], used["characters"]["b"]["expressions"]])
	_expect(not used["characters"].has("nobody"), "ids outside the catalog are not counted")


func _shapes() -> void:
	_expect(Runner.new().load_story(SHAPES + "ch1_story.json"), "a catalog with `license` fields loads")
	var report: Dictionary = ArtCheck.check(SHAPES)
	var text: String = "\n".join(PackedStringArray(report["todo"] + report["suggestions"]))
	_expect(report["errors"].is_empty(), "no errors: %s" % [report["errors"]])
	var todo: String = "\n".join(PackedStringArray(report["todo"]))
	_expect(todo.contains("（dusk）") and todo.contains("（shadow）") and todo.contains("表情 angry"),
		"to draw: the gradient background, the silhouette, the face with no picture:\n%s" % todo)
	_expect(not todo.contains("black") and not todo.contains("spare") and (report["todo"] as Array).size() == 3,
		"a flat colour and an unused background are not to-dos")
	for expected: String in ["（room） 是 800×600", "腳底離底邊還有 100 px", "表情 smile 畫布 500×1700 比定稿 600×1700 小",
			"（plain） 沒有透明底", "鑰匙（key）是 300×200"]:
		_expect(text.contains(expected), "suggests: %s" % expected)
	_expect(not text.contains("（hall） 是"), "a background of the advised size has no suggestion")
	_expect(report["no_license"] == ["backgrounds/hall"], "only the picture without an author lacks a license: %s" % [report["no_license"]])
	_expect(report["unused"] == ["backgrounds/spare"], "unused: %s" % [report["unused"]])
	var markdown: String = ArtCheck.to_markdown(report)
	_expect(markdown.contains("# 投稿檢查：檢查用作品") and markdown.contains("| 0 | 3 | 5 | 1 |"), "the report's summary row")


func _broken_and_shipped() -> void:
	var report: Dictionary = ArtCheck.check(BROKEN)
	var errors: String = "\n".join(PackedStringArray(report["errors"]))
	_expect(ArtCheck.error_count(report) == 2 and errors.contains("art/missing.png` 檔案不存在") and errors.contains("劇本 broken_ch1"),
		"a missing picture and the story the game rejects are errors:\n%s" % errors)
	var example: Dictionary = ArtCheck.check("res://stories/example")
	_expect(example["errors"].is_empty() and (example["todo"] as Array).size() == 4, "the example work: all to-do, no errors")
	_expect(ArtCheck.check("res://data/")["errors"].is_empty(), "the base work has no errors")
	_expect(ArtCheck.works("res://tests/fixtures/art_check/") == ["res://data/", "res://tests/fixtures/art_check/broken/",
		"res://tests/fixtures/art_check/shapes/"], "works: the base work, then each folder with a pack.json")


func _credits() -> void:
	var library: RefCounted = Library.new("res://tests/fixtures/no_registry.json", "user://art_check_progress.cfg",
		"res://tests/fixtures/art_check/")
	var sections: Array = library.credit_sections("res://tests/fixtures/no_game_credits.json")
	var shapes: Array = sections.filter(func(s: Dictionary) -> bool: return s["title"] == "第一章")
	_expect(shapes.size() == 1 and shapes[0]["credits"] == [{"role": "立繪", "names": ["畫師甲", "畫師丙"]},
		{"role": "背景", "names": ["畫師甲"]}, {"role": "路人設計", "names": ["畫師丁"]}, {"role": "道具", "names": ["畫師乙"]}],
		"製作名單 adds the makers of what the chapter uses, by role, without repeats: %s" % [shapes])
