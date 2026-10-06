extends Control

## V1 直立視覺小說外殼。
##
## 分層由下到上：背景 → 立繪 → 特效 → 對話框（scenes/ui/dialogue_box_<風格>.tscn）→ 彈出視窗。
## 故事流程由 scripts/story_runner.gd 執行；背景、立繪與素材從同一份 catalog 載入。
## 所有輸入只處理滑鼠事件（專案把觸控模擬成滑鼠），一次觸控只會觸發一次動作。

const STORY_RUNNER_SCRIPT: Script = preload("res://scripts/story_runner.gd")
const DialogueBox = preload("res://scripts/dialogue_box.gd")
## One reading-box scene per UI edition; switching the edition swaps the scene.
const DIALOGUE_SCENES: Dictionary = {
	"cinema": preload("res://scenes/ui/dialogue_box_cinema.tscn"),
	"ledger": preload("res://scenes/ui/dialogue_box_ledger.tscn"),
	"manga": preload("res://scenes/ui/dialogue_box_manga.tscn"),
	"gintama": preload("res://scenes/ui/dialogue_box_gintama.tscn"),
}
const ChoiceSheet = preload("res://scripts/choice_sheet.gd")
const MenuPanel = preload("res://scripts/menu_panel.gd")
const TitleScreen = preload("res://scripts/title_screen.gd")
const STAGE_STYLE: Script = preload("res://scripts/ui_stage_style.gd")
const StageEffects = preload("res://scripts/stage_effects.gd")
const ComedyLayer = preload("res://scripts/comedy_layer.gd")
const RoundView = preload("res://scripts/round_view.gd")
const QteRing = preload("res://scripts/qte_ring.gd")
const QTE_SCENE: PackedScene = preload("res://scenes/ui/qte_ring.tscn")
const RoundHud = preload("res://scripts/round_hud.gd")
const ROUND_HUD_SCENE: PackedScene = preload("res://scenes/ui/round_hud.tscn")
const GameOverScreen = preload("res://scripts/game_over.gd")
const GAME_OVER_SCENE: PackedScene = preload("res://scenes/ui/game_over.tscn")
const MENU_SCENES: Dictionary = {
	"cinema": preload("res://scenes/ui/menu_panel_cinema.tscn"),
	"ledger": preload("res://scenes/ui/menu_panel_ledger.tscn"),
	"manga": preload("res://scenes/ui/menu_panel_manga.tscn"),
	"gintama": preload("res://scenes/ui/menu_panel_gintama.tscn"),
}
const TITLE_SCENES: Dictionary = {
	"cinema": preload("res://scenes/ui/title_screen_cinema.tscn"),
	"ledger": preload("res://scenes/ui/title_screen_ledger.tscn"),
	"manga": preload("res://scenes/ui/title_screen_manga.tscn"),
	"gintama": preload("res://scenes/ui/title_screen_gintama.tscn"),
}
const CHOICE_SHEETS: Dictionary = {
	"cinema": preload("res://scenes/ui/choice_sheet_cinema.tscn"),
	"ledger": preload("res://scenes/ui/choice_sheet_ledger.tscn"),
	"manga": preload("res://scenes/ui/choice_sheet_manga.tscn"),
	"gintama": preload("res://scenes/ui/choice_sheet_gintama.tscn"),
}
## A director choice sits in its own sheet whatever the edition (scenes/ui/choice_sheet_director.tscn).
const DIRECTOR_SHEET: PackedScene = preload("res://scenes/ui/choice_sheet_director.tscn")
const SPRITE_SCRIPT: Script = preload("res://scripts/placeholder_sprite.gd")
## Each character's own size and framing (tools/make_character_scenes.gd creates missing ones).
const CHARACTER_SCENE: String = "res://scenes/characters/%s.tscn"
## A spot to search, laid over its object in the background picture; and the folded reading box.
const HOTSPOT_SCENE: PackedScene = preload("res://scenes/ui/hotspot.tscn")
const INVESTIGATE_BAR_SCENE: PackedScene = preload("res://scenes/ui/investigate_bar.tscn")
const CHAPTER_RESULT_SCENE: PackedScene = preload("res://scenes/ui/chapter_result.tscn")
const CHAPTER_SELECT_SCENE: PackedScene = preload("res://scenes/ui/chapter_select.tscn")
const SETTINGS_SCENE: PackedScene = preload("res://scenes/ui/settings_panel.tscn")
const SETTINGS_SCRIPT: Script = preload("res://scripts/settings.gd")
const DialogueText: Script = preload("res://scripts/dialogue_text.gd")
const StageMotion: Script = preload("res://scripts/stage_motion.gd")
const ReadingRollback: Script = preload("res://scripts/reading_rollback.gd")
## A spot's size when the story gives none, as fractions of the picture.
const DEFAULT_HOTSPOT_SIZE: Array = [0.12, 0.12]
const SAVE_SLOTS_SCRIPT: Script = preload("res://scripts/save_slots.gd")
const UI_STYLES_SCRIPT: Script = preload("res://scripts/ui_styles.gd")
const CASE_FILE_SCENE: PackedScene = preload("res://scenes/ui/case_file_panel.tscn")

const DESIGN_WIDTH: float = 1080.0
## One CSS px of the HTML reference (docs/ui-options) in logical px.
const CSS_PX: float = DESIGN_WIDTH / 390.0
const FONT_PATH: String = "res://assets/fonts/story-cjk.ttc"
const SAVE_SCHEMA: int = 3
const UI_PREFERENCE_PATH: String = "user://ui_preferences.cfg"
const PHASE3_STORY_PATH: String = "res://data/phase3_story.json"
const PHASE3_SAVE_PATH: String = "user://strawberry_phase3.save"
const STORY_CHOICE_PATH: String = "user://story_choice.cfg"
const DEFAULT_BOKE_TIMER_SECONDS: float = 8.0

@export_file("*.json") var story_path: String = "res://data/debt_story.json"
@export var save_path: String = "user://debt_commission.save"
## The stories the player can pick (data/stories.json): chapters in order, then samples, each with
## its own save namespace. Web builds preselect one with ?sample=<id>; a desktop/editor run
## remembers the last choice.
@export_file("*.json") var stories_path: String = "res://data/stories.json"
## Best grade per cleared story ([cleared] <story id> = S/A/B/C); a cleared chapter unlocks the next.
@export var progress_path: String = "user://progress.cfg"
## Text speed, auto-play speed and volumes (settings.gd), each an index into its choices.
@export var settings_path: String = "user://settings.cfg"
var _story_choices: Array[Dictionary] = []
var _story_titles: Dictionary = {}
var _chapter_result: Control = null
var _chapter_select: Control = null
var _settings_panel: Control = null
var _settings: Dictionary = {}
var _settings_return: String = "title"
var ui_preference_path: String = UI_PREFERENCE_PATH

const DIALOG_RATIO: float = 0.28
const EDGE: float = 24.0
const DIALOG_GAP: float = 12.0
const QUICKBAR_HEIGHT: float = 160.0
const LONG_PRESS_SEC: float = 0.5
const TAP_SLOP: float = 30.0
const SWIPE_DISTANCE: float = 140.0
const AUTO_DELAY_SEC: float = 1.0
const AUTO_PER_CHAR_SEC: float = 0.03
const SKIP_DELAY_SEC: float = 0.06
const TOAST_SEC: float = 1.4
const QA_PUBLISH_SEC: float = 0.2

const AUDIO_PATHS: Dictionary = {
	"paper": "res://assets/audio/paper.wav",
	"knock": "res://assets/audio/knock.wav",
	"step": "res://assets/audio/step.wav",
	"stamp": "res://assets/audio/stamp.wav",
	"ambient": "res://assets/audio/ambient.wav",
}

## Background frames and the left/center/right standing slots, laid out in the editor.
const STAGE_SCENE: PackedScene = preload("res://scenes/stage.tscn")

const COLOR_PANEL: Color = Color(0.035, 0.045, 0.09, 0.76)
const COLOR_PANEL_SOLID: Color = Color("#101530")
const COLOR_GOLD: Color = Color("#c9a24a")
const COLOR_UI_ACCENT: Color = Color("#b7c6e2")
const COLOR_BUTTON_SURFACE: Color = Color(0.045, 0.06, 0.115, 0.82)
const COLOR_BUTTON_HOVER: Color = Color(0.09, 0.12, 0.205, 0.94)
const COLOR_BUTTON_BORDER: Color = Color(0.42, 0.49, 0.63, 0.22)
const COLOR_BUTTON_ACTIVE: Color = Color("#b7c6e2")
const COLOR_TEXT: Color = Color("#f6f1e7")
const COLOR_TEXT_SOFT: Color = Color("#b9b4c8")
const COLOR_THOUGHT: Color = Color("#9fc3ff")
const COLOR_DISABLED: Color = Color("#5d6070")

var _font: Font = ThemeDB.fallback_font
var _runner: RefCounted = null
var _story_ready: bool = false
var _phase3_enabled: bool = false
var _story_error: String = ""
var _catalog: Dictionary = {}
var _actors: Dictionary = {}
var _backgrounds: Dictionary = {}
var _actor_slots: Dictionary = {}
var _current_bg_id: String = ""
var _background_gradient: Gradient = null
## The frame showing now (scenes/stage.tscn Backgrounds/<id>, else Backgrounds/Default).
var _background_rect: TextureRect = null
var _background_frames: Dictionary = {}
var _stage_area: Control = null
var _slot_markers: Dictionary = {}
var _paper_textures: Dictionary = {}

## The game area and its layers are nodes of main.tscn, back to front: Background, Character,
## Interaction (character hotspots), Effect (HUD), Dialogue, Comedy (comedy overlay), Overlay, Popup.
@onready var _game: Control = %Game
@onready var _bg_layer: Control = %BackgroundLayer
@onready var _char_layer: Control = %CharacterLayer
@onready var _interaction_layer: Control = %InteractionLayer
@onready var _fx_layer: Control = %EffectLayer
@onready var _dialog_layer: Control = %DialogueLayer
@onready var _comedy_layer: ComedyLayer = %ComedyLayer
@onready var _overlay_layer: Control = %OverlayLayer
@onready var _popup_layer: Control = %PopupLayer
## shake / flash / cutin / freeze / bgm / se steps (scripts/stage_effects.gd).
var _effects: StageEffects = null
var _motion: StageMotion = null
## The mounted title_screen and menu_panel scenes; the buttons and dictionaries below point into them.
var _title_screen: TitleScreen = null
var _title_style_buttons: Dictionary = {}
var _menu_style_buttons: Dictionary = {}

var _place_tag: Label = null
var _sprites: Dictionary = {}
var _tap_catcher: Control = null
## The mounted dialogue_box scene; the fields below point into it.
var _dialog_panel: DialogueBox = null
var _text_label: RichTextLabel = null
var _name_plate: Control = null
var _name_label: Label = null
## The mounted choice_sheet scene; it stands in for the dialogue box while options are up.
var _choice_sheet: ChoiceSheet = null
var _sheet_prompt: String = ""
var _sheet_timed: bool = false
## What the choice on the sheet asks for: "pov" (the edition's sheet) or "director" (the director's own),
## the director's footnote, and the tone of each row ("" for none).
var _sheet_perspective: String = "pov"
var _sheet_note: String = ""
var _sheet_tones: PackedStringArray = []
var _sheet_censor: bool = false
var _sheet_super: bool = false
var _previous_power: int = 0
var _qte: QteRing = null
var _end_box: Control = null
var _quickbar: Container = null
var _log_button: Button = null
var _auto_button: Button = null
var _advance_button: Button = null
var _restart_button: Button = null
var _end_title_button: Button = null
var _menu_button: Button = null
var _menu_overlay: MenuPanel = null
var _menu_panel: Control = null
var _menu_close: Button = null
var _menu_items: Dictionary = {}
var _log_overlay: Control = null
var _log_entries: VBoxContainer = null
var _log_scroll: ScrollContainer = null
var _log_close: Button = null
var _toast: Label = null
var _begin_button: Button = null
var _continue_button: Button = null
var _title_load_button: Button = null
var _story_switch: Button = null
var _case_file_panel: Panel = null
## The gameplay HUD scene (glasses, power, combo, countdown, materials); the labels point into it.
var _phase3_hud: RoundHud = null
var _phase3_stats_label: Label = null
var _phase3_timer_label: Label = null
var _investigation_continue_button: Button = null
## Investigation: spots by id (hotspot.tscn) on a layer covering the whole picture. While searching,
## the background frame is stretched to the whole picture (_picture, in game coordinates before
## panning) and slides sideways by _pan within _pan_range; _frame_offsets restores it afterwards.
var _hotspots: Dictionary = {}
var _hotspot_layer: Control = null
var _picture: Rect2 = Rect2()
var _pan: float = 0.0
var _pan_start: float = 0.0
var _pan_range: Vector2 = Vector2.ZERO
var _frame_offsets: Array[float] = []
var _investigate_bar: Control = null
var _investigate_collapsed: bool = false
## The search's topic buttons in the reading box: {"talk:<id>" | "move:<id>": Button}.
var _topic_buttons: Dictionary = {}
## How far each place of a search was panned ("<investigation>/<place>"), kept across its reactions.
var _investigation_pans: Dictionary = {}
var _cast_pan_origins: Dictionary = {}
var _round_stages: Dictionary = {}
var _investigation_home_casts: Dictionary = {}
var _pan_key: String = ""
## The character scene holding a placard (elisabeth.tscn's `Placard`), if any.
var _placard_holder: Control = null
var _boke_controls: Control = null
var _boke_previous_button: Button = null
var _boke_line_label: Label = null
var _boke_next_button: Button = null
var _boke_listen_button: Button = null
var _boke_tsukkomi_button: Button = null
var _game_over_retry_button: Button = null
## Shattered glasses and checkpoint retry (scenes/ui/game_over.tscn); the retry button above is its.
var _game_over: GameOverScreen = null

var _slot_overlay: Control = null
var _slot_panel: Control = null
var _slot_title: Label = null
var _slot_page_label: Label = null
var _slot_prev_button: Button = null
var _slot_next_button: Button = null
var _slot_close_button: Button = null
var _slot_auto_button: Button = null
var _slot_card_buttons: Array[Button] = []
var _slot_card_numbers: Array[Label] = []
var _slot_card_titles: Array[Label] = []
var _slot_card_times: Array[Label] = []
var _slot_card_previews: Array[TextureRect] = []
var _slot_visible_entries: Array[Dictionary] = []
var _slot_confirmation_overlay: Control = null
var _slot_confirmation_panel: Control = null
var _slot_confirmation_label: Label = null
var _slot_confirm_yes: Button = null
var _slot_confirm_no: Button = null
var _slot_mode: String = ""
var _slot_return_screen: String = ""
var _slot_page: int = 0
var _slot_pending_index: int = -1
var _slot_typewriter_paused: bool = false
var _slot_preview_png: String = ""

var _safe_top: float = 0.0
var _safe_bottom: float = 0.0

var _audio_players: Dictionary = {}
var _audio_muted: bool = false
var _ui_style_id: String = UI_STYLES_SCRIPT.DEFAULT_ID

var _screen_mode: String = "title"
var _mode_before_overlay: String = "story"
var _story_busy: bool = false
var _generation: int = 0
var _line_generation: int = 0
var _text_complete: bool = true
var _full_text: String = ""
var _line_plan: Dictionary = {}
var _rollback: ReadingRollback = ReadingRollback.new()
var _rolling_back: bool = false
var _pending_round_mode: String = ""
var _visible_text: String = ""
var _current_speaker: String = ""
var _current_line_key: String = ""
var _line_logged: bool = false
var _current_command: Dictionary = {}
var _current_options: Array[Dictionary] = []
var _choice_buttons: Array[Button] = []
var _history: Array[Dictionary] = []
var _boke_time_remaining: float = 0.0
var _boke_timer_round_id: String = ""
var _last_boke_display_second: int = -1
var _restored_boke_timer_remaining: float = -1.0
var _restored_boke_ui_mode: String = ""
var _last_boke_result: String = ""

var _ui_hidden: bool = false
var _plate_speaker: String = "narrator"
var _plate_thought: bool = false
var _auto: bool = false
var _skip: bool = false
var _gesture_active: bool = false
var _gesture_moved: bool = false
var _gesture_in_comedy: bool = false
var _gesture_long: bool = false
var _gesture_start: Vector2 = Vector2.ZERO
var _gesture_token: int = 0
var _toast_token: int = 0
var _text_tone: String = "body"
## Nominal top of the reading area: sprites, hotspots and choices sit above it, so they stay put
## while the dialogue box grows or shrinks with each line.
var _stage_bottom: float = 0.0
var _panel_scale: float = 1.0

var _qa_enabled: bool = false
var _qa_elapsed: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(FONT_PATH):
		var loaded_font: Resource = load(FONT_PATH)
		if loaded_font is Font:
			_font = loaded_font as Font
	var ui_theme: Theme = Theme.new()
	ui_theme.default_font = _font
	ui_theme.default_font_size = 44
	theme = ui_theme
	_ui_style_id = UI_STYLES_SCRIPT.load_preference(ui_preference_path)

	_story_choices = _read_story_choices()
	_settings = SETTINGS_SCRIPT.load_settings(settings_path)
	_select_story_variant()
	_load_story()
	_build_audio()
	_build_ui()
	_motion = StageMotion.new()
	add_child(_motion)
	_motion.setup(_stage_area.get_node("%BackgroundGhost"), %SceneFade)
	_apply_ui_style()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_detect_qa_mode()
	_show_title()


## Each entry: {id, kind ("chapter" or "sample"), path, save}.
func _read_story_choices() -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(stories_path))
	if parsed is Dictionary:
		for entry: Variant in (parsed as Dictionary).get("stories", []):
			if entry is Dictionary and (entry as Dictionary).has_all(["id", "path", "save"]):
				choices.append(entry as Dictionary)
	return choices


