extends Control

## 《請幫我向你老闆討債》第一場的直式故事 UI。
##
## 這個檔案只負責畫面、輸入、演出協調與最小續讀；故事流程及舞台狀態
## 分別由 scripts/story_runner.gd 與 scripts/story_stage.gd 擁有。兩者都用
## preload 載入，避免依賴全域 class_name，也讓主場景保持一個 root Control。

const STORY_RUNNER_SCRIPT: Script = preload("res://scripts/story_runner.gd")
const STORY_STAGE_SCRIPT: Script = preload("res://scripts/story_stage.gd")
const ACTOR_DOLL_SCRIPT: Script = preload("res://scripts/actor_doll.gd")

const DESIGN_SIZE: Vector2 = Vector2(720.0, 1280.0)
const STAGE_DESIGN_SIZE: Vector2 = Vector2(720.0, 620.0)
const STORY_DATA_PATH: String = "res://data/debt_story.json"
const FONT_PATH: String = "res://assets/fonts/story-cjk.ttc"
const SAVE_PATH: String = "user://debt_commission.save"
const SAVE_SCHEMA: int = 1
const SAVE_STORY_ID: String = "debt_commission"
const STAGE_SNAPSHOT_VERSION: int = 1
const TYPEWRITER_INTERVAL: float = 0.032

const AUDIO_PATHS: Dictionary = {
	"paper": "res://assets/audio/paper.wav",
	"knock": "res://assets/audio/knock.wav",
	"step": "res://assets/audio/step.wav",
	"stamp": "res://assets/audio/stamp.wav",
	"ambient": "res://assets/audio/ambient.wav",
}

const SPEAKER_NAMES: Dictionary = {
	"shinpachi": "新八",
	"gintoki": "銀時",
	"otose": "登勢",
	"narrator": "旁白",
}

const COLOR_PAPER: Color = Color("#f2e5cf")
const COLOR_PAPER_LIGHT: Color = Color("#fbf4e7")
const COLOR_PAPER_DARK: Color = Color("#e5cfad")
const COLOR_INK: Color = Color("#302a25")
const COLOR_INK_SOFT: Color = Color("#67594c")
const COLOR_RED: Color = Color("#a63c32")
const COLOR_RED_DARK: Color = Color("#7f2b25")
const COLOR_WOOD: Color = Color("#805336")
const COLOR_WOOD_DARK: Color = Color("#563824")
const COLOR_GOLD: Color = Color("#c18a3d")
const COLOR_DISABLED: Color = Color("#a69a8b")

var _content: Control = null
var _title_screen: Control = null
var _story_screen: Control = null
var _log_overlay: Control = null
var _log_panel: Panel = null
var _log_entries: VBoxContainer = null
var _log_scroll: ScrollContainer = null

var _start_button: Button = null
var _continue_button: Button = null
var _title_mute_button: Button = null
var _story_restart_button: Button = null
var _story_log_button: Button = null
var _story_mute_button: Button = null
var _log_close_button: Button = null
var _next_button: Button = null

var _stage_host: Control = null
var _stage: Node2D = null
var _portrait_frame: Control = null
var _portrait_placeholder: Label = null
var _portrait_dolls: Dictionary = {}
var _dialogue_panel: Panel = null
var _text_panel: Panel = null
var _speaker_label: Label = null
var _dialogue_label: Label = null
var _choice_prompt_label: Label = null
var _choices_box: VBoxContainer = null
var _end_badge: Label = null

var _runner: RefCounted = null
var _story_ready: bool = false
var _story_error: String = ""
var _story_font: Font = ThemeDB.fallback_font
var _ui_theme: Theme = null

var _audio_players: Dictionary = {}
var _audio_muted: bool = false

var _screen_mode: String = "title"
var _mode_before_log: String = "title"
var _story_busy: bool = false
var _generation: int = 0
var _line_generation: int = 0
var _typewriter_running: bool = false
var _text_complete: bool = true
var _full_text: String = ""
var _visible_text: String = ""
var _current_speaker: String = ""
var _current_line_key: String = ""
var _line_logged: bool = false
var _end_logged: bool = false

var _current_command: Dictionary = {}
var _current_options: Array[Dictionary] = []
var _choice_buttons: Array[Button] = []
var _history: Array[Dictionary] = []

var _qa_enabled: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(_on_root_resized)

	_configure_font()
	_build_runtime_objects()
	_build_ui()
	_layout_design_root()
	_refresh_continue_button()
	_detect_qa_mode()
	_show_title()
	_publish_qa_state()


func _configure_font() -> void:
	if ResourceLoader.exists(FONT_PATH):
		var loaded_font: Resource = load(FONT_PATH)
		if loaded_font is Font:
			_story_font = loaded_font as Font

	_ui_theme = Theme.new()
	_ui_theme.default_font = _story_font
	_ui_theme.default_font_size = 24
	theme = _ui_theme


func _build_runtime_objects() -> void:
	var runner_object: Object = STORY_RUNNER_SCRIPT.new()
	_runner = runner_object as RefCounted
	if _runner == null:
		_story_error = "無法建立故事流程。"
		return

	var loaded: Variant = _runner.call("load_story", STORY_DATA_PATH)
	_story_ready = bool(loaded)
	if not _story_ready:
		_story_error = _runner_string("error_message", "故事資料尚未就緒。")

	var stage_object: Object = STORY_STAGE_SCRIPT.new()
	_stage = stage_object as Node2D
	if _stage == null:
		_story_ready = false
		_story_error = "無法建立房間舞台。"
		return

	_audio_players.clear()
	for audio_id_variant: Variant in AUDIO_PATHS.keys():
		var audio_id: String = str(audio_id_variant)
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "Audio_%s" % audio_id
		player.volume_db = -80.0 if _audio_muted else 0.0
		add_child(player)
		var audio_path: String = str(AUDIO_PATHS.get(audio_id, ""))
		if not audio_path.is_empty() and ResourceLoader.exists(audio_path):
			var loaded_audio: Resource = load(audio_path)
			if loaded_audio is AudioStream:
				player.stream = loaded_audio as AudioStream
		_audio_players[audio_id] = player


func _build_ui() -> void:
	_content = Control.new()
	_content.name = "DesignRoot"
	_content.size = DESIGN_SIZE
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_content)

	_build_title_screen()
	_build_story_screen()
	_build_log_overlay()
	_build_portraits()

	if _stage != null and _stage_host != null:
		if _stage.get_parent() != null and _stage.get_parent() != _stage_host:
			var old_parent: Node = _stage.get_parent()
			old_parent.remove_child(_stage)
		_stage_host.add_child(_stage)
		_stage.name = "StoryStage"
		_stage.z_index = 1

	if _runner != null and not _story_ready:
		_start_button.disabled = true
		_continue_button.disabled = true


