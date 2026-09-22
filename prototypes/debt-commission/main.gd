extends Control

## V1 直立視覺小說外殼（roadmap Phase 1）。
##
## 分層由下到上：背景 → 立繪 → 特效 → 對話框 → 懸浮按鈕 → 彈出視窗。
## 故事流程由 scripts/story_runner.gd 執行 data/debt_story.json；bg／char 等 V1 指令在 Phase 2 加入。
## 所有輸入只處理滑鼠事件（專案把觸控模擬成滑鼠），一次觸控只會觸發一次動作。

const STORY_RUNNER_SCRIPT: Script = preload("res://scripts/story_runner.gd")
const FLOATING_BUTTON_SCRIPT: Script = preload("res://scripts/floating_button.gd")
const SPRITE_SCRIPT: Script = preload("res://scripts/placeholder_sprite.gd")

const DESIGN_WIDTH: float = 1080.0
const STORY_DATA_PATH: String = "res://data/debt_story.json"
const FONT_PATH: String = "res://assets/fonts/story-cjk.ttc"
const SAVE_PATH: String = "user://debt_commission.save"
const SAVE_SCHEMA: int = 2
const SAVE_STORY_ID: String = "debt_commission"

const TYPEWRITER_INTERVAL: float = 0.032
const DIALOG_RATIO: float = 0.28
const EDGE: float = 24.0
const QUICKBAR_HEIGHT: float = 104.0
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

# 素材表：placeholder 的名字、顏色與站位集中在這裡，之後換正式立繪只改這一處。
const ACTORS: Dictionary = {
	"shinpachi": {"name": "新八", "color": Color("#4f7fcf"), "slot": "left"},
	"gintoki": {"name": "銀時", "color": Color("#aab6c8"), "slot": "center"},
	"otose": {"name": "登勢", "color": Color("#9a6bb0"), "slot": "right"},
}
const SLOT_X: Dictionary = {"left": 0.2, "center": 0.5, "right": 0.8}
const PLACE_NAME: String = "萬事屋・客廳"
const BG_TOP: Color = Color("#2e2a45")
const BG_BOTTOM: Color = Color("#b9794f")

const COLOR_LETTERBOX: Color = Color("#0b0d18")
const COLOR_PANEL: Color = Color(0.06, 0.08, 0.17, 0.88)
const COLOR_PANEL_SOLID: Color = Color("#101530")
const COLOR_GOLD: Color = Color("#c9a24a")
const COLOR_TEXT: Color = Color("#f6f1e7")
const COLOR_TEXT_SOFT: Color = Color("#b9b4c8")
const COLOR_THOUGHT: Color = Color("#9fc3ff")
const COLOR_DISABLED: Color = Color("#5d6070")

var _font: Font = ThemeDB.fallback_font
var _runner: RefCounted = null
var _story_ready: bool = false
var _story_error: String = ""

var _game: Control = null
var _bg_layer: Control = null
var _char_layer: Control = null
var _fx_layer: Control = null
var _dialog_layer: Control = null
var _float_layer: Control = null
var _popup_layer: Control = null
var _title_screen: Control = null

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
var _title_error: Label = null

var _safe_top: float = 0.0
var _safe_bottom: float = 0.0

var _audio_players: Dictionary = {}
var _audio_muted: bool = false

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

	_load_story()
	_build_audio()
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_detect_qa_mode()
	_show_title()


func _load_story() -> void:
	_runner = STORY_RUNNER_SCRIPT.new() as RefCounted
	_story_ready = bool(_runner.call("load_story", STORY_DATA_PATH))
	if not _story_ready:
		_story_error = _runner_string("error_message", "故事資料尚未就緒。")


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
	_build_dialogue()
	_build_floating_buttons()
	_build_menu()
	_build_log()
	_build_toast()
	_build_title()


func _add_layer(layer_name: String) -> Control:
	var layer: Control = Control.new()
	layer.name = layer_name
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game.add_child(layer)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return layer


func _build_background() -> void:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, BG_TOP)
	gradient.set_color(1, BG_BOTTOM)
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	var background: TextureRect = TextureRect.new()
	background.texture = texture
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_layer.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_place_tag = _make_label(_bg_layer, PLACE_NAME, 40, COLOR_TEXT)
	_place_tag.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.55))
	_place_tag.add_theme_constant_override("outline_size", 10)