func _select_story_variant() -> void:
	# Web：網址 ?sample=<id> 開固定片段。桌機或編輯器直接執行主場景時，沿用上次在標題選的故事。
	# 測試與劇本試玩會自己設定 story_path，此時 main 不是 current_scene，不套用記憶的選擇。
	var choice_id: String = ""
	if OS.has_feature("web"):
		choice_id = str(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('sample') || ''"))
	elif get_tree().current_scene == self:
		var config: ConfigFile = ConfigFile.new()
		if config.load(STORY_CHOICE_PATH) == OK:
			choice_id = str(config.get_value("story", "id", ""))
	if choice_id.is_empty() and get_tree().current_scene == self:
		choice_id = "chapter1"
	for choice: Dictionary in _story_choices:
		if choice["id"] == choice_id:
			story_path = choice["path"]
			save_path = choice["save"]


func _story_choice_index() -> int:
	for index: int in range(_story_choices.size()):
		if _story_choices[index]["path"] == story_path:
			return index
	return -1


## The title's story label opens 章節選擇.
func _on_story_switch_pressed() -> void:
	_open_chapter_select()


func _open_chapter_select() -> void:
	if _screen_mode != "title":
		return
	_screen_mode = "chapter_select"
	var entries: Array[Dictionary] = []
	for index: int in range(_story_choices.size()):
		var choice: Dictionary = _story_choices[index]
		var kind: String = str(choice.get("kind", "sample"))
		var locked: bool = not _story_unlocked(index)
		var grade: String = _cleared_grade(str(choice["id"]))
		var note: String = "試玩片段"
		if kind == "chapter":
			note = "完成前一章後開放" if locked else ("最佳評價 " + grade if not grade.is_empty() else "未完成")
		entries.append({"index": index, "id": str(choice["id"]), "kind": kind, "title": _story_title(choice),
			"note": note, "locked": locked, "current": index == _story_choice_index()})
	_chapter_select.call("set_style", _ui_style_id)
	_chapter_select.call("open", entries)
	_publish_qa_state()


func _on_chapter_picked(index: int) -> void:
	if index < 0 or index >= _story_choices.size() or not _story_unlocked(index):
		return
	_choose_story(_story_choices[index])
	_close_chapter_select()


func _close_chapter_select() -> void:
	_chapter_select.visible = false
	_show_title()


## A story's own title (read once from its file).
func _story_title(choice: Dictionary) -> String:
	var path: String = str(choice["path"])
	if not _story_titles.has(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		_story_titles[path] = str((parsed as Dictionary).get("title", choice["id"])) if parsed is Dictionary else str(choice["id"])
	return _story_titles[path]


## 設定 from the title or from 目錄 (which stays open underneath).
func _open_settings() -> void:
	if _screen_mode not in ["title", "menu"]:
		return
	_settings_return = _screen_mode
	_screen_mode = "settings"
	_settings_panel.call("set_style", _ui_style_id)
	_settings_panel.call("open", _settings)
	_publish_qa_state()


func _close_settings() -> void:
	_settings_panel.visible = false
	_screen_mode = _settings_return
	_publish_qa_state()


func _on_setting_changed(key: String, value: int) -> void:
	_settings[key] = value
	SETTINGS_SCRIPT.save_settings(settings_path, _settings)
	if key.ends_with("_volume"):
		_apply_audio_levels()
	if key in ["font_size", "paper_opacity"]:
		_apply_reading_settings()
	_publish_qa_state()


func _apply_reading_settings() -> void:
	_dialog_panel.apply_reading_settings(SETTINGS_SCRIPT.FONT_SCALES[int(_settings.get("font_size", 1))],
		SETTINGS_SCRIPT.PAPER_OPACITIES[int(_settings.get("paper_opacity", 2))])
	if _command_op(_current_command) == "say":
		_line_plan = DialogueText.compile(_dict_string(_current_command,"text"), _text_interval(),
			_text_label.get_theme_font_size("normal_font_size"))
		_set_visible_text(_visible_text, _text_complete)


## Settings volumes on every player; the 音效 switch in 目錄 silences all of them on top.
func _apply_audio_levels() -> void:
	var se: float = SETTINGS_SCRIPT.VOLUMES[int(_settings["se_volume"])]
	for player: AudioStreamPlayer in _audio_players.values():
		player.volume_db = -80.0 if _audio_muted or se <= 0.0 else linear_to_db(se)
	_effects.set_volumes(SETTINGS_SCRIPT.VOLUMES[int(_settings["bgm_volume"])], se)


func _text_interval() -> float:
	return SETTINGS_SCRIPT.TEXT_INTERVALS[int(_settings["text_speed"])]


func _refresh_story_switch() -> void:
	if _story_switch == null:
		return
	var info: Dictionary = _runner.call("story_info") as Dictionary if _story_ready else {}
	var title: String = str(info.get("title", story_path.get_file()))
	var index: int = _story_choice_index()
	_story_switch.text = "%s\n章節選擇 ›" % title


func _load_story() -> void:
	_runner = STORY_RUNNER_SCRIPT.new() as RefCounted
	_story_ready = bool(_runner.call("load_story", story_path))
	if not _story_ready:
		_story_error = _runner_string("error_message", "故事資料尚未就緒。")
		return
	var initial_snapshot: Dictionary = _runner.call("snapshot") as Dictionary
	_phase3_enabled = bool(_runner.call("has_gameplay"))
	_catalog = _runner.call("get_asset_catalog") as Dictionary
	_actors = _catalog.get("characters", {}) as Dictionary
	_backgrounds = _catalog.get("backgrounds", {}) as Dictionary
	for actor_id: String in _actors.keys():
		var info: Dictionary = _actors[actor_id] as Dictionary
		_actor_slots[actor_id] = str(info.get("slot", "center"))


func _build_audio() -> void:
	for audio_id: String in AUDIO_PATHS.keys():
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "Audio_%s" % audio_id
		add_child(player)
		var path: String = str(AUDIO_PATHS[audio_id])
		if ResourceLoader.exists(path):
			player.stream = load(path) as AudioStream
		_audio_players[audio_id] = player


# ---------------------------------------------------------------- UI 建構

func _build_ui() -> void:
	_build_background()
	_build_sprites()
	_build_phase3_hud()
	_build_dialogue()
	_build_investigate_bar()
	_mount_menu()
	_build_log()
	_build_case_file()
	_build_toast()
	_mount_title()
	_build_slot_picker()
	_chapter_select = CHAPTER_SELECT_SCENE.instantiate() as Control
	_game.add_child(_chapter_select)  # above the title screen
	_chapter_select.connect("picked", _on_chapter_picked)
	_chapter_select.connect("closed", _close_chapter_select)
	_settings_panel = SETTINGS_SCENE.instantiate() as Control
	_game.add_child(_settings_panel)
	_settings_panel.connect("changed", _on_setting_changed)
	_settings_panel.connect("closed", _close_settings)
	_game_over = GAME_OVER_SCENE.instantiate() as GameOverScreen
	_overlay_layer.add_child(_game_over)
	_game_over_retry_button = _game_over.retry_button
	_game_over.retry_pressed.connect(_on_game_over_retry_pressed)
	_game_over.title_pressed.connect(_show_title)
	_chapter_result = CHAPTER_RESULT_SCENE.instantiate() as Control
	_overlay_layer.add_child(_chapter_result)
	_chapter_result.connect("title_pressed", _show_title)
	_chapter_result.connect("next_pressed", _on_next_chapter_pressed)
	_effects = StageEffects.new()
	_effects.name = "StageEffects"
	add_child(_effects)
	_effects.setup([_bg_layer, _char_layer, _interaction_layer, _fx_layer, _dialog_layer], _overlay_layer, _catalog)
	_comedy_layer.setup(_effects, [_bg_layer, _char_layer], _catalog, _comedy_speaker_rect, _comedy_dialog_rect)
	_comedy_layer.finished.connect(_publish_qa_state)
	_apply_audio_levels()
	_refresh_gameplay_ui()


func _build_background() -> void:
	_background_gradient = Gradient.new()
	var stage: Control = STAGE_SCENE.instantiate() as Control
	_bg_layer.add_child(stage)
	stage.get_node("DialogueGuide").free()  # editor-only guide
	for frame: TextureRect in stage.get_node("Backgrounds").get_children():
		_background_frames[str(frame.name)] = frame
	_background_rect = _background_frames["Default"]
	_stage_area = stage.get_node("StageArea") as Control
	for marker: Control in _stage_area.get_children():
		var preview: Node = marker.get_node_or_null("Preview")  # editor-only portrait
		if preview != null:
			preview.free()
		_slot_markers[str(marker.name)] = marker
	_place_tag = _make_label(_bg_layer, "萬事屋・客廳", 40, COLOR_TEXT)
	_place_tag.set_meta("ui_style_role", "scene_overlay")
	_place_tag.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.72))
	_place_tag.add_theme_constant_override("outline_size", 4)
	var initial_bg: String = "yorozuya_living_room"
	if not _backgrounds.has(initial_bg) and not _backgrounds.is_empty():
		initial_bg = str(_backgrounds.keys()[0])
	_apply_background(initial_bg)


## A background whose paper is left transparent (hand-drawn art often is) laid on white, so the
## layers behind it never show through. Cached per path.
func _paper_backed(path: String) -> Texture2D:
	if _paper_textures.has(path):
		return _paper_textures[path]
	var texture: Texture2D = load(path) as Texture2D
	var image: Image = texture.get_image()
	if image != null and image.detect_alpha() != Image.ALPHA_NONE:
		if image.is_compressed():
			image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		var paper: Image = Image.create(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
		paper.fill(Color.WHITE)
		paper.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
		texture = ImageTexture.create_from_image(paper)
	_paper_textures[path] = texture
	return texture


func _apply_background(background_id: String, animate: bool = false) -> void:
	if not _backgrounds.has(background_id):
		return
	var changing: bool = animate and not _skip and _motion != null and _background_rect != null and background_id != _current_bg_id
	if changing:
		_motion.capture_background(_background_rect)
	var info: Dictionary = _backgrounds[background_id] as Dictionary
	_current_bg_id = background_id
	_place_tag.text = str(info.get("label", background_id))
	var path: String = str(info.get("path", ""))
	if not path.is_empty() and load(path) is Texture2D:
		# The catalog picks the art; the stage scene's frame of the same name sets its framing.
		_background_rect = _background_frames.get(background_id, _background_frames["Default"])
		_background_rect.texture = _paper_backed(path)
	else:
		_background_gradient.set_color(0, Color(str(info.get("top", "#2e2a45"))))
		_background_gradient.set_color(1, Color(str(info.get("bottom", "#b9794f"))))
		var texture: GradientTexture2D = GradientTexture2D.new()
		texture.gradient = _background_gradient
		texture.fill_from = Vector2(0.5, 0.0)
		texture.fill_to = Vector2(0.5, 1.0)
		_background_rect = _background_frames["Default"]
		_background_rect.texture = texture
	for frame: TextureRect in _background_frames.values():
		frame.visible = frame == _background_rect
	if changing:
		_motion.crossfade()


func _build_sprites() -> void:
	for actor_id: String in _actors.keys():
		var info: Dictionary = _actors[actor_id] as Dictionary
		var scene_path: String = CHARACTER_SCENE % actor_id
		var sprite: Control = (load(scene_path) as PackedScene).instantiate() as Control \
			if ResourceLoader.exists(scene_path) else SPRITE_SCRIPT.new() as Control
		_char_layer.add_child(sprite)
		sprite.call("setup", actor_id, str(info["name"]), Color(str(info["color"])), _font)
		var art_path: String = str(info.get("path", ""))
		if not art_path.is_empty():
			var art: Resource = load(art_path)
			if art is Texture2D:
				sprite.call("set_art", art)
		var faces: Dictionary = {}
		for expression: String in (info.get("expressions", {}) as Dictionary).keys():
			var face: Texture2D = _catalog_picture({"path": info["expressions"][expression]})
			if face != null:
				faces[expression] = face
		sprite.call("set_expression_art", faces)
		sprite.visible = false
		_sprites[actor_id] = sprite
		if sprite.has_method("has_placard") and bool(sprite.call("has_placard")):
			_placard_holder = sprite


func _build_phase3_hud() -> void:
	_phase3_hud = ROUND_HUD_SCENE.instantiate() as RoundHud
	_fx_layer.add_child(_phase3_hud)
	_phase3_stats_label = _phase3_hud.power_value
	_phase3_timer_label = _phase3_hud.timer
	_phase3_hud.visible = false

## `char` places a character (slot, expression) for when they speak; only `hide` (visible false)
## takes them off stage. Characters come on stage by speaking (_focus_speaker).
func _apply_character(command: Dictionary) -> void:
	var actor_id: String = _dict_string(command, "id")
	if not _sprites.has(actor_id):
		return
	var sprite: Control = _sprites[actor_id] as Control
	if not _dict_bool(command, "visible", true):
		_motion.character(sprite, "leave", _skip)
	if command.has("expression"):
		sprite.call("set_expression", _dict_string(command, "expression"))
	if command.has("position"):
		_actor_slots[actor_id] = _dict_string(command, "position")
		_layout_sprite(actor_id)
	if _dict_bool(command, "enter") and not sprite.visible:
		# `enter`: someone who has not spoken (Elisabeth) comes on stage at their slot, lit.
		_layout_sprite(actor_id)
		sprite.modulate = Color.WHITE
		sprite.visible = true
		_motion.character(sprite, "enter", _skip)


func _build_dialogue() -> void:
	# 全畫面點擊區在對話框之下；對話框本身不攔截，點畫面任一處都由這裡處理手勢。
	_tap_catcher = Control.new()
	_tap_catcher.name = "TapCatcher"
	_tap_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_tap_catcher.gui_input.connect(_on_catcher_input)
	_dialog_layer.add_child(_tap_catcher)
	_tap_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_mount_dialogue_box()
	_mount_choice_sheet()

	_end_box = preload("res://scenes/ui/end_controls.tscn").instantiate()
	_dialog_layer.add_child(_end_box)
	_restart_button = _end_box.get_node("%Restart")
	_end_title_button = _end_box.get_node("%EndTitle")
	_restart_button.pressed.connect(_on_restart_pressed)
	_end_title_button.pressed.connect(_show_title)



## Puts the current edition's reading box in the dialogue layer. On an edition switch the action
## controls and the shown line move into the new box, and the old one is freed.
func _mount_dialogue_box() -> void:
	var old: DialogueBox = _dialog_panel
	_dialog_panel = (DIALOGUE_SCENES[_ui_style_id] as PackedScene).instantiate() as DialogueBox
	_dialog_layer.add_child(_dialog_panel)
	_dialog_panel.apply_reading_settings(SETTINGS_SCRIPT.FONT_SCALES[int(_settings.get("font_size",1))],
		SETTINGS_SCRIPT.PAPER_OPACITIES[int(_settings.get("paper_opacity",2))])
	_dialog_layer.move_child(_dialog_panel, _tap_catcher.get_index() + 1)
	_text_label = _dialog_panel.text
	_name_plate = _dialog_panel.speaker_row
	_name_label = _dialog_panel.speaker_name
	_quickbar = _dialog_panel.toolbar
	_menu_button = _dialog_panel.menu_button
	_log_button = _dialog_panel.log_button
	_auto_button = _dialog_panel.auto_button
	_advance_button = _dialog_panel.advance_button
	_dialog_panel.menu_pressed.connect(_open_menu)
	_dialog_panel.log_pressed.connect(_open_log)
	_dialog_panel.auto_pressed.connect(func() -> void: _set_auto(not _auto))
	_dialog_panel.skip_pressed.connect(func() -> void:
		if _screen_mode == "story":
			_set_skip(not _skip))
	_dialog_panel.advance_pressed.connect(_on_screen_tap)
	_dialog_panel.collapse_pressed.connect(_set_investigation_collapsed.bind(true))
	_investigation_continue_button = _dialog_panel.investigation_continue
	_boke_controls = _dialog_panel.round_controls
	_boke_previous_button = _dialog_panel.boke_previous
	_boke_line_label = _dialog_panel.boke_line_index
	_boke_next_button = _dialog_panel.boke_next
	_boke_listen_button = _dialog_panel.boke_listen
	_boke_tsukkomi_button = _dialog_panel.boke_tsukkomi
	_investigation_continue_button.pressed.connect(_on_investigation_continue_pressed)
	_boke_previous_button.pressed.connect(_on_boke_previous_pressed)
	_boke_next_button.pressed.connect(_on_boke_next_pressed)
	_boke_listen_button.pressed.connect(_on_boke_listen_pressed)
	_boke_tsukkomi_button.pressed.connect(_on_boke_tsukkomi_pressed)
	_dialog_panel.censor_bar.pressed.connect(_on_censor_pressed)
	_dialog_panel.set_chapter(_chapter_title())
	_fit_bottom_panel(_dialog_panel)
	if old == null:
		return
	# The action widgets keep what they showed.
	for pair: Array in [[old.investigation_continue, _investigation_continue_button], [old.boke_previous, _boke_previous_button],
			[old.boke_next, _boke_next_button], [old.boke_listen, _boke_listen_button],
			[old.boke_tsukkomi, _boke_tsukkomi_button], [old.censor_bar, _dialog_panel.censor_bar]]:
		(pair[1] as Button).visible = (pair[0] as Button).visible
		(pair[1] as Button).disabled = (pair[0] as Button).disabled
		(pair[1] as Button).text = (pair[0] as Button).text
	_boke_controls.visible = old.round_controls.visible
	_boke_line_label.text = old.boke_line_index.text
	_dialog_panel.visible = old.visible
	_dialog_panel.set_reading_enabled(not old.auto_button.disabled)
	_advance_button.visible = old.advance_button.visible
	_dialog_panel.set_auto(_auto)
	_dialog_panel.set_tone(_text_tone)
	_set_name_plate(_plate_speaker, _plate_thought)
	_set_visible_text(_visible_text, _text_complete)
	if _hotspot_layer != null:
		_show_topics(_current_command)  # the search's topics move into the new box
	_dialog_layer.remove_child(old)
	old.queue_free()


## The choice sheet sits above the dialogue box; on an edition switch the options on screen are rebuilt
## in the new sheet (a director choice stays in the director's).
func _mount_choice_sheet() -> void:
	_swap_choice_sheet()
	if _choice_buttons.is_empty():
		_choice_sheet.visible = false
	else:
		_show_choice_sheet()


## The scene the choice on screen asks for: the director's own, or the edition's.
func _choice_sheet_scene() -> PackedScene:
	return DIRECTOR_SHEET if _sheet_perspective == "director" else CHOICE_SHEETS[_ui_style_id]


## Puts a fresh sheet of that scene in place of the mounted one; the one place that decides which it is.
func _swap_choice_sheet() -> void:
	var old: ChoiceSheet = _choice_sheet
	_choice_sheet = _choice_sheet_scene().instantiate() as ChoiceSheet
	_dialog_layer.add_child(_choice_sheet)
	_dialog_layer.move_child(_choice_sheet, _dialog_panel.get_index() + 1)
	_choice_sheet.menu_pressed.connect(_open_menu)
	_choice_sheet.censor_pressed.connect(_on_censor_pressed)
	_choice_sheet.super_pressed.connect(_on_super_pressed)
	_choice_sheet.pop_finished.connect(_publish_qa_state)
	_choice_sheet.clear_options()
	_fit_choice_sheet()
	if old != null:
		_dialog_layer.remove_child(old)
		old.queue_free()


## Fills the sheet from _current_options. Story choices answer through _on_choice_pressed, a timed
## tsukkomi through _on_boke_option_pressed.
func _show_choice_sheet() -> void:
	if _choice_sheet.scene_file_path != _choice_sheet_scene().resource_path:
		_swap_choice_sheet()  # a director choice takes its own sheet, the next pov choice or round the edition's
	_fit_choice_sheet()
	var labels: PackedStringArray = []
	for option: Dictionary in _current_options:
		labels.append(_dict_string(option, "label"))
	var hint: String = "選一句吐槽" if _sheet_timed else ("選一個接下來的發展" if _sheet_perspective == "director" else "選一句回應")
	_choice_buttons = _choice_sheet.show_options(_sheet_prompt, labels, hint, _sheet_tones)
	_choice_sheet.set_note(_sheet_note)
	for index: int in range(_choice_buttons.size()):
		var option_id: String = _dict_string(_current_options[index], "id")
		var row: Button = _choice_buttons[index]
		row.name = "Boke_" + option_id if _sheet_timed else "Choice_%d" % index
		row.pressed.connect((_on_boke_option_pressed if _sheet_timed else _on_choice_pressed).bind(option_id))
	if _sheet_timed:
		_choice_sheet.set_timer(_boke_time_remaining, float(_current_command.get("timer_seconds", DEFAULT_BOKE_TIMER_SECONDS)),
			_screen_mode != "tsukkomi")
	_choice_sheet.censor_bar.visible = _sheet_timed and _sheet_censor
	_choice_sheet.super_button.visible = _sheet_timed and _sheet_super
	_choice_sheet.super_button.text = str(_current_command.get("super_label", "超必殺！"))
	_refresh_reading_ui()


## While options are up the sheet stands in for the dialogue box; both hide with the UI.
func _refresh_reading_ui() -> void:
	var choosing: bool = not _choice_buttons.is_empty()
	_dialog_panel.visible = not _ui_hidden and not choosing and not _investigate_collapsed
	_choice_sheet.visible = not _ui_hidden and choosing


## Story title up to its first separator, shown at the right of the speaker row.
func _chapter_title() -> String:
	var title: String = str((_runner.call("story_info") as Dictionary).get("title", "")) if _story_ready else ""
	return title.get_slice("｜", 0).get_slice("：", 0).get_slice("（", 0).strip_edges()


## The current edition's 目錄 at the bottom of the popup layer; on an edition switch the new one
## takes over whether it is open.
func _mount_menu() -> void:
	var old: MenuPanel = _menu_overlay
	_menu_overlay = (MENU_SCENES[_ui_style_id] as PackedScene).instantiate() as MenuPanel
	_popup_layer.add_child(_menu_overlay)
	_popup_layer.move_child(_menu_overlay, 0)
	_menu_panel = _menu_overlay.panel
	_menu_close = _menu_overlay.close_button
	_menu_items = _menu_overlay.rows
	_menu_style_buttons = _menu_overlay.style_buttons
	_menu_overlay.closed.connect(_close_menu)
	_menu_overlay.row_pressed.connect(_on_menu_row_pressed)
	_menu_overlay.style_pressed.connect(_on_ui_style_selected)
	_menu_overlay.visible = old != null and old.visible
	if old != null:
		_popup_layer.remove_child(old)
		old.queue_free()
	_refresh_menu_rows()
	_fit_menu()


func _on_menu_row_pressed(row_id: String) -> void:
	match row_id:
		"resume":
			_close_menu()
		"save", "load":
			_open_slot_picker(row_id)
		"rollback":
			_rollback_line()
		"quick_save":
			_quick_save()
		"quick_load":
			_quick_load()
		"material":
			_open_case_file("materials")
		"profile":
			_open_case_file("profiles")
		"log":
			_open_log()
		"skip":
			_start_skip_from_menu()
		"mute":
			_toggle_mute()
		"settings":
			_open_settings()
		"title":
			_show_title()


## Rows that depend on the story and the moment: 略讀 only from a story line, materials and
## profiles only in stories with gameplay, the sound state, the current edition.
func _refresh_menu_rows() -> void:
	var from_mode: String = _mode_before_overlay if _screen_mode == "menu" else _screen_mode
	(_menu_items["skip"] as Button).disabled = from_mode != "story"
	(_menu_items["rollback"] as Button).disabled = from_mode != "story" or not _rollback.available()
	(_menu_items["quick_save"] as Button).disabled = not _saveable_current_state()
	(_menu_items["quick_load"] as Button).disabled = _read_save_payload(SAVE_SLOTS_SCRIPT.quick_path(save_path)).is_empty()
	for key: String in ["material", "profile"]:
		(_menu_items[key] as Button).visible = _phase3_enabled
	_menu_overlay.set_row_hint("mute", "關" if _audio_muted else "開")
	_menu_overlay.set_active_style(_ui_style_id)
	_refresh_phase3_hud()


## The menu covers the game area at _panel_scale; its rows scroll when the screen is too short.
func _fit_menu() -> void:
	if _game == null or _menu_overlay == null:
		return
	_fit_full_area(_menu_overlay.area)
	_menu_overlay.fit((_game.size.y - _safe_top - _safe_bottom) / _panel_scale - 36.0 * CSS_PX)


func _build_log() -> void:
	_log_overlay = preload("res://scenes/ui/dialogue_log.tscn").instantiate()
	_popup_layer.add_child(_log_overlay)
	_log_overlay.visible = false
	_log_close = _log_overlay.get_node("%LogClose")
	_log_scroll = _log_overlay.get_node("%LogScroll")
	_log_entries = _log_overlay.get_node("%LogEntries")
	_log_close.pressed.connect(_close_log)


func _build_toast() -> void:
	_toast = _make_label(_popup_layer, "", 40, COLOR_TEXT)
	_toast.name = "Toast"
	_toast.set_meta("ui_style_role", "toast")
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast.add_theme_stylebox_override("normal", _make_style(Color(0.035, 0.045, 0.09, 0.92), COLOR_BUTTON_BORDER, 10, 0))
	_toast.visible = false


## The current edition's title screen above the popups; an edition switch keeps whether it shows.
func _mount_title() -> void:
	var old: TitleScreen = _title_screen
	_title_screen = (TITLE_SCENES[_ui_style_id] as PackedScene).instantiate() as TitleScreen
	_game.add_child(_title_screen)
	_game.move_child(_title_screen, _popup_layer.get_index() + 1)
	_story_switch = _title_screen.story_switch
	_begin_button = _title_screen.begin_button
	_continue_button = _title_screen.continue_button
	_title_load_button = _title_screen.load_button
	_title_style_buttons = _title_screen.style_buttons
	_title_screen.begin_pressed.connect(_on_begin_pressed)
	_title_screen.continue_pressed.connect(_on_continue_pressed)
	_title_screen.load_pressed.connect(func() -> void: _open_slot_picker("load"))
	_title_screen.story_switch_pressed.connect(_on_story_switch_pressed)
	_title_screen.settings_pressed.connect(_open_settings)
	_title_screen.style_pressed.connect(_on_ui_style_selected)
	_fit_bottom_panel(_title_screen.card_area)
	if old != null:
		_title_screen.visible = old.visible
		_game.remove_child(old)
		old.queue_free()
	_refresh_title()


## Story label, which buttons work, the last error and the story's exterior photo.
func _refresh_title() -> void:
	_refresh_story_switch()
	_continue_button.disabled = not _has_valid_save()
	_begin_button.disabled = not _story_ready
	_title_screen.set_error(_story_error)
	_title_screen.set_active_style(_ui_style_id)
	var exterior: String = str((_backgrounds.get("yorozuya_exterior", {}) as Dictionary).get("path", ""))
	if not exterior.is_empty() and ResourceLoader.exists(exterior):
		_title_screen.background.texture = _paper_backed(exterior)


func _build_slot_picker() -> void:
	_slot_overlay = preload("res://scenes/ui/save_slots_panel.tscn").instantiate()
	_game.add_child(_slot_overlay)
	_slot_overlay.visible = false
	_slot_panel = _slot_overlay.get_node("%SlotPanel")
	_slot_title = _slot_overlay.get_node("%SlotTitle")
	_slot_page_label = _slot_overlay.get_node("%SlotPage")
	_slot_close_button = _slot_overlay.get_node("%SlotClose")
	_slot_prev_button = _slot_overlay.get_node("%SlotPrev")
	_slot_next_button = _slot_overlay.get_node("%SlotNext")
	_slot_auto_button = _slot_overlay.get_node("%SlotAuto")
	_slot_close_button.pressed.connect(_close_slot_picker)
	_slot_prev_button.pressed.connect(func() -> void: _change_slot_page(-1))
	_slot_next_button.pressed.connect(func() -> void: _change_slot_page(1))
	_slot_auto_button.pressed.connect(_load_autosave_from_picker)
	_slot_overlay.get_node("%SlotDim").gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and not event.is_pressed() and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_close_slot_picker())
	for local_index in SAVE_SLOTS_SCRIPT.PAGE_SIZE:
		var card: Button = _slot_overlay.get_node("%Cards").get_child(local_index)
		card.pressed.connect(_on_slot_card_pressed.bind(local_index))
		_slot_card_buttons.append(card)
		_slot_card_numbers.append(card.get_node("%Number"))
		_slot_card_titles.append(card.get_node("%SlotTitle"))
		_slot_card_times.append(card.get_node("%SavedTime"))
		_slot_card_previews.append(card.get_node("%Preview"))
	_slot_confirmation_overlay = _slot_overlay.get_node("SlotConfirmationOverlay")
	_slot_confirmation_overlay.visible = false
	_slot_confirmation_panel = _slot_confirmation_overlay.get_node("%ConfirmationPanel")
	_slot_confirmation_label = _slot_confirmation_overlay.get_node("%Question")
	_slot_confirm_yes = _slot_confirmation_overlay.get_node("%SlotConfirmYes")
	_slot_confirm_no = _slot_confirmation_overlay.get_node("%SlotConfirmNo")
	_slot_confirm_yes.pressed.connect(_confirm_slot_overwrite)
	_slot_confirm_no.pressed.connect(_cancel_slot_confirmation)
	_slot_confirmation_overlay.get_node("%Dim").gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and not event.is_pressed() and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_cancel_slot_confirmation())


