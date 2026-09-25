extends Control

## V1 直立視覺小說外殼。
##
## 分層由下到上：背景 → 立繪 → 特效 → 對話框 → 懸浮按鈕 → 彈出視窗。
## 故事流程由 scripts/story_runner.gd 執行；背景、立繪與素材從同一份 catalog 載入。
## 所有輸入只處理滑鼠事件（專案把觸控模擬成滑鼠），一次觸控只會觸發一次動作。

const STORY_RUNNER_SCRIPT: Script = preload("res://scripts/story_runner.gd")
const FLOATING_BUTTON_SCRIPT: Script = preload("res://scripts/floating_button.gd")
const SPRITE_SCRIPT: Script = preload("res://scripts/placeholder_sprite.gd")
const SAVE_SLOTS_SCRIPT: Script = preload("res://scripts/save_slots.gd")
const UI_STYLES_SCRIPT: Script = preload("res://scripts/ui_styles.gd")

const DESIGN_WIDTH: float = 1080.0
const FONT_PATH: String = "res://assets/fonts/story-cjk.ttc"
const SAVE_SCHEMA: int = 3
const UI_PREFERENCE_PATH: String = "user://ui_preferences.cfg"
const PHASE3_STORY_PATH: String = "res://data/phase3_story.json"
const PHASE3_SAVE_PATH: String = "user://strawberry_phase3.save"
const DEFAULT_BOKE_TIMER_SECONDS: float = 8.0

@export_file("*.json") var story_path: String = "res://data/debt_story.json"
@export var save_path: String = "user://debt_commission.save"
var ui_preference_path: String = UI_PREFERENCE_PATH

const TYPEWRITER_INTERVAL: float = 0.032
const DIALOG_RATIO: float = 0.28
const EDGE: float = 24.0
const DIALOG_GAP: float = 12.0
const QUICKBAR_HEIGHT: float = 160.0
const TEXT_FONT_MAX: int = 56
const TEXT_FONT_MIN: int = 42
const TEXT_MAX_LINES: int = 3
const LONG_PRESS_SEC: float = 0.5
const TAP_SLOP: float = 30.0
const SWIPE_DISTANCE: float = 140.0
const IDLE_SEC: float = 3.0
const IDLE_ALPHA: float = 0.4
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

const SLOT_X: Dictionary = {"left": 0.2, "center": 0.5, "right": 0.8}

const COLOR_LETTERBOX: Color = Color("#0b0d18")
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
var _background_rect: TextureRect = null

var _game: Control = null
var _bg_layer: Control = null
var _char_layer: Control = null
var _fx_layer: Control = null
var _dialog_layer: Control = null
var _float_layer: Control = null
var _popup_layer: Control = null
var _title_screen: Control = null
var _title_style_panel: Panel = null
var _title_style_caption: Label = null
var _title_style_row: HBoxContainer = null
var _title_style_buttons: Dictionary = {}
var _menu_style_caption: Label = null
var _menu_style_row: HBoxContainer = null
var _menu_style_buttons: Dictionary = {}
var _menu_panel_shell: Panel = null

var _place_tag: Label = null
var _sprites: Dictionary = {}
var _tap_catcher: Control = null
var _dialog_panel: Panel = null
var _text_label: Label = null
var _next_indicator: Label = null
var _name_plate: Panel = null
var _name_label: Label = null
var _choice_box: VBoxContainer = null
var _end_box: HBoxContainer = null
var _quickbar: HBoxContainer = null
var _log_button: Button = null
var _auto_button: Button = null
var _skip_button: Button = null
var _material_button: Button = null
var _restart_button: Button = null
var _end_title_button: Button = null
var _menu_button: Control = null
var _save_button: Control = null
var _menu_overlay: Control = null
var _menu_dim: ColorRect = null
var _menu_panel: VBoxContainer = null
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
var _title_error: Label = null
var _phase3_hud: Panel = null
var _phase3_stats_label: Label = null
var _phase3_inventory_label: Label = null
var _phase3_timer_label: Label = null
var _investigation_continue_button: Button = null
var _hotspot_buttons: Dictionary = {}
var _boke_controls: HBoxContainer = null
var _boke_previous_button: Button = null
var _boke_line_label: Label = null
var _boke_next_button: Button = null
var _boke_listen_button: Button = null
var _boke_tsukkomi_button: Button = null
var _game_over_retry_button: Button = null

var _slot_overlay: Control = null
var _slot_panel: Panel = null
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
var _slot_confirmation_panel: Panel = null
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
var _ui_style_id: String = "cinema"

var _screen_mode: String = "title"
var _mode_before_overlay: String = "story"
var _story_busy: bool = false
var _generation: int = 0
var _line_generation: int = 0
var _text_complete: bool = true
var _full_text: String = ""
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
var _gesture_long: bool = false
var _gesture_start: Vector2 = Vector2.ZERO
var _gesture_token: int = 0
var _last_activity_ms: int = 0
var _toast_token: int = 0
var _float_alpha: float = 1.0

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

	_select_story_variant()
	_load_story()
	_build_audio()
	_build_ui()
	_apply_ui_style()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_detect_qa_mode()
	_show_title()


func _select_story_variant() -> void:
	# 固定的驗收片段由網址開啟；正式試玩的入口仍使用場景設定的故事。
	if not OS.has_feature("web"):
		return
	var sample: String = str(JavaScriptBridge.eval(
		"new URLSearchParams(window.location.search).get('sample') || ''"))
	if sample == "phase2":
		story_path = "res://data/phase2_story.json"
		save_path = "user://strawberry_phase2.save"
	elif sample == "phase3":
		story_path = PHASE3_STORY_PATH
		save_path = PHASE3_SAVE_PATH


func _load_story() -> void:
	_runner = STORY_RUNNER_SCRIPT.new() as RefCounted
	_story_ready = bool(_runner.call("load_story", story_path))
	if not _story_ready:
		_story_error = _runner_string("error_message", "故事資料尚未就緒。")
		return
	var initial_snapshot: Dictionary = _runner.call("snapshot") as Dictionary
	_phase3_enabled = str(initial_snapshot.get("story_id", "")) == "strawberry_phase3"
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
	var letterbox: ColorRect = ColorRect.new()
	letterbox.color = COLOR_LETTERBOX
	letterbox.set_meta("ui_style_role", "letterbox")
	letterbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(letterbox)
	letterbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_game = Control.new()
	_game.name = "Game"
	_game.clip_contents = true
	_game.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_game)

	_bg_layer = _add_layer("BackgroundLayer")
	_char_layer = _add_layer("CharacterLayer")
	_fx_layer = _add_layer("EffectLayer")
	_dialog_layer = _add_layer("DialogueLayer")
	_float_layer = _add_layer("FloatingLayer")
	_popup_layer = _add_layer("PopupLayer")
	_title_screen = _add_layer("TitleScreen")

	_build_background()
	_build_sprites()
	_build_phase3_hud()
	_build_dialogue()
	_build_floating_buttons()
	_build_menu()
	_build_log()
	_build_toast()
	_build_title()
	_build_slot_picker()


func _add_layer(layer_name: String) -> Control:
	var layer: Control = Control.new()
	layer.name = layer_name
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game.add_child(layer)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return layer


func _build_background() -> void:
	_background_gradient = Gradient.new()
	_background_gradient.set_color(0, Color("#2e2a45"))
	_background_gradient.set_color(1, Color("#b9794f"))
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = _background_gradient
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	_background_rect = TextureRect.new()
	_background_rect.texture = texture
	_background_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_background_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_layer.add_child(_background_rect)
	_background_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_place_tag = _make_label(_bg_layer, "萬事屋・客廳", 40, COLOR_TEXT)
	_place_tag.set_meta("ui_style_role", "scene_overlay")
	_place_tag.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.72))
	_place_tag.add_theme_constant_override("outline_size", 4)
	var initial_bg: String = "yorozuya_living_room"
	if not _backgrounds.has(initial_bg) and not _backgrounds.is_empty():
		initial_bg = str(_backgrounds.keys()[0])
	_apply_background(initial_bg)


func _apply_background(background_id: String) -> void:
	if not _backgrounds.has(background_id):
		return
	var info: Dictionary = _backgrounds[background_id] as Dictionary
	_current_bg_id = background_id
	_place_tag.text = str(info.get("label", background_id))
	var path: String = str(info.get("path", ""))
	if not path.is_empty():
		var art: Resource = load(path)
		if art is Texture2D:
			_background_rect.texture = art as Texture2D
			_background_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			return
	_background_gradient.set_color(0, Color(str(info.get("top", "#2e2a45"))))
	_background_gradient.set_color(1, Color(str(info.get("bottom", "#b9794f"))))
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = _background_gradient
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	_background_rect.texture = texture
	_background_rect.stretch_mode = TextureRect.STRETCH_SCALE


func _build_sprites() -> void:
	for actor_id: String in _actors.keys():
		var info: Dictionary = _actors[actor_id] as Dictionary
		var sprite: Control = SPRITE_SCRIPT.new() as Control
		_char_layer.add_child(sprite)
		sprite.call("setup", actor_id, str(info["name"]), Color(str(info["color"])), _font)
		var art_path: String = str(info.get("path", ""))
		if not art_path.is_empty():
			var art: Resource = load(art_path)
			if art is Texture2D:
				sprite.call("set_art", art, bool(info.get("silhouette", false)))
		sprite.visible = false
		_sprites[actor_id] = sprite


func _build_phase3_hud() -> void:
	_phase3_hud = Panel.new()
	_phase3_hud.name = "Phase3Hud"
	_phase3_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phase3_hud.set_meta("ui_style_role", "hud")
	_phase3_hud.add_theme_stylebox_override("panel", _make_style(COLOR_PANEL, COLOR_BUTTON_BORDER, 8, 0))
	_fx_layer.add_child(_phase3_hud)
	_phase3_stats_label = _make_label(_phase3_hud, "眼鏡 5/5　力量 0/100", 30, COLOR_TEXT)
	_phase3_stats_label.name = "Phase3Stats"
	_phase3_inventory_label = _make_label(_phase3_hud, "線索：尚無", 27, COLOR_TEXT_SOFT)
	_phase3_inventory_label.name = "Phase3Inventory"
	_phase3_timer_label = _make_label(_phase3_hud, "", 30, COLOR_GOLD)
	_phase3_timer_label.name = "Phase3Timer"
	_phase3_hud.visible = false