func _build_title_screen() -> void:
	_title_screen = Control.new()
	_title_screen.name = "TitleScreen"
	_title_screen.size = DESIGN_SIZE
	_content.add_child(_title_screen)

	var background: ColorRect = _make_color_rect(_title_screen, Rect2(Vector2.ZERO, DESIGN_SIZE), COLOR_PAPER)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var top_rule: ColorRect = _make_color_rect(_title_screen,
		Rect2(Vector2(52.0, 76.0), Vector2(616.0, 3.0)), COLOR_RED)
	top_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bottom_rule: ColorRect = _make_color_rect(_title_screen,
		Rect2(Vector2(118.0, 1110.0), Vector2(484.0, 2.0)), COLOR_WOOD)
	bottom_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var eyebrow: Label = _make_label(_title_screen, Rect2(Vector2(60.0, 108.0), Vector2(600.0, 40.0)),
		"第一場・萬事屋", 25, COLOR_RED, HORIZONTAL_ALIGNMENT_CENTER)
	eyebrow.add_theme_constant_override("outline_size", 4)
	eyebrow.add_theme_color_override("font_outline_color", COLOR_PAPER)

	var title: Label = _make_label(_title_screen, Rect2(Vector2(48.0, 178.0), Vector2(624.0, 150.0)),
		"請幫我向你老闆討債", 48, COLOR_INK, HORIZONTAL_ALIGNMENT_CENTER)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 2)
	title.add_theme_color_override("font_outline_color", COLOR_PAPER_LIGHT)

	var subtitle: Label = _make_label(_title_screen, Rect2(Vector2(76.0, 352.0), Vector2(568.0, 100.0)),
		"一張正經委託\n午後，帳本與糰子都在桌上。", 27, COLOR_INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var seal: Panel = Panel.new()
	seal.name = "StorySeal"
	seal.position = Vector2(278.0, 505.0)
	seal.size = Vector2(164.0, 164.0)
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seal.add_theme_stylebox_override("panel", _make_style(COLOR_RED, COLOR_RED_DARK, 82, 3, 14.0))
	_title_screen.add_child(seal)
	var seal_label: Label = _make_label(seal, Rect2(Vector2.ZERO, seal.size), "借\n金", 33, COLOR_PAPER_LIGHT,
		HORIZONTAL_ALIGNMENT_CENTER)
	seal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_start_button = _make_button(_title_screen, Rect2(Vector2(120.0, 762.0), Vector2(480.0, 82.0)),
		"開始故事", 30, COLOR_RED)
	_start_button.name = "BeginButton"
	_start_button.pressed.connect(_on_begin_pressed)

	_continue_button = _make_button(_title_screen, Rect2(Vector2(120.0, 862.0), Vector2(480.0, 70.0)),
		"繼續閱讀", 26, COLOR_WOOD)
	_continue_button.name = "ContinueButton"
	_continue_button.pressed.connect(_on_continue_pressed)

	var hint: Label = _make_label(_title_screen, Rect2(Vector2(72.0, 974.0), Vector2(576.0, 76.0)),
		"觸控或滑鼠皆可操作\n文字會逐字出現，再按一次推進。", 21, COLOR_INK_SOFT,
		HORIZONTAL_ALIGNMENT_CENTER)
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_title_mute_button = _make_small_button(_title_screen, Rect2(Vector2(560.0, 36.0), Vector2(108.0, 48.0)),
		"音效：開")
	_title_mute_button.name = "TitleMuteButton"
	_title_mute_button.pressed.connect(_on_mute_pressed)

	var footer: Label = _make_label(_title_screen, Rect2(Vector2(60.0, 1142.0), Vector2(600.0, 54.0)),
		"故事原型・第一場", 20, COLOR_INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
	footer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var error_label: Label = _make_label(_title_screen, Rect2(Vector2(68.0, 1038.0), Vector2(584.0, 54.0)),
		"", 18, COLOR_RED, HORIZONTAL_ALIGNMENT_CENTER)
	error_label.name = "StoryError"
	error_label.visible = false


func _build_story_screen() -> void:
	_story_screen = Control.new()
	_story_screen.name = "StoryScreen"
	_story_screen.size = DESIGN_SIZE
	_story_screen.visible = false
	_content.add_child(_story_screen)

	var background: ColorRect = _make_color_rect(_story_screen, Rect2(Vector2.ZERO, DESIGN_SIZE), COLOR_PAPER)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var header: Panel = Panel.new()
	header.name = "StoryHeader"
	header.position = Vector2(24.0, 16.0)
	header.size = Vector2(672.0, 90.0)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_stylebox_override("panel", _make_style(COLOR_PAPER_LIGHT, COLOR_PAPER_DARK, 3, 2, 12.0))
	_story_screen.add_child(header)

	var title_label: Label = _make_label(header, Rect2(Vector2(22.0, 12.0), Vector2(300.0, 38.0)),
		"請幫我向你老闆討債", 25, COLOR_INK, HORIZONTAL_ALIGNMENT_LEFT)
	title_label.name = "StoryTitle"
	var chapter_label: Label = _make_label(header, Rect2(Vector2(24.0, 50.0), Vector2(320.0, 28.0)),
		"第一場　｜　一張正經委託", 18, COLOR_RED, HORIZONTAL_ALIGNMENT_LEFT)
	chapter_label.name = "ChapterTitle"

	_story_restart_button = _make_small_button(header, Rect2(Vector2(326.0, 21.0), Vector2(104.0, 48.0)), "重玩")
	_story_restart_button.name = "RestartButton"
	_story_restart_button.pressed.connect(_on_restart_pressed)
	_story_log_button = _make_small_button(header, Rect2(Vector2(438.0, 21.0), Vector2(104.0, 48.0)), "紀錄")
	_story_log_button.name = "LogButton"
	_story_log_button.pressed.connect(_on_log_pressed)
	_story_mute_button = _make_small_button(header, Rect2(Vector2(550.0, 21.0), Vector2(100.0, 48.0)), "音效：開")
	_story_mute_button.name = "MuteButton"
	_story_mute_button.pressed.connect(_on_mute_pressed)

	var stage_frame: Panel = Panel.new()
	stage_frame.name = "StageFrame"
	stage_frame.position = Vector2(24.0, 122.0)
	stage_frame.size = Vector2(672.0, 610.0)
	stage_frame.clip_contents = true
	stage_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_frame.add_theme_stylebox_override("panel", _make_style(COLOR_PAPER_DARK, COLOR_WOOD, 3, 3, 10.0))
	_story_screen.add_child(stage_frame)

	_stage_host = Control.new()
	_stage_host.name = "StageHost"
	_stage_host.position = Vector2(8.0, 8.0)
	_stage_host.size = Vector2(656.0, 594.0)
	_stage_host.clip_contents = true
	_stage_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_frame.add_child(_stage_host)

	_dialogue_panel = Panel.new()
	_dialogue_panel.name = "DialoguePanel"
	_dialogue_panel.position = Vector2(24.0, 744.0)
	_dialogue_panel.size = Vector2(672.0, 520.0)
	_dialogue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_panel.add_theme_stylebox_override("panel", _make_style(COLOR_PAPER_LIGHT, COLOR_PAPER_DARK, 3, 2, 12.0))
	_story_screen.add_child(_dialogue_panel)

	_portrait_frame = Control.new()
	_portrait_frame.name = "PortraitFrame"
	_portrait_frame.position = Vector2(18.0, 28.0)
	_portrait_frame.size = Vector2(154.0, 180.0)
	_portrait_frame.clip_contents = true
	_portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_panel.add_child(_portrait_frame)

	var portrait_rule: ColorRect = _make_color_rect(_dialogue_panel,
		Rect2(Vector2(190.0, 28.0), Vector2(1.0, 178.0)), COLOR_PAPER_DARK)
	portrait_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_text_panel = Panel.new()
	_text_panel.name = "TextPanel"
	_text_panel.position = Vector2(202.0, 28.0)
	_text_panel.size = Vector2(452.0, 226.0)
	_text_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_text_panel.add_theme_stylebox_override("panel", _make_style(COLOR_PAPER, COLOR_PAPER_DARK, 2, 1, 10.0))
	_text_panel.gui_input.connect(_on_text_panel_gui_input)
	_dialogue_panel.add_child(_text_panel)

	_speaker_label = _make_label(_text_panel, Rect2(Vector2(16.0, 12.0), Vector2(420.0, 34.0)),
		"", 25, COLOR_RED, HORIZONTAL_ALIGNMENT_LEFT)
	_speaker_label.name = "SpeakerName"
	_speaker_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.10))
	_speaker_label.add_theme_constant_override("shadow_offset_x", 1)
	_speaker_label.add_theme_constant_override("shadow_offset_y", 1)

	_dialogue_label = _make_label(_text_panel, Rect2(Vector2(16.0, 51.0), Vector2(420.0, 162.0)),
		"", 32, COLOR_INK, HORIZONTAL_ALIGNMENT_LEFT)
	_dialogue_label.name = "DialogueText"
	_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_dialogue_label.clip_text = false

	_choice_prompt_label = _make_label(_dialogue_panel, Rect2(Vector2(34.0, 218.0), Vector2(600.0, 34.0)),
		"", 20, COLOR_INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT)
	_choice_prompt_label.name = "ChoicePrompt"
	_choice_prompt_label.visible = false

	_choices_box = VBoxContainer.new()
	_choices_box.name = "Choices"
	_choices_box.position = Vector2(202.0, 268.0)
	_choices_box.size = Vector2(452.0, 136.0)
	_choices_box.add_theme_constant_override("separation", 10)
	_choices_box.mouse_filter = Control.MOUSE_FILTER_PASS
	_dialogue_panel.add_child(_choices_box)

	_next_button = _make_button(_dialogue_panel, Rect2(Vector2(202.0, 396.0), Vector2(452.0, 96.0)),
		"下一句  >", 27, COLOR_RED)
	_next_button.name = "NextButton"
	_next_button.pressed.connect(_on_next_pressed)

	_end_badge = _make_label(_dialogue_panel, Rect2(Vector2(34.0, 462.0), Vector2(600.0, 34.0)),
		"本場完成・明日下午三點", 19, COLOR_RED, HORIZONTAL_ALIGNMENT_CENTER)
	_end_badge.name = "EndBadge"
	_end_badge.visible = false

	_portrait_placeholder = _make_label(_portrait_frame, Rect2(Vector2.ZERO, _portrait_frame.size),
		"旁白", 22, COLOR_INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
	_portrait_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_portrait_placeholder.visible = false


func _build_portraits() -> void:
	if _portrait_frame == null:
		return
	for actor_id: String in ["shinpachi", "gintoki", "otose"]:
		var actor_object: Object = ACTOR_DOLL_SCRIPT.new()
		var doll: Node2D = actor_object as Node2D
		if doll == null:
			continue
		doll.name = "Portrait_%s" % actor_id
		doll.call("setup", actor_id, true)
		doll.position = Vector2(_portrait_frame.size.x * 0.5, _portrait_frame.size.y - 6.0)
		doll.scale = Vector2(0.88, 0.88)
		doll.visible = false
		_portrait_frame.add_child(doll)
		_portrait_dolls[actor_id] = doll


func _build_log_overlay() -> void:
	_log_overlay = Control.new()
	_log_overlay.name = "LogOverlay"
	_log_overlay.size = DESIGN_SIZE
	_log_overlay.visible = false
	_log_overlay.z_index = 2048
	_log_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_content.add_child(_log_overlay)

	var dim: ColorRect = _make_color_rect(_log_overlay, Rect2(Vector2.ZERO, DESIGN_SIZE), Color(0.10, 0.07, 0.05, 0.38))
	dim.mouse_filter = Control.MOUSE_FILTER_STOP

	_log_panel = Panel.new()
	_log_panel.name = "LogPanel"
	_log_panel.position = Vector2(48.0, 78.0)
	_log_panel.size = Vector2(624.0, 1120.0)
	_log_panel.add_theme_stylebox_override("panel", _make_style(COLOR_PAPER_LIGHT, COLOR_WOOD, 4, 3, 14.0))
	_log_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_log_overlay.add_child(_log_panel)

	var log_title: Label = _make_label(_log_panel, Rect2(Vector2(26.0, 22.0), Vector2(330.0, 42.0)),
		"讀過的台詞", 30, COLOR_INK, HORIZONTAL_ALIGNMENT_LEFT)
	log_title.name = "LogTitle"
	var log_subtitle: Label = _make_label(_log_panel, Rect2(Vector2(28.0, 64.0), Vector2(400.0, 30.0)),
		"只記錄已經走過的這一條路", 18, COLOR_INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT)
	log_subtitle.name = "LogSubtitle"

	_log_close_button = _make_small_button(_log_panel, Rect2(Vector2(482.0, 20.0), Vector2(112.0, 50.0)), "關閉")
	_log_close_button.name = "LogCloseButton"
	_log_close_button.pressed.connect(_on_log_close_pressed)

	_log_scroll = ScrollContainer.new()
	_log_scroll.name = "LogScroll"
	_log_scroll.position = Vector2(24.0, 112.0)
	_log_scroll.size = Vector2(576.0, 956.0)
	_log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_log_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_log_panel.add_child(_log_scroll)

	_log_entries = VBoxContainer.new()
	_log_entries.name = "LogEntries"
	_log_entries.custom_minimum_size = Vector2(556.0, 0.0)
	_log_entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_entries.add_theme_constant_override("separation", 12)
	_log_scroll.add_child(_log_entries)


func _layout_design_root() -> void:
	if _content == null:
		return
	var viewport_size: Vector2 = size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var scale_factor: float = min(viewport_size.x / DESIGN_SIZE.x, viewport_size.y / DESIGN_SIZE.y)
	scale_factor = max(scale_factor, 0.1)
	_content.size = DESIGN_SIZE
	_content.scale = Vector2(scale_factor, scale_factor)
	_content.position = Vector2(
		(viewport_size.x - DESIGN_SIZE.x * scale_factor) * 0.5,
		(viewport_size.y - DESIGN_SIZE.y * scale_factor) * 0.5
	)

	if _stage_host != null and _stage != null:
		var stage_scale: float = min(_stage_host.size.x / STAGE_DESIGN_SIZE.x,
			_stage_host.size.y / STAGE_DESIGN_SIZE.y)
		_stage.scale = Vector2(stage_scale, stage_scale)
		_stage.position = Vector2(
			(_stage_host.size.x - STAGE_DESIGN_SIZE.x * stage_scale) * 0.5,
			(_stage_host.size.y - STAGE_DESIGN_SIZE.y * stage_scale) * 0.5)

	_publish_qa_state()


func _on_root_resized() -> void:
	_layout_design_root()


func _on_begin_pressed() -> void:
	if _story_busy or not _story_ready:
		return
	_start_audio_after_user_gesture()
	_start_new_story()


func _on_continue_pressed() -> void:
	if _story_busy:
		return
	_start_audio_after_user_gesture()
	var payload: Dictionary = _read_save_payload()
	if payload.is_empty() or not _validate_save_payload(payload):
		_story_error = "這份續讀資料已失效，請重新開始。"
		_show_title_error(_story_error)
		_refresh_continue_button()
		return
	if not _apply_save_payload(payload):
		_story_error = "續讀資料無法套用，請重新開始。"
		_show_title_error(_story_error)
		return
	_show_story_screen()
	_render_restored_current()


func _start_new_story() -> void:
	_cancel_generation()
	_delete_save()
	_history.clear()
	_current_options.clear()
	_current_command.clear()
	_end_logged = false
	_story_error = ""

	if _runner == null or _stage == null:
		_show_title_error("故事流程尚未就緒。")
		return

	_runner.call("reset")
	_stage.call("reset_stage")
	_show_story_screen()
	_start_generation_drive()


func _on_restart_pressed() -> void:
	_start_audio_after_user_gesture()
	_start_new_story()


func _on_next_pressed() -> void:
	if _screen_mode != "story" or _story_busy or _current_command.is_empty():
		return
	if _command_op(_current_command) != "say":
		return
	if not _text_complete:
		_complete_current_line()
		return
	_advance_current_line()


func _on_text_panel_gui_input(event: InputEvent) -> void:
	if not _screen_mode == "story" or _story_busy:
		return
	var pressed: bool = false
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		pressed = mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	# The project converts touches into mouse events for all Control widgets.
	# Handling ScreenTouch as well would reveal and advance on the same tap.
	if pressed:
		_text_panel.accept_event()
		_on_next_pressed()


func _advance_current_line() -> void:
	if _runner == null:
		return
	_cancel_typewriter()
	_next_button.disabled = true
	_story_busy = true
	var generation: int = _generation
	var advanced: Variant = _runner.call("advance")
	if not _is_generation_current(generation):
		return
	if advanced == null and not _runner_error_is_empty():
		_story_busy = false
		_show_runtime_error(_runner_string("error_message", "故事無法繼續。"))
		return
	_start_generation_drive()


func _start_generation_drive() -> void:
	var generation: int = _generation
	call_deferred("_drive_story", generation)


func _drive_story(generation: int) -> void:
	if not _is_generation_current(generation) or _runner == null:
		return
	_story_busy = true
	_publish_qa_state()

	while _is_generation_current(generation):
		var command: Dictionary = _runner_current()
		if command.is_empty():
			_story_busy = false
			_show_runtime_error("故事流程沒有可呈現的指令。")
			return

		var operation: String = _command_op(command)
		match operation:
			"say":
				_story_busy = false
				_present_say(command, false)
				return
			"choice":
				_story_busy = false
				_present_choice(command, false)
				_save_game()
				return
			"end":
				_story_busy = false
				_present_end(command, false)
				_save_game()
				return
			"sound":
				_play_sound(_dict_string(command, "id"))
				_runner.call("advance")
				continue
			"set_flag", "condition", "goto":
				_runner.call("advance")
				continue
			_:
				await _perform_stage_command(command, generation)
				if not _is_generation_current(generation):
					return
				_runner.call("advance")

	_story_busy = false
	_publish_qa_state()


func _perform_stage_command(command: Dictionary, generation: int) -> void:
	if _stage == null:
		return
	if not _is_generation_current(generation):
		return
	# await 對同步返回值會立即繼續，對 Stage 的 awaitable perform 則會等到
	# tween / wait 完成；generation 檢查負責丟棄 restart 前的舊回呼。
	await _stage.call("perform", command)


func _present_say(command: Dictionary, restored: bool) -> void:
	_current_command = command.duplicate(true)
	_current_speaker = _dict_string(command, "speaker", "narrator")
	_full_text = _dict_string(command, "text")
	_visible_text = ""
	_text_complete = false
	_line_generation += 1
	_typewriter_running = false
	_current_line_key = _line_key(command, "say")
	_line_logged = _history_has_key(_current_line_key)
	_end_badge.visible = false
	_choice_prompt_label.visible = false
	_clear_choice_buttons()
	_set_speaker_visual(command)
	_set_portrait(_current_speaker, _dict_string(command, "expression", "neutral"),
		_dict_bool(command, "thought", false))
	_update_text_visual()
	_next_button.visible = true
	_next_button.disabled = false
	_next_button.text = "繼續  >" if restored else "顯示全文"
	_next_button.grab_focus()
	_screen_mode = "story"
	_publish_qa_state()

	if restored:
		if _line_logged:
			_visible_text = _full_text
			_text_complete = true
			_update_text_visual()
			_next_button.text = "繼續  >"
		else:
			# A save taken at the start of a typewriter line deliberately keeps the
			# line out of history.  Resume that same stable line from its beginning.
			_start_typewriter(_full_text, _line_generation)
	else:
		# Save before starting the typewriter, so closing the tab mid-line still
		# restores this line without falsely marking it as read.
		_save_game()
		_start_typewriter(_full_text, _line_generation)
	# A previously read line is restored synchronously, without a typewriter tick
	# to publish its final text. Observe the same state that is now on screen.
	_publish_qa_state()


func _present_choice(command: Dictionary, restored: bool) -> void:
	_current_command = command.duplicate(true)
	_current_speaker = "shinpachi"
	_full_text = _dict_string(command, "prompt", "請選擇問話方式。")
	_visible_text = _full_text
	_text_complete = true
	_line_generation += 1
	_typewriter_running = false
	_current_line_key = _line_key(command, "choice")
	_line_logged = _history_has_key(_current_line_key)
	_end_badge.visible = false
	_set_speaker_visual({"speaker": "shinpachi", "expression": "thinking"})
	_set_portrait("shinpachi", "thinking", false)
	_update_text_visual()
	_next_button.visible = false
	_choice_prompt_label.visible = false
	_screen_mode = "choice"

	_clear_choice_buttons()
	_current_options.clear()
	var raw_options: Variant = command.get("options", [])
	if raw_options is Array:
		for option_variant: Variant in raw_options:
			if option_variant is Dictionary:
				var option: Dictionary = (option_variant as Dictionary).duplicate(true)
				_current_options.append(option)

	for option_index: int in range(_current_options.size()):
		var option: Dictionary = _current_options[option_index]
		var option_id: String = _dict_string(option, "id")
		var option_label: String = _dict_string(option, "label", "繼續")
		var choice_button: Button = _make_choice_button(option_label, option_index)
		choice_button.pressed.connect(_on_choice_pressed.bind(option_id))
		_choices_box.add_child(choice_button)
		_choice_buttons.append(choice_button)
	if not _choice_buttons.is_empty():
		_choice_buttons[0].grab_focus()

	if not _line_logged:
		_append_history_entry({
			"key": _current_line_key,
			"kind": "say",
			"speaker": "shinpachi",
			"text": _full_text,
			"thought": false,
		})
		_line_logged = true
	_update_text_visual()
	call_deferred("_publish_qa_state_after_layout")


func _present_end(command: Dictionary, restored: bool) -> void:
	_current_command = command.duplicate(true)
	_current_speaker = "narrator"
	_full_text = _dict_string(command, "text", "第一場結束。")
	_visible_text = _full_text
	_text_complete = true
	_line_generation += 1
	_typewriter_running = false
	_current_line_key = _line_key(command, "end")
	_end_logged = _history_has_key(_current_line_key)
	_clear_choice_buttons()
	_choice_prompt_label.visible = false
	_set_speaker_visual({"speaker": "narrator", "expression": "neutral"})
	_set_portrait("narrator", "neutral", false)
	_update_text_visual()
	_next_button.visible = false
	_end_badge.visible = true
	_screen_mode = "end"
	_story_restart_button.grab_focus()
	if not _end_logged:
		_append_history_entry({
			"key": _current_line_key,
			"kind": "end",
			"speaker": "narrator",
			"text": _full_text,
		})
		_end_logged = true
	_publish_qa_state()


func _render_restored_current() -> void:
	_cancel_generation()
	var current: Dictionary = _runner_current()
	if current.is_empty():
		_show_title_error("續讀位置不存在，請重新開始。")
		return
	var operation: String = _command_op(current)
	match operation:
		"say":
			_present_say(current, true)
		"choice":
			_present_choice(current, true)
		"end":
			_present_end(current, true)
		_:
			# 穩定存檔只會落在 say／choice／end；遇到舊格式的非穩定位置時，
			# 只處理必要的演出指令，不先替玩家推進一個故事指令。
			_story_busy = true
			_start_generation_drive()


func _on_choice_pressed(option_id: String) -> void:
	if _screen_mode != "choice" or _story_busy or _runner == null:
		return
	_story_busy = true
	_screen_mode = "busy"
	var selected_label: String = _option_label(option_id)
	_clear_choice_buttons()
	var chosen: bool = bool(_runner.call("choose", option_id))
	if not chosen:
		_story_busy = false
		_screen_mode = "choice"
		_show_runtime_error(_runner_string("error_message", "這個選項目前不能選。"))
		_present_choice(_current_command, true)
		return

	_append_history_entry({
		"key": "choice:%s:%s" % [_current_line_key, option_id],
		"kind": "choice",
		"speaker": "player",
		"text": selected_label,
		"option_id": option_id,
	})
	_start_generation_drive()


func _start_typewriter(text_value: String, token: int) -> void:
	_typewriter_running = true
	_text_complete = text_value.is_empty()
	_visible_text = ""
	_update_text_visual()
	if text_value.is_empty():
		_complete_current_line()
		return
	_typewriter_loop(text_value, token)


func _typewriter_loop(text_value: String, token: int) -> void:
	var character_count: int = text_value.length()
	for character_index: int in range(character_count):
		if token != _line_generation or _screen_mode == "title":
			return
		_visible_text = text_value.substr(0, character_index + 1)
		_update_text_visual()
		if _qa_enabled and (character_index % 3 == 0):
			_publish_qa_state()
		await get_tree().create_timer(TYPEWRITER_INTERVAL).timeout
		if token != _line_generation:
			return
	_typewriter_running = false
	_text_complete = true
	_visible_text = text_value
	_update_text_visual()
	_log_current_line_if_needed()
	_save_game()
	_publish_qa_state()


func _complete_current_line() -> void:
	_line_generation += 1
	_typewriter_running = false
	_text_complete = true
	_visible_text = _full_text
	_update_text_visual()
	_log_current_line_if_needed()
	_save_game()
	_publish_qa_state()


func _cancel_typewriter() -> void:
	_line_generation += 1
	_typewriter_running = false


func _log_current_line_if_needed() -> void:
	if _line_logged or _current_line_key.is_empty():
		return
	_append_history_entry({
		"key": _current_line_key,
		"kind": "say",
		"speaker": _current_speaker,
		"text": _full_text,
		"thought": _dict_bool(_current_command, "thought", false),
	})
	_line_logged = true


func _set_speaker_visual(command: Dictionary) -> void:
	if _stage == null:
		return
	var speaker: String = _dict_string(command, "speaker", "")
	if speaker.is_empty() or speaker == "narrator":
		_stage.call("set_speaker", "", "neutral")
		return
	var expression: String = _dict_string(command, "expression", "neutral")
	_stage.call("set_speaker", speaker, expression)


func _set_portrait(actor_id: String, expression: String, thought: bool) -> void:
	if _portrait_frame == null:
		return
	_portrait_placeholder.visible = actor_id == "narrator" or not _portrait_dolls.has(actor_id)
	if _portrait_placeholder.visible:
		_portrait_placeholder.text = "旁白" if actor_id == "narrator" else ""

	for actor_variant: Variant in _portrait_dolls.keys():
		var actor_key: String = str(actor_variant)
		var doll_value: Variant = _portrait_dolls.get(actor_key)
		if not doll_value is Node2D:
			continue
		var doll: Node2D = doll_value as Node2D
		doll.visible = actor_key == actor_id
		if doll.visible:
			doll.call("set_expression", expression)
			doll.call("set_speaking", not thought)

	_speaker_label.add_theme_color_override("font_color", COLOR_WOOD if thought else COLOR_RED)
	_speaker_label.text = _speaker_display_name(actor_id, thought)


func _update_text_visual() -> void:
	if _dialogue_label == null:
		return
	_dialogue_label.text = _visible_text
	var desired_size: int = 32
	var available_width: float = max(_dialogue_label.size.x, 100.0)
	var available_height: float = max(_dialogue_label.size.y, 60.0)
	while desired_size > 26:
		var measured: Vector2 = _story_font.get_multiline_string_size(
			_full_text, HORIZONTAL_ALIGNMENT_LEFT, available_width, desired_size)
		if measured.y <= available_height:
			break
		desired_size -= 1
	_dialogue_label.add_theme_font_size_override("font_size", desired_size)
	_dialogue_label.add_theme_color_override("font_color", COLOR_WOOD if _dict_bool(_current_command, "thought", false) else COLOR_INK)
	if _next_button != null and _command_op(_current_command) == "say":
		_next_button.text = "下一句  >" if _text_complete else "顯示全文"


func _clear_choice_buttons() -> void:
	_current_options.clear()
	for button: Button in _choice_buttons:
		if is_instance_valid(button):
			button.queue_free()
	_choice_buttons.clear()


func _make_choice_button(label_text: String, option_index: int) -> Button:
	var button: Button = Button.new()
	button.name = "Choice_%d" % option_index
	button.text = label_text
	button.custom_minimum_size = Vector2(0.0, 96.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 28)
	button.add_theme_color_override("font_color", COLOR_INK)
	button.add_theme_color_override("font_hover_color", COLOR_INK)
	button.add_theme_color_override("font_focus_color", COLOR_INK)
	button.add_theme_color_override("font_pressed_color", COLOR_PAPER_LIGHT)
	button.add_theme_stylebox_override("normal", _make_style(COLOR_PAPER, COLOR_PAPER_DARK, 2, 1, 10.0))
	button.add_theme_stylebox_override("hover", _make_style(Color("#f6e1c0"), COLOR_GOLD, 2, 2, 10.0))
	button.add_theme_stylebox_override("pressed", _make_style(COLOR_RED, COLOR_RED_DARK, 2, 2, 10.0))
	button.add_theme_stylebox_override("focus", _make_style(Color("#f6e1c0"), COLOR_RED, 2, 2, 10.0))
	button.add_theme_stylebox_override("disabled", _make_style(COLOR_PAPER_DARK, COLOR_PAPER_DARK, 2, 1, 10.0))
	return button


func _option_label(option_id: String) -> String:
	for option: Dictionary in _current_options:
		if _dict_string(option, "id") == option_id:
			return _dict_string(option, "label", option_id)
	return option_id


func _speaker_display_name(actor_id: String, thought: bool) -> String:
	var name_value: String = str(SPEAKER_NAMES.get(actor_id, actor_id))
	if thought:
		return "%s・心聲" % name_value
	return name_value


func _append_history_entry(entry: Dictionary) -> void:
	var copy: Dictionary = entry.duplicate(true)
	var key: String = _dict_string(copy, "key")
	if not key.is_empty() and _history_has_key(key):
		return
	_history.append(copy)


func _history_has_key(key: String) -> bool:
	if key.is_empty():
		return false
	for entry: Dictionary in _history:
		if _dict_string(entry, "key") == key:
			return true
	return false


func _on_log_pressed() -> void:
	if _log_overlay == null or _screen_mode == "title" or _screen_mode == "log":
		return
	_mode_before_log = _screen_mode
	_screen_mode = "log"
	_refresh_log_entries()
	_log_overlay.visible = true
	_publish_qa_state()


func _on_log_close_pressed() -> void:
	if _log_overlay == null:
		return
	_log_overlay.visible = false
	_screen_mode = _mode_before_log
	_publish_qa_state()


func _refresh_log_entries() -> void:
	if _log_entries == null:
		return
	for child: Node in _log_entries.get_children():
		child.queue_free()

	if _history.is_empty():
		var empty_label: Label = _make_log_label("還沒有讀過的台詞。", false)
		return

	for entry: Dictionary in _history:
		var kind: String = _dict_string(entry, "kind", "say")
		var entry_label: Label
		if kind == "choice":
			entry_label = _make_log_label("選擇　%s" % _dict_string(entry, "text"), true)
		else:
			var speaker: String = _dict_string(entry, "speaker", "narrator")
			var thought: bool = _dict_bool(entry, "thought", false)
			var prefix: String = _speaker_display_name(speaker, thought)
			entry_label = _make_log_label("%s\n%s" % [prefix, _dict_string(entry, "text")], thought)

	call_deferred("_scroll_log_to_bottom")


func _scroll_log_to_bottom() -> void:
	if _log_scroll == null:
		return
	_log_scroll.set_deferred("scroll_vertical", _log_scroll.get_v_scroll_bar().max_value)


func _make_log_label(value: String, emphasized: bool) -> Label:
	var label: Label = _make_label(_log_entries, Rect2(Vector2.ZERO, Vector2(556.0, 0.0)), value,
		22 if not emphasized else 23, COLOR_WOOD if emphasized else COLOR_INK,
		HORIZONTAL_ALIGNMENT_LEFT)
	label.custom_minimum_size = Vector2(540.0, 44.0 if emphasized else 64.0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	return label


func _on_mute_pressed() -> void:
	_audio_muted = not _audio_muted
	for player_variant: Variant in _audio_players.values():
		if player_variant is AudioStreamPlayer:
			var player: AudioStreamPlayer = player_variant as AudioStreamPlayer
			player.volume_db = -80.0 if _audio_muted else 0.0
	_update_mute_button_text()
	_publish_qa_state()


func _update_mute_button_text() -> void:
	var text_value: String = "音效：關" if _audio_muted else "音效：開"
	if _title_mute_button != null:
		_title_mute_button.text = text_value
	if _story_mute_button != null:
		_story_mute_button.text = text_value


func _start_audio_after_user_gesture() -> void:
	_play_sound("paper")
	var ambient_variant: Variant = _audio_players.get("ambient")
	if ambient_variant is AudioStreamPlayer:
		var ambient: AudioStreamPlayer = ambient_variant as AudioStreamPlayer
		if ambient.stream != null and not _audio_muted and not ambient.playing:
			ambient.play()


func _play_sound(audio_id: String) -> void:
	if _audio_muted:
		return
	var player_variant: Variant = _audio_players.get(audio_id)
	if not player_variant is AudioStreamPlayer:
		return
	var player: AudioStreamPlayer = player_variant as AudioStreamPlayer
	if player.stream != null:
		player.play()


func _show_title() -> void:
	_cancel_generation()
	_screen_mode = "title"
	_title_screen.visible = true
	_story_screen.visible = false
	_log_overlay.visible = false
	_update_mute_button_text()
	_refresh_continue_button()
	_show_title_error(_story_error)
	if _start_button != null and not _start_button.disabled:
		_start_button.grab_focus()
	_publish_qa_state()


func _show_story_screen() -> void:
	_title_screen.visible = false
	_story_screen.visible = true
	_log_overlay.visible = false
	_screen_mode = "busy"
	_next_button.visible = false
	_next_button.disabled = true
	_update_mute_button_text()
	_publish_qa_state()


func _show_title_error(message: String) -> void:
	var error_label: Label = _title_screen.get_node_or_null("StoryError") as Label
	if error_label == null:
		return
	error_label.text = message
	error_label.visible = not message.is_empty()


func _show_runtime_error(message: String) -> void:
	_story_busy = false
	_story_error = message
	_speaker_label.text = "演出錯誤"
	_dialogue_label.text = message
	_dialogue_label.add_theme_color_override("font_color", COLOR_RED)
	_next_button.visible = false
	_screen_mode = "story"
	_publish_qa_state()


func _refresh_continue_button() -> void:
	if _continue_button == null:
		return
	_continue_button.disabled = not _has_valid_save()
	_continue_button.text = "繼續閱讀" if not _continue_button.disabled else "尚無續讀"


func _has_valid_save() -> bool:
	var payload: Dictionary = _read_save_payload()
	return not payload.is_empty() and _validate_save_payload(payload)


func _read_save_payload() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	# store_var/get_var(false) deliberately preserve Stage's Vector2 and Color
	# values.  JSON is reserved for the read-only QA bridge, whose state is
	# converted to plain x/y objects by _json_safe().
	var parsed: Variant = file.get_var(false)
	file.close()
	if not parsed is Dictionary:
		return {}
	return (parsed as Dictionary).duplicate(true)


func _validate_save_payload(payload: Dictionary) -> bool:
	if int(payload.get("schema", -1)) != SAVE_SCHEMA:
		return false
	if str(payload.get("story_id", "")) != SAVE_STORY_ID:
		return false
	var runner_snapshot_value: Variant = payload.get("runner", null)
	var stage_snapshot_value: Variant = payload.get("stage", null)
	var history_value: Variant = payload.get("history", null)
	if not runner_snapshot_value is Dictionary or not stage_snapshot_value is Dictionary or not history_value is Array:
		return false
	var runner_snapshot: Dictionary = runner_snapshot_value as Dictionary
	if not runner_snapshot.has("version") or not runner_snapshot.has("node_id") \
			or not runner_snapshot.has("step_index") or not runner_snapshot.has("flags"):
		return false
	if not (runner_snapshot.get("flags") is Dictionary):
		return false
	if not _validate_stage_snapshot(stage_snapshot_value as Dictionary):
		return false

	for history_entry_variant: Variant in history_value as Array:
		if not history_entry_variant is Dictionary:
			return false

	# 用一個全新的 runner 先驗證版本、節點、步序和 flags；只有成功才會
	# 對目前遊戲的 runner 呼叫 restore，避免壞檔破壞現況。
	var probe_object: Object = STORY_RUNNER_SCRIPT.new()
	var probe: RefCounted = probe_object as RefCounted
	if probe == null:
		return false
	if not bool(probe.call("load_story", STORY_DATA_PATH)):
		return false
	return bool(probe.call("restore", runner_snapshot))


func _validate_stage_snapshot(snapshot_data: Dictionary) -> bool:
	if int(snapshot_data.get("version", -1)) != STAGE_SNAPSHOT_VERSION:
		return false
	var actors_value: Variant = snapshot_data.get("actors", null)
	var camera_value: Variant = snapshot_data.get("camera", null)
	if not actors_value is Dictionary or not camera_value is Dictionary:
		return false
	var actors: Dictionary = actors_value as Dictionary
	for actor_id: String in ["gintoki", "shinpachi", "otose"]:
		var actor_value: Variant = actors.get(actor_id, null)
		if not actor_value is Dictionary:
			return false
		var actor_state: Dictionary = actor_value as Dictionary
		if not _is_vector2_or_xy(actor_state.get("position", null)):
			return false
		if actor_state.has("modulate") and not actor_state.get("modulate") is Color:
			return false
	var camera: Dictionary = camera_value as Dictionary
	return _is_vector2_or_xy(camera.get("position", null))


func _is_vector2_or_xy(value: Variant) -> bool:
	if value is Vector2:
		return true
	if not value is Dictionary:
		return false
	var dictionary_value: Dictionary = value as Dictionary
	return dictionary_value.has("x") and dictionary_value.has("y")


func _apply_save_payload(payload: Dictionary) -> bool:
	if not _validate_save_payload(payload) or _runner == null or _stage == null:
		return false
	var runner_snapshot: Dictionary = payload.get("runner", {}) as Dictionary
	var stage_snapshot: Dictionary = payload.get("stage", {}) as Dictionary
	if not bool(_runner.call("restore", runner_snapshot)):
		return false

	# restore 不會呼叫 advance；舞台 restore 只套狀態，不重播 tween。
	_stage.call("restore", stage_snapshot)
	_history.clear()
	var history_value: Variant = payload.get("history", [])
	if history_value is Array:
		for history_entry_variant: Variant in history_value as Array:
			if history_entry_variant is Dictionary:
				_history.append((history_entry_variant as Dictionary).duplicate(true))
	_end_logged = false
	return true


func _save_game() -> void:
	if _runner == null or _stage == null:
		return
	var current: Dictionary = _runner_current()
	var current_operation: String = _command_op(current)
	if current_operation not in ["say", "choice", "end"]:
		return
	var runner_snapshot: Dictionary = _runner_snapshot()
	var stage_snapshot_value: Variant = _stage.call("snapshot")
	if runner_snapshot.is_empty() or not stage_snapshot_value is Dictionary:
		return
	var stage_snapshot: Dictionary = stage_snapshot_value as Dictionary
	if stage_snapshot.is_empty():
		return

	var history_to_save: Array[Dictionary] = []
	for entry: Dictionary in _history:
		history_to_save.append(entry.duplicate(true))
	var payload: Dictionary = {
		"schema": SAVE_SCHEMA,
		"story_id": SAVE_STORY_ID,
		"runner": runner_snapshot,
		"stage": stage_snapshot,
		"history": history_to_save,
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_var(payload, false)
	file.close()


func _delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _cancel_generation() -> void:
	_generation += 1
	_story_busy = false
	_cancel_typewriter()
	if _stage != null:
		_stage.call("cancel")


func _is_generation_current(generation: int) -> bool:
	return generation == _generation and is_inside_tree()


func _runner_current() -> Dictionary:
	if _runner == null:
		return {}
	var current_value: Variant = _runner.call("current")
	if not current_value is Dictionary:
		return {}
	return (current_value as Dictionary).duplicate(true)


func _runner_snapshot() -> Dictionary:
	if _runner == null:
		return {}
	var snapshot_value: Variant = _runner.call("snapshot")
	if not snapshot_value is Dictionary:
		return {}
	return (snapshot_value as Dictionary).duplicate(true)


func _runner_string(property_name: String, fallback: String) -> String:
	if _runner == null:
		return fallback
	var value: Variant = _runner.get(property_name)
	var text_value: String = str(value)
	return fallback if text_value.is_empty() else text_value


func _runner_error_is_empty() -> bool:
	return _runner_string("error_message", "").is_empty()


func _command_op(command: Dictionary) -> String:
	var operation: String = _dict_string(command, "op")
	if operation.is_empty():
		operation = _dict_string(command, "type")
	return operation


func _line_key(command: Dictionary, kind: String) -> String:
	var node_id: String = _dict_string(command, "node_id", "unknown")
	var step_index: String = str(command.get("step_index", -1))
	return "%s:%s:%s" % [kind, node_id, step_index]


func _dict_string(data: Dictionary, key: String, fallback: String = "") -> String:
	var value: Variant = data.get(key, fallback)
	return str(value)


func _dict_bool(data: Dictionary, key: String, fallback: bool = false) -> bool:
	var value: Variant = data.get(key, fallback)
	return bool(value)


func _make_color_rect(parent: Node, rect: Rect2, color: Color) -> ColorRect:
	var rectangle: ColorRect = ColorRect.new()
	rectangle.position = rect.position
	rectangle.size = rect.size
	rectangle.color = color
	parent.add_child(rectangle)
	return rectangle


func _make_label(parent: Node, rect: Rect2, value: String, font_size: int, color: Color,
		alignment: HorizontalAlignment) -> Label:
	var label: Label = Label.new()
	label.position = rect.position
	label.size = rect.size
	label.text = value
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _make_button(parent: Node, rect: Rect2, value: String, font_size: int, accent: Color) -> Button:
	var button: Button = Button.new()
	button.position = rect.position
	button.size = rect.size
	button.text = value
	button.focus_mode = Control.FOCUS_ALL
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", COLOR_PAPER_LIGHT)
	button.add_theme_color_override("font_hover_color", COLOR_PAPER_LIGHT)
	button.add_theme_color_override("font_pressed_color", COLOR_PAPER_LIGHT)
	button.add_theme_color_override("font_focus_color", COLOR_PAPER_LIGHT)
	button.add_theme_color_override("font_disabled_color", COLOR_DISABLED)
	button.add_theme_stylebox_override("normal", _make_style(accent, accent.darkened(0.25), 3, 2, 12.0))
	button.add_theme_stylebox_override("hover", _make_style(accent.lightened(0.10), accent, 3, 3, 12.0))
	button.add_theme_stylebox_override("pressed", _make_style(accent.darkened(0.12), COLOR_RED_DARK, 3, 3, 12.0))
	button.add_theme_stylebox_override("focus", _make_style(accent.lightened(0.10), COLOR_GOLD, 3, 3, 12.0))
	button.add_theme_stylebox_override("disabled", _make_style(COLOR_PAPER_DARK, COLOR_PAPER_DARK, 3, 1, 12.0))
	parent.add_child(button)
	return button


func _make_small_button(parent: Node, rect: Rect2, value: String) -> Button:
	var button: Button = Button.new()
	button.position = rect.position
	button.size = rect.size
	button.text = value
	button.focus_mode = Control.FOCUS_ALL
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", COLOR_INK)
	button.add_theme_color_override("font_hover_color", COLOR_RED_DARK)
	button.add_theme_color_override("font_focus_color", COLOR_INK)
	button.add_theme_color_override("font_pressed_color", COLOR_PAPER_LIGHT)
	button.add_theme_stylebox_override("normal", _make_style(COLOR_PAPER, COLOR_PAPER_DARK, 2, 1, 8.0))
	button.add_theme_stylebox_override("hover", _make_style(Color("#f6e1c0"), COLOR_GOLD, 2, 2, 8.0))
	button.add_theme_stylebox_override("pressed", _make_style(COLOR_RED, COLOR_RED_DARK, 2, 2, 8.0))
	button.add_theme_stylebox_override("focus", _make_style(Color("#f6e1c0"), COLOR_RED, 2, 2, 8.0))
	button.add_theme_stylebox_override("disabled", _make_style(COLOR_PAPER_DARK, COLOR_PAPER_DARK, 2, 1, 8.0))
	parent.add_child(button)
	return button


func _make_style(background: Color, border: Color, radius: int, border_width: int,
		padding: float) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style


func _detect_qa_mode() -> void:
	_qa_enabled = false
	if not OS.has_feature("web"):
		return
	var result: Variant = JavaScriptBridge.eval(
		"new URLSearchParams(window.location.search).get('qa') === '1'")
	_qa_enabled = bool(result)


func _publish_qa_state() -> void:
	if not _qa_enabled or not OS.has_feature("web"):
		return

	var current: Dictionary = _runner_current()
	var snapshot: Dictionary = _runner_snapshot()
	var choices: Array[Dictionary] = []
	for option_index: int in range(_choice_buttons.size()):
		var choice_button: Button = _choice_buttons[option_index]
		if not is_instance_valid(choice_button) or not choice_button.is_visible_in_tree():
			continue
		if choice_button.disabled:
			continue
		var option: Dictionary = _current_options[option_index] if option_index < _current_options.size() else {}
		choices.append({
			"id": _dict_string(option, "id"),
			"label": _dict_string(option, "label"),
			"rect": _control_rect(choice_button),
		})

	var controls: Dictionary = {}
	_add_control_rect(controls, "begin", _start_button)
	_add_control_rect(controls, "continue", _continue_button)
	_add_control_rect(controls, "next", _next_button)
	_add_control_rect(controls, "dialogue", _text_panel)
	_add_control_rect(controls, "log", _story_log_button)
	_add_control_rect(controls, "log_close", _log_close_button)
	_add_control_rect(controls, "restart", _story_restart_button)
	_add_control_rect(controls, "mute", _story_mute_button if _story_screen.visible else _title_mute_button)

	var actors: Dictionary = {}
	if _stage != null:
		var actors_value: Variant = _stage.call("get_actor_state")
		if actors_value is Dictionary:
			actors = (actors_value as Dictionary).duplicate(true)

	var flags: Dictionary = {}
	var flags_value: Variant = snapshot.get("flags", {})
	if flags_value is Dictionary:
		flags = (flags_value as Dictionary).duplicate(true)

	var state: Dictionary = {
		"screen": _qa_screen_name(),
		"text": _visible_text,
		"speaker": _current_speaker,
		"node_id": _dict_string(current, "node_id", _dict_string(snapshot, "node_id")),
		"step_index": int(current.get("step_index", snapshot.get("step_index", -1))),
		"flags": flags,
		"text_complete": _text_complete,
		"audio_muted": _audio_muted,
		"viewport": {
			"width": get_viewport_rect().size.x,
			"height": get_viewport_rect().size.y,
		},
		"actors": actors,
		"choices": choices,
		"controls": controls,
	}

	var safe_state: Variant = _json_safe(state)
	var json_state: String = JSON.stringify(safe_state)
	var script_text: String = "(function(){var d=%s;var f=function(o){if(o&&typeof o==='object'&&!Object.isFrozen(o)){Object.freeze(o);Object.getOwnPropertyNames(o).forEach(function(k){f(o[k]);});}return o;};window.__debtQA=f(d);})();" % json_state
	JavaScriptBridge.eval(script_text)


func _publish_qa_state_after_layout() -> void:
	await get_tree().process_frame
	_publish_qa_state()


func _qa_screen_name() -> String:
	if _screen_mode == "log":
		return "log"
	if _story_busy or _screen_mode == "busy":
		return "busy"
	if _screen_mode == "choice":
		return "choice"
	if _screen_mode == "end":
		return "end"
	if _screen_mode == "title":
		return "title"
	return "story"


func _add_control_rect(target: Dictionary, key: String, control: Control) -> void:
	if control == null or not is_instance_valid(control) or not control.is_visible_in_tree():
		return
	if control is BaseButton and (control as BaseButton).disabled:
		return
	target[key] = _control_rect(control)


func _control_rect(control: Control) -> Dictionary:
	var rect: Rect2 = control.get_global_rect()
	return {
		"x": rect.position.x,
		"y": rect.position.y,
		"width": rect.size.x,
		"height": rect.size.y,
	}


func _json_safe(value: Variant) -> Variant:
	if value is Dictionary:
		var safe_dictionary: Dictionary = {}
		for key_variant: Variant in (value as Dictionary).keys():
			safe_dictionary[str(key_variant)] = _json_safe((value as Dictionary).get(key_variant))
		return safe_dictionary
	if value is Array:
		var safe_array: Array[Variant] = []
		for item: Variant in value as Array:
			safe_array.append(_json_safe(item))
		return safe_array
	if value is Vector2:
		var vector_2: Vector2 = value as Vector2
		return {"x": vector_2.x, "y": vector_2.y}
	if value is Vector3:
		var vector_3: Vector3 = value as Vector3
		return {"x": vector_3.x, "y": vector_3.y, "z": vector_3.z}
	if value is Color:
		var color_value: Color = value as Color
		return {"r": color_value.r, "g": color_value.g, "b": color_value.b, "a": color_value.a}
	return value