func _layout() -> void:
	if _game == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	# stretch expand 讓邏輯尺寸至少 1080×1920；遊戲區固定 1080 寬，較長的手機往下延伸，桌機左右留黑邊。
	var width: float = minf(viewport_size.x, DESIGN_WIDTH)
	var height: float = viewport_size.y
	_game.position = Vector2(floorf((viewport_size.x - width) * 0.5), 0.0)
	_game.size = Vector2(width, height)
	_read_safe_area(viewport_size)

	var top: float = EDGE + _safe_top
	var bottom: float = height - EDGE - _safe_bottom
	_place_tag.position = Vector2(EDGE + 12.0, top + 8.0)
	_place_tag.size = Vector2(width * 0.6, 60.0)
	_phase3_hud.offset_top = _safe_top

	# 對話框與選項面板依內容往上長、貼齊底部；這裡只讓出手機手勢列，並在窄螢幕等比放大（見 _ui_scale）。
	_panel_scale = _ui_scale()
	_fit_bottom_panel(_dialog_panel)
	_fit_bottom_panel(_investigate_bar)
	_fit_choice_sheet()
	var dialog_height: float = roundf(height * DIALOG_RATIO) if _phase3_enabled else clampf(height * 0.20, 360.0, 440.0)
	var dialog_y: float = bottom - (QUICKBAR_HEIGHT + DIALOG_GAP + dialog_height) * _panel_scale
	_stage_bottom = dialog_y
	_stage_area.offset_bottom = dialog_y - height

	_fit_full_area(_end_box)

	for actor_id: String in _sprites.keys():
		_layout_sprite(actor_id)

	_fit_menu()
	_fit_full_area(_game_over)
	_fit_full_area(_chapter_result)
	_fit_full_area(_comedy_layer)
	_fit_bottom_panel(_title_screen.card_area)
	_fit_panel_area(_log_overlay, Rect2(0.0,top,width,bottom-top))

	_layout_slot_picker(width, height, top, bottom)
	_case_file_panel.call("layout", Rect2(0.0, top, width, bottom - top))
	_fit_panel_area(_chapter_select, Rect2(0.0, top, width, bottom - top))
	_fit_panel_area(_settings_panel, Rect2(0.0, top, width, bottom - top))
	if _screen_mode == "investigate":
		_layout_hotspots()
	_publish_qa_state()


## The scenes are drawn for a 390 CSS px wide game area (1080 / 390 logical px per CSS px). On a
## narrower phone they would shrink with it, so the box scales up by 390 / CSS width to keep its
## buttons at least 48 CSS px. CSS px = screen px / device pixel ratio.
func _ui_scale() -> float:
	var screen_px: float = _game.size.x * get_viewport().get_final_transform().get_scale().x
	var css_px: float = screen_px / maxf(1.0, DisplayServer.screen_get_scale())
	var k: float = 390.0 / maxf(css_px, 1.0)
	# 0.4 % headroom: a 48 CSS px button scaled to exactly 48 measures 47.997 after rounding.
	return 1.0 if k <= 1.0 else minf(k * 1.004, 1.5)


## Full-screen scene part at _panel_scale, laid out smaller so that scaled it covers the game area.
func _fit_full_area(area: Control) -> void:
	area.scale = Vector2(_panel_scale, _panel_scale)
	area.offset_right = _game.size.x / _panel_scale - _game.size.x
	area.offset_bottom = _game.size.y / _panel_scale - _game.size.y


## A full-screen panel scene at _panel_scale, laid out smaller so that scaled it fills `area`
## (the game area between the safe-area edges).
func _fit_panel_area(panel: Control, area: Rect2) -> void:
	panel.scale = Vector2(_panel_scale, _panel_scale)
	panel.offset_left = area.position.x
	panel.offset_top = area.position.y
	panel.offset_right = area.position.x + area.size.x / _panel_scale - _game.size.x
	panel.offset_bottom = area.position.y + area.size.y / _panel_scale - _game.size.y


## The sheet at _panel_scale, kept below the place name and the HUD (about 96 CSS px from the top).
## While a placard answers the line being chosen, the sheet also stays below the board.
func _fit_choice_sheet() -> void:
	_fit_bottom_panel(_choice_sheet)
	if _game != null and _game.size.y > 0.0:
		var top: float = _safe_top + 96.0 * CSS_PX
		if _screen_mode == "tsukkomi" and _placard_open():
			top = maxf(top, (_placard_holder.call("placard_rect") as Rect2).end.y - _game.global_position.y + 4.0 * CSS_PX)
		_choice_sheet.set_max_height((_game.size.y - top - _safe_bottom) / _panel_scale)


## Bottom-anchored panel scene at _panel_scale, laid out narrower so that scaled it spans the game width.
func _fit_bottom_panel(panel: Control) -> void:
	panel.scale = Vector2(_panel_scale, _panel_scale)
	panel.offset_right = _game.size.x / _panel_scale - _game.size.x
	panel.offset_bottom = -_safe_bottom


func _layout_sprite(actor_id: String) -> void:
	if _dialog_panel == null or not _sprites.has(actor_id):
		return
	var sprite: Control = _sprites[actor_id] as Control
	var marker: Control = _slot_markers.get(str(_actor_slots.get(actor_id, "center")), _slot_markers["center"])
	# The character's standing box (its scene root) is scaled to the slot's height (scenes/stage.tscn)
	# and stands on the slot's bottom edge, centred; its Art keeps the framing set in its own scene.
	# Worked out from anchors, since the stage may not have had its layout pass since _layout moved
	# StageArea's bottom.
	var area: Rect2 = _anchored_rect(_stage_area, Rect2(Vector2.ZERO, _game.size))
	var box: Rect2 = _anchored_rect(marker, area)
	var reference: Vector2 = SPRITE_SCRIPT.REFERENCE_SIZE
	sprite.size = reference
	sprite.pivot_offset = Vector2(reference.x * 0.5, reference.y)
	sprite.scale = Vector2.ONE * (box.size.y / reference.y)
	sprite.position = Vector2(box.get_center().x, box.end.y) - sprite.pivot_offset


## Where a Control's anchors and offsets place it inside parent_rect (no minimum size or grow).
func _anchored_rect(node: Control, parent_rect: Rect2) -> Rect2:
	var start: Vector2 = parent_rect.position + parent_rect.size * Vector2(node.anchor_left, node.anchor_top) \
		+ Vector2(node.offset_left, node.offset_top)
	var end: Vector2 = parent_rect.position + parent_rect.size * Vector2(node.anchor_right, node.anchor_bottom) \
		+ Vector2(node.offset_right, node.offset_bottom)
	return Rect2(start, end - start)


func _layout_slot_picker(width: float, height: float, top: float, bottom: float) -> void:
	if _slot_overlay != null:
		_fit_panel_area(_slot_overlay, Rect2(0.0,top,width,bottom-top))


func _read_safe_area(viewport_size: Vector2) -> void:
	# ponytail: 只在 Android／iOS 原生匯出讀取瀏海與手勢列；瀏覽器分頁本身已避開安全區（未設 viewport-fit=cover）。
	_safe_top = 0.0
	_safe_bottom = 0.0
	if OS.get_name() not in ["Android", "iOS"]:
		return
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var screen: Vector2i = DisplayServer.screen_get_size()
	if screen.y <= 0:
		return
	var to_logical: float = viewport_size.y / float(screen.y)
	_safe_top = float(safe.position.y) * to_logical
	_safe_bottom = float(screen.y - safe.end.y) * to_logical


# ---------------------------------------------------------------- 畫面切換

func _show_title() -> void:
	_cancel_generation()
	_effects.play_bgm("")
	_close_qte()
	_close_overlays()
	_set_ui_hidden(false)
	_set_auto(false)
	_set_skip(false)
	_screen_mode = "title"
	_phase3_hud.visible = false
	_title_screen.visible = true
	_dialog_layer.visible = false
	_refresh_title()
	_publish_qa_state()


func _show_story_screen() -> void:
	_title_screen.visible = false
	_dialog_layer.visible = true
	_screen_mode = "busy"
	_phase3_hud.visible = _phase3_enabled and not _ui_hidden


func _on_begin_pressed() -> void:
	if not _story_ready:
		return
	_start_audio_after_user_gesture()
	_start_new_story()


func _on_continue_pressed() -> void:
	_start_audio_after_user_gesture()
	var payload: Dictionary = _read_save_payload()
	if not _apply_save_payload(payload):
		_story_error = "這份續讀資料已失效，請重新開始。"
		_show_title()
		return
	_show_story_screen()
	_render_restored_current()


func _on_restart_pressed() -> void:
	_start_audio_after_user_gesture()
	_start_new_story()


func _start_new_story() -> void:
	_round_stages.clear()
	_rollback.clear()
	_previous_power = 0
	_cancel_generation()
	_close_overlays()
	_effects.play_bgm("")
	_delete_save()
	_history.clear()
	_boke_time_remaining = 0.0
	_boke_timer_round_id = ""
	_restored_boke_timer_remaining = -1.0
	_restored_boke_ui_mode = ""
	_last_boke_result = ""
	_clear_hotspots()
	_investigation_pans.clear()
	_investigation_home_casts.clear()
	_story_error = ""
	_set_auto(false)
	_set_skip(false)
	_runner.call("reset")
	for actor_id: String in _actors.keys():
		_actor_slots[actor_id] = str((_actors[actor_id] as Dictionary).get("slot", "center"))
	for sprite: Control in _sprites.values():
		sprite.visible = false
		sprite.call("set_expression", "neutral")
	_apply_background("yorozuya_living_room")
	for actor_id: String in _sprites.keys():
		_layout_sprite(actor_id)
	_show_story_screen()
	_start_drive()


# ---------------------------------------------------------------- 故事推進

func _start_drive() -> void:
	call_deferred("_drive_story", _generation)


func _drive_story(generation: int) -> void:
	if generation != _generation:
		return
	_story_busy = true
	_screen_mode = "busy"
	_publish_qa_state()
	while generation == _generation:
		var command: Dictionary = _runner_current()
		if command.is_empty():
			_show_runtime_error("故事流程沒有可呈現的指令。")
			return
		match _command_op(command):
			"say":
				_story_busy = false
				_present_say(command, false)
				return
			"choice":
				_rollback.clear()
				_story_busy = false
				_present_choice(command)
				_save_game()
				return
			"end":
				_rollback.clear()
				_story_busy = false
				_present_end(command)
				_save_game()
				return
			"result":
				_rollback.clear()
				_story_busy = false
				_present_result(command)
				_save_game()
				return
			"investigate":
				_rollback.clear()
				_story_busy = false
				_present_investigation(command, false)
				_save_game()
				return
			"boke_round":
				_rollback.clear()
				_story_busy = false
				_present_boke_round(command, false)
				_save_game()
				return
			"sound":
				_play_sound(_dict_string(command, "id"))
			"bg":
				if _dict_string(command, "id") != _current_bg_id:
					_clear_stage()  # a new scene starts with nobody on stage
				_apply_background(_dict_string(command, "id"), true)
			"char":
				_apply_character(command)
			"show":
				_sprite(_dict_string(command, "actor")).visible = true
			"hide":
				_motion.character(_sprite(_dict_string(command, "actor")), "leave", _skip)
			"expression":
				_sprite(_dict_string(command, "actor")).call("set_expression", _dict_string(command, "value", "neutral"))
			"wait":
				if not _skip:
					await get_tree().create_timer(float(command.get("duration", 0.0))).timeout
					if generation != _generation:
						return
			"shake", "flash", "cutin", "bgm", "se", "beam":
				_effects.play(command, _skip)
			"freeze":
				var hold: float = _effects.play(command, _skip)
				if hold > 0.0:
					await get_tree().create_timer(hold).timeout
					if generation != _generation:
						return
			"fade":
				var fade_time: float = _motion.fade(_dict_string(command, "direction", "out"), float(command.get("duration", 0.3)), _skip)
				if fade_time > 0.0:
					await get_tree().create_timer(fade_time).timeout
					if generation != _generation:
						return
			"comedy":
				_log_comedy(command)
				if not _skip and _comedy_layer.play(command) > 0.0:
					_publish_qa_state()
					while _comedy_layer.is_active() and generation == _generation:
						await get_tree().process_frame  # a tap or stop() ends it early
					if generation != _generation:
						return
			_:
				pass  # ponytail: move／face／camera 屬於舊的俯視舞台；VN 立繪沒有對應演出，直接略過
		_runner.call("advance")
	_story_busy = false


## A comedy step's line goes into the log whether it plays or is skipped; the speaker is the one named.
func _log_comedy(command: Dictionary) -> void:
	_append_history({"key": _line_key(command, "comedy"), "kind": "say", "speaker": _dict_string(command, "speaker"),
		"text": _dict_string(command, "text"), "thought": false})


## Where the speaker's picture is on screen (empty when they are not on stage): the comedy layer
## hangs a small reaction there.
func _comedy_speaker_rect(speaker: String) -> Rect2:
	var sprite: Control = _sprites.get(speaker) as Control
	return sprite.call("art_rect") if sprite != null and sprite.visible and sprite.has_method("art_rect") else Rect2()


func _comedy_dialog_rect() -> Rect2:
	return _dialog_panel.get_global_rect()


func _advance_current_line() -> void:
	if _command_op(_runner_current()) == "say":
		_rollback.remember(_build_save_payload(""))
	_line_generation += 1
	_story_busy = true
	var advanced: Variant = _runner.call("advance")
	if advanced == null and not _runner_string("error_message", "").is_empty():
		_show_runtime_error(_runner_string("error_message", "故事無法繼續。"))
		return
	_start_drive()


