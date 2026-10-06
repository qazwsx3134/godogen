extends "res://addons/proto_kit/test_kit.gd"
## scenes/stage.tscn drives the stage: an actor's standing box is scaled to its slot (left/center/right)
## and stands on the slot's bottom edge, while its art keeps the framing of its own
## scenes/characters/<id>.tscn in any slot; moving a slot moves the actor, each background shows in the
## frame of its name, the editor-only guides are gone at runtime, and playing never writes back into
## the scene files.

const STAGE_PATH: String = "res://scenes/stage.tscn"
const KAGURA_PATH: String = "res://scenes/characters/kagura.tscn"
const TEST_SAVE: String = "user://stage_scene_test.save"
const TEST_UI: String = "user://stage_scene_test_ui.cfg"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene_before: String = FileAccess.get_file_as_string(STAGE_PATH)
	var kagura_before: String = FileAccess.get_file_as_string(KAGURA_PATH)
	var source: Node = (load(STAGE_PATH) as PackedScene).instantiate()
	for slot: String in ["left", "center", "right"]:
		_expect(source.has_node("StageArea/%s/Preview" % slot), "the %s slot shows a portrait in the editor" % slot)
	_expect(source.has_node("DialogueGuide") and source.has_node("Backgrounds/Default"), "editor guide and default frame exist")
	source.free()

	var game: Control = (load("res://main.tscn") as PackedScene).instantiate() as Control
	game.story_path = "res://data/phase4_story.json"
	game.save_path = TEST_SAVE
	game.ui_preference_path = TEST_UI
	root.add_child(game)
	await _frames(3)
	game._on_begin_pressed()
	await _until(func() -> bool: return game._screen_mode == "story", "story starts")
	# Staging: the opening places Gintoki with char() but only Shinpachi speaks.
	_expect(game._sprites["shinpachi"].visible and not game._sprites["gintoki"].visible,
		"only the character who speaks is on stage; char() alone does not bring anyone on")
	game._focus_speaker("gintoki", "")
	_expect(game._sprites["gintoki"].visible and game._sprites["shinpachi"].visible,
		"a new speaker joins the stage and the earlier speaker stays")
	_expect(game._char_layer.get_child(-1) == game._sprites["gintoki"] and game._sprites["shinpachi"].modulate.r < 0.9
		and game._sprites["gintoki"].modulate == Color.WHITE, "the speaker is in front and lit, the others dimmed")
	game._focus_speaker("gintoki+kagura", "")
	_expect(game._sprites["kagura"].visible and game._sprites["kagura"].modulate == Color.WHITE
		and game._sprites["gintoki"].modulate == Color.WHITE and game._sprites["shinpachi"].modulate.r < 0.9,
		"a line said together lights both speakers")
	game._apply_character({"id": "kagura", "visible": false})
	await create_timer(0.25).timeout
	_expect(not game._sprites["kagura"].visible, "hide() takes a character off stage")
	var kagura_art: TextureRect = game._sprites["kagura"].get_node("Art")
	var usual: Texture2D = kagura_art.texture
	var face: Texture2D = load("res://assets/image/gin-san.png")
	game._sprites["kagura"].call("set_expression_art", {"angry": face})
	game._focus_speaker("kagura", "angry")
	_expect(kagura_art.texture == face, "a line tagged with a face that has a picture shows that picture")
	game._focus_speaker("kagura", "panic")
	_expect(kagura_art.texture == usual, "a face without a picture shows the character's usual picture")
	game._sprites["kagura"].call("set_expression_art", {})
	game._apply_character({"id": "kagura", "visible": false})
	await create_timer(0.25).timeout
	# A fitted face (tools/fit_expressions.gd) is wider than the usual picture where the pose sticks
	# out: it keeps the usual picture's scale, feet line and centre.
	var shinpachi: Control = game._sprites["shinpachi"]
	var shinpachi_art: TextureRect = shinpachi.get_node("Art")
	shinpachi.call("set_expression", "neutral")
	var usual_rect: Rect2 = shinpachi_art.get_global_rect()
	var usual_width: float = float(shinpachi_art.texture.get_width())
	shinpachi.call("set_expression", "shout")
	var shout_rect: Rect2 = shinpachi_art.get_global_rect()
	_expect(shinpachi_art.texture.resource_path.ends_with("shinpachi_shout.png")
		and absf(shout_rect.end.y - usual_rect.end.y) < 1.0 and absf(shout_rect.get_center().x - usual_rect.get_center().x) < 1.0
		and absf(shout_rect.size.x / usual_rect.size.x - shinpachi_art.texture.get_width() / usual_width) < 0.01,
		"a fitted face keeps the usual picture's scale, feet line and centre")
	shinpachi.call("set_expression", "neutral")
	_expect(shinpachi_art.get_global_rect().is_equal_approx(usual_rect), "the usual picture goes back to its own rect")
	var stage: Node = game._stage_area.get_parent()
	_expect(not stage.has_node("DialogueGuide"), "the dialogue guide is editor-only")
	_expect(not game._stage_area.has_node("left/Preview"), "slot portraits are editor-only")

	game._apply_character({"id": "kagura", "position": "left", "visible": true})
	await _frames(2)
	var marker: Control = game._slot_markers["left"]
	var sprite: Control = game._sprites["kagura"]
	_expect(_stands_in(sprite, marker), "kagura's standing box fills the left slot and stands on its bottom edge")
	var kagura_framing: float = _art_ratio(sprite)
	_expect(kagura_framing > 1.05, "kagura's art is framed larger than her box, as set in her own scene")
	game._apply_character({"id": "kagura", "position": "right", "visible": true})
	game._apply_character({"id": "otose", "position": "left", "visible": true})
	await _frames(2)
	_expect(_stands_in(sprite, game._slot_markers["right"]) and is_equal_approx(_art_ratio(sprite), kagura_framing),
		"kagura keeps her own framing in another slot")
	_expect(_stands_in(game._sprites["otose"], marker) and not is_equal_approx(_art_ratio(game._sprites["otose"]), kagura_framing),
		"another character in the left slot gets the same box with its own framing")
	game._apply_character({"id": "kagura", "position": "left", "visible": true})
	await _frames(2)
	var scale_y: float = game._game.get_global_transform().get_scale().y
	_expect(absf(marker.get_global_rect().end.y - (game._stage_bottom + marker.offset_bottom) * scale_y) < 0.5,
		"the slot's bottom edge keeps its offset from the dialogue box's top")

	marker.offset_left += 120.0
	marker.offset_right += 120.0
	var height_before: float = sprite.get_global_rect().size.y
	marker.offset_top += 400.0  # shorter box, shorter actor
	game._layout()
	await _frames(2)
	_expect(_stands_in(sprite, marker) and sprite.get_global_rect().size.y < height_before - 300.0,
		"moving and shrinking the slot moves and shrinks the actor")

	for id: String in ["yorozuya_exterior", "yorozuya_kitchen"]:
		game._apply_background(id)
		var shown: Array = game._background_frames.values().filter(func(frame: Control) -> bool: return frame.visible)
		_expect(shown.size() == 1 and str(shown[0].name) == id and shown[0].texture != null, "%s shows in its own frame" % id)
	var gradient_only: Dictionary = game._backgrounds.duplicate(true)
	game._backgrounds["no_art"] = {"label": "x", "top": "#000000", "bottom": "#ffffff"}
	game._apply_background("no_art")
	_expect(game._background_rect == game._background_frames["Default"] and game._background_rect.visible,
		"a background without art shows its gradient in the default frame")
	game._backgrounds = gradient_only

	game.queue_free()
	await _frames(2)
	_expect(FileAccess.get_file_as_string(STAGE_PATH) == scene_before and FileAccess.get_file_as_string(KAGURA_PATH) == kagura_before,
		"playing leaves the stage and character scenes unchanged")
	for path: String in [TEST_SAVE, TEST_UI]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_finish("stage scene")


func _stands_in(sprite: Control, marker: Control) -> bool:
	var box: Rect2 = marker.get_global_rect()
	var art: Rect2 = sprite.get_global_rect()
	return absf(art.get_center().x - box.get_center().x) < 1.0 and absf(art.end.y - box.end.y) < 1.0 \
		and absf(art.size.y - box.size.y) < 1.0


## Art height over standing-box height: the framing a character scene gives its picture.
func _art_ratio(sprite: Control) -> float:
	return (sprite.get_node("Art") as Control).get_global_rect().size.y / sprite.get_global_rect().size.y
