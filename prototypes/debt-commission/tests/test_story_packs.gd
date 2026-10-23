extends "res://addons/proto_kit/test_kit.gd"
## 故事包: stories/<work>/pack.json joins the chapter list after the base work, with its own catalog
## (relative asset paths), its own chapter order, unlocks, carry flags, numbering and 鑑賞 unlocks; a
## taken story id is left out; the cast is rebuilt from the work's catalog and back again.

const Runner = preload("res://scripts/story_runner.gd")
const Library = preload("res://scripts/story_library.gd")
const Builder = preload("res://tools/story_build/story_builder.gd")
const REGISTRY: String = "res://tests/fixtures/stories_chapters.json"
const PACKS: String = "res://tests/fixtures/packs/"
const TITAN: String = "res://tests/fixtures/packs/titan/"
const FILES: Array[String] = ["user://packs_progress.cfg", "user://packs_settings.cfg", "user://fixture_chapter_a.save",
	"user://pack_titan_titan_ch1.save", "user://pack_titan_titan_ch2.save"]


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_cleanup()
	_discovery_and_order()
	_catalog_and_builder()
	await _playing_another_work()
	_cleanup()
	_finish("STORY PACK TESTS")


func _discovery_and_order() -> void:
	var library: RefCounted = Library.new(REGISTRY, FILES[0], PACKS)
	var ids: Array = library.stories.map(func(e: Dictionary) -> String: return e["id"])
	_expect(ids == ["chapter_a", "chapter_b", "sample", "titan_ch1", "titan_ch2"],
		"the pack's stories follow the base work, in its order: %s" % [ids])
	_expect(library.rejected == ["chapter_a"], "a pack story whose id is taken is left out: %s" % [library.rejected])
	var ch1: Dictionary = library.stories[3]
	_expect(ch1["path"] == TITAN + "ch1_story.json" and ch1["save"] == "user://pack_titan_titan_ch1.save"
		and ch1["work"] == "titan" and ch1["work_title"] == "測試作品：城牆", "pack paths are made res:// and saves are the work's own")
	_expect(library.cover(ch1) == TITAN + "art/wall.png" and library.credit_line(library.credits(ch1)) == "劇本 測試作者",
		"the work's cover and credits are each chapter's")
	_expect(library.unlocked(3) and not library.unlocked(1), "the pack's first chapter is open while the base work's second is locked")
	_expect(not library.unlocked(4), "the pack's second chapter waits for its first")
	library.record_clear("titan_ch1", "完")
	_expect(library.unlocked(4) and not library.unlocked(1), "clearing the pack's first chapter opens only its own second")
	_expect(library.next_chapter(3)["id"] == "titan_ch2" and library.next_chapter(1).is_empty(),
		"下一章 stays inside each work")
	library.record_ending("chapter_b", "", {"wall_seen": "base"})
	library.record_ending("titan_ch1", "", {"wall_seen": true})
	_expect(library.previous_carry(4) == {"wall_seen": true}, "carry flags come from the same work's chapter")
	library.unlock(Library.gallery_key("titan", "bg"), "wall")
	_expect(library.unlocked_ids("titan/bg") == ["wall"] and library.unlocked_ids("bg").is_empty(), "鑑賞 unlocks are kept per work")


func _catalog_and_builder() -> void:
	_expect(Runner.catalog_path_for(TITAN + "ch1_story.json") == TITAN + "catalog.json"
		and Runner.catalog_path_for("res://data/chapter1_story.json") == Runner.ASSET_CATALOG_PATH, "the catalog beside the story is used")
	var r = Runner.new()
	_expect(r.load_story(TITAN + "ch1_story.json"), "a pack story loads against its own catalog: %s" % r.error_message)
	var catalog: Dictionary = r.get_asset_catalog()
	_expect(catalog["backgrounds"]["wall"]["path"] == TITAN + "art/wall.png" and not catalog["characters"].has("gintoki"),
		"relative paths become res:// and only the work's characters are there")
	_expect(r.default_pov() == "eren", "the pack's default_pov")
	var built: Dictionary = Builder.build_text("~ start\n艾連: 牆的另一邊。\ndo end(\"完\")\n", TITAN + "probe.dialogue")
	_expect(str(built["error"]).is_empty() and ((built["story"]["nodes"]["start"]["steps"] as Array)[0] as Dictionary)["speaker"] == "eren",
		"the builder finds speakers in the pack's catalog: %s" % built["error"])


func _playing_another_work() -> void:
	var game: Control = (load("res://main.tscn") as PackedScene).instantiate() as Control
	game.stories_path = REGISTRY
	game.packs_root = PACKS
	game.story_path = "res://tests/fixtures/chapter_a_story.json"
	game.save_path = FILES[2]
	game.progress_path = FILES[0]
	game.settings_path = FILES[1]
	root.add_child(game)
	await _frames(3)
	_expect(game._sprites.has("shinpachi") and not game._sprites.has("eren"), "the base work's cast is on hand")
	game._open_chapter_select()
	await _frames(2)
	_expect(game._chapter_select.find_child("Work_titan", true, false) != null
		and (game._chapter_select.call("rows")["titan_ch1"] as Button).get_parent().get_node("Plaque/Number").text == "第 1 章",
		"章節選擇 lists the pack under its title, numbered from 第 1 章")
	game._close_chapter_select()
	game._choose_story(game._story_choices[3])
	await _frames(3)
	_expect(game._sprites.has("eren") and not game._sprites.has("shinpachi") and game._effects._catalog == game._catalog,
		"choosing the pack rebuilds the cast and hands its catalog to the effects")
	game._on_begin_pressed()
	for i: int in range(400):
		if game._screen_mode == "end":
			break
		if game._screen_mode == "story" and not game._story_busy:
			if game._text_complete:
				game._advance_current_line()
			else:
				game._complete_current_line()
		await _frames(1)
	_expect(game._screen_mode == "end" and game._cleared_grade("titan_ch1") == game.CLEARED_WITHOUT_GRADE,
		"a chapter without rounds is cleared at its end")
	_expect(game._library.unlocked_ids("titan/bg") == ["wall"] and game._library.unlocked_ids("titan/bgm") == ["bgm_wall"],
		"鑑賞 records the pack's picture and music under the work")
	_expect(game._story_unlocked(4) and not game._story_unlocked(1), "its next chapter opens, the base work's does not")
	game._show_title()
	await _frames(2)
	game._choose_story(game._story_choices[0])
	await _frames(3)
	_expect(game._sprites.has("shinpachi") and not game._sprites.has("eren"), "back to the base work: its cast again")
	game.queue_free()
	await _frames(2)


func _cleanup() -> void:
	for path: String in FILES:
		for suffix: String in ["", ".bak"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