func _present_say(command: Dictionary, restored: bool) -> void:
	_pending_round_mode = ""
	_current_command = command.duplicate(true)
	_clear_hotspots()
	_investigation_continue_button.visible = false
	_boke_controls.visible = false
	_game_over_retry_button.visible = false
	_dialog_panel.set_reading_enabled(true)
	_current_speaker = _dict_string(command, "speaker", "narrator")
	_line_plan = DialogueText.compile(_dict_string(command, "text"), _text_interval(),
		_text_label.get_theme_font_size("normal_font_size"))
	_full_text = str(_line_plan["plain"])
	_current_line_key = _line_key(command, "say")
	_line_logged = _history_has_key(_current_line_key)
	_line_generation += 1
	_clear_choices()
	_end_box.visible = false
	_screen_mode = "story"
	_refresh_phase3_hud()
	var thought: bool = _dict_bool(command, "thought")
	_set_name_plate(_current_speaker, thought)
	if not _dict_bool(command, "offscreen"):  # a voice from off stage leaves the stage as it is
		_focus_speaker(_current_speaker, _dict_string(command, "expression", ""))
	_set_text_tone("thought" if thought else "body")
	if restored and _line_logged:
		_set_visible_text(_full_text, true)
		_on_line_completed()
		return
	if not restored:
		# 在打字前存檔：中途關閉分頁會回到這一句，且不會把它記成已讀。
		_save_game()
	_set_visible_text("", false)
	if _skip:
		_complete_current_line()
		return
	_typewriter(_line_generation)
	_publish_qa_state()


func _present_investigation(command: Dictionary, restored: bool) -> void:
	_current_command = command.duplicate(true)
	_current_speaker = "shinpachi"
	_full_text = _dict_string(command, "prompt", "調查現場，尋找線索。")
	_current_line_key = _line_key(command, "investigate")
	if _dict_string(command, "place", "home") != "home":
		_current_line_key += ":" + _dict_string(command, "place")
	_line_logged = _history_has_key(_current_line_key)
	_line_generation += 1
	_story_busy = false
	_set_auto(false)
	_set_skip(false)
	_clear_choices()
	_clear_hotspots()
	_screen_mode = "investigate"
	_dialog_layer.visible = true
	_dialog_panel.visible = true  # the prompt shows first; 收起 folds the box away
	_end_box.visible = false
	_investigation_continue_button.visible = true
	_boke_controls.visible = false
	_dialog_panel.set_reading_enabled(false)
	_set_name_plate("shinpachi", true)
	if _dict_bool(command, "keep_cast"):
		var home_key: String = _dict_string(command, "id", _dict_string(command, "node"))
		var place: String = _dict_string(command, "place", "home")
		if not _investigation_home_casts.has(home_key) or (place == "home" and (_dict_string(command, "bg").is_empty() or _current_bg_id == _dict_string(command, "bg"))):
			_investigation_home_casts[home_key] = (_build_save_payload("").get("sprites", {}) as Dictionary).duplicate(true)
		var home_cast: Dictionary = _investigation_home_casts[home_key]
		for actor_id: String in _sprites:
			var sprite: Control = _sprites[actor_id]
			var pose: Dictionary = home_cast.get(actor_id, {})
			sprite.visible = place == "home" and bool(pose.get("visible", false))
			if sprite.visible:
				_actor_slots[actor_id] = str(pose.get("position", "center"))
				sprite.call("set_expression", str(pose.get("expression", "neutral")))
			sprite.modulate = Color.WHITE  # nobody is in focus while searching: any of them can be tapped
	else:
		_clear_stage()  # the player searches the room itself
	var place_bg: String = _dict_string(command, "bg")
	if not place_bg.is_empty() and place_bg != _current_bg_id:
		_apply_background(place_bg)  # each place of the search shows its own picture
	_set_text_tone("thought")
	_layout()
	_set_visible_text(_full_text, true)
	_current_command = _runner_current()
	_build_hotspots(_current_command)
	_show_topics(_current_command)
	_update_investigation_controls()
	if not _line_logged:
		_append_history({"key": _current_line_key, "kind": "investigate", "speaker": "shinpachi",
			"text": _full_text})
		_line_logged = true
	_refresh_phase3_hud()
	_publish_qa_state()


func _build_investigate_bar() -> void:
	_investigate_bar = INVESTIGATE_BAR_SCENE.instantiate() as Control
	_dialog_layer.add_child(_investigate_bar)
	_investigate_bar.visible = false
	_investigate_bar.connect("expand_pressed", _set_investigation_collapsed.bind(false))


## Folds the reading box into the one-line bar (or back) while searching.
func _set_investigation_collapsed(value: bool) -> void:
	_investigate_collapsed = value and _screen_mode == "investigate"
	_investigate_bar.visible = _investigate_collapsed
	_refresh_reading_ui()
	_publish_qa_state()


## The spots of this investigation, on a layer over the whole background picture: each sits over
## its object at the story's `pos` (centre) and `size`, fractions of the picture.
func _build_hotspots(command: Dictionary) -> void:
	_clear_hotspots()
	_pan_key = "%s/%s" % [_dict_string(command, "id"), _dict_string(command, "place", "home")]
	if bool(command.get("keep_cast",false)):
		for actor: String in _sprites.keys():
			if (_sprites[actor] as Control).visible:
				_cast_pan_origins[actor] = (_sprites[actor] as Control).position.x
	_pan = float(_investigation_pans.get(_pan_key, 0.0))  # back from a reaction: where the player left it
	var frame: TextureRect = _background_rect
	_frame_offsets = [frame.offset_left, frame.offset_top, frame.offset_right, frame.offset_bottom]
	_hotspot_layer = Control.new()
	_hotspot_layer.name = "Hotspots"
	_hotspot_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_hotspot_layer)
	_hotspot_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for raw_hotspot: Variant in command.get("hotspots", []):
		if not raw_hotspot is Dictionary:
			continue
		var hotspot: Dictionary = raw_hotspot as Dictionary
		var hotspot_id: String = _dict_string(hotspot, "id")
		var spot: Control = HOTSPOT_SCENE.instantiate() as Control
		spot.name = "Hotspot_" + hotspot_id
		if hotspot.has("character"):
			# A character's spot covers their portrait on the stage instead of a place on the picture:
			# it lies on the interaction layer (sized by _layout_hotspots) and exists while they are on stage.
			if not _dict_bool(hotspot, "present", true):
				spot.free()
				continue
			_interaction_layer.add_child(spot)
		else:
			var pos: Array = hotspot.get("pos", [0.5, 0.5]) as Array
			var extent: Array = hotspot.get("size", DEFAULT_HOTSPOT_SIZE) as Array
			_hotspot_layer.add_child(spot)
			spot.anchor_left = clampf(float(pos[0]) - float(extent[0]) * 0.5, 0.0, 1.0)
			spot.anchor_right = clampf(float(pos[0]) + float(extent[0]) * 0.5, 0.0, 1.0)
			spot.anchor_top = clampf(float(pos[1]) - float(extent[1]) * 0.5, 0.0, 1.0)
			spot.anchor_bottom = clampf(float(pos[1]) + float(extent[1]) * 0.5, 0.0, 1.0)
			spot.offset_left = 0.0
			spot.offset_top = 0.0
			spot.offset_right = 0.0
			spot.offset_bottom = 0.0
		spot.call("set_found", bool(hotspot.get("checked", false)), false)
		_hotspots[hotspot_id] = spot
	_layout_hotspots()


## Stretches the background frame to the whole picture (which covers the frame's own rect,
## centred) so every part of it can slide into view, and works out how far it may slide.
func _layout_hotspots() -> void:
	if _hotspot_layer == null or not is_instance_valid(_hotspot_layer):
		return
	var frame: TextureRect = _hotspot_layer.get_parent() as TextureRect
	var own: Rect2 = _anchored_rect_with(frame, _frame_offsets, Rect2(Vector2.ZERO, _game.size))
	_picture = own
	if frame.texture != null and not frame.texture is GradientTexture2D:
		var art: Vector2 = Vector2(frame.texture.get_width(), frame.texture.get_height())
		var drawn: Vector2 = art * maxf(own.size.x / art.x, own.size.y / art.y)
		_picture = Rect2(own.position + (own.size - drawn) * 0.5, drawn)
	_pan_range = Vector2(minf(0.0, _game.size.x - _picture.end.x), maxf(0.0, -_picture.position.x))
	_set_pan(_pan)
	_place_cast_hotspots()


## A character's spot lies over their portrait as it is on screen (kept inside the game area).
func _place_cast_hotspots() -> void:
	var screen: Rect2 = Rect2(_game.global_position, _game.size)
	for raw_hotspot: Variant in _current_command.get("hotspots", []):
		var hotspot: Dictionary = raw_hotspot as Dictionary
		var spot: Control = _hotspots.get(_dict_string(hotspot, "id")) as Control
		if spot == null or spot.get_parent() != _interaction_layer:
			continue
		var portrait: Rect2 = (_sprites[_dict_string(hotspot, "character")] as Control).call("art_rect")
		if hotspot.has("art_region"):
			var region: Array = hotspot["art_region"]
			portrait = Rect2(portrait.position + portrait.size * Vector2(region[0],region[1]),
				portrait.size * Vector2(region[2],region[3]))
		var shown: Rect2 = portrait.intersection(screen)
		if not shown.has_area():
			shown = portrait  # wholly off screen: nothing to clip, and nobody can tap it
		spot.position = shown.position - _interaction_layer.global_position
		spot.size = shown.size


func _set_pan(value: float) -> void:
	_pan = clampf(value, _pan_range.x, _pan_range.y)
	if _hotspot_layer == null or not is_instance_valid(_hotspot_layer):
		return
	var frame: TextureRect = _hotspot_layer.get_parent() as TextureRect
	var start: Vector2 = _game.size * Vector2(frame.anchor_left, frame.anchor_top)
	var end: Vector2 = _game.size * Vector2(frame.anchor_right, frame.anchor_bottom)
	frame.offset_left = _picture.position.x + _pan - start.x
	frame.offset_right = _picture.end.x + _pan - end.x
	frame.offset_top = _picture.position.y - start.y
	frame.offset_bottom = _picture.end.y - end.y
	for actor: String in _cast_pan_origins.keys():
		(_sprites[actor] as Control).position.x = float(_cast_pan_origins[actor]) + _pan
	_place_cast_hotspots()


func _clear_hotspots() -> void:
	for actor: String in _cast_pan_origins.keys():
		(_sprites[actor] as Control).position.x = float(_cast_pan_origins[actor])
	_cast_pan_origins.clear()
	if not _pan_key.is_empty() and _hotspot_layer != null:
		_investigation_pans[_pan_key] = _pan
	_pan_key = ""
	_topic_buttons.clear()
	if _dialog_panel != null:
		_dialog_panel.set_topics([], [])
	if _hotspot_layer != null and is_instance_valid(_hotspot_layer):
		var frame: TextureRect = _hotspot_layer.get_parent() as TextureRect
		frame.offset_left = _frame_offsets[0]
		frame.offset_top = _frame_offsets[1]
		frame.offset_right = _frame_offsets[2]
		frame.offset_bottom = _frame_offsets[3]
		_hotspot_layer.queue_free()
	_hotspot_layer = null
	for spot: Control in _hotspots.values():
		if spot.get_parent() == _interaction_layer:
			spot.queue_free()  # a character's spot lies on the interaction layer, not on the picture
	_hotspots.clear()
	_pan = 0.0
	_pan_range = Vector2.ZERO
	_investigate_collapsed = false
	if _investigate_bar != null:
		_investigate_bar.visible = false


## Where a Control would sit inside parent_rect with the given offsets [left, top, right, bottom].
func _anchored_rect_with(node: Control, offsets: Array[float], parent_rect: Rect2) -> Rect2:
	var start: Vector2 = parent_rect.position + parent_rect.size * Vector2(node.anchor_left, node.anchor_top) \
		+ Vector2(offsets[0], offsets[1])
	var end: Vector2 = parent_rect.position + parent_rect.size * Vector2(node.anchor_right, node.anchor_bottom) \
		+ Vector2(offsets[2], offsets[3])
	return Rect2(start, end - start)


## A tap on the picture while searching: the spot under it, unless the reading box covers it.
## Found spots are done, except those with `lines`, which answer every tap. Where spots overlap, an
## object beats a character (a character's spot is their whole portrait, so no object may hide in it)
## and the smaller object wins; of two characters, the one in front wins.
func _tap_investigation(at: Vector2) -> void:
	if _story_busy or (_dialog_panel.visible and _dialog_panel.get_global_rect().has_point(at)):
		return
	var tapped: String = ""
	var tapped_rank: float = INF
	for hotspot_id: String in _hotspots.keys():
		var spot: Control = _hotspots[hotspot_id] as Control
		var data: Dictionary = _hotspot_data(hotspot_id)
		if bool(spot.get("found")) and not data.has("lines"):
			continue
		var hit: Rect2 = _hotspot_hit_rect(spot)
		var rank: float = hit.get_area() if not data.has("character") else 1.0e9 - _sprites[data["character"]].get_index()
		if hit.has_point(at) and rank < tapped_rank:
			tapped = hotspot_id
			tapped_rank = rank
	if not tapped.is_empty():
		_collect_hotspot(tapped)


## The runner's entry for a hotspot of the current search ({} when there is none).
func _hotspot_data(hotspot_id: String) -> Dictionary:
	for raw_hotspot: Variant in _current_command.get("hotspots", []):
		if raw_hotspot is Dictionary and _dict_string(raw_hotspot as Dictionary, "id") == hotspot_id:
			return raw_hotspot as Dictionary
	return {}


## The spot's rect, grown to at least 48 CSS px each way so small objects stay tappable.
func _hotspot_hit_rect(spot: Control) -> Rect2:
	var rect: Rect2 = spot.get_global_rect()
	var least: float = 48.0 * CSS_PX * _panel_scale
	var grow: Vector2 = (Vector2(least, least) - rect.size).max(Vector2.ZERO) * 0.5
	return rect.grow_individual(grow.x, grow.y, grow.x, grow.y)


func _collect_hotspot(hotspot_id: String) -> void:
	if _screen_mode != "investigate" or _story_busy:
		return
	_sync_cast()
	var spot: Control = _hotspots.get(hotspot_id) as Control
	var first_time: bool = spot == null or not bool(spot.get("found"))  # `lines` spots answer every tap
	if not bool(_runner.call("inspect_hotspot", hotspot_id)):
		_show_toast(_runner_string("error_message", "這個位置目前不能調查。"))
		return
	var item_id: String = _dict_string(_hotspot_data(hotspot_id), "item")
	var item_info: Dictionary = (_catalog.get("items", {}) as Dictionary).get(item_id, {}) as Dictionary
	var item_name: String = str(item_info.get("name", item_id))
	var next: Dictionary = _runner_current()
	(_hotspots[hotspot_id] as Control).call("set_found", true, first_time)
	if not item_id.is_empty() and first_time:
		_show_toast("取得線索：" + item_name)
	if _command_op(next) != "investigate":
		# The spot has something to say: its scene plays and leads back to the search.
		_refresh_phase3_hud()
		_story_busy = true
		_screen_mode = "busy"
		_start_drive()
		return
	if _dict_string(next, "place") != _dict_string(_current_command, "place"):
		_present_investigation(next, true)  # a searched-out side place sends the player home
		_save_game()
		return
	_current_command = next
	_update_investigation_controls()
	_refresh_phase3_hud()
	_save_game()
	if not _investigation_continue_button.disabled and _investigate_collapsed:
		_set_investigation_collapsed(false)  # every clue found: bring back 繼續
	_publish_qa_state()


## 繼續 opens once every required spot of every place is checked (runner `complete`/`progress`).
func _update_investigation_controls() -> void:
	var all_checked: bool = bool(_current_command.get("complete", false))
	var progress: Array = _current_command.get("progress", [0, 0]) as Array
	_investigation_continue_button.disabled = not all_checked
	_investigation_continue_button.text = "線索已取得・繼續" if all_checked else "先調查所有位置"
	_investigate_bar.call("set_progress", int(progress[0]), int(progress[1]))


## The 對話 and 移動 rows of the reading box for this place of the search.
func _show_topics(command: Dictionary) -> void:
	_topic_buttons = _dialog_panel.set_topics(command.get("talk", []) as Array, command.get("moves", []) as Array)
	for key: String in _topic_buttons.keys():
		var topic_id: String = key.get_slice(":", 1)
		(_topic_buttons[key] as Button).pressed.connect(
			(_on_talk_pressed if key.begins_with("talk:") else _on_move_pressed).bind(topic_id))


## A talk topic: its scene plays once and leads back to the search.
func _on_talk_pressed(topic_id: String) -> void:
	if _screen_mode != "investigate" or _story_busy:
		return
	if not bool(_runner.call("talk_topic", topic_id)):
		_show_toast(_runner_string("error_message", "這個話題現在不能聊。"))
		return
	_story_busy = true
	_screen_mode = "busy"
	_start_drive()


## Moving: another place of the search, with its own picture, spots and topics.
func _on_move_pressed(place_id: String) -> void:
	if _screen_mode != "investigate" or _story_busy:
		return
	if not bool(_runner.call("move_to", place_id)):
		_show_toast(_runner_string("error_message", "現在不能去那裡。"))
		return
	_present_investigation(_runner_current(), true)
	_save_game()


func _on_investigation_continue_pressed() -> void:
	if _screen_mode != "investigate" or _story_busy or _investigation_continue_button.disabled:
		return
	var home_bg: String = _dict_string(_current_command, "home_bg")
	if not home_bg.is_empty() and home_bg != _current_bg_id:
		_clear_hotspots()
		_apply_background(home_bg)  # the search ends where it began
	_story_busy = true
	_screen_mode = "busy"
	_sync_cast()
	var next: Dictionary = _runner.call("advance") as Dictionary
	if _command_op(next) == "investigate":
		_story_busy = false
		_present_investigation(next, true)
		return
	_start_drive()


func _present_boke_round(command: Dictionary, restored: bool, requested_ui_mode: String = "") -> void:
	_pending_round_mode = ""
	_line_generation += 1
	var round_id: String = _dict_string(command,"id")
	if not _round_stages.has(round_id):
		var stage_payload: Dictionary = _build_save_payload("")
		_round_stages[round_id] = {"background": stage_payload.get("background",_current_bg_id),
			"sprites": stage_payload.get("sprites",{}).duplicate(true), "bgm": _effects.current_bgm}
	var target_ui_mode: String = requested_ui_mode
	if target_ui_mode.is_empty():
		target_ui_mode = _restored_boke_ui_mode if restored and not _restored_boke_ui_mode.is_empty() else "boke_round"
	if target_ui_mode not in ["boke_round", "tsukkomi"]:
		target_ui_mode = "boke_round"
	if RoundView.automatic(command):  # combo lines open their slot at once
		target_ui_mode = "qte" if RoundView.action(command) == "qte" else "tsukkomi"
	_close_qte()
	_current_command = command.duplicate(true)
	_current_speaker = RoundView.speaker(command)
	_clear_hotspots()
	_investigation_continue_button.visible = false
	_game_over_retry_button.visible = false
	_end_box.visible = false
	_clear_choices()
	_set_auto(false)
	_set_skip(false)
	_screen_mode = "boke_round"
	_story_busy = false
	_dialog_layer.visible = true
	_dialog_panel.visible = true
	_boke_controls.visible = not RoundView.automatic(command)
	_dialog_panel.set_reading_enabled(false)
	_set_name_plate(_current_speaker, false)
	_focus_speaker(_current_speaker, "annoyed")
	_layout()
	_line_plan = DialogueText.compile(RoundView.text(command), _text_interval(), _text_label.get_theme_font_size("normal_font_size"))
	_full_text = str(_line_plan["plain"])
	_set_text_tone("body")
	_set_visible_text(_full_text, true)
	_render_round_bar()
	var line_index: int = int(command.get("line_index", 0))
	_current_line_key = "%s:%s:%s" % [_line_key(command, "boke"), _dict_string(RoundView.line(command), "id"), line_index]
	_line_logged = _history_has_key(_current_line_key)
	var type_line: bool = bool((command.get("rules", {}) as Dictionary).get("type_lines", false)) and not _line_logged \
		and (not restored or requested_ui_mode in ["", "boke_round"])
	if type_line:
		_pending_round_mode = target_ui_mode if RoundView.automatic(command) else ""
		_boke_time_remaining = 0.0
		_set_visible_text("", false)
		_typewriter(_line_generation)
		_refresh_phase3_hud()
		_publish_qa_state()
		return
	if not _line_logged:
		_append_history({"key": _current_line_key, "kind": "say", "speaker": _current_speaker, "text": _full_text})
		_line_logged = true
	match target_ui_mode:
		"tsukkomi":
			_present_tsukkomi_options(command, restored)
		"qte":
			_start_qte(command)
		_:
			_boke_time_remaining = 0.0
			_boke_timer_round_id = ""
			_restored_boke_timer_remaining = -1.0
			_restored_boke_ui_mode = ""
			_screen_mode = "boke_round"
			_current_options.clear()
	_refresh_phase3_hud()
	_publish_qa_state()