func _apply_character(command: Dictionary) -> void:
	var actor_id: String = _dict_string(command, "id")
	if not _sprites.has(actor_id):
		return
	var sprite: Control = _sprites[actor_id] as Control
	sprite.visible = _dict_bool(command, "visible", true)
	if command.has("expression"):
		sprite.call("set_expression", _dict_string(command, "expression"))
	if command.has("position"):
		_actor_slots[actor_id] = _dict_string(command, "position")
		_layout_sprite(actor_id)


func _build_dialogue() -> void:
	# 全畫面點擊區在對話框之下；對話框本身不攔截，點畫面任一處都由這裡處理手勢。
	_tap_catcher = Control.new()
	_tap_catcher.name = "TapCatcher"
	_tap_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_tap_catcher.gui_input.connect(_on_catcher_input)
	_dialog_layer.add_child(_tap_catcher)
	_tap_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_dialog_panel = Panel.new()
	_dialog_panel.name = "DialoguePanel"
	_dialog_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialog_panel.set_meta("ui_style_role", "dialogue")
	_dialog_panel.add_theme_stylebox_override("panel", _make_dialog_style())
	_dialog_layer.add_child(_dialog_panel)

	_text_label = _make_label(_dialog_panel, "", TEXT_FONT_MAX, COLOR_TEXT)
	_text_label.name = "DialogueText"
	_text_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_text_label.add_theme_constant_override("line_spacing", 10)
	_text_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.88))
	_text_label.add_theme_constant_override("outline_size", 4)

	_next_indicator = _make_label(_dialog_panel, "▼", 40, COLOR_UI_ACCENT)
	_next_indicator.name = "NextIndicator"
	var blink: Tween = create_tween().set_loops()
	blink.tween_property(_next_indicator, "modulate:a", 0.15, 0.45)
	blink.tween_property(_next_indicator, "modulate:a", 1.0, 0.45)

	_name_plate = Panel.new()
	_name_plate.name = "NamePlate"
	_name_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_plate.set_meta("ui_style_role", "name")
	_name_plate.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_dialog_layer.add_child(_name_plate)
	_name_label = _make_label(_name_plate, "", 44, COLOR_TEXT)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
	_name_label.add_theme_constant_override("outline_size", 3)

	_choice_box = VBoxContainer.new()
	_choice_box.name = "Choices"
	_choice_box.alignment = BoxContainer.ALIGNMENT_END
	_choice_box.add_theme_constant_override("separation", 28)
	_choice_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialog_layer.add_child(_choice_box)

	_end_box = HBoxContainer.new()
	_end_box.name = "EndButtons"
	_end_box.add_theme_constant_override("separation", 28)
	_end_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialog_layer.add_child(_end_box)
	_restart_button = _make_button(_end_box, "重玩", 46)
	_restart_button.pressed.connect(_on_restart_pressed)
	_game_over_retry_button = _make_button(_end_box, "檢查點重試", 42)
	_game_over_retry_button.name = "GameOverRetry"
	_game_over_retry_button.visible = false
	_game_over_retry_button.pressed.connect(_on_game_over_retry_pressed)
	_end_title_button = _make_button(_end_box, "回標題", 46)
	_end_title_button.pressed.connect(_show_title)
	for button: Button in [_restart_button, _game_over_retry_button, _end_title_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 160.0

	_investigation_continue_button = _make_button(_dialog_panel, "檢查完成・繼續", 34)
	_investigation_continue_button.name = "InvestigationContinue"
	_set_button_style(_investigation_continue_button, "primary")
	_investigation_continue_button.visible = false
	_investigation_continue_button.pressed.connect(_on_investigation_continue_pressed)

	_boke_controls = HBoxContainer.new()
	_boke_controls.name = "BokeControls"
	_boke_controls.add_theme_constant_override("separation", 12)
	_boke_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boke_controls.visible = false
	_dialog_panel.add_child(_boke_controls)
	_boke_previous_button = _make_button(_boke_controls, "‹ 前句", 30)
	_boke_previous_button.name = "BokePrevious"
	_boke_previous_button.pressed.connect(_on_boke_previous_pressed)
	_boke_line_label = _make_label(_boke_controls, "1 / 1", 28, COLOR_GOLD)
	_boke_line_label.name = "BokeLineIndex"
	_boke_line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boke_line_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_boke_line_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boke_next_button = _make_button(_boke_controls, "後句 ›", 30)
	_boke_next_button.name = "BokeNext"
	_boke_next_button.pressed.connect(_on_boke_next_pressed)
	_boke_listen_button = _make_button(_boke_controls, "聽仔細", 30)
	_boke_listen_button.name = "BokeListen"
	_boke_listen_button.pressed.connect(_on_boke_listen_pressed)
	_boke_tsukkomi_button = _make_button(_boke_controls, "吐槽！", 32)
	_boke_tsukkomi_button.name = "BokeTsukkomi"
	_set_button_style(_boke_tsukkomi_button, "boke_primary")
	_boke_tsukkomi_button.pressed.connect(_on_boke_tsukkomi_pressed)

	_quickbar = HBoxContainer.new()
	_quickbar.name = "QuickBar"
	_quickbar.add_theme_constant_override("separation", 16)
	_quickbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialog_layer.add_child(_quickbar)
	_log_button = _make_button(_quickbar, "紀錄", 34)
	_set_button_style(_log_button, "quickbar")
	_log_button.pressed.connect(_open_log)
	_auto_button = _make_button(_quickbar, "自動", 34)
	_set_button_style(_auto_button, "quickbar")
	_auto_button.pressed.connect(func() -> void: _set_auto(not _auto))
	_skip_button = _make_button(_quickbar, "略讀", 34)
	_set_button_style(_skip_button, "quickbar")
	_skip_button.pressed.connect(func() -> void: _set_skip(not _skip))
	_material_button = _make_button(_quickbar, "素材", 34)
	_set_button_style(_material_button, "quickbar")
	_material_button.disabled = not _phase3_enabled
	_material_button.pressed.connect(_show_inventory_feedback)
	for button: Button in [_log_button, _auto_button, _skip_button, _material_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = QUICKBAR_HEIGHT


func _build_floating_buttons() -> void:
	_menu_button = FLOATING_BUTTON_SCRIPT.new() as Control
	_menu_button.name = "MenuButton"
	_float_layer.add_child(_menu_button)
	_menu_button.call("setup", "≡", _font, _ui_style_id)
	_menu_button.connect("tapped", _open_menu)

	_save_button = FLOATING_BUTTON_SCRIPT.new() as Control
	_save_button.name = "SaveButton"
	_float_layer.add_child(_save_button)
	_save_button.call("setup", "S", _font, _ui_style_id)
	_save_button.connect("tapped", func() -> void: _open_slot_picker("save"))
	_save_button.connect("long_pressed", func() -> void: _open_slot_picker("save"))
	for button: Control in [_menu_button, _save_button]:
		button.connect("moved", _publish_qa_state)


func _build_menu() -> void:
	_menu_overlay = Control.new()
	_menu_overlay.name = "MenuOverlay"
	_menu_overlay.visible = false
	_menu_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup_layer.add_child(_menu_overlay)
	_menu_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 背景變暗＋模糊；點背景任一處關閉選單。
	var blur: Shader = Shader.new()
	blur.code = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * 3.0;
	vec3 sum = vec3(0.0);
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			sum += texture(screen_tex, SCREEN_UV + vec2(float(x), float(y)) * px).rgb;
		}
	}
	COLOR = vec4(mix(sum / 25.0, vec3(0.02, 0.03, 0.07), 0.5), 1.0);
}
"""
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = blur
	_menu_dim = ColorRect.new()
	_menu_dim.name = "MenuDim"
	_menu_dim.material = material
	_menu_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and not event.is_pressed() \
				and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_close_menu())
	_menu_overlay.add_child(_menu_dim)
	_menu_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_menu_panel_shell = Panel.new()
	_menu_panel_shell.name = "MenuPanelShell"
	_menu_panel_shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_panel_shell.set_meta("ui_style_role", "menu")
	_menu_overlay.add_child(_menu_panel_shell)

	_menu_panel = VBoxContainer.new()
	_menu_panel.name = "MenuPanel"
	_menu_panel.add_theme_constant_override("separation", 14)
	_menu_overlay.add_child(_menu_panel)
	_menu_style_caption = _make_label(_menu_panel, "介面風格", 48, COLOR_TEXT_SOFT)
	_menu_style_caption.name = "MenuStyleCaption"
	_menu_style_row = HBoxContainer.new()
	_menu_style_row.name = "MenuStyleSelector"
	_menu_style_row.add_theme_constant_override("separation", 8)
	_menu_panel.add_child(_menu_style_row)
	for style_id: String in UI_STYLES_SCRIPT.style_ids():
		var style_button: Button = _make_button(_menu_style_row,
			{"cinema": "A 映畫", "ledger": "B 委託簿", "manga": "C 分鏡"}[style_id], 48)
		style_button.name = "MenuStyle_" + style_id
		style_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		style_button.custom_minimum_size.y = 164.0
		_set_button_style(style_button, "selector", style_id == _ui_style_id)
		style_button.pressed.connect(_on_ui_style_selected.bind(style_id))
		_menu_style_buttons[style_id] = style_button
	var material_action: Callable = _show_inventory_feedback if _phase3_enabled else Callable()
	var entries: Array = [
		["save", "儲存進度", func() -> void: _open_slot_picker("save")],
		["load", "讀取存檔", func() -> void: _open_slot_picker("load")],
		["material", "吐槽素材", material_action],
		["profile", "人物檔案", Callable()],
		["log", "對話紀錄", _open_log],
		["settings", "設 定", Callable()],
		["mute", "音效：開", _toggle_mute],
		["title", "回標題", _show_title],
	]
	for entry: Array in entries:
		var button: Button = _make_button(_menu_panel, str(entry[1]), 48)
		_set_button_style(button, "menu")
		button.custom_minimum_size = Vector2(860.0, 164.0)
		var action: Callable = entry[2]
		if action.is_valid():
			button.pressed.connect(action)
		else:
			button.disabled = true
			button.visible = false  # 尚未提供的功能不佔選單操作空間。
		_menu_items[str(entry[0])] = button

	_menu_close = _make_button(_menu_overlay, "×", 60)
	_menu_close.name = "MenuClose"
	_set_button_style(_menu_close, "standard")
	_menu_close.size = Vector2(112.0, 112.0)
	_menu_close.pressed.connect(_close_menu)


func _build_log() -> void:
	_log_overlay = Panel.new()
	_log_overlay.name = "LogOverlay"
	_log_overlay.visible = false
	_log_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_log_overlay.set_meta("ui_style_role", "log")
	_log_overlay.add_theme_stylebox_override("panel", _make_style(Color(0.04, 0.05, 0.11, 0.96), COLOR_GOLD, 0, 0))
	_popup_layer.add_child(_log_overlay)
	_log_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var title: Label = _make_label(_log_overlay, "對話紀錄", 56, COLOR_GOLD)
	title.name = "LogTitle"
	_log_close = _make_button(_log_overlay, "關閉", 42)
	_log_close.name = "LogClose"
	_log_close.pressed.connect(_close_log)

	_log_scroll = ScrollContainer.new()
	_log_scroll.name = "LogScroll"
	_log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_log_overlay.add_child(_log_scroll)
	_log_entries = VBoxContainer.new()
	_log_entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_entries.add_theme_constant_override("separation", 28)
	_log_scroll.add_child(_log_entries)


func _build_toast() -> void:
	_toast = _make_label(_popup_layer, "", 40, COLOR_TEXT)
	_toast.name = "Toast"
	_toast.set_meta("ui_style_role", "toast")
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast.add_theme_stylebox_override("normal", _make_style(Color(0.035, 0.045, 0.09, 0.92), COLOR_BUTTON_BORDER, 10, 0))
	_toast.visible = false


func _build_title() -> void:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color("#1d2748"))
	gradient.set_color(1, Color("#7b3f3f"))
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	var background: TextureRect = TextureRect.new()
	background.texture = texture
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.modulate = Color(0.68, 0.73, 0.84, 1.0)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	_title_screen.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var exterior_info: Dictionary = _backgrounds.get("yorozuya_exterior", {}) as Dictionary
	var exterior_path: String = str(exterior_info.get("path", ""))
	if not exterior_path.is_empty():
		var exterior_art: Resource = load(exterior_path)
		if exterior_art is Texture2D:
			background.texture = exterior_art as Texture2D

	var logo: Label = _make_label(_title_screen, "萬事屋\n吐槽 ADV", 104, COLOR_TEXT)
	logo.name = "Logo"
	logo.set_meta("ui_style_role", "title_overlay")
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	logo.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.86))
	logo.add_theme_constant_override("outline_size", 6)
	var subtitle_text: String = "暫定標題・V1 Phase 2 劇本引擎\n試玩文本：第一場《請幫我向你老闆討債》"
	if story_path.ends_with("phase2_story.json"):
		subtitle_text = "Phase 2 草莓牛奶技術測試\n非核准的第一章劇本"
	elif story_path.ends_with("phase3_story.json"):
		subtitle_text = "Phase 3 調查與吐槽技術試片\n非核准的第一章劇本"
	var subtitle: Label = _make_label(_title_screen, subtitle_text, 36, COLOR_TEXT_SOFT)
	subtitle.name = "Subtitle"
	subtitle.set_meta("ui_style_role", "title_overlay")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	subtitle.add_theme_constant_override("outline_size", 3)

	_title_style_panel = Panel.new()
	_title_style_panel.name = "TitleStylePanel"
	_title_style_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_style_panel.set_meta("ui_style_role", "title_selector")
	_title_screen.add_child(_title_style_panel)
	_title_style_caption = _make_label(_title_style_panel, "介面風格", 44, COLOR_TEXT_SOFT)
	_title_style_caption.name = "TitleStyleCaption"
	_title_style_row = HBoxContainer.new()
	_title_style_row.name = "TitleStyleSelector"
	_title_style_row.add_theme_constant_override("separation", 8)
	_title_style_panel.add_child(_title_style_row)
	for style_id: String in UI_STYLES_SCRIPT.style_ids():
		var style_button: Button = _make_button(_title_style_row,
			{"cinema": "A 映畫", "ledger": "B 委託簿", "manga": "C 分鏡"}[style_id], 48)
		style_button.name = "TitleStyle_" + style_id
		style_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		style_button.custom_minimum_size.y = 164.0
		_set_button_style(style_button, "selector", style_id == _ui_style_id)
		style_button.pressed.connect(_on_ui_style_selected.bind(style_id))
		_title_style_buttons[style_id] = style_button

	_begin_button = _make_button(_title_screen, "新遊戲", 52)
	_begin_button.name = "BeginButton"
	_set_button_style(_begin_button, "primary")
	_begin_button.pressed.connect(_on_begin_pressed)
	_continue_button = _make_button(_title_screen, "繼續", 52)
	_continue_button.name = "ContinueButton"
	_set_button_style(_continue_button, "primary")
	_continue_button.pressed.connect(_on_continue_pressed)
	_title_load_button = _make_button(_title_screen, "讀取存檔", 52)
	_title_load_button.name = "TitleLoadButton"
	_set_button_style(_title_load_button, "subtle")
	_title_load_button.pressed.connect(func() -> void: _open_slot_picker("load"))

	_title_error = _make_label(_title_screen, "", 34, Color("#ff9d8a"))
	_title_error.name = "TitleError"
	_set_label_style(_title_error, "danger")
	_title_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_error.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	var version_text: String = "v0.3 · Phase 2"
	if story_path.ends_with("phase3_story.json"):
		version_text = "v0.4 · Phase 3"
	var version: Label = _make_label(_title_screen, version_text, 30, COLOR_TEXT_SOFT)
	version.name = "Version"
	version.set_meta("ui_style_role", "title_overlay")


func _build_slot_picker() -> void:
	_slot_overlay = Control.new()
	_slot_overlay.name = "SaveSlotOverlay"
	_slot_overlay.visible = false
	_slot_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_game.add_child(_slot_overlay)
	_slot_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim: ColorRect = ColorRect.new()
	dim.name = "SlotDim"
	dim.color = Color(0.015, 0.02, 0.06, 0.88)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and not event.is_pressed() \
				and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_close_slot_picker())
	_slot_overlay.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_slot_panel = Panel.new()
	_slot_panel.name = "SlotPanel"
	_slot_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_slot_panel.set_meta("ui_style_role", "slots")
	_slot_panel.add_theme_stylebox_override("panel", _make_style(Color(0.035, 0.045, 0.09, 0.96), COLOR_BUTTON_BORDER, 12, 0))
	_slot_overlay.add_child(_slot_panel)
	_slot_title = _make_label(_slot_panel, "存檔位", 44, COLOR_GOLD)
	_slot_title.name = "SlotTitle"
	_slot_page_label = _make_label(_slot_panel, "1 / 3", 30, COLOR_TEXT_SOFT)
	_slot_page_label.name = "SlotPage"
	_slot_close_button = _make_button(_slot_panel, "關閉", 30)
	_slot_close_button.name = "SlotClose"
	_slot_close_button.pressed.connect(_close_slot_picker)
	_slot_prev_button = _make_button(_slot_panel, "‹", 44)
	_slot_prev_button.name = "SlotPrev"
	_slot_prev_button.pressed.connect(func() -> void: _change_slot_page(-1))
	_slot_next_button = _make_button(_slot_panel, "›", 44)
	_slot_next_button.name = "SlotNext"
	_slot_next_button.pressed.connect(func() -> void: _change_slot_page(1))
	_slot_auto_button = _make_button(_slot_panel, "繼續自動存檔", 30)
	_slot_auto_button.name = "SlotAuto"
	_set_button_style(_slot_auto_button, "primary")
	_slot_auto_button.pressed.connect(_load_autosave_from_picker)

	for local_index: int in range(SAVE_SLOTS_SCRIPT.PAGE_SIZE):
		var card: Button = _make_button(_slot_panel, "", 28)
		card.name = "SlotCard%d" % (local_index + 1)
		_set_button_style(card, "slot_card")
		card.pressed.connect(_on_slot_card_pressed.bind(local_index))
		var number_label: Label = _make_label(card, "", 28, COLOR_GOLD)
		var title_label: Label = _make_label(card, "", 24, COLOR_TEXT)
		title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var time_label: Label = _make_label(card, "", 18, COLOR_TEXT_SOFT)
		var preview: TextureRect = TextureRect.new()
		preview.name = "Preview"
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		card.add_child(preview)
		_slot_card_buttons.append(card)
		_slot_card_numbers.append(number_label)
		_slot_card_titles.append(title_label)
		_slot_card_times.append(time_label)
		_slot_card_previews.append(preview)

	_slot_confirmation_overlay = Control.new()
	_slot_confirmation_overlay.name = "SlotConfirmationOverlay"
	_slot_confirmation_overlay.visible = false
	_slot_confirmation_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_slot_overlay.add_child(_slot_confirmation_overlay)
	_slot_confirmation_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var confirm_dim: ColorRect = ColorRect.new()
	confirm_dim.color = Color(0.0, 0.0, 0.0, 0.68)
	confirm_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and not event.is_pressed() \
				and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_cancel_slot_confirmation())
	_slot_confirmation_overlay.add_child(confirm_dim)
	confirm_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slot_confirmation_panel = Panel.new()
	_slot_confirmation_panel.name = "OverwriteConfirmation"
	_slot_confirmation_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_slot_confirmation_panel.set_meta("ui_style_role", "confirmation")
	_slot_confirmation_panel.add_theme_stylebox_override("panel", _make_style(Color(0.055, 0.065, 0.12, 0.98), COLOR_BUTTON_BORDER, 12, 0))
	_slot_confirmation_overlay.add_child(_slot_confirmation_panel)
	_slot_confirmation_label = _make_label(_slot_confirmation_panel, "覆寫這個存檔位？", 34, COLOR_TEXT)
	_slot_confirmation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slot_confirm_yes = _make_button(_slot_confirmation_panel, "覆寫", 30)
	_slot_confirm_yes.name = "SlotConfirmYes"
	_set_button_style(_slot_confirm_yes, "danger_action")
	_slot_confirm_yes.pressed.connect(_confirm_slot_overwrite)
	_slot_confirm_no = _make_button(_slot_confirmation_panel, "返回", 30)
	_slot_confirm_no.name = "SlotConfirmNo"
	_slot_confirm_no.pressed.connect(_cancel_slot_confirmation)


# ---------------------------------------------------------------- 版面

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
	_phase3_hud.position = Vector2(EDGE + 24.0, top + 84.0)
	_phase3_hud.size = Vector2(maxf(0.0, width - EDGE * 2.0 - 168.0), 84.0)
	_phase3_stats_label.position = Vector2(16.0, 8.0)
	_phase3_stats_label.size = Vector2(286.0, 68.0)
	_phase3_inventory_label.position = Vector2(306.0, 8.0)
	_phase3_inventory_label.size = Vector2(maxf(0.0, _phase3_hud.size.x - 530.0), 68.0)
	_phase3_timer_label.position = Vector2(maxf(306.0, _phase3_hud.size.x - 220.0), 8.0)
	_phase3_timer_label.size = Vector2(208.0, 68.0)

	var quickbar_y: float = bottom - QUICKBAR_HEIGHT
	_quickbar.position = Vector2(EDGE, quickbar_y)
	_quickbar.size = Vector2(width - EDGE * 2.0, QUICKBAR_HEIGHT)
	var dialog_height: float = roundf(height * DIALOG_RATIO) if _phase3_enabled else clampf(height * 0.20, 360.0, 440.0)
	var dialog_y: float = quickbar_y - DIALOG_GAP - dialog_height
	_dialog_panel.position = Vector2(0.0, dialog_y)
	_dialog_panel.size = Vector2(width, height - dialog_y)
	_text_label.position = Vector2(56.0, 68.0)
	var interactive_dialog: bool = _screen_mode in ["investigate", "boke_round", "tsukkomi"]
	_text_label.size = Vector2(width - 160.0, dialog_height - (272.0 if interactive_dialog else 128.0))
	_next_indicator.position = Vector2(_dialog_panel.size.x - 72.0, dialog_height - 66.0)
	_next_indicator.size = Vector2(40.0, 48.0)
	var continue_min_width: float = _investigation_continue_button.get_combined_minimum_size().x
	var continue_width: float = minf(maxf(264.0, continue_min_width), maxf(0.0, width - 112.0))
	_investigation_continue_button.position = Vector2(width - 56.0 - continue_width, dialog_height - 176.0)
	_investigation_continue_button.size = Vector2(continue_width, 160.0)
	_boke_controls.position = Vector2(40.0, dialog_height - 176.0)
	_boke_controls.size = Vector2(_dialog_panel.size.x - 80.0, 160.0)
	for boke_control: Button in [_boke_previous_button, _boke_next_button, _boke_listen_button, _boke_tsukkomi_button]:
		boke_control.custom_minimum_size = Vector2(204.0, 160.0)
	_name_plate.position = Vector2(56.0, dialog_y + 12.0)
	var name_width: float = maxf(220.0,
		_font.get_string_size(_name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x + 32.0)
	_name_plate.size.x = minf(name_width, maxf(0.0, width - EDGE * 2.0))
	_name_plate.size.y = 44.0
	_name_label.size = _name_plate.size

	_choice_box.position = Vector2(80.0, top + 180.0)
	_choice_box.size = Vector2(width - 160.0, dialog_y - 56.0 - (top + 180.0))
	_end_box.position = Vector2(80.0, dialog_y - 56.0 - 160.0)
	_end_box.size = Vector2(width - 160.0, 160.0)

	for actor_id: String in _sprites.keys():
		_layout_sprite(actor_id)

	if _menu_button.position == Vector2.ZERO and _save_button.position == Vector2.ZERO:
		_menu_button.position = Vector2(width, top + 80.0)
		_save_button.position = Vector2(width, top + 228.0)
	_update_float_bounds()

	_menu_close.position = Vector2(width - EDGE - 112.0, top)
	_layout_menu_panel()
	_log_overlay.get_node("LogTitle").position = Vector2(56.0, top + 24.0)
	_log_close.position = Vector2(width - EDGE - 220.0, top + 12.0)
	_log_close.size = Vector2(220.0, 100.0)
	_log_scroll.position = Vector2(56.0, top + 150.0)
	_log_scroll.size = Vector2(width - 112.0, bottom - (top + 150.0))
	_log_entries.custom_minimum_size = Vector2(width - 140.0, 0.0)

	_layout_title(width, height, top, bottom)
	_layout_slot_picker(width, height, top, bottom)
	if _screen_mode == "investigate":
		_layout_hotspots(_current_command)
	_publish_qa_state()


func _layout_sprite(actor_id: String) -> void:
	if _dialog_panel == null or not _sprites.has(actor_id):
		return
	var sprite: Control = _sprites[actor_id] as Control
	var slot: String = str(_actor_slots.get(actor_id, "center"))
	var slot_x: float = float(SLOT_X.get(slot, 0.5))
	# 立繪頭部在對話框上方，底部只少量進入透明對話層。
	var sprite_top: float = _dialog_panel.position.y + 180.0 - 1040.0
	var actor_info: Dictionary = _actors.get(actor_id, {}) as Dictionary
	var sprite_x: float = _game.size.x * slot_x - sprite.size.x * 0.5
	if bool(actor_info.get("silhouette", false)):
		sprite_x = clampf(sprite_x, 0.0, maxf(0.0, _game.size.x - sprite.size.x))
	sprite.size = Vector2(sprite.size.x, 1040.0)
	sprite.position = Vector2(sprite_x, sprite_top)
	sprite.queue_redraw()


# 懸浮按鈕只能停在對話框上方；選項出現時也避開選項，免得點選項變成開選單。
func _update_float_bounds() -> void:
	var top: float = EDGE + _safe_top
	var limit: float = _dialog_panel.position.y - 24.0
	if _screen_mode in ["choice", "tsukkomi"] and not _choice_buttons.is_empty():
		limit = _choice_box.position.y + _choice_box.size.y - _choice_box.get_combined_minimum_size().y - 24.0
	var bounds: Rect2 = Rect2(EDGE, top, _game.size.x - EDGE * 2.0 - 128.0, maxf(0.0, limit - 128.0 - top))
	for button: Control in [_menu_button, _save_button]:
		button.set("bounds", bounds)
		button.call("snap_to_edge", false)


func _layout_title(width: float, height: float, top: float, bottom: float) -> void:
	var logo: Label = _title_screen.get_node("Logo")
	logo.position = Vector2(140.0, height * 0.18)
	logo.size = Vector2(width - 280.0, 320.0)
	var subtitle: Label = _title_screen.get_node("Subtitle")
	subtitle.position = Vector2(60.0, logo.position.y + 360.0)
	subtitle.size = Vector2(width - 120.0, 110.0)
	_begin_button.position = Vector2(240.0, height * 0.56)
	_begin_button.size = Vector2(width - 480.0, 132.0)
	_continue_button.position = Vector2(240.0, height * 0.56 + 164.0)
	_continue_button.size = Vector2(width - 480.0, 132.0)
	_title_load_button.position = Vector2(240.0, height * 0.56 + 328.0)
	_title_load_button.size = Vector2(width - 480.0, 132.0)
	_title_style_panel.position = Vector2(56.0, height * 0.43)
	_title_style_panel.size = Vector2(width - 112.0, 224.0)
	_title_style_caption.position = Vector2(20.0, 6.0)
	_title_style_caption.size = Vector2(_title_style_panel.size.x - 40.0, 52.0)
	_title_style_row.position = Vector2(20.0, 58.0)
	_title_style_row.size = Vector2(_title_style_panel.size.x - 40.0, 164.0)
	_title_error.position = Vector2(80.0, _title_load_button.position.y + 170.0)
	_title_error.size = Vector2(width - 160.0, 100.0)
	var version: Label = _title_screen.get_node("Version")
	version.position = Vector2(EDGE + 12.0, bottom - 48.0)
	version.size = Vector2(360.0, 48.0)


func _layout_menu_panel() -> void:
	_menu_panel.size = _menu_panel.get_combined_minimum_size()
	var width: float = _game.size.x
	var anchor: Vector2 = _menu_button.position
	var on_left: bool = anchor.x + 64.0 < width * 0.5
	var x: float = (width - _menu_panel.size.x) * 0.5
	var y: float = maxf(EDGE + _safe_top + 140.0, (_game.size.y - _menu_panel.size.y) * 0.5)
	_menu_panel.position = Vector2(x, y)
	_menu_panel.pivot_offset = Vector2(0.0 if on_left else _menu_panel.size.x, 0.0)
	if _menu_panel_shell != null:
		_menu_panel_shell.position = _menu_panel.position - Vector2(14.0, 14.0)
		_menu_panel_shell.size = _menu_panel.size + Vector2(28.0, 28.0)


func _layout_slot_picker(width: float, height: float, top: float, bottom: float) -> void:
	if _slot_panel == null:
		return
	var panel_width: float = minf(width - EDGE * 2.0, 960.0)
	var usable_height: float = maxf(320.0, bottom - top)
	var panel_height: float = minf(usable_height, 1440.0)
	_slot_panel.size = Vector2(panel_width, panel_height)
	_slot_panel.position = Vector2((width - panel_width) * 0.5, top + (usable_height - panel_height) * 0.5)
	_slot_title.position = Vector2(28.0, 22.0)
	_slot_title.size = Vector2(panel_width - 220.0, 58.0)
	_slot_close_button.position = Vector2(panel_width - 142.0, 18.0)
	_slot_close_button.size = Vector2(112.0, 64.0)
	_slot_prev_button.position = Vector2(panel_width * 0.5 - 138.0, 92.0)
	_slot_prev_button.size = Vector2(72.0, 60.0)
	_slot_page_label.position = Vector2(panel_width * 0.5 - 54.0, 98.0)
	_slot_page_label.size = Vector2(108.0, 48.0)
	_slot_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slot_next_button.position = Vector2(panel_width * 0.5 + 66.0, 92.0)
	_slot_next_button.size = Vector2(72.0, 60.0)
	var content_margin: float = 24.0
	var card_gap: float = 14.0
	var card_width: float = maxf(0.0, (panel_width - content_margin * 2.0 - card_gap) * 0.5)
	var footer_height: float = 104.0
	var card_top: float = 164.0
	var card_area_height: float = maxf(120.0, panel_height - card_top - footer_height - 16.0)
	var card_height: float = maxf(40.0, (card_area_height - card_gap * 2.0) / 3.0)
	for local_index: int in range(_slot_card_buttons.size()):
		var column: int = local_index % 2
		var row: int = local_index / 2
		var card: Button = _slot_card_buttons[local_index]
		card.position = Vector2(content_margin + column * (card_width + card_gap), card_top + row * (card_height + card_gap))
		card.size = Vector2(card_width, card_height)
		var number_label: Label = _slot_card_numbers[local_index]
		number_label.position = Vector2(12.0, 6.0)
		number_label.size = Vector2(50.0, 38.0)
		number_label.add_theme_font_size_override("font_size", 26)
		var title_label: Label = _slot_card_titles[local_index]
		var preview: TextureRect = _slot_card_previews[local_index]
		var preview_width: float = clampf(card_width * 0.3, 44.0, 108.0)
		preview.position = Vector2(12.0, 12.0)
		preview.size = Vector2(preview_width, maxf(0.0, card_height - 24.0))
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		title_label.position = Vector2(preview_width + 22.0, 10.0)
		title_label.size = Vector2(maxf(0.0, card_width - preview_width - 34.0), maxf(24.0, card_height - 58.0))
		title_label.add_theme_font_size_override("font_size", 20 if width < 600.0 else 27)
		var time_label: Label = _slot_card_times[local_index]
		time_label.position = Vector2(preview_width + 22.0, card_height - 36.0)
		time_label.size = Vector2(maxf(0.0, card_width - preview_width - 34.0), 28.0)
		time_label.add_theme_font_size_override("font_size", 17 if width < 600.0 else 19)
	var footer_y: float = panel_height - 86.0
	_slot_auto_button.position = Vector2(content_margin, footer_y)
	_slot_auto_button.size = Vector2(minf(300.0, panel_width * 0.42), 62.0)
	_slot_confirmation_panel.size = Vector2(minf(panel_width - 36.0, 620.0), 250.0)
	_slot_confirmation_panel.position = Vector2((width - _slot_confirmation_panel.size.x) * 0.5,
		(height - _slot_confirmation_panel.size.y) * 0.5)
	_slot_confirmation_label.position = Vector2(24.0, 34.0)
	_slot_confirmation_label.size = Vector2(_slot_confirmation_panel.size.x - 48.0, 88.0)
	_slot_confirm_no.position = Vector2(40.0, 152.0)
	_slot_confirm_no.size = Vector2((_slot_confirmation_panel.size.x - 100.0) * 0.5, 64.0)
	_slot_confirm_yes.position = Vector2(60.0 + _slot_confirm_no.size.x, 152.0)
	_slot_confirm_yes.size = _slot_confirm_no.size


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
	_close_overlays()
	_set_ui_hidden(false)
	_set_auto(false)
	_set_skip(false)
	_screen_mode = "title"
	_phase3_hud.visible = false
	_title_screen.visible = true
	_dialog_layer.visible = false
	_float_layer.visible = false
	_continue_button.disabled = not _has_valid_save()
	_title_error.text = _story_error
	_begin_button.disabled = not _story_ready
	_publish_qa_state()


func _show_story_screen() -> void:
	_title_screen.visible = false
	_dialog_layer.visible = true
	_float_layer.visible = true
	_screen_mode = "busy"
	_phase3_hud.visible = _phase3_enabled and not _ui_hidden
	_last_activity_ms = Time.get_ticks_msec()


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
	_cancel_generation()
	_delete_save()
	_history.clear()
	_boke_time_remaining = 0.0
	_boke_timer_round_id = ""
	_restored_boke_timer_remaining = -1.0
	_restored_boke_ui_mode = ""
	_last_boke_result = ""
	_clear_hotspots()
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
				_story_busy = false
				_present_choice(command)
				_save_game()
				return
			"end":
				_story_busy = false
				_present_end(command)
				_save_game()
				return
			"investigate":
				_story_busy = false
				_present_investigation(command, false)
				_save_game()
				return
			"boke_round":
				_story_busy = false
				_present_boke_round(command, false)
				_save_game()
				return
			"sound":
				_play_sound(_dict_string(command, "id"))
			"bg":
				_apply_background(_dict_string(command, "id"))
			"char":
				_apply_character(command)
			"show":
				_sprite(_dict_string(command, "actor")).visible = true
			"hide":
				_sprite(_dict_string(command, "actor")).visible = false
			"expression":
				_sprite(_dict_string(command, "actor")).call("set_expression", _dict_string(command, "value", "neutral"))
			"wait":
				if not _skip:
					await get_tree().create_timer(float(command.get("duration", 0.0))).timeout
					if generation != _generation:
						return
			_:
				pass  # ponytail: move／face／camera 屬於舊的俯視舞台；VN 立繪沒有對應演出，直接略過
		_runner.call("advance")
	_story_busy = false


func _advance_current_line() -> void:
	_line_generation += 1
	_story_busy = true
	var advanced: Variant = _runner.call("advance")
	if advanced == null and not _runner_string("error_message", "").is_empty():
		_show_runtime_error(_runner_string("error_message", "故事無法繼續。"))
		return
	_start_drive()


func _present_say(command: Dictionary, restored: bool) -> void:
	_current_command = command.duplicate(true)
	_clear_hotspots()
	_investigation_continue_button.visible = false
	_boke_controls.visible = false
	_game_over_retry_button.visible = false
	_auto_button.disabled = false
	_skip_button.disabled = false
	_current_speaker = _dict_string(command, "speaker", "narrator")
	_full_text = _dict_string(command, "text")
	_current_line_key = _line_key(command, "say")
	_line_logged = _history_has_key(_current_line_key)
	_line_generation += 1
	_clear_choices()
	_choice_box.visible = false
	_end_box.visible = false
	_screen_mode = "story"
	_refresh_phase3_hud()
	var thought: bool = _dict_bool(command, "thought")
	_set_name_plate(_current_speaker, thought)
	_focus_speaker(_current_speaker, _dict_string(command, "expression", ""))
	_set_label_style(_text_label, "thought" if thought else "body")
	_fit_text_size(_full_text)
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
	_line_logged = _history_has_key(_current_line_key)
	_line_generation += 1
	_story_busy = false
	_set_auto(false)
	_set_skip(false)
	_clear_choices()
	_clear_hotspots()
	_screen_mode = "investigate"
	_dialog_layer.visible = true
	_dialog_panel.visible = true
	_choice_box.visible = false
	_end_box.visible = false
	_investigation_continue_button.visible = true
	_boke_controls.visible = false
	_auto_button.disabled = true
	_skip_button.disabled = true
	_set_name_plate("shinpachi", true)
	_focus_speaker("shinpachi", "thinking")
	_set_label_style(_text_label, "thought")
	_layout()
	_fit_text_size(_full_text)
	_set_visible_text(_full_text, true)
	_build_hotspots(command)
	_update_investigation_controls()
	if not _line_logged:
		_append_history({"key": _current_line_key, "kind": "investigate", "speaker": "shinpachi",
			"text": _full_text})
		_line_logged = true
	_refresh_phase3_hud()
	_publish_qa_state()


func _build_hotspots(command: Dictionary) -> void:
	_clear_hotspots()
	for raw_hotspot: Variant in command.get("hotspots", []):
		if not raw_hotspot is Dictionary:
			continue
		var hotspot: Dictionary = raw_hotspot as Dictionary
		var hotspot_id: String = _dict_string(hotspot, "id")
		var checked: bool = bool(hotspot.get("checked", false))
		var button: Button = _make_button(_dialog_layer,
			("✓ " if checked else "⌕ ") + _dict_string(hotspot, "label", hotspot_id), 32)
		button.name = "Hotspot_" + hotspot_id
		button.custom_minimum_size = Vector2(220.0, 120.0)
		button.disabled = checked
		button.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		button.pressed.connect(_on_hotspot_pressed.bind(hotspot_id))
		_hotspot_buttons[hotspot_id] = button
	_layout_hotspots(command)


func _layout_hotspots(command: Dictionary) -> void:
	if _dialog_panel == null or command.is_empty():
		return
	var stage_height: float = maxf(1.0, _dialog_panel.position.y)
	var safe_top: float = EDGE + _safe_top + 180.0
	var button_size: Vector2 = Vector2(clampf(_game.size.x * 0.27, 220.0, 300.0), 124.0)
	for raw_hotspot: Variant in command.get("hotspots", []):
		if not raw_hotspot is Dictionary:
			continue
		var hotspot: Dictionary = raw_hotspot as Dictionary
		var hotspot_id: String = _dict_string(hotspot, "id")
		if not _hotspot_buttons.has(hotspot_id):
			continue
		var pos: Array = hotspot.get("pos", [0.5, 0.5]) as Array
		if pos.size() != 2:
			continue
		var center: Vector2 = Vector2(float(pos[0]) * _game.size.x, float(pos[1]) * stage_height)
		center.y = clampf(center.y, safe_top + button_size.y * 0.5, stage_height - button_size.y * 0.5)
		center.x = clampf(center.x, button_size.x * 0.5 + EDGE, _game.size.x - button_size.x * 0.5 - EDGE)
		var button: Button = _hotspot_buttons[hotspot_id] as Button
		button.position = center - button_size * 0.5
		button.size = button_size


func _clear_hotspots() -> void:
	for button: Button in _hotspot_buttons.values():
		if is_instance_valid(button):
			button.queue_free()
	_hotspot_buttons.clear()


func _on_hotspot_pressed(hotspot_id: String) -> void:
	if _screen_mode != "investigate" or _story_busy:
		return
	if not bool(_runner.call("inspect_hotspot", hotspot_id)):
		_show_toast(_runner_string("error_message", "這個位置目前不能調查。"))
		return
	var item_id: String = ""
	for raw_hotspot: Variant in _current_command.get("hotspots", []):
		if raw_hotspot is Dictionary and _dict_string(raw_hotspot as Dictionary, "id") == hotspot_id:
			item_id = _dict_string(raw_hotspot as Dictionary, "item")
			break
	var item_info: Dictionary = (_catalog.get("items", {}) as Dictionary).get(item_id, {}) as Dictionary
	var item_name: String = str(item_info.get("name", item_id))
	_current_command = _runner_current()
	_build_hotspots(_current_command)
	_update_investigation_controls()
	_refresh_phase3_hud()
	_show_toast("取得線索：" + item_name)
	_save_game()
	_publish_qa_state()


func _update_investigation_controls() -> void:
	var all_checked: bool = true
	var hotspots: Array = _current_command.get("hotspots", []) as Array
	for raw_hotspot: Variant in hotspots:
		if not raw_hotspot is Dictionary or not bool((raw_hotspot as Dictionary).get("checked", false)):
			all_checked = false
	_investigation_continue_button.disabled = not all_checked or hotspots.is_empty()
	_investigation_continue_button.text = "線索已取得・繼續" if all_checked and not hotspots.is_empty() else "先調查所有位置"


func _on_investigation_continue_pressed() -> void:
	if _screen_mode != "investigate" or _story_busy or _investigation_continue_button.disabled:
		return
	_story_busy = true
	_screen_mode = "busy"
	var next: Dictionary = _runner.call("advance") as Dictionary
	if _command_op(next) == "investigate":
		_story_busy = false
		_present_investigation(next, true)
		return
	_start_drive()


func _present_boke_round(command: Dictionary, restored: bool, requested_ui_mode: String = "") -> void:
	var target_ui_mode: String = requested_ui_mode
	if target_ui_mode.is_empty():
		target_ui_mode = _restored_boke_ui_mode if restored and not _restored_boke_ui_mode.is_empty() else "boke_round"
	if target_ui_mode not in ["boke_round", "tsukkomi"]:
		target_ui_mode = "boke_round"
	_current_command = command.duplicate(true)
	_current_speaker = _dict_string(command, "speaker", "gintoki")
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
	_choice_box.visible = false
	_boke_controls.visible = true
	_auto_button.disabled = true
	_skip_button.disabled = true
	_set_name_plate(_current_speaker, false)
	_focus_speaker(_current_speaker, "annoyed")
	_layout()
	var current_line: Dictionary = command.get("current_line", {}) as Dictionary
	_full_text = _dict_string(current_line, "text", "（銀時正在等你的吐槽。）")
	if bool(command.get("listened", false)):
		_full_text += "\n\n「" + _dict_string(current_line, "listen_text") + "」"
	_set_label_style(_text_label, "body")
	_fit_text_size(_full_text)
	_set_visible_text(_full_text, true)
	var lines: Array = command.get("lines", []) as Array
	var line_index: int = int(command.get("line_index", 0))
	_boke_line_label.text = "%d / %d" % [line_index + 1, lines.size()]
	_boke_previous_button.disabled = line_index <= 0
	_boke_next_button.disabled = line_index >= lines.size() - 1
	_boke_listen_button.visible = current_line.has("listen")
	_boke_listen_button.disabled = bool(command.get("listened", false))
	_boke_listen_button.text = "已聽過" if bool(command.get("listened", false)) else "聽仔細"
	_current_line_key = "%s:%s:%s" % [_line_key(command, "boke"), _dict_string(current_line, "id"), line_index]
	_line_logged = _history_has_key(_current_line_key)
	if not _line_logged:
		_append_history({"key": _current_line_key, "kind": "say", "speaker": _current_speaker, "text": _full_text})
		_line_logged = true
	if target_ui_mode == "tsukkomi":
		_present_tsukkomi_options(command, restored)
	else:
		_boke_time_remaining = 0.0
		_boke_timer_round_id = ""
		_restored_boke_timer_remaining = -1.0
		_restored_boke_ui_mode = ""
		_screen_mode = "boke_round"
		_choice_box.visible = false
		_boke_controls.visible = true
		_current_options.clear()
	_refresh_phase3_hud()
	call_deferred("_update_float_bounds")
	_publish_qa_state()


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
	_choice_box.visible = true
	_boke_controls.visible = false
	_current_options.clear()
	var tsukkomi: Dictionary = command.get("tsukkomi", {}) as Dictionary
	for option_variant: Variant in tsukkomi.get("options", []):
		if not option_variant is Dictionary:
			continue
		var option: Dictionary = (option_variant as Dictionary).duplicate(true)
		_current_options.append(option)
		var button: Button = _make_button(_choice_box, "▶ " + _dict_string(option, "label"), 39)
		button.name = "Boke_" + _dict_string(option, "id")
		_set_button_style(button, "choice")
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		button.custom_minimum_size = Vector2(0.0, 164.0)
		button.pressed.connect(_on_boke_option_pressed.bind(_dict_string(option, "id")))
		_choice_buttons.append(button)


func _on_boke_tsukkomi_pressed() -> void:
	if _screen_mode != "boke_round" or _story_busy:
		return
	_present_tsukkomi_options(_current_command, false)
	_save_game()
	_refresh_phase3_hud()
	call_deferred("_update_float_bounds")
	_publish_qa_state()


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


func _resolve_boke_presentation(result: Dictionary, option_label: String = "", prior_ui_mode: String = "") -> void:
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
			feedback = "完美吐槽！力量 +30"
		"weak":
			feedback = "普通吐槽！力量 +10"
		"fail":
			feedback = "冷場！眼鏡 -1" if not bool(result.get("game_over", false)) else "眼鏡耗盡・Game Over"
		"hidden":
			feedback = "放棄吐槽・狀態不變"
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
	_boke_timer_round_id = ""
	_boke_time_remaining = 0.0
	_restored_boke_timer_remaining = -1.0
	_restored_boke_ui_mode = ""
	_last_boke_result = "retry"
	_story_busy = false
	_screen_mode = "busy"
	_render_restored_current()
	_refresh_phase3_hud()
	_save_game()
	_publish_qa_state()


func _typewriter(token: int) -> void:
	for index: int in range(_visible_text.length(), _full_text.length()):
		if token != _line_generation:
			return
		_set_visible_text(_full_text.substr(0, index + 1), false)
		await get_tree().create_timer(TYPEWRITER_INTERVAL).timeout
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
	_publish_qa_state()
	if _skip:
		_skip_step(_line_generation)
	elif _auto:
		_auto_step(_line_generation)


func _set_visible_text(value: String, complete: bool) -> void:
	_visible_text = value
	_text_complete = complete
	_text_label.text = value
	_next_indicator.visible = complete and _screen_mode == "story"


func _fit_text_size(value: String) -> void:
	var font_size: int = TEXT_FONT_MAX
	while font_size > TEXT_FONT_MIN:
		var lines: float = _font.get_multiline_string_size(value, HORIZONTAL_ALIGNMENT_LEFT,
			_text_label.size.x, font_size).y / _font.get_height(font_size)
		if lines <= TEXT_MAX_LINES + 0.1:
			break
		font_size -= 2
	_text_label.add_theme_font_size_override("font_size", font_size)


func _present_choice(command: Dictionary) -> void:
	_current_command = command.duplicate(true)
	_current_speaker = "shinpachi"
	_full_text = _dict_string(command, "prompt", "我該怎麼做……？")
	_current_line_key = _line_key(command, "choice")
	_line_logged = _history_has_key(_current_line_key)
	_line_generation += 1
	_set_skip(false)
	_screen_mode = "choice"
	_clear_hotspots()
	_investigation_continue_button.visible = false
	_boke_controls.visible = false
	_choice_box.visible = true
	_end_box.visible = false
	_refresh_phase3_hud()
	_set_name_plate("shinpachi", true)
	_focus_speaker("shinpachi", "thinking")
	_set_label_style(_text_label, "thought")
	_fit_text_size(_full_text)
	_set_visible_text(_full_text, true)
	if not _line_logged:
		_append_history({"key": _current_line_key, "kind": "say", "speaker": "shinpachi",
			"text": _full_text, "thought": true})
		_line_logged = true

	_clear_choices()
	for option_variant: Variant in command.get("options", []):
		if not option_variant is Dictionary:
			continue
		var option: Dictionary = (option_variant as Dictionary).duplicate(true)
		_current_options.append(option)
		var button: Button = _make_button(_choice_box, "▶ " + _dict_string(option, "label"), 46)
		button.name = "Choice_%d" % _choice_buttons.size()
		_set_button_style(button, "choice")
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		button.custom_minimum_size = Vector2(0.0, 164.0)
		button.pressed.connect(_on_choice_pressed.bind(_dict_string(option, "id")))
		_choice_buttons.append(button)
	call_deferred("_update_float_bounds")
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
	_update_float_bounds()
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
	_choice_box.visible = false
	_refresh_phase3_hud()
	_set_name_plate("narrator", false)
	_focus_speaker("narrator", "")
	_set_label_style(_text_label, "accent")
	_fit_text_size(_full_text)
	_set_visible_text(_full_text, true)
	_end_box.visible = true
	var snapshot: Dictionary = _runner.call("snapshot") as Dictionary
	_game_over_retry_button.visible = bool(snapshot.get("game_over_active", false))
	if not _history_has_key(_current_line_key):
		_append_history({"key": _current_line_key, "kind": "say", "speaker": "narrator", "text": _full_text})
	_publish_qa_state()


func _render_restored_current() -> void:
	var current: Dictionary = _runner_current()
	match _command_op(current):
		"say":
			_present_say(current, true)
		"choice":
			_present_choice(current)
		"end":
			_present_end(current)
		"investigate":
			_present_investigation(current, true)
		"boke_round":
			_present_boke_round(current, true)
		_:
			_start_drive()


func _show_runtime_error(message: String) -> void:
	_story_busy = false
	_story_error = message
	_screen_mode = "story"
	_current_command = {}
	_set_name_plate("narrator", false)
	_set_label_style(_text_label, "danger")
	_set_visible_text(message, false)
	_publish_qa_state()


func _set_name_plate(speaker: String, thought: bool) -> void:
	_plate_speaker = speaker
	_plate_thought = thought
	_name_plate.visible = speaker != "narrator" and _actors.has(speaker)
	if not _name_plate.visible:
		return
	var info: Dictionary = _actors[speaker] as Dictionary
	_name_label.text = str(info["name"]) + ("・心聲" if thought else "")
	_name_plate.set_meta("ui_style_role", "name_thought" if thought else "name")
	_name_label.set_meta("ui_style_role", "speaker")
	UI_STYLES_SCRIPT.apply_panel(_name_plate, _ui_style_id,
		"name_thought" if thought else "name")
	UI_STYLES_SCRIPT.apply_label(_name_label, _ui_style_id, "speaker")
	var text_width: float = _font.get_string_size(_name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x
	_name_plate.size.x = maxf(220.0, text_width + 32.0)
	_name_label.size = _name_plate.size


func _focus_speaker(speaker: String, expression: String) -> void:
	for actor_id: String in _sprites.keys():
		var sprite: Control = _sprites[actor_id]
		var focused: bool = speaker == "narrator" or actor_id == speaker
		sprite.modulate = Color.WHITE if focused else Color(0.5, 0.5, 0.56)
		if actor_id == speaker:
			_char_layer.move_child(sprite, -1)
			if not expression.is_empty():
				sprite.call("set_expression", expression)


func _sprite(actor_id: String) -> Control:
	return _sprites.get(actor_id, _sprites.get("shinpachi")) as Control


func _clear_choices() -> void:
	_current_options.clear()
	for button: Button in _choice_buttons:
		button.queue_free()
	_choice_buttons.clear()


# ---------------------------------------------------------------- 手勢

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		_last_activity_ms = Time.get_ticks_msec()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _screen_mode in ["save_slots", "load_slots", "slot_confirm"]:
		get_viewport().set_input_as_handled()
		if _screen_mode == "slot_confirm":
			_cancel_slot_confirmation()
		else:
			_close_slot_picker()
		return
	if event.is_action_pressed("ui_accept") and _screen_mode == "story":
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
			_gesture_moved = false
			_gesture_long = false
			_gesture_start = button.global_position
			_gesture_token += 1
			_wait_long_press(_gesture_token)
			return
		if not _gesture_active:
			return
		_gesture_active = false
		_gesture_token += 1
		if _gesture_long:
			return
		if _ui_hidden:
			_set_ui_hidden(false)  # 隱藏 UI 時，點一下只負責恢復，不推進劇情。
			return
		var delta: Vector2 = button.global_position - _gesture_start
		if _gesture_moved:
			if -delta.y > SWIPE_DISTANCE and absf(delta.x) < -delta.y:
				_open_log()
			return
		_on_screen_tap()
	elif event is InputEventMouseMotion and _gesture_active and not _gesture_moved:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if motion.global_position.distance_to(_gesture_start) > TAP_SLOP:
			_gesture_moved = true
			_gesture_token += 1


func _wait_long_press(token: int) -> void:
	await get_tree().create_timer(LONG_PRESS_SEC).timeout
	if token != _gesture_token or not _gesture_active or _gesture_moved:
		return
	_gesture_long = true
	if _screen_mode in ["story", "choice", "end"]:
		_set_ui_hidden(not _ui_hidden)


func _on_screen_tap() -> void:
	if _skip:
		_set_skip(false)
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
	_dialog_panel.visible = not value
	_choice_box.visible = not value
	_quickbar.visible = not value
	_end_box.visible = not value and _screen_mode == "end"
	_float_layer.visible = not value and _screen_mode != "title"
	if value:
		_name_plate.visible = false
	else:
		_set_name_plate(_plate_speaker, _plate_thought)
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
	await get_tree().create_timer(AUTO_DELAY_SEC + _full_text.length() * AUTO_PER_CHAR_SEC).timeout
	if _auto and token == _line_generation and _screen_mode == "story" and not _ui_hidden and not _story_busy:
		_advance_current_line()


func _skip_step(token: int) -> void:
	await get_tree().create_timer(SKIP_DELAY_SEC).timeout
	if _skip and token == _line_generation and _screen_mode == "story" and not _story_busy:
		_advance_current_line()


func _update_toggle_styles() -> void:
	if _auto_button == null:
		return
	for pair: Array in [[_auto_button, _auto], [_skip_button, _skip]]:
		var button: Button = pair[0]
		var active: bool = pair[1]
		_set_button_style(button, "quickbar", active)


func _process(delta: float) -> void:
	if _float_layer == null:
		return
	if _screen_mode == "tsukkomi" and not _story_busy:
		_boke_time_remaining = maxf(0.0, _boke_time_remaining - delta)
		var displayed_second: int = ceili(_boke_time_remaining)
		if displayed_second != _last_boke_display_second:
			_last_boke_display_second = displayed_second
			_refresh_phase3_hud()
			_publish_qa_state()
		if _boke_time_remaining <= 0.0:
			_on_boke_timeout()
			return
	var dragging: bool = bool(_menu_button.call("is_dragging")) or bool(_save_button.call("is_dragging"))
	var idle: bool = Time.get_ticks_msec() - _last_activity_ms > int(IDLE_SEC * 1000.0)
	var target: float = IDLE_ALPHA if idle and not dragging else 1.0
	_float_alpha = move_toward(_float_alpha, target, delta * 3.0)
	_menu_button.modulate.a = _float_alpha
	_save_button.modulate.a = _float_alpha
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
	_update_mute_label()
	_layout_menu_panel()
	_menu_overlay.visible = true
	_refresh_phase3_hud()
	_menu_panel.scale = Vector2(0.7, 0.7)
	_menu_panel.modulate.a = 0.0
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(_menu_panel, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_menu_panel, "modulate:a", 1.0, 0.1)
	_publish_qa_state()


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
	for child: Node in _log_entries.get_children():
		child.queue_free()
	for entry: Dictionary in _history:
		var label: Label
		if _dict_string(entry, "kind") == "choice":
			label = _make_label(_log_entries, "▶ 選擇：%s" % _dict_string(entry, "text"), 40, COLOR_GOLD)
		else:
			var speaker: String = _dict_string(entry, "speaker", "narrator")
			var speaker_name: String = str((_actors.get(speaker, {}) as Dictionary).get("name", "旁白"))
			if _dict_bool(entry, "thought"):
				speaker_name += "・心聲"
			label = _make_label(_log_entries, "%s\n%s" % [speaker_name, _dict_string(entry, "text")], 40,
				COLOR_THOUGHT if _dict_bool(entry, "thought") else COLOR_TEXT)
		label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		label.custom_minimum_size = Vector2(_log_entries.custom_minimum_size.x, 0.0)
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
	if _menu_overlay != null:
		_menu_overlay.visible = false
		_log_overlay.visible = false
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
	if payload.is_empty() or not bool(SAVE_SLOTS_SCRIPT.write_atomic(path, payload)):
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
	# 在存檔鈕旁冒出；按鈕靠右時提示在左邊。
	var anchor: Vector2 = _save_button.position
	var on_left: bool = anchor.x + 64.0 < _game.size.x * 0.5
	_toast.position = Vector2(anchor.x + 148.0 if on_left else anchor.x - toast_size.x - 20.0, anchor.y + 16.0)
	_toast.visible = true
	_toast.modulate.a = 1.0
	_publish_qa_state()
	await get_tree().create_timer(TOAST_SEC).timeout
	if token == _toast_token:
		_toast.visible = false
		_publish_qa_state()


func _toggle_mute() -> void:
	_audio_muted = not _audio_muted
	for player: AudioStreamPlayer in _audio_players.values():
		player.volume_db = -80.0 if _audio_muted else 0.0
	_update_mute_label()
	_publish_qa_state()


func _update_mute_label() -> void:
	(_menu_items["mute"] as Button).text = "音效：關" if _audio_muted else "音效：開"


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
	_phase3_hud.visible = _phase3_enabled and _screen_mode != "title" and not _ui_hidden
	if not _phase3_enabled or _runner == null:
		return
	var snapshot: Dictionary = _runner.call("snapshot") as Dictionary
	var gameplay: Dictionary = snapshot.get("gameplay", {}) as Dictionary
	_phase3_stats_label.text = "眼鏡 %d/%d　力量 %d/%d" % [
		int(gameplay.get("glasses", 0)), int(gameplay.get("max_glasses", 5)),
		int(gameplay.get("power", 0)), int(gameplay.get("max_power", 100))]
	var items: Array = snapshot.get("items", []) as Array
	var item_names: Array[String] = []
	var catalog_items: Dictionary = _catalog.get("items", {}) as Dictionary
	for item_index: int in range(mini(items.size(), 2)):
		var item_id: String = str(items[item_index])
		var item_info: Dictionary = catalog_items.get(item_id, {}) as Dictionary
		item_names.append(str(item_info.get("name", item_id)))
	var extra_count: int = maxi(0, items.size() - item_names.size())
	var inventory_text: String = "尚無"
	if not item_names.is_empty():
		inventory_text = "、".join(item_names)
		if extra_count > 0:
			inventory_text += " +%d" % extra_count
	_phase3_inventory_label.text = "線索：%s" % inventory_text
	_material_button.text = "線索 %d" % items.size()
	if _menu_items.has("material"):
		(_menu_items["material"] as Button).text = "吐槽素材（%d）" % items.size()
	var current: Dictionary = _runner_current()
	if _command_op(current) == "boke_round" and _effective_boke_ui_mode() == "tsukkomi":
		var prefix: String = "倒數" if _screen_mode == "tsukkomi" else "暫停"
		_phase3_timer_label.text = "%s %02d 秒" % [prefix, ceili(_boke_time_remaining)]
	else:
		_phase3_timer_label.text = ""


func _show_inventory_feedback() -> void:
	if not _phase3_enabled or _runner == null:
		return
	var snapshot: Dictionary = _runner.call("snapshot") as Dictionary
	var items: Array = snapshot.get("items", []) as Array
	if items.is_empty():
		_show_toast("目前尚未取得線索")
		return
	var names: Array[String] = []
	var catalog_items: Dictionary = _catalog.get("items", {}) as Dictionary
	for raw_item: Variant in items:
		var item_id: String = str(raw_item)
		var item_info: Dictionary = catalog_items.get(item_id, {}) as Dictionary
		names.append(str(item_info.get("name", item_id)))
	_show_toast("持有線索：" + "、".join(names))


# ---------------------------------------------------------------- 存讀檔

func _save_game() -> bool:
	if not _saveable_current_state():
		return false
	var payload: Dictionary = _build_save_payload("")
	return not payload.is_empty() and bool(SAVE_SLOTS_SCRIPT.write_atomic(save_path, payload))


func _saveable_current_state() -> bool:
	return _runner != null and not _story_busy and _command_op(_runner_current()) in [
		"say", "choice", "end", "investigate", "boke_round"]


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
	}
	if _command_op(current) == "boke_round":
		var boke_ui_mode: String = _effective_boke_ui_mode()
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
		if not SLOT_X.has(str((state as Dictionary).get("position", default_position))):
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
	if payload.has("boke_timer_remaining"):
		var remaining: Variant = payload["boke_timer_remaining"]
		if (typeof(remaining) != TYPE_INT and typeof(remaining) != TYPE_FLOAT) or float(remaining) < 0.0:
			return false
	if payload.has("boke_ui_screen"):
		if typeof(payload["boke_ui_screen"]) != TYPE_STRING or str(payload["boke_ui_screen"]) not in ["boke_round", "tsukkomi"]:
			return false
	# 先用全新的 runner 驗證，成功才動目前的遊戲狀態。
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
	_history.clear()
	for entry: Variant in payload["history"]:
		_history.append((entry as Dictionary).duplicate(true))
	return true


func _delete_save() -> void:
	for path: String in [save_path, save_path + ".bak", save_path + ".bak.old", save_path + ".old",
		save_path + ".tmp", save_path + ".bak.tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _cancel_generation() -> void:
	_generation += 1
	_line_generation += 1
	_story_busy = false


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
	var value: Variant = _runner.call("current") if _runner != null else null
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


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


func _make_dialog_style() -> StyleBoxFlat:
	return UI_STYLES_SCRIPT.panel_style(_ui_style_id, "dialogue")


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
	if _menu_panel != null:
		_layout_menu_panel()
	_publish_qa_state()


func _apply_ui_style() -> void:
	if _title_style_caption != null:
		_title_style_caption.text = "介面風格 · " + UI_STYLES_SCRIPT.style_label(_ui_style_id)
	if _menu_style_caption != null:
		_menu_style_caption.text = "介面風格 · " + UI_STYLES_SCRIPT.style_label(_ui_style_id)
	if _title_style_buttons.is_empty() and _menu_style_buttons.is_empty():
		return
	for style_id: String in _title_style_buttons.keys():
		(_title_style_buttons[style_id] as Button).set_meta("ui_style_active", style_id == _ui_style_id)
	for style_id: String in _menu_style_buttons.keys():
		(_menu_style_buttons[style_id] as Button).set_meta("ui_style_active", style_id == _ui_style_id)
	_apply_ui_style_recursive(self)
	if _menu_button != null:
		_menu_button.call("set_style", _ui_style_id)
		_save_button.call("set_style", _ui_style_id)
	_update_toggle_styles()


func _apply_ui_style_recursive(node: Node) -> void:
	var role: String = str(node.get_meta("ui_style_role", ""))
	if node is Button and not role.is_empty():
		var button: Button = node as Button
		UI_STYLES_SCRIPT.apply_button(button, _ui_style_id, role,
			bool(button.get_meta("ui_style_active", false)))
	elif node is Label and not role.is_empty():
		UI_STYLES_SCRIPT.apply_label(node as Label, _ui_style_id, role)
	elif node is Panel and not role.is_empty():
		UI_STYLES_SCRIPT.apply_panel(node as Panel, _ui_style_id, role)
	elif node is ColorRect and role == "letterbox":
		(node as ColorRect).color = UI_STYLES_SCRIPT.palette(_ui_style_id)["canvas"] as Color
	for child: Node in node.get_children():
		_apply_ui_style_recursive(child)


# ---------------------------------------------------------------- QA（僅 ?qa=1 的 Web 版）

func _detect_qa_mode() -> void:
	_qa_enabled = OS.has_feature("web") and bool(JavaScriptBridge.eval(
		"new URLSearchParams(window.location.search).get('qa') === '1'"))


func _publish_qa_state() -> void:
	if not _qa_enabled:
		return
	var current: Dictionary = _runner_current()
	var snapshot: Dictionary = _runner.call("snapshot")
	var choices: Array = []
	for index: int in range(_choice_buttons.size()):
		if index < _current_options.size() and _choice_buttons[index].is_visible_in_tree():
			choices.append({"id": _dict_string(_current_options[index], "id"),
				"label": _dict_string(_current_options[index], "label"), "rect": _rect(_choice_buttons[index])})
	var controls: Dictionary = {}
	var named: Dictionary = {
		"begin": _begin_button, "continue": _continue_button, "title_load": _title_load_button, "dialogue": _dialog_panel,
		"log": _log_button, "auto": _auto_button, "skip": _skip_button, "material": _material_button,
		"menu": _menu_button, "save": _save_button, "menu_close": _menu_close, "log_close": _log_close,
		"restart": _restart_button, "title": _end_title_button, "investigate_continue": _investigation_continue_button,
		"boke_previous": _boke_previous_button, "boke_next": _boke_next_button,
		"boke_listen": _boke_listen_button, "boke_tsukkomi": _boke_tsukkomi_button,
		"game_over_retry": _game_over_retry_button,
	}
	for item_id: String in _menu_items.keys():
		named["menu_" + item_id] = _menu_items[item_id]
	for style_id: String in _title_style_buttons.keys():
		named["title_style_" + style_id] = _title_style_buttons[style_id]
	for style_id: String in _menu_style_buttons.keys():
		named["menu_style_" + style_id] = _menu_style_buttons[style_id]
	for control_name: String in named.keys():
		var control: Control = named[control_name]
		if control.is_visible_in_tree() and not (control is BaseButton and (control as BaseButton).disabled):
			controls[control_name] = _rect(control)
	for style_id: String in UI_STYLES_SCRIPT.style_ids():
		var title_style_button: Button = _title_style_buttons.get(style_id) as Button
		var menu_style_button: Button = _menu_style_buttons.get(style_id) as Button
		if title_style_button != null and title_style_button.is_visible_in_tree():
			controls["style_" + style_id] = _rect(title_style_button)
		elif menu_style_button != null and menu_style_button.is_visible_in_tree():
			controls["style_" + style_id] = _rect(menu_style_button)
	var hotspot_state: Array[Dictionary] = []
	for raw_hotspot: Variant in current.get("hotspots", []):
		if not raw_hotspot is Dictionary:
			continue
		var hotspot: Dictionary = raw_hotspot as Dictionary
		var hotspot_id: String = _dict_string(hotspot, "id")
		var button: Control = _hotspot_buttons.get(hotspot_id) as Control
		var hotspot_entry: Dictionary = {
			"id": hotspot_id,
			"label": _dict_string(hotspot, "label"),
			"checked": bool(hotspot.get("checked", false)),
			"pos": hotspot.get("pos", []),
			"rect": _rect(button) if button != null and is_instance_valid(button) else {},
		}
		hotspot_state.append(hotspot_entry)
	# 舞台中央空白處：點畫面任一處也能推進，且不會碰到懸浮按鈕。
	if _dialog_panel.is_visible_in_tree() or _ui_hidden:
		var stage: Rect2 = Rect2(_game.position + Vector2(_game.size.x * 0.35, _game.size.y * 0.3),
			Vector2(_game.size.x * 0.3, _game.size.y * 0.08))
		controls["stage"] = {"x": stage.position.x, "y": stage.position.y, "width": stage.size.x, "height": stage.size.y}
	if _menu_overlay.visible:
		var dim: Rect2 = Rect2(_game.position + Vector2(_game.size.x * 0.1, _game.size.y - 200.0), Vector2(160.0, 80.0))
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
		"screen": "busy" if _story_busy and _screen_mode == "busy" else _screen_mode,
		"text": _visible_text,
		"speaker": _current_speaker,
		"node_id": _dict_string(current, "node_id", _dict_string(snapshot, "node_id")),
		"step_index": int(current.get("step_index", snapshot.get("step_index", -1))),
		"flags": snapshot.get("flags", {}),
		"items": snapshot.get("items", []),
		"background": _current_bg_id,
		"text_complete": _text_complete,
		"ui_hidden": _ui_hidden,
		"auto": _auto,
		"skip": _skip,
		"audio_muted": _audio_muted,
		"ui_style": _ui_style_id,
		"toast": _toast.text if _toast.visible else "",
		"float_alpha": _float_alpha,
		"viewport": {"width": get_viewport_rect().size.x, "height": get_viewport_rect().size.y},
		"game": _rect(_game),
		"dialog": _rect(_dialog_panel),
		"quickbar": _rect(_quickbar),
		"name_plate": _rect(_name_plate) if _name_plate.is_visible_in_tree() else {},
		"sprites": sprites,
		"log_scroll": {"value": _log_scroll.scroll_vertical, "max": _log_scroll.get_v_scroll_bar().max_value - _log_scroll.size.y},
		"choices": choices,
		"phase3": {
			"enabled": _phase3_enabled,
			"gameplay": snapshot.get("gameplay", {}),
			"inventory": snapshot.get("items", []),
			"hotspots": hotspot_state,
			"boke_screen_mode": _effective_boke_ui_mode() if _command_op(current) == "boke_round" else "",
			"boke_line_index": int(current.get("line_index", -1)),
			"boke_line_count": (current.get("lines", []) as Array).size(),
			"boke_listened": bool(current.get("listened", false)),
			"boke_listen_available": (current.get("current_line", {}) as Dictionary).has("listen"),
			"timer_remaining": _boke_time_remaining,
			"timer_active": _command_op(current) == "boke_round" and _effective_boke_ui_mode() == "tsukkomi",
			"timer_paused": _command_op(current) == "boke_round" and _effective_boke_ui_mode() == "tsukkomi" and _screen_mode != "tsukkomi",
			"checkpoint_ready": not (snapshot.get("checkpoint", {}) as Dictionary).is_empty(),
			"game_over_active": bool(snapshot.get("game_over_active", false)),
			"last_result": _last_boke_result,
		},
		"controls": controls,
		"slot_page": _slot_page,
		"slots": visible_slots,
	}
	JavaScriptBridge.eval("window.__debtQA=Object.freeze(%s);" % JSON.stringify(state))


func _rect(control: Control) -> Dictionary:
	var rect: Rect2 = control.get_global_rect()
	return {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y}