func _build_sprites() -> void:
	for actor_id: String in ACTORS.keys():
		var info: Dictionary = ACTORS[actor_id]
		var sprite: Control = SPRITE_SCRIPT.new() as Control
		_char_layer.add_child(sprite)
		sprite.call("setup", actor_id, str(info["name"]), info["color"] as Color, _font)
		sprite.visible = false
		_sprites[actor_id] = sprite


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
	_dialog_panel.add_theme_stylebox_override("panel", _make_style(COLOR_PANEL, COLOR_GOLD, 22, 4))
	_dialog_layer.add_child(_dialog_panel)

	_text_label = _make_label(_dialog_panel, "", TEXT_FONT_MAX, COLOR_TEXT)
	_text_label.name = "DialogueText"
	_text_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_text_label.add_theme_constant_override("line_spacing", 10)

	_next_indicator = _make_label(_dialog_panel, "▼", 40, COLOR_GOLD)
	_next_indicator.name = "NextIndicator"
	var blink: Tween = create_tween().set_loops()
	blink.tween_property(_next_indicator, "modulate:a", 0.15, 0.45)
	blink.tween_property(_next_indicator, "modulate:a", 1.0, 0.45)

	_name_plate = Panel.new()
	_name_plate.name = "NamePlate"
	_name_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialog_layer.add_child(_name_plate)
	_name_label = _make_label(_name_plate, "", 44, COLOR_TEXT)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

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
	_end_title_button = _make_button(_end_box, "回標題", 46)
	_end_title_button.pressed.connect(_show_title)
	for button: Button in [_restart_button, _end_title_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_quickbar = HBoxContainer.new()
	_quickbar.name = "QuickBar"
	_quickbar.add_theme_constant_override("separation", 16)
	_quickbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialog_layer.add_child(_quickbar)
	_log_button = _make_button(_quickbar, "LOG", 38)
	_log_button.pressed.connect(_open_log)
	_auto_button = _make_button(_quickbar, "AUTO", 38)
	_auto_button.pressed.connect(func() -> void: _set_auto(not _auto))
	_skip_button = _make_button(_quickbar, "SKIP", 38)
	_skip_button.pressed.connect(func() -> void: _set_skip(not _skip))
	_material_button = _make_button(_quickbar, "素材", 38)
	_material_button.disabled = true  # ponytail: 吐槽素材畫面在 Phase 3
	for button: Button in [_log_button, _auto_button, _skip_button, _material_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _build_floating_buttons() -> void:
	_menu_button = FLOATING_BUTTON_SCRIPT.new() as Control
	_menu_button.name = "MenuButton"
	_float_layer.add_child(_menu_button)
	_menu_button.call("setup", "≡", _font)
	_menu_button.connect("tapped", _open_menu)

	_save_button = FLOATING_BUTTON_SCRIPT.new() as Control
	_save_button.name = "SaveButton"
	_float_layer.add_child(_save_button)
	_save_button.call("setup", "S", _font)
	_save_button.connect("tapped", func() -> void: _show_toast("長按快速存檔"))
	_save_button.connect("long_pressed", _quick_save)
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

	_menu_panel = VBoxContainer.new()
	_menu_panel.name = "MenuPanel"
	_menu_panel.add_theme_constant_override("separation", 14)
	_menu_overlay.add_child(_menu_panel)
	var entries: Array = [
		["save", "存 檔", _quick_save],
		["load", "讀 檔", _load_from_menu],
		["material", "吐槽素材", Callable()],
		["profile", "人物檔案", Callable()],
		["log", "對話紀錄", _open_log],
		["settings", "設 定", Callable()],
		["mute", "音效：開", _toggle_mute],
		["title", "回標題", _show_title],
	]
	for entry: Array in entries:
		var button: Button = _make_button(_menu_panel, str(entry[1]), 44)
		button.custom_minimum_size = Vector2(520.0, 104.0)
		var action: Callable = entry[2]
		if action.is_valid():
			button.pressed.connect(action)
		else:
			button.disabled = true  # ponytail: 素材／人物檔案 Phase 3、設定 Phase 5
		_menu_items[str(entry[0])] = button

	_menu_close = _make_button(_menu_overlay, "×", 60)
	_menu_close.name = "MenuClose"
	_menu_close.size = Vector2(112.0, 112.0)
	_menu_close.pressed.connect(_close_menu)


func _build_log() -> void:
	_log_overlay = Panel.new()
	_log_overlay.name = "LogOverlay"
	_log_overlay.visible = false
	_log_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
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
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast.add_theme_stylebox_override("normal", _make_style(COLOR_PANEL_SOLID, COLOR_GOLD, 40, 3))
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
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	_title_screen.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var logo: Label = _make_label(_title_screen, "萬事屋\n吐槽 ADV", 104, COLOR_TEXT)
	logo.name = "Logo"
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_stylebox_override("normal", _make_style(Color(0.06, 0.08, 0.17, 0.7), COLOR_GOLD, 12, 6))
	var subtitle: Label = _make_label(_title_screen, "暫定標題・V1 Phase 1 版面測試\n試玩文本：第一場《請幫我向你老闆討債》", 36, COLOR_TEXT_SOFT)
	subtitle.name = "Subtitle"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_begin_button = _make_button(_title_screen, "新遊戲", 52)
	_begin_button.name = "BeginButton"
	_begin_button.pressed.connect(_on_begin_pressed)
	_continue_button = _make_button(_title_screen, "繼續", 52)
	_continue_button.name = "ContinueButton"
	_continue_button.pressed.connect(_on_continue_pressed)

	_title_error = _make_label(_title_screen, "", 34, Color("#ff9d8a"))
	_title_error.name = "TitleError"
	_title_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_error.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	var version: Label = _make_label(_title_screen, "v0.2 · Phase 1", 30, COLOR_TEXT_SOFT)
	version.name = "Version"


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

	var quickbar_y: float = bottom - QUICKBAR_HEIGHT
	_quickbar.position = Vector2(EDGE, quickbar_y)
	_quickbar.size = Vector2(width - EDGE * 2.0, QUICKBAR_HEIGHT)
	var dialog_height: float = roundf(height * DIALOG_RATIO)
	var dialog_y: float = quickbar_y - 16.0 - dialog_height
	_dialog_panel.position = Vector2(EDGE, dialog_y)
	_dialog_panel.size = Vector2(width - EDGE * 2.0, dialog_height)
	_text_label.position = Vector2(52.0, 64.0)
	_text_label.size = Vector2(_dialog_panel.size.x - 104.0, dialog_height - 128.0)
	_next_indicator.position = Vector2(_dialog_panel.size.x - 84.0, dialog_height - 76.0)
	_next_indicator.size = Vector2(48.0, 52.0)
	_name_plate.position = Vector2(EDGE + 36.0, dialog_y - 46.0)
	_name_plate.size.y = 92.0
	_name_label.size = _name_plate.size

	_choice_box.position = Vector2(80.0, top + 180.0)
	_choice_box.size = Vector2(width - 160.0, dialog_y - 56.0 - (top + 180.0))
	_end_box.position = Vector2(80.0, dialog_y - 56.0 - 124.0)
	_end_box.size = Vector2(width - 160.0, 124.0)

	for actor_id: String in _sprites.keys():
		var sprite: Control = _sprites[actor_id]
		var slot_x: float = float(SLOT_X[str(ACTORS[actor_id]["slot"])])
		# 立繪頭部在對話框上方，身體延伸到畫面底部，下緣被對話框蓋住。
		var sprite_top: float = dialog_y + 180.0 - 1040.0
		sprite.position = Vector2(width * slot_x - sprite.size.x * 0.5, sprite_top)
		sprite.size = Vector2(sprite.size.x, height - sprite_top)
		sprite.queue_redraw()

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
	_publish_qa_state()


# 懸浮按鈕只能停在對話框上方；選項出現時也避開選項，免得點選項變成開選單。
func _update_float_bounds() -> void:
	var top: float = EDGE + _safe_top
	var limit: float = _dialog_panel.position.y - 24.0
	if _screen_mode == "choice" and not _choice_buttons.is_empty():
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
	_title_error.position = Vector2(80.0, _continue_button.position.y + 170.0)
	_title_error.size = Vector2(width - 160.0, 100.0)
	var version: Label = _title_screen.get_node("Version")
	version.position = Vector2(EDGE + 12.0, bottom - 48.0)
	version.size = Vector2(360.0, 48.0)


func _layout_menu_panel() -> void:
	_menu_panel.size = _menu_panel.get_combined_minimum_size()
	var width: float = _game.size.x
	var anchor: Vector2 = _menu_button.position
	var on_left: bool = anchor.x + 64.0 < width * 0.5
	var x: float = EDGE + 150.0 if on_left else width - EDGE - 150.0 - _menu_panel.size.x
	var y: float = clampf(anchor.y, EDGE + _safe_top + 120.0,
		maxf(EDGE, _game.size.y - EDGE - _safe_bottom - _menu_panel.size.y))
	_menu_panel.position = Vector2(x, y)
	_menu_panel.pivot_offset = Vector2(0.0 if on_left else _menu_panel.size.x, 0.0)


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
	_story_error = ""
	_set_auto(false)
	_set_skip(false)
	_runner.call("reset")
	for sprite: Control in _sprites.values():
		sprite.visible = false
		sprite.call("set_expression", "neutral")
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
			"sound":
				_play_sound(_dict_string(command, "id"))
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
	_current_speaker = _dict_string(command, "speaker", "narrator")
	_full_text = _dict_string(command, "text")
	_current_line_key = _line_key(command, "say")
	_line_logged = _history_has_key(_current_line_key)
	_line_generation += 1
	_clear_choices()
	_end_box.visible = false
	_screen_mode = "story"
	var thought: bool = _dict_bool(command, "thought")
	_set_name_plate(_current_speaker, thought)
	_focus_speaker(_current_speaker, _dict_string(command, "expression", ""))
	_text_label.add_theme_color_override("font_color", COLOR_THOUGHT if thought else COLOR_TEXT)
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


func _typewriter(token: int) -> void:
	for index: int in range(_full_text.length()):
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
	_end_box.visible = false
	_set_name_plate("shinpachi", true)
	_focus_speaker("shinpachi", "thinking")
	_text_label.add_theme_color_override("font_color", COLOR_THOUGHT)
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
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		button.custom_minimum_size = Vector2(0.0, 132.0)
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
	_current_speaker = "narrator"
	_full_text = _dict_string(command, "text", "本場結束。")
	_current_line_key = _line_key(command, "end")
	_line_generation += 1
	_set_auto(false)
	_set_skip(false)
	_screen_mode = "end"
	_clear_choices()
	_set_name_plate("narrator", false)
	_focus_speaker("narrator", "")
	_text_label.add_theme_color_override("font_color", COLOR_GOLD)
	_fit_text_size(_full_text)
	_set_visible_text(_full_text, true)
	_end_box.visible = true
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
		_:
			_start_drive()


func _show_runtime_error(message: String) -> void:
	_story_busy = false
	_story_error = message
	_screen_mode = "story"
	_current_command = {}
	_set_name_plate("narrator", false)
	_text_label.add_theme_color_override("font_color", Color("#ff9d8a"))
	_set_visible_text(message, false)
	_publish_qa_state()


func _set_name_plate(speaker: String, thought: bool) -> void:
	_plate_speaker = speaker
	_plate_thought = thought
	_name_plate.visible = speaker != "narrator" and ACTORS.has(speaker)
	if not _name_plate.visible:
		return
	var info: Dictionary = ACTORS[speaker]
	var color: Color = info["color"] as Color
	_name_plate.add_theme_stylebox_override("panel", _make_style(color.darkened(0.35), COLOR_GOLD, 16, 4))
	_name_label.text = str(info["name"]) + ("・心聲" if thought else "")
	var text_width: float = _font.get_string_size(_name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x
	_name_plate.size.x = maxf(220.0, text_width + 80.0)
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
	return _sprites.get(actor_id, _sprites["shinpachi"]) as Control


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
	if not value and _auto:
		_auto_step(_line_generation)
	_publish_qa_state()


func _set_auto(value: bool) -> void:
	_auto = value
	if value:
		_skip = false
	_update_toggle_styles()
	if value and _text_complete:
		_auto_step(_line_generation)
	_publish_qa_state()


func _set_skip(value: bool) -> void:
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
		button.add_theme_stylebox_override("normal", _make_style(COLOR_GOLD if active else COLOR_PANEL, COLOR_GOLD, 18, 3))
		button.add_theme_color_override("font_color", COLOR_PANEL_SOLID if active else COLOR_TEXT)


func _process(delta: float) -> void:
	if _float_layer == null:
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
	if _screen_mode not in ["story", "choice", "end"]:
		return
	_mode_before_overlay = _screen_mode
	_screen_mode = "menu"
	_update_mute_label()
	_layout_menu_panel()
	_menu_overlay.visible = true
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
	if _auto:
		_auto_step(_line_generation)
	_publish_qa_state()


func _open_log() -> void:
	if _screen_mode == "menu":
		_close_menu()
	if _screen_mode not in ["story", "choice", "end"]:
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
			var speaker_name: String = str(ACTORS.get(speaker, {}).get("name", "旁白"))
			if _dict_bool(entry, "thought"):
				speaker_name += "・心聲"
			label = _make_label(_log_entries, "%s\n%s" % [speaker_name, _dict_string(entry, "text")], 40,
				COLOR_THOUGHT if _dict_bool(entry, "thought") else COLOR_TEXT)
		label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		label.custom_minimum_size = Vector2(_log_entries.custom_minimum_size.x, 0.0)
	_log_overlay.visible = true
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
	if _auto:
		_auto_step(_line_generation)
	_publish_qa_state()


func _close_overlays() -> void:
	if _menu_overlay != null:
		_menu_overlay.visible = false
		_log_overlay.visible = false


func _load_from_menu() -> void:
	var payload: Dictionary = _read_save_payload()
	_close_menu()
	if not _apply_save_payload(payload):
		_show_toast("沒有可讀取的存檔")
		return
	_cancel_generation()
	_show_story_screen()
	_render_restored_current()
	_show_toast("已讀檔")


func _quick_save() -> void:
	if _screen_mode == "menu":
		_close_menu()
	_show_toast("已存檔" if _save_game() else "演出中，稍後再存")


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


# ---------------------------------------------------------------- 存讀檔

func _save_game() -> bool:
	if _command_op(_runner_current()) not in ["say", "choice", "end"]:
		return false
	var sprites: Dictionary = {}
	for actor_id: String in _sprites.keys():
		var sprite: Control = _sprites[actor_id]
		sprites[actor_id] = {"visible": sprite.visible, "expression": str(sprite.get("expression"))}
	var payload: Dictionary = {
		"schema": SAVE_SCHEMA,
		"story_id": SAVE_STORY_ID,
		"runner": _runner.call("snapshot"),
		"sprites": sprites,
		"history": _history.duplicate(true),
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_var(payload, false)
	file.close()
	return true


func _read_save_payload() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = file.get_var(false)
	file.close()
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}


func _validate_save_payload(payload: Dictionary) -> bool:
	# schema 2 起沒有舊舞台快照；舊版 schema 1 的存檔直接視為失效。
	if int(payload.get("schema", -1)) != SAVE_SCHEMA or str(payload.get("story_id", "")) != SAVE_STORY_ID:
		return false
	var runner_snapshot: Variant = payload.get("runner")
	var sprites: Variant = payload.get("sprites")
	var history: Variant = payload.get("history")
	if not runner_snapshot is Dictionary or not sprites is Dictionary or not history is Array:
		return false
	for actor_id: String in ACTORS.keys():
		var state: Variant = (sprites as Dictionary).get(actor_id)
		if not state is Dictionary or not (state as Dictionary).get("visible") is bool:
			return false
	for entry: Variant in history as Array:
		if not entry is Dictionary:
			return false
	# 先用全新的 runner 驗證，成功才動目前的遊戲狀態。
	var probe: RefCounted = STORY_RUNNER_SCRIPT.new() as RefCounted
	return bool(probe.call("load_story", STORY_DATA_PATH)) and bool(probe.call("restore", runner_snapshot))


func _has_valid_save() -> bool:
	return _validate_save_payload(_read_save_payload())


func _apply_save_payload(payload: Dictionary) -> bool:
	if not _validate_save_payload(payload) or not bool(_runner.call("restore", payload["runner"])):
		return false
	var sprites: Dictionary = payload["sprites"]
	for actor_id: String in _sprites.keys():
		var state: Dictionary = sprites[actor_id]
		var sprite: Control = _sprites[actor_id]
		sprite.visible = bool(state["visible"])
		sprite.call("set_expression", str(state.get("expression", "neutral")))
	_history.clear()
	for entry: Variant in payload["history"]:
		_history.append((entry as Dictionary).duplicate(true))
	return true


func _delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _cancel_generation() -> void:
	_generation += 1
	_line_generation += 1
	_story_busy = false


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
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _make_button(parent: Node, value: String, font_size: int) -> Button:
	var button: Button = Button.new()
	button.text = value
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", COLOR_TEXT)
	button.add_theme_color_override("font_pressed_color", COLOR_PANEL_SOLID)
	button.add_theme_color_override("font_disabled_color", COLOR_DISABLED)
	button.add_theme_stylebox_override("normal", _make_style(COLOR_PANEL, COLOR_GOLD, 18, 3))
	button.add_theme_stylebox_override("hover", _make_style(Color(0.12, 0.15, 0.3, 0.92), COLOR_GOLD, 18, 4))
	button.add_theme_stylebox_override("pressed", _make_style(COLOR_GOLD, COLOR_GOLD, 18, 4))
	button.add_theme_stylebox_override("disabled", _make_style(Color(0.06, 0.07, 0.12, 0.7), COLOR_DISABLED, 18, 2))
	parent.add_child(button)
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
		"begin": _begin_button, "continue": _continue_button, "dialogue": _dialog_panel,
		"log": _log_button, "auto": _auto_button, "skip": _skip_button, "material": _material_button,
		"menu": _menu_button, "save": _save_button, "menu_close": _menu_close, "log_close": _log_close,
		"restart": _restart_button, "title": _end_title_button,
	}
	for item_id: String in _menu_items.keys():
		named["menu_" + item_id] = _menu_items[item_id]
	for control_name: String in named.keys():
		var control: Control = named[control_name]
		if control.is_visible_in_tree() and not (control is BaseButton and (control as BaseButton).disabled):
			controls[control_name] = _rect(control)
	# 舞台中央空白處：點畫面任一處也能推進，且不會碰到懸浮按鈕。
	if _dialog_panel.is_visible_in_tree() or _ui_hidden:
		var stage: Rect2 = Rect2(_game.position + Vector2(_game.size.x * 0.35, _game.size.y * 0.3),
			Vector2(_game.size.x * 0.3, _game.size.y * 0.08))
		controls["stage"] = {"x": stage.position.x, "y": stage.position.y, "width": stage.size.x, "height": stage.size.y}
	if _menu_overlay.visible:
		var dim: Rect2 = Rect2(_game.position + Vector2(_game.size.x * 0.1, _game.size.y - 200.0), Vector2(160.0, 80.0))
		controls["menu_dim"] = {"x": dim.position.x, "y": dim.position.y, "width": dim.size.x, "height": dim.size.y}
	var sprites: Dictionary = {}
	for actor_id: String in _sprites.keys():
		var sprite: Control = _sprites[actor_id]
		sprites[actor_id] = {"visible": sprite.visible, "expression": str(sprite.get("expression")),
			"focused": sprite.modulate.r > 0.9}
	var state: Dictionary = {
		"screen": "busy" if _story_busy and _screen_mode == "busy" else _screen_mode,
		"text": _visible_text,
		"speaker": _current_speaker,
		"node_id": _dict_string(current, "node_id", _dict_string(snapshot, "node_id")),
		"step_index": int(current.get("step_index", snapshot.get("step_index", -1))),
		"flags": snapshot.get("flags", {}),
		"text_complete": _text_complete,
		"ui_hidden": _ui_hidden,
		"auto": _auto,
		"skip": _skip,
		"audio_muted": _audio_muted,
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
		"controls": controls,
	}
	JavaScriptBridge.eval("window.__debtQA=Object.freeze(%s);" % JSON.stringify(state))


func _rect(control: Control) -> Dictionary:
	var rect: Rect2 = control.get_global_rect()
	return {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y}