## The round bar for _current_command (scripts/round_view.gd decides what it shows).
func _render_round_bar() -> void:
	var command: Dictionary = _current_command
	var index: int = int(command.get("line_index", 0))
	var browse: bool = RoundView.navigable(command)
	_boke_previous_button.visible = browse
	_boke_next_button.visible = browse
	_boke_previous_button.disabled = index <= 0
	_boke_next_button.disabled = index >= (command.get("lines", []) as Array).size() - 1
	_boke_line_label.text = RoundView.index_text(command)
	var heard: bool = RoundView.listened(command)
	_boke_listen_button.visible = RoundView.can_listen(command)
	_boke_listen_button.disabled = heard
	_boke_listen_button.text = "已聽過" if heard else "聽下去"
	_boke_tsukkomi_button.disabled = RoundView.action(command).is_empty()
	_boke_tsukkomi_button.text = "已接住" if RoundView.caught(command) else "吐槽！"
	_dialog_panel.censor_bar.visible = RoundView.censor(command)


func _present_tsukkomi_options(command: Dictionary, restored: bool) -> void:
	_current_command = command.duplicate(true)
	var round_id: String = _dict_string(command, "id")
	var timer_seconds: float = float(command.get("timer_seconds", DEFAULT_BOKE_TIMER_SECONDS))
	if _boke_timer_round_id != round_id:
		if restored and _restored_boke_timer_remaining >= 0.0:
			_boke_time_remaining = clampf(_restored_boke_timer_remaining, 0.0, timer_seconds)
		else:
			_boke_time_remaining = timer_seconds
		_boke_timer_round_id = round_id
		_last_boke_display_second = -1
		_restored_boke_timer_remaining = -1.0
	_restored_boke_ui_mode = ""
	_screen_mode = "tsukkomi"
	_boke_controls.visible = false
	_current_options.clear()
	for option_variant: Variant in RoundView.options(command):
		if option_variant is Dictionary:
			_current_options.append((option_variant as Dictionary).duplicate(true))
	_sheet_prompt = _full_text
	_sheet_timed = true
	_sheet_perspective = "pov"
	_sheet_note = ""
	_sheet_tones = PackedStringArray()
	_sheet_censor = RoundView.censor(command)
	_sheet_super = bool(command.get("super_available", false))
	_show_choice_sheet()


func _on_boke_tsukkomi_pressed() -> void:
	if _screen_mode != "boke_round" or _story_busy:
		return
	if not _text_complete:
		_complete_current_line()
		return
	match RoundView.action(_current_command):
		"options":
			_present_tsukkomi_options(_current_command, false)
			_save_game()
			_refresh_phase3_hud()
			_publish_qa_state()
		"qte":
			_start_qte(_current_command)
		"whiff":
			_round_action(func() -> Dictionary: return _runner.call("whiff_boke"), "（空揮）", "boke_round")


## Hands one round move to the runner and plays its outcome.
func _round_action(move: Callable, label: String, prior_ui_mode: String, feedback: String = "") -> void:
	_story_busy = true
	_screen_mode = "busy"
	_resolve_boke_presentation(move.call() as Dictionary, label, prior_ui_mode, feedback)


## The censor bar, torn off while reading (no timer) or while the options run.
func _on_censor_pressed() -> void:
	if _screen_mode not in ["boke_round", "tsukkomi"] or _story_busy or not RoundView.censor(_current_command):
		return
	_round_action(func() -> Dictionary: return _runner.call("resolve_censor"), "（撕下消音條）", _screen_mode)


## The placard, pointed at while reading (no timer) or while the options run; like the censor bar.
func _on_placard_pressed() -> void:
	if not _placard_open():
		return
	_round_action(func() -> Dictionary: return _runner.call("resolve_placard"), "（指著牌子）", _screen_mode)


## The placard answers the current line: it is on stage, the round shows that line, nothing busy.
func _placard_open() -> bool:
	if _placard_holder == null or not _placard_holder.visible or _runner == null or _story_busy:
		return false
	return _screen_mode in ["boke_round", "tsukkomi"] and bool((_runner.call("placard_view") as Dictionary).get("tappable", false))


## The board on screen grown to at least 48 CSS px each way (like a hotspot), inside the game
## area and above the reading box or options sheet (a tap there belongs to them).
func _placard_hit_rect() -> Rect2:
	var rect: Rect2 = _placard_holder.call("placard_rect")
	var least: float = 48.0 * CSS_PX * _panel_scale
	var grow: Vector2 = (Vector2(least, least) - rect.size).max(Vector2.ZERO) * 0.5
	rect = rect.grow_individual(grow.x, grow.y, grow.x, grow.y).intersection(Rect2(_game.global_position, _game.size))
	for panel: Control in [_dialog_panel, _choice_sheet]:
		var top: float = panel.get_global_rect().position.y
		if panel.is_visible_in_tree() and rect.end.y > top:
			rect.size.y = maxf(0.0, top - rect.position.y)
	return rect


## The runner decides what the placard says; it glows while its line is up on the timed sheet.
func _refresh_placard() -> void:
	if _placard_holder == null or _runner == null or not _story_ready:
		return
	var view: Dictionary = _runner.call("placard_view") as Dictionary
	_placard_holder.call("set_placard", str(view.get("text", "")),
		bool(view.get("tappable", false)) and _screen_mode == "tsukkomi")
	if bool(view.get("tappable", false)) and _placard_holder.visible:
		# While the board answers the line, its holder steps in front of the speaker, lit.
		_char_layer.move_child(_placard_holder, -1)
		_placard_holder.modulate = Color.WHITE


func _on_super_pressed() -> void:
	if _screen_mode != "tsukkomi" or _story_busy or not bool(_current_command.get("super_available", false)):
		return
	_round_action(func() -> Dictionary: return _runner.call("use_super"), "超必殺吐槽", "tsukkomi", "超必殺吐槽！全部戳破")


func _start_qte(command: Dictionary) -> void:
	_close_qte()
	_screen_mode = "qte"
	_qte = QTE_SCENE.instantiate() as QteRing
	_overlay_layer.add_child(_qte)
	_qte.resolved.connect(_on_qte_resolved)
	_qte.start(RoundView.qte(command))
	_publish_qa_state()


## tapped=false: the ring ran out. offset: seconds from the moment the rings met.
func _on_qte_resolved(tapped: bool, offset: float) -> void:
	if _screen_mode != "qte" or _story_busy:
		return
	_close_qte()
	_round_action(func() -> Dictionary: return _runner.call("resolve_qte", tapped, offset), "", "qte")


func _close_qte() -> void:
	if _qte != null and is_instance_valid(_qte):
		_qte.queue_free()
	_qte = null


func _on_boke_previous_pressed() -> void:
	_set_boke_line(int(_current_command.get("line_index", 0)) - 1)


func _on_boke_next_pressed() -> void:
	_set_boke_line(int(_current_command.get("line_index", 0)) + 1)


func _set_boke_line(index: int) -> void:
	if _screen_mode != "boke_round" or _story_busy:
		return
	if not bool(_runner.call("set_boke_line", index)):
		return
	_present_boke_round(_runner_current(), true)
	_save_game()


func _on_boke_listen_pressed() -> void:
	if _screen_mode != "boke_round" or _story_busy:
		return
	if not _text_complete:
		_complete_current_line()
		return
	if RoundView.is_v2(_current_command):
		# The runner has jumped into the line's listen scene; play it, it leads back to the round.
		if bool(_runner.call("listen_boke_line")):
			_story_busy = true
			_screen_mode = "busy"
			_start_drive()
		return
	if not bool(_runner.call("listen_boke_line")):
		return
	var line: Dictionary = _current_command.get("current_line", {}) as Dictionary
	var followup: String = _dict_string(line, "listen")
	_append_history({"key": _current_line_key + ":listen", "kind": "say", "speaker": _current_speaker, "text": followup})
	_present_boke_round(_runner_current(), true)
	_save_game()


func _on_boke_option_pressed(option_id: String) -> void:
	if _screen_mode != "tsukkomi" or _story_busy:
		return
	var option_label: String = option_id
	for option: Dictionary in _current_options:
		if _dict_string(option, "id") == option_id:
			option_label = _dict_string(option, "label", option_id)
			break
	_story_busy = true
	_screen_mode = "busy"
	var result: Dictionary = _runner.call("resolve_boke", option_id) as Dictionary
	_resolve_boke_presentation(result, option_label, "tsukkomi")


func _resolve_boke_presentation(result: Dictionary, option_label: String = "", prior_ui_mode: String = "",
		feedback_override: String = "") -> void:
	if result.is_empty():
		_story_busy = false
		_present_boke_round(_runner_current(), true, prior_ui_mode)
		return
	_last_boke_result = _dict_string(result, "result")
	_boke_time_remaining = 0.0
	_boke_timer_round_id = ""
	_boke_controls.visible = false
	_clear_choices()
	if not option_label.is_empty():
		_append_history({"key": "%s:result:%s" % [_current_line_key, _last_boke_result], "kind": "choice", "text": option_label})
	var feedback: String = ""
	match _last_boke_result:
		"perfect":
			feedback = "完美吐槽！吐槽之力 +30"
			_effects.play_perfect_voice(int((_runner.get("stats") as Dictionary).get("perfect", 1)))
		"weak":
			feedback = "普通吐槽！吐槽之力 +10"
		"fail":
			feedback = "冷場！眼鏡 -1" if not bool(result.get("game_over", false)) else "眼鏡耗盡・Game Over"
		"hidden":
			feedback = "放棄吐槽・狀態不變"
	if not feedback_override.is_empty():
		feedback = feedback_override
	var power: int = int((_runner.get("gameplay") as Dictionary).get("power", 0))
	var maximum: int = int((_runner.get("gameplay") as Dictionary).get("max_power", 100))
	if power >= maximum and _previous_power < maximum:
		_effects.play({"op": "cutin", "text": "吐槽之力全滿！", "speaker": "shinpachi"}, _skip)
		_effects.play({"op": "se", "id": "power_up"}, _skip)
	_previous_power = power
	_refresh_phase3_hud()
	_show_toast(feedback)
	_start_drive()


func _on_boke_timeout() -> void:
	if _screen_mode != "tsukkomi" or _story_busy:
		return
	_story_busy = true
	_screen_mode = "busy"
	var result: Dictionary = _runner.call("timeout_boke") as Dictionary
	_resolve_boke_presentation(result, "", "tsukkomi")


func _on_game_over_retry_pressed() -> void:
	if not _phase3_enabled or _runner == null or _story_busy:
		return
	if not bool(_runner.call("retry_checkpoint")):
		_show_toast(_runner_string("error_message", "目前沒有可重試的檢查點。"))
		return
	_cancel_generation()
	_rollback.clear()
	_boke_timer_round_id = ""
	_boke_time_remaining = 0.0
	_restored_boke_timer_remaining = -1.0
	_restored_boke_ui_mode = ""
	_previous_power = int((_runner.get("gameplay") as Dictionary).get("power", 0))
	_last_boke_result = "retry"
	var snapshot: Dictionary = _runner.call("snapshot")
	var retry_round: String = str((snapshot.get("checkpoint",{}) as Dictionary).get("round_id",""))
	var stage: Dictionary = _round_stages.get(retry_round,{})
	if not stage.is_empty():
		_apply_background(str(stage["background"]))
		for actor: String in _sprites.keys():
			var state: Dictionary = stage["sprites"].get(actor,{})
			_actor_slots[actor] = str(state.get("position","center"))
			(_sprites[actor] as Control).visible = bool(state.get("visible",false))
			_sprites[actor].call("set_expression",str(state.get("expression","neutral")))
			_layout_sprite(actor)
		_effects.play_bgm(str(stage.get("bgm","")))
	_story_busy = false
	_screen_mode = "busy"
	_game_over.visible = false
	_render_restored_current()
	_refresh_phase3_hud()
	_save_game()
	_publish_qa_state()


func _typewriter(token: int) -> void:
	if _text_interval() <= 0.0:  # 瞬間: the whole line at once; the first tap advances
		_complete_current_line()
		return
	var plan: Dictionary = _line_plan if str(_line_plan.get("plain", "")) == _full_text else DialogueText.compile(_full_text, _text_interval())
	for end: int in plan["ends"]:
		if end <= _visible_text.length():
			continue
		if token != _line_generation:
			return
		var pause: float = DialogueText.before_delay(plan, _visible_text.length())
		if pause > 0.0:
			await get_tree().create_timer(pause).timeout
			if token != _line_generation:
				return
		var cluster: String = _full_text.substr(_visible_text.length(), end - _visible_text.length())
		_set_visible_text(_full_text.substr(0, end), false)
		_effects.play_type_tick(_current_speaker, cluster, _dict_bool(_current_command, "thought"), _skip)
		await get_tree().create_timer(DialogueText.after_delay(plan, end)).timeout
	if token == _line_generation:
		var final_pause: float = DialogueText.before_delay(plan, _full_text.length())
		if final_pause > 0.0:
			await get_tree().create_timer(final_pause).timeout
	if token == _line_generation:
		_complete_current_line()


func _complete_current_line() -> void:
	_line_generation += 1
	_set_visible_text(_full_text, true)
	if not _line_logged:
		_append_history({"key": _current_line_key, "kind": "say", "speaker": _current_speaker,
			"text": _full_text, "thought": _dict_bool(_current_command, "thought")})
		_line_logged = true
	_save_game()
	_on_line_completed()


func _on_line_completed() -> void:
	if _screen_mode == "boke_round" and not _pending_round_mode.is_empty():
		var mode: String = _pending_round_mode
		_pending_round_mode = ""
		if mode == "qte":
			_start_qte(_current_command)
		else:
			_present_tsukkomi_options(_current_command, false)
		_save_game()
	_publish_qa_state()
	if _skip:
		_skip_step(_line_generation)
	elif _auto:
		_auto_step(_line_generation)


## While typing, the whole line is laid out once and revealed character by character, so the box
## is already at its final height and the text never rewraps.
func _set_visible_text(value: String, complete: bool) -> void:
	_visible_text = value
	_text_complete = complete
	var typing: bool = _full_text.begins_with(value)
	var markup: String = str(_line_plan["rendered"]) if typing and _line_plan.has("rendered") and str(_line_plan.get("plain", "")) == _full_text else (_full_text if typing else value)
	if _text_label.text != markup:
		_text_label.text = markup
	_text_label.visible_characters = value.length() if typing and not complete else -1
	_advance_button.visible = _command_op(_current_command) == "say"  # not the screen mode: lines finish behind 目錄 too


func _set_text_tone(tone: String) -> void:
	_text_tone = tone
	_dialog_panel.set_tone(tone)


## A pov choice is a thought of `pov` (Shinpachi unless the step names someone else): their name plate
## and portrait, the prompt as an inner voice, options in the edition's sheet. A director choice is the
## player stepping out of the story: narration, nobody comes on stage or into focus, the director's sheet
## springs in with a clap.
func _present_choice(command: Dictionary) -> void:
	var director: bool = _dict_string(command, "perspective", "pov") == "director"
	var pov: String = _dict_string(command, "pov", STORY_RUNNER_SCRIPT.DEFAULT_POV)
	_current_command = command.duplicate(true)
	_current_speaker = "" if director else pov
	_full_text = _dict_string(command, "prompt", "接下來發生什麼？" if director else "我該怎麼做……？")
	_current_line_key = _line_key(command, "choice")
	_line_logged = _history_has_key(_current_line_key)
	_line_generation += 1
	_set_skip(false)
	_screen_mode = "choice"
	_clear_hotspots()
	_investigation_continue_button.visible = false
	_boke_controls.visible = false
	_end_box.visible = false
	_refresh_phase3_hud()
	if director:
		_set_name_plate("narrator", false)
		_set_text_tone("body")
	else:
		_set_name_plate(pov, true)
		_focus_speaker(pov, "thinking")
		_set_text_tone("thought")
	_set_visible_text(_full_text, true)
	if not _line_logged:
		_append_history({"key": _current_line_key, "kind": "say", "speaker": "narrator" if director else pov,
			"text": _full_text, "thought": not director})
		_line_logged = true

	_clear_choices()
	_sheet_perspective = "director" if director else "pov"
	_sheet_note = _dict_string(command, "note") if director else ""
	for option_variant: Variant in command.get("options", []):
		if not option_variant is Dictionary:
			continue
		var option: Dictionary = (option_variant as Dictionary).duplicate(true)
		_current_options.append(option)
		_sheet_tones.append(_dict_string(option, "tone"))
	_sheet_prompt = _full_text
	_sheet_timed = false
	_show_choice_sheet()
	if director:
		_choice_sheet.pop_in()
		_effects.play({"op": "se", "id": "director_clap"}, false)  # silent while muted
	call_deferred("_publish_qa_state")


func _on_choice_pressed(option_id: String) -> void:
	if _screen_mode != "choice" or _story_busy:
		return
	var label: String = option_id
	for option: Dictionary in _current_options:
		if _dict_string(option, "id") == option_id:
			label = _dict_string(option, "label", option_id)
	_story_busy = true
	_screen_mode = "busy"
	if not bool(_runner.call("choose", option_id)):
		_show_runtime_error(_runner_string("error_message", "這個選項目前不能選。"))
		return
	_clear_choices()
	_append_history({"key": "choice:%s:%s" % [_current_line_key, option_id], "kind": "choice",
		"text": label})
	_start_drive()


func _present_end(command: Dictionary) -> void:
	_current_command = command.duplicate(true)
	_clear_hotspots()
	_investigation_continue_button.visible = false
	_boke_controls.visible = false
	_current_speaker = "narrator"
	_full_text = _dict_string(command, "text", "本場結束。")
	_current_line_key = _line_key(command, "end")
	_line_generation += 1
	_set_auto(false)
	_set_skip(false)
	_screen_mode = "end"
	_clear_choices()
	_refresh_phase3_hud()
	_set_name_plate("narrator", false)
	_focus_speaker("narrator", "")
	_set_text_tone("accent")
	_set_visible_text(_full_text, true)
	var snapshot: Dictionary = _runner.call("snapshot") as Dictionary
	var game_over: bool = bool(snapshot.get("game_over_active", false))
	_end_box.visible = not game_over
	_game_over_retry_button.visible = game_over
	if game_over:
		_game_over.open(_full_text)
	if not _history_has_key(_current_line_key):
		_append_history({"key": _current_line_key, "kind": "say", "speaker": "narrator", "text": _full_text})
	_publish_qa_state()


func _render_restored_current() -> void:
	_comedy_layer.stop()
	var current: Dictionary = _runner_current()
	while _command_op(current) == "comedy":  # a played overlay never comes back with a save
		_log_comedy(current)
		var position_before: Array = [_runner_string("node_id", ""), int(_runner.get("step_index"))]
		_runner.call("advance")
		if [_runner_string("node_id", ""), int(_runner.get("step_index"))] == position_before:
			_show_runtime_error(_runner_string("error_message", "故事無法繼續。"))
			return
		current = _runner_current()
	match _command_op(current):
		"say":
			_present_say(current, true)
		"choice":
			_present_choice(current)
		"end":
			_present_end(current)
		"result":
			_present_result(current)
		"investigate":
			_present_investigation(current, true)
		"boke_round":
			_present_boke_round(current, true)
		_:
			_start_drive()


## The chapter result (`result` step) over the stage: the numbers, the grade from the glasses left
## and its closing line. The best grade per story goes to progress_path, which unlocks the next
## chapter; 下一章 shows when there is one.
func _present_result(command: Dictionary) -> void:
	_current_command = command.duplicate(true)
	_story_busy = false
	_set_auto(false)
	_set_skip(false)
	_clear_choices()
	_clear_hotspots()
	_end_box.visible = false
	_screen_mode = "result"
	var summary: Dictionary = _runner.call("chapter_result") as Dictionary
	_record_clear(str(summary.get("grade", "C")))
	var speaker: String = str((summary.get("line", {}) as Dictionary).get("speaker", "narrator"))
	_chapter_result.call("show_result", summary, str((_actors.get(speaker, {}) as Dictionary).get("name", "")),
		not _next_chapter().is_empty())
	_chapter_result.visible = true
	_toast.visible = false
	_refresh_phase3_hud()
	_publish_qa_state()


