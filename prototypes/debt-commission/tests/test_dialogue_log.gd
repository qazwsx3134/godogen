extends "res://addons/proto_kit/test_kit.gd"
## Dialogue log read like a chat (docs/PLAN-LOG-AVATAR-TUTORIAL.md A): others left with avatar and name ink,
## the POV and choices right, narration centred; every character's name ink is readable on washi.

const UI_STYLES = preload("res://scripts/ui_styles.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	test_log_name_ink_reads_on_washi_for_every_character()
	await test_log_rows_place_each_kind_of_line()
	_finish("DIALOGUE LOG TESTS")


func test_log_name_ink_reads_on_washi_for_every_character() -> void:
	# Arrange
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_catalog.json"))
	var ground: Color = UI_STYLES.palette("gintama")["panel"]
	# Act / Assert
	for id: String in catalog.characters:
		var ink: Color = UI_STYLES.ink_for(catalog.characters[id], "gintama")
		_expect(UI_STYLES.contrast(ink, ground) >= 4.5, "log ink: %s reads on washi (%.2f:1)" % [id,
			UI_STYLES.contrast(ink, ground)])


func test_log_rows_place_each_kind_of_line() -> void:
	# Arrange
	var game: Node = load("res://main.tscn").instantiate()
	game.save_path = "user://dialogue_log_test.save"
	root.add_child(game)
	await _frames(3)
	game._on_begin_pressed()
	await _frames(3)
	var pov: String = game._default_pov()
	var other: String = "gintoki" if pov != "gintoki" else "kagura"
	game._history.assign([
		{"speaker": other, "text": "今天也沒有工作啊。"},
		{"speaker": pov, "text": "那就去找工作啊！"},
		{"speaker": "narrator", "text": "窗外下起了雨。"},
		{"kind": "choice", "text": "吐槽他"},
		{"speaker": other + "+" + pov, "text": "合聲！"},
	])
	# Act
	game._open_log()
	await _frames(2)
	var rows: Array[Node] = game._log_entries.get_children().filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())
	# Assert
	_expect(rows.size() == 5, "log: one row per history line (%d)" % rows.size())
	var left: Node = rows[0]
	var ink: Color = UI_STYLES.ink_for(game._actors[other], game._ui_style_id)
	_expect(left.get_node("%Avatar").visible and left.get_node("%Speaker").horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT,
		"log: another speaker sits on the left with an avatar")
	if UI_STYLES.washi(game._ui_style_id):
		_expect(left.get_node("%Speaker").get_theme_color("font_color") == ink,
			"log: the name uses the speaker's ink, not the role colour")
	_expect(not rows[1].get_node("%Avatar").visible and rows[1].get_node("%Text").horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT,
		"log: the POV sits on the right without an avatar")
	_expect(not rows[2].get_node("%Avatar").visible and rows[2].get_node("%Text").horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER,
		"log: narration is centred")
	_expect(rows[3].get_node("%Speaker").text == "▶ 選擇" and rows[3].get_node("%Text").horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT,
		"log: the player's choice sits on the right")
	_expect(rows[4].get_node("%Avatar").visible and String(rows[4].get_node("%Speaker").text).contains("、"),
		"log: a duet takes the first speaker's avatar and lists both names")
	var source: String = FileAccess.get_file_as_string("res://scenes/ui/log_entry.tscn")
	game.queue_free()
	await _frames(2)
	_expect(FileAccess.get_file_as_string("res://scenes/ui/log_entry.tscn") == source, "log: opening never rewrites the scene")