func _on_next_chapter_pressed() -> void:
	var next: Dictionary = _next_chapter()
	if next.is_empty():
		return
	_choose_story(next)
	if _story_ready:
		_on_begin_pressed()
	else:
		_show_title()


## The id progress and chapter select know this story by: its registry id, else its own id.
func _progress_id() -> String:
	var index: int = _story_choice_index()
	if index >= 0:
		return str(_story_choices[index]["id"])
	return str((_runner.call("story_info") as Dictionary).get("id", story_path.get_file()))


func _record_clear(grade: String) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(progress_path)
	var best: String = str(config.get_value("cleared", _progress_id(), ""))
	var grades: Array = STORY_RUNNER_SCRIPT.GRADES
	if best.is_empty() or grades.find(grade) < grades.find(best):
		config.set_value("cleared", _progress_id(), grade)
		config.save(progress_path)


## The best grade of a cleared story, "" when not cleared.
func _cleared_grade(story_id: String) -> String:
	var config: ConfigFile = ConfigFile.new()
	return str(config.get_value("cleared", story_id, "")) if config.load(progress_path) == OK else ""


## The chapter after the current one in the registry, {} when this is not a chapter or the last.
func _next_chapter() -> Dictionary:
	var index: int = _story_choice_index()
	if index < 0 or str(_story_choices[index].get("kind", "")) != "chapter":
		return {}
	for later: int in range(index + 1, _story_choices.size()):
		if str(_story_choices[later].get("kind", "")) == "chapter":
			return _story_choices[later]
	return {}


## A chapter opens once the chapter before it is cleared; samples are always open.
func _story_unlocked(index: int) -> bool:
	if str(_story_choices[index].get("kind", "")) != "chapter":
		return true
	for earlier: int in range(index - 1, -1, -1):
		if str(_story_choices[earlier].get("kind", "")) == "chapter":
			return not _cleared_grade(str(_story_choices[earlier]["id"])).is_empty()
	return true


## Switches the title to another story (and remembers it for the next run).
func _choose_story(choice: Dictionary) -> void:
	story_path = choice["path"]
	save_path = choice["save"]
	var config: ConfigFile = ConfigFile.new()
	config.set_value("story", "id", choice["id"])
	config.save(STORY_CHOICE_PATH)
	_story_error = ""
	_load_story()
	_dialog_panel.set_chapter(_chapter_title())
	_refresh_story_switch()
	_refresh_gameplay_ui()


func _show_runtime_error(message: String) -> void:
	_clear_choices()  # the message goes in the dialogue box, which the choice sheet would keep hidden
	_story_busy = false
	_story_error = message
	_screen_mode = "story"
	_current_command = {}
	_set_name_plate("narrator", false)
	_set_text_tone("danger")
	_set_visible_text(message, false)
	_publish_qa_state()


## Narrator lines show 旁白; a combined speaker ("gintoki+kagura") lists both names.
func _set_name_plate(speaker: String, thought: bool) -> void:
	_plate_speaker = speaker
	_plate_thought = thought
	var names: PackedStringArray = []
	for actor_id: String in speaker.split("+"):
		if _actors.has(actor_id):
			names.append(str((_actors[actor_id] as Dictionary)["name"]))
	_dialog_panel.set_speaker("・".join(names) + ("・心聲" if thought and not names.is_empty() else ""))


## Whoever speaks (both, for a line said together) comes on stage at their slot and to the front;
## everyone already on stage stays behind, dimmed. Narration leaves the stage as it is, all lit.
func _focus_speaker(speaker: String, expression: String) -> void:
	var speaking: PackedStringArray = speaker.split("+", false)
	for actor_id: String in _sprites.keys():
		var sprite: Control = _sprites[actor_id]
		var talking: bool = speaking.has(actor_id)
		sprite.modulate = Color.WHITE if talking or speaker == "narrator" else Color(0.5, 0.5, 0.56)
		if talking:
			var entering: bool = not sprite.visible
			if not sprite.visible:
				_layout_sprite(actor_id)
				sprite.visible = true
			_char_layer.move_child(sprite, -1)
			if not expression.is_empty():
				sprite.call("set_expression", expression)
			_motion.character(sprite, "enter" if entering else "speak", _skip)


func _clear_stage() -> void:
	if _motion != null:
		_motion.cancel_characters()
	for sprite: Control in _sprites.values():
		sprite.visible = false


func _sprite(actor_id: String) -> Control:
	return _sprites.get(actor_id, _sprites.get("shinpachi")) as Control


func _clear_choices() -> void:
	_current_options.clear()
	_choice_buttons.clear()
	_sheet_perspective = "pov"
	_sheet_note = ""
	_sheet_tones = PackedStringArray()
	if _choice_sheet != null:
		_choice_sheet.clear_options()
		_refresh_reading_ui()


# ---------------------------------------------------------------- 手勢

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _screen_mode == "case_file":
		get_viewport().set_input_as_handled()
		_close_case_file()
		return
	if event.is_action_pressed("ui_cancel") and _screen_mode in ["save_slots", "load_slots", "slot_confirm"]:
		get_viewport().set_input_as_handled()
		if _screen_mode == "slot_confirm":
			_cancel_slot_confirmation()
		else:
			_close_slot_picker()
		return
	if event.is_action_pressed("ui_accept") and (_screen_mode == "story" or _comedy_layer.is_active()):
		get_viewport().set_input_as_handled()
		_on_screen_tap()


func _on_catcher_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		_tap_catcher.accept_event()
		if button.pressed:
			_gesture_active = true
			_gesture_in_comedy = _comedy_layer.is_active()
			_gesture_moved = false
			_gesture_long = false
			_gesture_start = button.global_position
			_pan_start = _pan
			_gesture_token += 1
			_wait_long_press(_gesture_token)
			return
		if not _gesture_active:
			return
		_gesture_active = false
		_gesture_token += 1
		if _gesture_long:
			return
		if _gesture_in_comedy or _comedy_layer.is_active():
			# A press that began over the overlay ends it (or, if it ended meanwhile, does nothing):
			# the release must not reach the line that follows.
			_gesture_in_comedy = false
			_comedy_layer.fast_forward()
			return
		if _ui_hidden:
			_set_ui_hidden(false)  # 隱藏 UI 時，點一下只負責恢復，不推進劇情。
			return
		var delta: Vector2 = button.global_position - _gesture_start
		if _gesture_moved:
			if -delta.y > SWIPE_DISTANCE and absf(delta.x) < -delta.y:
				_open_log()
			return
		if _placard_open() and _placard_hit_rect().has_point(button.global_position):
			_on_placard_pressed()
			return
		if _screen_mode == "investigate":
			_tap_investigation(button.global_position)
		else:
			_on_screen_tap()
	elif event is InputEventMouseMotion and _gesture_active:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if not _gesture_moved and motion.global_position.distance_to(_gesture_start) > TAP_SLOP:
			_gesture_moved = true
			_gesture_token += 1
		if _gesture_moved and _screen_mode == "investigate":
			_set_pan(_pan_start + motion.global_position.x - _gesture_start.x)  # drag the picture sideways


func _wait_long_press(token: int) -> void:
	await get_tree().create_timer(LONG_PRESS_SEC).timeout
	if token != _gesture_token or not _gesture_active or _gesture_moved:
		return
	_gesture_long = true
	if _screen_mode in ["story", "choice", "end"]:
		_set_ui_hidden(not _ui_hidden)


func _on_screen_tap() -> void:
	if _comedy_layer.is_active():
		_comedy_layer.fast_forward()  # this tap only ends the overlay; the next line is not advanced
		return
	if _skip:
		_set_skip(false)
		return
	if _screen_mode == "boke_round" and not _text_complete:
		_complete_current_line()
		return
	if _screen_mode != "story" or _story_busy or _current_command.is_empty():
		return
	if _command_op(_current_command) != "say":
		return
	if not _text_complete:
		_complete_current_line()
	else:
		_advance_current_line()


func _set_ui_hidden(value: bool) -> void:
	_ui_hidden = value
	_refresh_reading_ui()
	_end_box.visible = not value and _screen_mode == "end"
	_phase3_hud.visible = _phase3_enabled and not value and _screen_mode != "title"
	if not value and _auto:
		_auto_step(_line_generation)
	_publish_qa_state()


func _set_auto(value: bool) -> void:
	if value and _screen_mode in ["save_slots", "load_slots", "slot_confirm"]:
		return
	_auto = value
	if value:
		_skip = false
	_update_toggle_styles()
	if value and _text_complete:
		_auto_step(_line_generation)
	_publish_qa_state()


func _set_skip(value: bool) -> void:
	if value and _screen_mode in ["save_slots", "load_slots", "slot_confirm"]:
		return
	_skip = value
	if value:
		_auto = false
		_motion.reset()
		_effects.stop_transients()
		_comedy_layer.fast_forward()  # skipping does not wait for an overlay
	_update_toggle_styles()
	if value and _screen_mode == "story":
		if _text_complete:
			_skip_step(_line_generation)
		else:
			_complete_current_line()
	_publish_qa_state()


func _auto_step(token: int) -> void:
	if _screen_mode != "story" or not _text_complete:
		return
	await get_tree().create_timer((AUTO_DELAY_SEC + DialogueText.readable_count(_full_text) * AUTO_PER_CHAR_SEC)
		* SETTINGS_SCRIPT.AUTO_FACTORS[int(_settings["auto_speed"])]).timeout
	if _auto and token == _line_generation and _screen_mode == "story" and not _ui_hidden and not _story_busy:
		_advance_current_line()


func _skip_step(token: int) -> void:
	await get_tree().create_timer(SKIP_DELAY_SEC).timeout
	if _skip and token == _line_generation and _screen_mode == "story" and not _story_busy:
		_advance_current_line()


func _update_toggle_styles() -> void:
	if _dialog_panel != null:
		_dialog_panel.set_auto(_auto)
		_dialog_panel.set_skip(_skip)


func _process(delta: float) -> void:
	if _dialog_panel == null:
		return
	if _screen_mode == "tsukkomi" and not _story_busy:
		_boke_time_remaining = maxf(0.0, _boke_time_remaining - delta)
		_choice_sheet.set_timer(_boke_time_remaining, float(_current_command.get("timer_seconds", DEFAULT_BOKE_TIMER_SECONDS)), false)
		var displayed_second: int = ceili(_boke_time_remaining)
		if displayed_second != _last_boke_display_second:
			_last_boke_display_second = displayed_second
			_refresh_phase3_hud()
			_publish_qa_state()
		if _boke_time_remaining <= 0.0:
			_on_boke_timeout()
			return
	if _qa_enabled:
		_qa_elapsed += delta
		if _qa_elapsed >= QA_PUBLISH_SEC:
			_qa_elapsed = 0.0
			_publish_qa_state()


# ---------------------------------------------------------------- 選單、紀錄、提示

func _open_menu() -> void:
	if _screen_mode not in ["story", "choice", "end", "investigate", "boke_round", "tsukkomi"]:
		return
	_mode_before_overlay = _screen_mode
	_screen_mode = "menu"
	_refresh_menu_rows()  # after the switch: the HUD and the sheet read the countdown as paused
	_fit_menu()
	_menu_overlay.visible = true
	_menu_overlay.pop_in().finished.connect(_publish_qa_state)
	_publish_qa_state()


func _start_skip_from_menu() -> void:
	_close_menu()
	_set_skip(true)
	if _skip:
		_show_toast("略讀中・點畫面停止")


func _close_menu() -> void:
	if not _menu_overlay.visible:
		return
	_menu_overlay.visible = false
	_screen_mode = _mode_before_overlay
	_refresh_phase3_hud()
	if _auto:
		_auto_step(_line_generation)
	_publish_qa_state()


func _open_log() -> void:
	if _screen_mode == "menu":
		_close_menu()
	if _screen_mode not in ["story", "choice", "end", "investigate", "boke_round", "tsukkomi"]:
		return
	_mode_before_overlay = _screen_mode
	_screen_mode = "log"
	for old: Node in _log_entries.get_children():
		_log_entries.remove_child(old)
		old.queue_free()
	for entry: Dictionary in _history:
		var row: Control = preload("res://scenes/ui/log_entry.tscn").instantiate()
		_log_entries.add_child(row)
		var heading: Label = row.get_node("%Speaker")
		var text: Label = row.get_node("%Text")
		text.text = _dict_string(entry,"text")
		if _dict_string(entry,"kind") == "choice":
			heading.text = "▶ 選擇"
		else:
			var names: PackedStringArray = []
			for actor in _dict_string(entry,"speaker","narrator").split("+",false):
				names.append(str((_actors.get(actor,{}) as Dictionary).get("name","旁白")))
			heading.text = "、".join(names) + ("・心聲" if _dict_bool(entry,"thought") else "")
		_apply_ui_style_recursive(row)
	_log_overlay.visible = true
	_refresh_phase3_hud()
	_scroll_log_to_bottom()
	_publish_qa_state()


func _scroll_log_to_bottom() -> void:
	await get_tree().process_frame
	_log_scroll.scroll_vertical = int(_log_scroll.get_v_scroll_bar().max_value)


func _close_log() -> void:
	if not _log_overlay.visible:
		return
	_log_overlay.visible = false
	_screen_mode = _mode_before_overlay
	_refresh_phase3_hud()
	if _auto:
		_auto_step(_line_generation)
	_publish_qa_state()


func _close_overlays() -> void:
	if _game_over != null:
		_game_over.visible = false
	if _chapter_result != null:
		_chapter_result.visible = false
	if _chapter_select != null:
		_chapter_select.visible = false
		_settings_panel.visible = false
	if _menu_overlay != null:
		_menu_overlay.visible = false
		_log_overlay.visible = false
	if _case_file_panel != null:
		_case_file_panel.visible = false
	if _slot_overlay != null:
		_slot_overlay.visible = false
		_slot_confirmation_overlay.visible = false
	_slot_mode = ""
	_slot_return_screen = ""
	_slot_pending_index = -1


func _load_from_menu() -> void:
	_open_slot_picker("load")


func _open_slot_picker(mode: String) -> void:
	if mode not in ["save", "load"]:
		return
	var return_screen: String = _screen_mode
	if return_screen == "menu":
		_slot_return_screen = "menu"
		return_screen = _mode_before_overlay
		_menu_overlay.visible = false
	elif return_screen not in ["title", "story", "choice", "end", "investigate", "boke_round", "tsukkomi"]:
		return
	else:
		_slot_return_screen = return_screen
	if mode == "save" and return_screen not in ["story", "choice", "end", "investigate", "boke_round", "tsukkomi"]:
		return
	_mode_before_overlay = return_screen
	_slot_typewriter_paused = return_screen == "story" and not _text_complete
	if _slot_typewriter_paused:
		_line_generation += 1
	_slot_mode = mode
	_slot_page = 0
	_slot_pending_index = -1
	_slot_confirmation_overlay.visible = false
	_slot_title.text = "選擇存檔位" if mode == "save" else "選擇讀取存檔"
	_screen_mode = "save_slots" if mode == "save" else "load_slots"
	_refresh_phase3_hud()
	await get_tree().process_frame
	_slot_preview_png = _capture_preview_png()
	_slot_overlay.visible = true
	_refresh_slot_page()
	_publish_qa_state()


func _change_slot_page(delta: int) -> void:
	_slot_page = clampi(_slot_page + delta, 0, SAVE_SLOTS_SCRIPT.PAGE_COUNT - 1)
	_refresh_slot_page()
	_publish_qa_state()


func _refresh_slot_page() -> void:
	if _slot_panel == null:
		return
	_slot_visible_entries.clear()
	_slot_page_label.text = "%d / %d" % [_slot_page + 1, SAVE_SLOTS_SCRIPT.PAGE_COUNT]
	_slot_prev_button.disabled = _slot_page <= 0
	_slot_next_button.disabled = _slot_page >= SAVE_SLOTS_SCRIPT.PAGE_COUNT - 1
	var can_save: bool = _saveable_current_state()
	var autosave: Dictionary = _read_save_payload(save_path)
	_slot_auto_button.visible = _slot_mode == "load" and not autosave.is_empty()
	_slot_auto_button.disabled = autosave.is_empty()
	for local_index: int in range(_slot_card_buttons.size()):
		var slot_index: int = _slot_page * SAVE_SLOTS_SCRIPT.PAGE_SIZE + local_index + 1
		var path: String = SAVE_SLOTS_SCRIPT.manual_path(save_path, slot_index)
		var occupied: bool = _slot_file_exists(path)
		var payload: Dictionary = _read_save_payload(path)
		var valid: bool = not payload.is_empty()
		var chapter: String = str(payload.get("chapter", payload.get("node_id", ""))) if valid else ""
		var saved_at: String = _payload_saved_time(payload, path) if valid else ""
		_slot_visible_entries.append({"index": slot_index, "occupied": occupied, "valid": valid,
			"chapter": chapter, "saved_at": saved_at})
		var button: Button = _slot_card_buttons[local_index]
		var number_label: Label = _slot_card_numbers[local_index]
		var title_label: Label = _slot_card_titles[local_index]
		var time_label: Label = _slot_card_times[local_index]
		var preview: TextureRect = _slot_card_previews[local_index]
		button.disabled = _slot_mode == "load" and not valid or _slot_mode == "save" and not can_save
		number_label.text = "%02d" % slot_index
		if valid:
			chapter = str(payload.get("chapter", payload.get("node_id", "存檔")))
			var node_id: String = str(payload.get("node_id", ""))
			title_label.text = chapter if node_id.is_empty() or node_id == chapter else "%s\n%s" % [chapter, node_id]
			time_label.text = saved_at
			preview.texture = _decode_preview(str(payload.get("preview_png", "")))
		else:
			preview.texture = null
			time_label.text = ""
			if occupied:
				title_label.text = "資料無效或不相容" if _slot_mode == "load" else "無效資料・確認後覆寫"
			else:
				title_label.text = "空白存檔位" if _slot_mode == "save" else "尚無存檔"
		var card_role: String = "slot_card" if valid else ("slot_card_invalid" if occupied else "slot_card_empty")
		_set_button_style(button, card_role)
		button.visible = true


func _on_slot_card_pressed(local_index: int) -> void:
	if local_index < 0 or local_index >= SAVE_SLOTS_SCRIPT.PAGE_SIZE:
		return
	var slot_index: int = _slot_page * SAVE_SLOTS_SCRIPT.PAGE_SIZE + local_index + 1
	var path: String = SAVE_SLOTS_SCRIPT.manual_path(save_path, slot_index)
	if _slot_mode == "save":
		if not _saveable_current_state():
			return
		if _slot_file_exists(path):
			_slot_pending_index = slot_index
			_slot_confirmation_label.text = "覆寫第 %02d 格的存檔？" % slot_index
			_slot_confirmation_overlay.visible = true
			_screen_mode = "slot_confirm"
			_publish_qa_state()
		else:
			_write_manual_slot(slot_index)
		return
	if _slot_mode == "load":
		var payload: Dictionary = _read_save_payload(path)
		if not payload.is_empty():
			_load_payload_from_picker(payload, "已讀取第 %02d 格" % slot_index)


func _confirm_slot_overwrite() -> void:
	if _slot_pending_index < 1:
		return
	var selected_index: int = _slot_pending_index
	_slot_confirmation_overlay.visible = false
	_slot_pending_index = -1
	_write_manual_slot(selected_index)


func _cancel_slot_confirmation() -> void:
	if not _slot_confirmation_overlay.visible:
		return
	_slot_confirmation_overlay.visible = false
	_slot_pending_index = -1
	_screen_mode = "save_slots"
	_publish_qa_state()


func _write_manual_slot(slot_index: int) -> void:
	var path: String = SAVE_SLOTS_SCRIPT.manual_path(save_path, slot_index)
	var payload: Dictionary = _build_save_payload(_slot_preview_png)
	if payload.is_empty() or not bool(SAVE_SLOTS_SCRIPT.write_atomic(path, payload, _validate_save_payload)):
		_show_toast("存檔失敗，原有資料已保留")
		_refresh_slot_page()
		_publish_qa_state()
		return
	_close_slot_picker()
	_show_toast("已存到第 %02d 格" % slot_index)


func _load_autosave_from_picker() -> void:
	var payload: Dictionary = _read_save_payload(save_path)
	if not payload.is_empty():
		_load_payload_from_picker(payload, "已讀取自動存檔")


func _load_payload_from_picker(payload: Dictionary, message: String) -> void:
	if not _validate_save_payload(payload):
		return
	_cancel_generation()
	_set_auto(false)
	_set_skip(false)
	if not _apply_save_payload(payload):
		return
	_close_slot_picker(false)
	_set_ui_hidden(false)
	_show_story_screen()
	_render_restored_current()
	_show_toast(message if _save_game() else "已讀檔，但續讀存檔更新失敗")


func _close_slot_picker(resume_story: bool = true) -> void:
	if _slot_overlay == null or not _slot_overlay.visible:
		return
	_slot_overlay.visible = false
	_slot_confirmation_overlay.visible = false
	_slot_pending_index = -1
	_slot_mode = ""
	var return_to_menu: bool = resume_story and _slot_return_screen == "menu"
	_screen_mode = "menu" if return_to_menu else _mode_before_overlay
	_menu_overlay.visible = return_to_menu
	_refresh_phase3_hud()
	if resume_story and _mode_before_overlay == "story":
		if _slot_typewriter_paused and not _text_complete:
			_typewriter(_line_generation)
		elif not return_to_menu and _skip:
			_skip_step(_line_generation)
		elif not return_to_menu and _auto:
			_auto_step(_line_generation)
	_slot_typewriter_paused = false
	_slot_return_screen = ""
	_publish_qa_state()


func _show_toast(message: String) -> void:
	_toast_token += 1
	var token: int = _toast_token
	_toast.text = message
	var toast_size: Vector2 = Vector2(_font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x + 96.0, 96.0)
	_toast.size = toast_size
	# 在畫面上方正中冒出，不擋對話框。
	_toast.position = Vector2((_game.size.x - toast_size.x) * 0.5, EDGE + _safe_top + 190.0)
	_toast.visible = true
	_toast.modulate.a = 1.0
	_publish_qa_state()
	await get_tree().create_timer(TOAST_SEC).timeout
	if token == _toast_token:
		_toast.visible = false
		_publish_qa_state()


func _toggle_mute() -> void:
	_audio_muted = not _audio_muted
	_apply_audio_levels()
	_effects.set_muted(_audio_muted)
	_refresh_menu_rows()
	_publish_qa_state()


func _start_audio_after_user_gesture() -> void:
	_play_sound("paper")
	var ambient: AudioStreamPlayer = _audio_players.get("ambient")
	if ambient != null and ambient.stream != null and not _audio_muted and not ambient.playing:
		ambient.play()


func _play_sound(audio_id: String) -> void:
	var player: AudioStreamPlayer = _audio_players.get(audio_id)
	if player != null and player.stream != null and not _audio_muted:
		player.play()


func _append_history(entry: Dictionary) -> void:
	if not _history_has_key(_dict_string(entry, "key")):
		_history.append(entry.duplicate(true))


func _history_has_key(key: String) -> bool:
	for entry: Dictionary in _history:
		if _dict_string(entry, "key") == key:
			return true
	return false


func _refresh_phase3_hud() -> void:
	if _phase3_hud == null:
		return
	_refresh_placard()
	_phase3_hud.visible = _phase3_enabled and _screen_mode != "title" and not _ui_hidden
	if not _phase3_enabled or _runner == null:
		return
	var snapshot: Dictionary = _runner.call("snapshot") as Dictionary
	var gameplay: Dictionary = snapshot.get("gameplay", {}) as Dictionary
	var current: Dictionary = _runner_current()
	_phase3_hud.show_stats(int(gameplay.get("glasses", 0)), int(gameplay.get("max_glasses", 5)),
		int(gameplay.get("power", 0)), int(gameplay.get("max_power", 100)),
		int(current.get("combo", 0)) if RoundView.automatic(current) else 0)
	var items: Array = snapshot.get("items", []) as Array
	var clues: Array[Dictionary] = []
	var catalog_items: Dictionary = _catalog.get("items", {}) as Dictionary
	for item_id: Variant in items:
		var info: Dictionary = catalog_items.get(str(item_id), {}) as Dictionary
		clues.append({"name": str(info.get("name", item_id)), "picture": _catalog_picture(info)})
	_phase3_hud.show_clues(clues)
	if _menu_items.has("material"):
		(_menu_items["material"] as Button).text = "吐槽素材（%d）" % items.size()
	if _command_op(current) == "boke_round" and _effective_boke_ui_mode() == "tsukkomi":
		var prefix: String = "倒數" if _screen_mode == "tsukkomi" else "暫停"
		_phase3_timer_label.text = "%s %02d 秒" % [prefix, ceili(_boke_time_remaining)]
		_choice_sheet.set_timer(_boke_time_remaining, float(current.get("timer_seconds", DEFAULT_BOKE_TIMER_SECONDS)),
			_screen_mode != "tsukkomi")
	else:
		_phase3_timer_label.text = ""


## Materials and profiles only exist in stories with investigation or tsukkomi rounds.
func _refresh_gameplay_ui() -> void:
	if _menu_overlay != null:
		_refresh_menu_rows()


func _build_case_file() -> void:
	_case_file_panel = CASE_FILE_SCENE.instantiate() as Panel
	_popup_layer.add_child(_case_file_panel)
	_case_file_panel.call("set_style", _ui_style_id)
	_case_file_panel.connect("closed", _close_case_file)
	_case_file_panel.connect("material_used", _on_case_file_material_used)


## A catalog entry's picture (`path`), or null when it has none yet (screens draw a placeholder).
func _catalog_picture(info: Dictionary) -> Texture2D:
	var path: String = str(info.get("path", ""))
	return load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else null


func _open_case_file(tab: String) -> void:
	if not _phase3_enabled or _runner == null:
		return
	if _screen_mode == "menu":
		_close_menu()
	if _screen_mode not in ["story", "choice", "end", "investigate", "boke_round", "tsukkomi"]:
		return
	_mode_before_overlay = _screen_mode
	_screen_mode = "case_file"
	var pictures: Dictionary = {}
	for collection: String in ["items", "characters"]:
		var entries: Dictionary = _catalog.get(collection, {}) as Dictionary
		for entry_id: String in entries.keys():
			var path: String = str((entries[entry_id] as Dictionary).get("path", ""))
			if not path.is_empty():
				pictures[entry_id] = path
	# 限時選詞中，能當根據的素材可以直接「拿來吐槽」。
	var usable: Dictionary = {}
	if _mode_before_overlay == "tsukkomi":
		for option: Dictionary in RoundView.options(_runner_current()):  # Phase 3 and v2 rounds alike
			if option.has("require"):
				usable[str(option["require"])] = str(option.get("id", ""))
	_case_file_panel.call("set_style", _ui_style_id)
	_case_file_panel.call("open", _runner.call("case_file"), tab, pictures, usable)
	_refresh_phase3_hud()
	_publish_qa_state()


func _close_case_file() -> void:
	if not _case_file_panel.visible:
		return
	_case_file_panel.visible = false
	_screen_mode = _mode_before_overlay
	_refresh_phase3_hud()
	_publish_qa_state()


func _on_case_file_material_used(option_id: String) -> void:
	_close_case_file()
	if _screen_mode == "tsukkomi":
		_on_boke_option_pressed(option_id)

# ---------------------------------------------------------------- 存讀檔

func _rollback_line() -> bool:
	var mode: String = _mode_before_overlay if _screen_mode == "menu" else _screen_mode
	if mode != "story" or not _rollback.available():
		return false
	var payload: Dictionary = _rollback.take()
	_rolling_back = true
	var restored: bool = _apply_save_payload(payload)
	_rolling_back = false
	if not restored:
		return false
	_set_auto(false)
	_set_skip(false)
	_close_overlays()
	_show_story_screen()
	_render_restored_current()
	_save_game()
	_show_toast("已回到上一句")
	return true


func _quick_save() -> bool:
	if not _saveable_current_state():
		return false
	var payload: Dictionary = _build_save_payload("")
	var written: bool = SAVE_SLOTS_SCRIPT.write_atomic(SAVE_SLOTS_SCRIPT.quick_path(save_path), payload, _validate_save_payload)
	_show_toast("已快速存檔" if written else "快速存檔失敗，原有資料已保留")
	_refresh_menu_rows()
	return written


func _quick_load() -> bool:
	var payload: Dictionary = _read_save_payload(SAVE_SLOTS_SCRIPT.quick_path(save_path))
	if payload.is_empty() or not _apply_save_payload(payload):
		_show_toast("尚無可讀取的快速存檔")
		return false
	_set_auto(false)
	_set_skip(false)
	_close_overlays()
	_set_ui_hidden(false)
	_show_story_screen()
	_render_restored_current()
	_save_game()
	_show_toast("已快速讀檔")
	return true

func _save_game() -> bool:
	if not _saveable_current_state():
		return false
	var payload: Dictionary = _build_save_payload("")
	return not payload.is_empty() and bool(SAVE_SLOTS_SCRIPT.write_atomic(save_path, payload, _validate_save_payload))


func _saveable_current_state() -> bool:
	return _runner != null and not _story_busy and _command_op(_runner_current()) in [
		"say", "choice", "end", "result", "investigate", "boke_round"]


func _build_save_payload(preview_png: String) -> Dictionary:
	var runner_snapshot: Dictionary = _runner.call("snapshot") as Dictionary
	if runner_snapshot.is_empty():
		return {}
	var sprites: Dictionary = {}
	for actor_id: String in _sprites.keys():
		var sprite: Control = _sprites[actor_id] as Control
		sprites[actor_id] = {"visible": sprite.visible, "expression": str(sprite.get("expression")),
			"position": str(_actor_slots.get(actor_id, "center"))}
	var current: Dictionary = _runner_current()
	var payload: Dictionary = {
		"schema": SAVE_SCHEMA,
		"version": SAVE_SCHEMA,
		"story_id": str(runner_snapshot.get("story_id", "")),
		"runner": runner_snapshot,
		"background": _current_bg_id,
		"sprites": sprites,
		"history": _history.duplicate(true),
		"chapter": str(current.get("node_title", current.get("node_id", ""))),
		"node_id": str(runner_snapshot.get("node_id", "")),
		"saved_at": Time.get_datetime_string_from_system(false, false),
		"preview_png": preview_png,
		"bgm": _effects.current_bgm,
		"round_stages": _round_stages.duplicate(true),
		"investigation_pans": _investigation_pans.duplicate(true),
		"investigation_home_casts": _investigation_home_casts.duplicate(true),
	}
	if _command_op(current) == "boke_round":
		var boke_ui_mode: String = _effective_boke_ui_mode()
		if boke_ui_mode not in ["boke_round", "tsukkomi"]:
			boke_ui_mode = "boke_round"  # a QTE restarts when its line comes back
		payload["boke_ui_screen"] = boke_ui_mode
		if boke_ui_mode == "tsukkomi":
			payload["boke_timer_remaining"] = _boke_time_remaining
	return payload


func _effective_boke_ui_mode() -> String:
	if _screen_mode in ["menu", "log", "save_slots", "load_slots", "slot_confirm"]:
		return _mode_before_overlay
	return _screen_mode


func _read_save_payload(path: String = "") -> Dictionary:
	var target_path: String = save_path if path.is_empty() else path
	for candidate_path: String in [target_path, target_path + ".bak", target_path + ".bak.old",
		target_path + ".old", target_path + ".tmp"]:
		var payload: Dictionary = _read_raw_save_payload(candidate_path)
		if not payload.is_empty() and _validate_save_payload(payload):
			return payload
	return {}


func _read_raw_save_payload(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = file.get_var(false)
	file.close()
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}


func _valid_saved_cast(cast: Variant) -> bool:
	if not cast is Dictionary:
		return false
	for actor_id: String in _actors:
		var pose: Variant = cast.get(actor_id)
		if not pose is Dictionary or not pose.get("visible") is bool or not _slot_markers.has(str(pose.get("position", ""))) or typeof(pose.get("expression", "")) != TYPE_STRING:
			return false
	return true


func _validate_save_payload(payload: Dictionary) -> bool:
	# Schema 3 saves written before background/position/thumbnail metadata are
	# migrated by supplying the same defaults the scene uses for a new game.
	var schema: int = int(payload.get("schema", payload.get("version", -1)))
	var version: int = int(payload.get("version", schema))
	if schema != SAVE_SCHEMA or version > SAVE_SCHEMA or version < 1:
		return false
	var runner_snapshot: Variant = payload.get("runner")
	var sprites: Variant = payload.get("sprites")
	var history: Variant = payload.get("history")
	if not runner_snapshot is Dictionary or not sprites is Dictionary or not history is Array:
		return false
	if _runner == null:
		return false
	var current_snapshot: Dictionary = _runner.call("snapshot") as Dictionary
	var story_id: String = str(current_snapshot.get("story_id", ""))
	if str(payload.get("story_id", str((runner_snapshot as Dictionary).get("story_id", "")))) != story_id:
		return false
	if str((runner_snapshot as Dictionary).get("story_id", "")) != story_id:
		return false
	var background_id: String = str(payload.get("background", _default_background_id()))
	if not _backgrounds.has(background_id):
		return false
	for actor_id: String in _actors.keys():
		var state: Variant = (sprites as Dictionary).get(actor_id)
		if not state is Dictionary or not (state as Dictionary).get("visible") is bool:
			return false
		var default_position: String = str((_actors[actor_id] as Dictionary).get("slot", "center"))
		if not _slot_markers.has(str((state as Dictionary).get("position", default_position))):
			return false
		if typeof((state as Dictionary).get("expression", "neutral")) != TYPE_STRING:
			return false
	for entry: Variant in history as Array:
		if not entry is Dictionary:
			return false
	if payload.has("saved_at") and typeof(payload["saved_at"]) != TYPE_STRING:
		return false
	if payload.has("preview_png") and typeof(payload["preview_png"]) != TYPE_STRING:
		return false
	if payload.has("bgm") and typeof(payload["bgm"]) != TYPE_STRING:
		return false
	if payload.has("boke_timer_remaining"):
		var remaining: Variant = payload["boke_timer_remaining"]
		if (typeof(remaining) != TYPE_INT and typeof(remaining) != TYPE_FLOAT) or float(remaining) < 0.0:
			return false
	if payload.has("boke_ui_screen"):
		if typeof(payload["boke_ui_screen"]) != TYPE_STRING or str(payload["boke_ui_screen"]) not in ["boke_round", "tsukkomi"]:
			return false
	# 先用全新的 runner 驗證，成功才動目前的遊戲狀態。
	for key: String in ["round_stages", "investigation_pans", "investigation_home_casts"]:
		if not payload.get(key, {}) is Dictionary:
			return false
	for pan: Variant in (payload.get("investigation_pans", {}) as Dictionary).values():
		if typeof(pan) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(pan)):
			return false
	for stage: Variant in (payload.get("round_stages", {}) as Dictionary).values():
		if not stage is Dictionary or not _backgrounds.has(str(stage.get("background", ""))) or typeof(stage.get("bgm", "")) != TYPE_STRING or not _valid_saved_cast(stage.get("sprites")):
			return false
	for cast: Variant in (payload.get("investigation_home_casts", {}) as Dictionary).values():
		if not _valid_saved_cast(cast):
			return false
	var probe: RefCounted = STORY_RUNNER_SCRIPT.new() as RefCounted
	if not bool(probe.call("load_story", story_path)) or not bool(probe.call("restore", runner_snapshot)):
		return false
	var probe_current: Dictionary = probe.call("current") as Dictionary
	var probe_op: String = _command_op(probe_current)
	if payload.has("boke_ui_screen") or payload.has("boke_timer_remaining"):
		if probe_op != "boke_round":
			return false
		var saved_boke_ui_mode: String = str(payload.get("boke_ui_screen",
			"tsukkomi" if payload.has("boke_timer_remaining") else "boke_round"))
		if payload.has("boke_timer_remaining") and saved_boke_ui_mode != "tsukkomi":
			return false
	if payload.has("boke_timer_remaining"):
		var max_remaining: float = float(probe_current.get("timer_seconds", DEFAULT_BOKE_TIMER_SECONDS))
		if float(payload["boke_timer_remaining"]) > max_remaining:
			return false
	return true


func _has_valid_save() -> bool:
	return not _read_save_payload().is_empty()


func _apply_save_payload(payload: Dictionary) -> bool:
	if not _validate_save_payload(payload) or not bool(_runner.call("restore", payload["runner"])):
		return false
	_cancel_generation()
	if not _rolling_back:
		_rollback.clear()
	var restored_current: Dictionary = _runner_current()
	if _command_op(restored_current) == "boke_round":
		_restored_boke_ui_mode = str(payload.get("boke_ui_screen",
			"tsukkomi" if payload.has("boke_timer_remaining") else "boke_round"))
		if _restored_boke_ui_mode == "tsukkomi":
			_restored_boke_timer_remaining = float(payload.get("boke_timer_remaining",
				restored_current.get("timer_seconds", DEFAULT_BOKE_TIMER_SECONDS)))
		else:
			_restored_boke_timer_remaining = -1.0
		_boke_timer_round_id = ""
		_boke_time_remaining = maxf(0.0, _restored_boke_timer_remaining)
	else:
		_restored_boke_timer_remaining = -1.0
		_restored_boke_ui_mode = ""
		_boke_timer_round_id = ""
		_boke_time_remaining = 0.0
	_apply_background(str(payload.get("background", _default_background_id())))
	var sprites: Dictionary = payload["sprites"]
	for actor_id: String in _sprites.keys():
		var state: Dictionary = sprites.get(actor_id, {"visible": false}) as Dictionary
		var sprite: Control = _sprites[actor_id]
		var default_position: String = str((_actors[actor_id] as Dictionary).get("slot", "center"))
		_actor_slots[actor_id] = str(state.get("position", default_position))
		sprite.visible = bool(state.get("visible", false))
		sprite.call("set_expression", str(state.get("expression", "neutral")))
		_layout_sprite(actor_id)
	_previous_power = int((_runner.get("gameplay") as Dictionary).get("power", 0))
	_round_stages = (payload.get("round_stages",{}) as Dictionary).duplicate(true)
	_investigation_pans = (payload.get("investigation_pans",{}) as Dictionary).duplicate(true)
	_investigation_home_casts = (payload.get("investigation_home_casts",{}) as Dictionary).duplicate(true)
	_history.clear()
	for entry: Variant in payload["history"]:
		_history.append((entry as Dictionary).duplicate(true))
	_effects.play_bgm(str(payload.get("bgm", "")))  # saves before music existed have none
	return true


func _delete_save() -> void:
	for path: String in [save_path, save_path + ".bak", save_path + ".bak.old", save_path + ".old",
		save_path + ".tmp", save_path + ".bak.tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _cancel_generation() -> void:
	_pending_round_mode = ""
	_generation += 1
	_line_generation += 1
	_story_busy = false
	_comedy_layer.stop()
	if _motion != null:
		_motion.reset()
	if _effects != null:
		_effects.stop_transients()


func _capture_preview_png() -> String:
	if DisplayServer.get_name() == "headless":
		return ""
	var viewport_texture: ViewportTexture = get_viewport().get_texture()
	if viewport_texture == null:
		return ""
	var image: Image = viewport_texture.get_image()
	if image == null or image.is_empty():
		return ""
	image.resize(135, 240, Image.INTERPOLATE_LANCZOS)
	var png: PackedByteArray = image.save_png_to_buffer()
	return Marshalls.raw_to_base64(png) if not png.is_empty() else ""


func _decode_preview(encoded: String) -> Texture2D:
	if encoded.is_empty():
		return null
	var image: Image = Image.new()
	if image.load_png_from_buffer(Marshalls.base64_to_raw(encoded)) != OK or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


func _payload_saved_time(payload: Dictionary, path: String) -> String:
	var saved_at: String = str(payload.get("saved_at", ""))
	if not saved_at.is_empty():
		var date_time: PackedStringArray = saved_at.replace("T", " ").split(" ")
		if date_time.size() >= 2 and date_time[0].length() >= 10:
			return "%s %s" % [date_time[0].substr(5, 5), date_time[1].substr(0, 5)]
		return saved_at.replace("T", " ")
	if FileAccess.file_exists(path):
		return "較早的存檔"
	if FileAccess.file_exists(path + ".bak"):
		return "備份存檔"
	return "較早的存檔"


func _slot_file_exists(path: String) -> bool:
	for candidate: String in [path, path + ".bak", path + ".bak.old", path + ".old", path + ".tmp"]:
		if FileAccess.file_exists(candidate):
			return true
	return false


func _default_background_id() -> String:
	if _backgrounds.has("yorozuya_living_room"):
		return "yorozuya_living_room"
	return str(_backgrounds.keys()[0]) if not _backgrounds.is_empty() else ""


# ---------------------------------------------------------------- 小工具

func _runner_current() -> Dictionary:
	_sync_cast()
	var value: Variant = _runner.call("current") if _runner != null else null
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


## The runner does not know the stage: tell it who is on it before it answers about an investigation.
func _sync_cast() -> void:
	if _runner == null:
		return
	var on_stage: Array = []
	for actor_id: String in _sprites.keys():
		if (_sprites[actor_id] as Control).visible:
			on_stage.append(actor_id)
	_runner.set("cast", on_stage)


func _runner_string(property_name: String, fallback: String) -> String:
	var text_value: String = str(_runner.get(property_name)) if _runner != null else ""
	return fallback if text_value.is_empty() else text_value


func _command_op(command: Dictionary) -> String:
	return _dict_string(command, "op")


func _line_key(command: Dictionary, kind: String) -> String:
	return "%s:%s:%s" % [kind, _dict_string(command, "node_id", "unknown"), str(command.get("step_index", -1))]


func _dict_string(data: Dictionary, key: String, fallback: String = "") -> String:
	return str(data.get(key, fallback))


func _dict_bool(data: Dictionary, key: String, fallback: bool = false) -> bool:
	return bool(data.get(key, fallback))


func _make_label(parent: Node, value: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.set_meta("ui_style_role", _label_role_for_color(color))
	parent.add_child(label)
	UI_STYLES_SCRIPT.apply_label(label, _ui_style_id, str(label.get_meta("ui_style_role")))
	return label


func _make_button(parent: Node, value: String, font_size: int) -> Button:
	var button: Button = Button.new()
	button.text = value
	button.add_theme_font_size_override("font_size", font_size)
	parent.add_child(button)
	_set_button_style(button, "standard")
	return button


func _make_style(background: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 28.0
	style.content_margin_right = 28.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style


func _label_role_for_color(color: Color) -> String:
	if color == COLOR_GOLD or color == COLOR_UI_ACCENT:
		return "accent"
	if color == COLOR_TEXT_SOFT:
		return "muted"
	if color == COLOR_THOUGHT:
		return "thought"
	if color == COLOR_DISABLED:
		return "disabled"
	if color == Color("#ff9d8a"):
		return "danger"
	return "body"


func _set_label_style(label: Label, role: String) -> void:
	label.set_meta("ui_style_role", role)
	UI_STYLES_SCRIPT.apply_label(label, _ui_style_id, role)


func _set_button_style(button: Button, role: String, active: bool = false) -> void:
	UI_STYLES_SCRIPT.apply_button(button, _ui_style_id, role, active)


func _on_ui_style_selected(style_id: String) -> void:
	_set_ui_style(style_id)


func _set_ui_style(style_id: String, persist: bool = true) -> void:
	_ui_style_id = UI_STYLES_SCRIPT.normalize_id(style_id)
	if persist:
		var save_error: Error = UI_STYLES_SCRIPT.save_preference(_ui_style_id, ui_preference_path)
		if save_error != OK:
			push_warning("Could not save UI style preference: %s" % error_string(save_error))
	_apply_ui_style()
	_publish_qa_state()


func _apply_ui_style() -> void:
	if _dialog_panel == null:
		return
	_comedy_layer.stop()
	if _dialog_panel.style_id != _ui_style_id:
		_mount_dialogue_box()
		_mount_choice_sheet()
		_mount_menu()
		_mount_title()
	_apply_ui_style_recursive(self)
	_update_toggle_styles()
	_apply_stage_style()
	if _effects != null:
		_effects.set_style(_ui_style_id)
	_phase3_hud.set_style(_ui_style_id)
	_investigate_bar.call("set_style", _ui_style_id)


## The photo treatment of each edition (ui_stage_style.gd) on the stage and title photos, and
## monochrome portraits in the manga edition, as in the HTML reference.
func _apply_stage_style() -> void:
	for frame: TextureRect in _background_frames.values():
		STAGE_STYLE.apply(frame, _ui_style_id)
	STAGE_STYLE.apply(_title_screen.background, _ui_style_id)
	for sprite: Control in _sprites.values():
		sprite.call("set_ui_style", _ui_style_id)  # the art shader goes monochrome for manga


func _apply_ui_style_recursive(node: Node) -> void:
	var role: String = str(node.get_meta("ui_style_role", ""))
	if node is Button and not role.is_empty():
		var button: Button = node as Button
		UI_STYLES_SCRIPT.apply_button(button, _ui_style_id, role,
			bool(button.get_meta("ui_style_active", false)))
	elif node is Label and not role.is_empty():
		UI_STYLES_SCRIPT.apply_label(node as Label, _ui_style_id, role)
	elif (node is Panel or node is PanelContainer) and not role.is_empty():
		UI_STYLES_SCRIPT.apply_panel(node as Control, _ui_style_id, role)
	elif node is ColorRect and role == "letterbox":
		(node as ColorRect).color = UI_STYLES_SCRIPT.palette(_ui_style_id)["canvas"] as Color
	for child: Node in node.get_children():
		_apply_ui_style_recursive(child)


# ---------------------------------------------------------------- QA（僅 ?qa=1 的 Web 版）

func _detect_qa_mode() -> void:
	_qa_enabled = OS.has_feature("web") and bool(JavaScriptBridge.eval(
		"new URLSearchParams(window.location.search).get('qa') === '1'"))


## Written just before the frame draws, once containers have laid out this frame's changes, so a
## test never reads the rows of a sheet or menu that is still being arranged.
func _publish_qa_state() -> void:
	if _qa_enabled and not RenderingServer.frame_pre_draw.is_connected(_write_qa_state):
		RenderingServer.frame_pre_draw.connect(_write_qa_state, CONNECT_ONE_SHOT)


func _write_qa_state() -> void:
	if not is_inside_tree():
		return
	var current: Dictionary = _runner_current()
	var snapshot: Dictionary = _runner.call("snapshot")
	var choices: Array = []
	for index: int in range(_choice_buttons.size()):
		if index < _current_options.size() and _tappable(_choice_buttons[index]):
			choices.append({"id": _dict_string(_current_options[index], "id"),
				"label": _dict_string(_current_options[index], "label"), "rect": _rect(_choice_buttons[index])})
	var controls: Dictionary = {}
	var named: Dictionary = {
		"begin": _begin_button, "continue": _continue_button, "title_load": _title_load_button, "dialogue": _dialog_panel,
		"log": _log_button, "auto": _auto_button, "advance": _advance_button,
		"menu": _choice_sheet.menu_button if _choice_sheet.is_visible_in_tree() else _menu_button, "menu_close": _menu_close, "log_close": _log_close,
		"restart": _restart_button, "title": _end_title_button, "investigate_continue": _investigation_continue_button,
		"investigate_collapse": _dialog_panel.investigation_collapse, "investigate_expand": _investigate_bar.get("expand_button"),
		"boke_previous": _boke_previous_button, "boke_next": _boke_next_button,
		"boke_listen": _boke_listen_button, "boke_tsukkomi": _boke_tsukkomi_button,
		"game_over_retry": _game_over_retry_button, "game_over_title": _game_over.title_button,
		"result_next": _chapter_result.get("next_button"), "result_title": _chapter_result.get("title_button"),
		"chapter_close": _chapter_select.get("close_button"), "settings_close": _settings_panel.get("close_button"),
		"title_settings": _title_screen.settings_button,
		"censor": _choice_sheet.censor_bar if _choice_sheet.censor_bar.is_visible_in_tree() else _dialog_panel.censor_bar,
		"super": _choice_sheet.super_button,
	}
	if _dialog_panel.skip_button != null:
		named["skip"] = _dialog_panel.skip_button
	for item_id: String in _menu_items.keys():
		named["menu_" + item_id] = _menu_items[item_id]
	var chapter_rows: Dictionary = _chapter_select.call("rows")
	for story_id: String in chapter_rows.keys():
		named["chapter_" + story_id] = chapter_rows[story_id]
	var setting_buttons: Dictionary = _settings_panel.call("buttons")
	for setting_id: String in setting_buttons.keys():
		named["setting_" + setting_id] = setting_buttons[setting_id]
	for style_id: String in _title_style_buttons.keys():
		named["title_style_" + style_id] = _title_style_buttons[style_id]
	for style_id: String in _menu_style_buttons.keys():
		named["menu_style_" + style_id] = _menu_style_buttons[style_id]
	# While 目錄 is open its dim covers everything else, so only its own controls can be tapped.
	var modal: Control = _menu_overlay if _menu_overlay.visible else null
	for panel: Control in [_settings_panel, _chapter_select]:  # opened over the title or 目錄
		if panel.visible:
			modal = panel
	for control_name: String in named.keys():
		var control: Control = named[control_name]
		if _tappable(control) and (modal == null or modal.is_ancestor_of(control)):
			controls[control_name] = _rect(control)
	for style_id: String in UI_STYLES_SCRIPT.style_ids():
		var title_style_button: Button = _title_style_buttons.get(style_id) as Button
		var menu_style_button: Button = _menu_style_buttons.get(style_id) as Button
		if title_style_button != null and _tappable(title_style_button):
			controls["style_" + style_id] = _rect(title_style_button)
		elif menu_style_button != null and _tappable(menu_style_button):
			controls["style_" + style_id] = _rect(menu_style_button)
	var hotspot_state: Array[Dictionary] = []
	for raw_hotspot: Variant in current.get("hotspots", []):
		if not raw_hotspot is Dictionary:
			continue
		var hotspot: Dictionary = raw_hotspot as Dictionary
		var hotspot_id: String = _dict_string(hotspot, "id")
		var spot: Control = _hotspots.get(hotspot_id) as Control
		var hit: Rect2 = _hotspot_hit_rect(spot) if spot != null and is_instance_valid(spot) else Rect2()
		# `rect` only while a tap there would reach the spot: on screen and not under the reading box.
		# A character's spot is their whole portrait, so it reports the part above the box.
		var reach: Rect2 = hit
		var covered: bool = _dialog_panel.visible and _dialog_panel.get_global_rect().intersects(hit)
		if hotspot.has("character") and covered:
			reach.end.y = minf(reach.end.y, _dialog_panel.get_global_rect().position.y)
			covered = false
		var reachable: bool = reach.has_area() and Rect2(_game.global_position, _game.size).encloses(reach) and not covered
		hotspot_state.append({
			"id": hotspot_id,
			"label": _dict_string(hotspot, "label"),
			"checked": bool(hotspot.get("checked", false)),
			"pos": hotspot.get("pos", []),
			"screen_rect": {"x": hit.position.x, "y": hit.position.y, "width": hit.size.x, "height": hit.size.y},
			"rect": {"x": reach.position.x, "y": reach.position.y, "width": reach.size.x, "height": reach.size.y} if reachable else {},
		})
	# 舞台中央空白處：點畫面任一處也能推進。
	if _dialog_panel.is_visible_in_tree() or _ui_hidden:
		var stage: Rect2 = Rect2(_game.position + Vector2(_game.size.x * 0.35, _game.size.y * 0.3),
			Vector2(_game.size.x * 0.3, _game.size.y * 0.08))
		controls["stage"] = {"x": stage.position.x, "y": stage.position.y, "width": stage.size.x, "height": stage.size.y}
	if _qte != null and is_instance_valid(_qte):  # the whole screen answers the QTE
		controls["qte"] = _rect(_qte)
	if _placard_open():  # the part of the board a tap reaches (at least 48 CSS px tall to count)
		var board: Rect2 = _placard_hit_rect()
		if board.size.y >= 48.0 * CSS_PX * _panel_scale - 1.0 and board.size.x > 0.0:
			controls["placard"] = {"x": board.position.x, "y": board.position.y, "width": board.size.x, "height": board.size.y}
	for key: String in _topic_buttons.keys():
		var topic: Button = _topic_buttons[key] as Button
		if is_instance_valid(topic) and _tappable(topic) and modal == null:
			controls[key.replace(":", "_")] = _rect(topic)
	if _menu_overlay.visible:  # the dimmed margin beside the panel
		var dim: Rect2 = Rect2(_game.position + Vector2(0.0, _game.size.y * 0.5 - 60.0), Vector2(14.0 * CSS_PX * _panel_scale, 120.0))
		controls["menu_dim"] = {"x": dim.position.x, "y": dim.position.y, "width": dim.size.x, "height": dim.size.y}
	var visible_slots: Array = []
	if _slot_overlay.visible:
		for local_index: int in range(_slot_card_buttons.size()):
			var card: Button = _slot_card_buttons[local_index]
			if not card.is_visible_in_tree() or local_index >= _slot_visible_entries.size():
				continue
			var entry: Dictionary = _slot_visible_entries[local_index].duplicate(true)
			entry["rect"] = _rect(card)
			visible_slots.append(entry)
			if not _slot_confirmation_overlay.visible:
				controls["slot_%d" % int(entry["index"])] = _rect(card)
		if not _slot_confirmation_overlay.visible:
			for pair: Array in [["slot_prev", _slot_prev_button], ["slot_next", _slot_next_button],
				["slot_close", _slot_close_button]]:
				var name: String = str(pair[0])
				var button: Control = pair[1] as Control
				if button.is_visible_in_tree() and not (button is BaseButton and (button as BaseButton).disabled):
					controls[name] = _rect(button)
			if _slot_auto_button.is_visible_in_tree() and not _slot_auto_button.disabled:
				controls["slot_auto"] = _rect(_slot_auto_button)
	if _slot_confirmation_overlay.visible:
		controls["slot_confirm_yes"] = _rect(_slot_confirm_yes)
		controls["slot_confirm_no"] = _rect(_slot_confirm_no)
	var sprites: Dictionary = {}
	for actor_id: String in _sprites.keys():
		var sprite: Control = _sprites[actor_id]
		sprites[actor_id] = {"visible": sprite.visible, "expression": str(sprite.get("expression")),
			"focused": sprite.modulate.r > 0.9, "position": str(_actor_slots.get(actor_id, "center"))}
	var state: Dictionary = {
		# While the menu pops in, its rows are scaled and not yet laid out: report busy until it settles.
		# The director's sheet springs in the same way.
		"screen": "busy" if (_screen_mode == "menu" and _menu_panel.scale != Vector2.ONE) or _choice_sheet.is_popping() else _screen_mode,
		"text": _visible_text,
		"full_text": _full_text,
		"speaker": _current_speaker,
		"node_id": _dict_string(current, "node_id", _dict_string(snapshot, "node_id")),
		"source_id": _dict_string(current,"source_id", _dict_string(RoundView.line(current), "source_id")),
		"step_index": int(current.get("step_index", snapshot.get("step_index", -1))),
		"flags": snapshot.get("flags", {}),
		"items": snapshot.get("items", []),
		"background": _current_bg_id,
		"text_complete": _text_complete,
		"ui_hidden": _ui_hidden,
		"auto": _auto,
		"skip": _skip,
		"audio_muted": _audio_muted,
		"result": _runner.call("chapter_result") if _screen_mode == "result" else {},
		"settings": _settings.duplicate(),
		"ui_style": _ui_style_id,
		"toast": _toast.text if _toast.visible else "",
		"viewport": {"width": get_viewport_rect().size.x, "height": get_viewport_rect().size.y},
		"game": _rect(_game),
		"dialog": _rect(_dialog_panel) if _dialog_panel.is_visible_in_tree() else {},
		"quickbar": _rect(_quickbar) if _quickbar.is_visible_in_tree() else {},
		"choice_sheet": _rect(_choice_sheet) if _choice_sheet.is_visible_in_tree() else {},
		"name_plate": _rect(_name_plate) if _name_plate.is_visible_in_tree() else {},
		"sprites": sprites,
		"placard": {"text": str(_placard_holder.call("placard_text")) if _placard_holder != null else "",
			"glowing": _placard_holder != null and bool(_placard_holder.call("placard_glowing")),
			"holder_visible": _placard_holder != null and _placard_holder.visible,
			"tappable": _placard_open()},
		"log_scroll": {"value": _log_scroll.scroll_vertical, "max": _log_scroll.get_v_scroll_bar().max_value - _log_scroll.size.y},
		"choices": choices,
		"choice": _choice_qa_state(current),
		"phase3": {
			"enabled": _phase3_enabled,
			"gameplay": snapshot.get("gameplay", {}),
			"inventory": snapshot.get("items", []),
			"hotspots": hotspot_state,
			"investigation": {"place": _dict_string(current, "place"), "place_label": _dict_string(current, "place_label"),
				"talk": (current.get("talk", []) as Array).map(func(topic: Dictionary) -> String: return str(topic["id"])),
				"moves": (current.get("moves", []) as Array).map(func(move: Dictionary) -> String: return str(move["id"])),
				"complete": bool(current.get("complete", false)), "progress": current.get("progress", [])}
				if _command_op(current) == "investigate" else {},
			"pan": {"offset": _pan, "min": _pan_range.x, "max": _pan_range.y},
			"investigate_collapsed": _investigate_collapsed,
			"boke_screen_mode": _effective_boke_ui_mode() if _command_op(current) == "boke_round" else "",
			"boke_line_index": int(current.get("line_index", -1)),
			"boke_line_count": (current.get("lines", []) as Array).size(),
			"boke_listened": RoundView.listened(current),
			"boke_listen_available": RoundView.can_listen(current),
			"round": {
				"mode": str(current.get("mode", "")), "combo": int(current.get("combo", 0)),
				"caught": current.get("caught_line_ids", []), "super_available": bool(current.get("super_available", false)),
				"super_label": _choice_sheet.super_button.text,
				"aura_active": _phase3_hud.glasses.get_children().any(func(icon: Node) -> bool: return bool(icon.get("charged")) and not bool(icon.get("broken"))),
				"censor": RoundView.censor(current), "placard": RoundView.placard(current), "qte_active": _qte != null,
				"qte_elapsed": _qte.call("elapsed") if _qte != null else 0.0,
			},
			"timer_remaining": _boke_time_remaining,
			"timer_active": _command_op(current) == "boke_round" and _effective_boke_ui_mode() == "tsukkomi",
			"timer_paused": _command_op(current) == "boke_round" and _effective_boke_ui_mode() == "tsukkomi" and _screen_mode != "tsukkomi",
			"checkpoint_ready": not (snapshot.get("checkpoint", {}) as Dictionary).is_empty(),
			"game_over_active": bool(snapshot.get("game_over_active", false)),
			"last_result": _last_boke_result,
		},
		"beam_active": _overlay_layer.get_children().any(func(node: Node) -> bool: return node.scene_file_path == "res://scenes/ui/beam.tscn"),
		"comedy": _comedy_layer.qa_state(),
		"controls": controls,
		"slot_page": _slot_page,
		"slots": visible_slots,
	}
	JavaScriptBridge.eval("window.__debtQA=Object.freeze(%s);" % JSON.stringify(state))


## The `choice` field of the QA snapshot while a `choice` step has its options up (else {}): the look the
## step asks for (`perspective`, whose thought `pov`, the director's `note`, each row's `tones`) and the
## sheet that really holds it (`director`, or the edition's id).
func _choice_qa_state(current: Dictionary) -> Dictionary:
	if _command_op(current) != "choice" or _choice_buttons.is_empty():
		return {}
	var director: bool = _dict_string(current, "perspective", "pov") == "director"
	var tones: Array = []
	for option: Dictionary in _current_options:
		tones.append(_dict_string(option, "tone"))
	return {"perspective": "director" if director else "pov",
		"pov": "" if director else _dict_string(current, "pov", STORY_RUNNER_SCRIPT.DEFAULT_POV),
		"note": _dict_string(current, "note"),
		"sheet": "director" if _choice_sheet.perspective == "director" else _choice_sheet.style_id,
		"tones": tones}


## Visible, enabled, and not scrolled or clipped out of view (a menu row below the fold is not).
func _tappable(control: Control) -> bool:
	if not control.is_visible_in_tree() or (control is BaseButton and (control as BaseButton).disabled):
		return false
	var area: Rect2 = control.get_global_rect()
	var parent: Node = control.get_parent()
	while parent is Control:
		if (parent as Control).clip_contents and not (parent as Control).get_global_rect().grow(0.5).encloses(area):
			return false
		parent = parent.get_parent()
	return true


func _rect(control: Control) -> Dictionary:
	var rect: Rect2 = control.get_global_rect()
	return {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y}
