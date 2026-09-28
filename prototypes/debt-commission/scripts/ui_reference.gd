extends RefCounted
## Runtime layout of the approved HTML UI options, expressed in device pixels.
const ORNAMENT: Script = preload("res://scripts/ui_ornament.gd")
const STAGE: Script = preload("res://scripts/ui_stage_style.gd")
const STYLES: Script = preload("res://scripts/ui_styles.gd")

static func _ornament(parent: Control, kind: String) -> Control:
	var art: Control = ORNAMENT.new()
	art.name = "Frame_" + kind
	art.set_meta("kind", kind)
	parent.add_child(art)
	parent.move_child(art, 0)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return art

static func install(g: Control) -> void:
	var d: Dictionary = {}
	g.set_meta("reference_ui", d)
	d["dialog_frame"] = _ornament(g._dialog_panel, "dialogue")
	d["mark"] = g._make_label(g._name_plate, "◇", 44, Color.WHITE)
	d["chapter"] = g._make_label(g._dialog_panel, "討債委託　／　01", 38, Color.WHITE)
	d["chapter"].horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	g._next_indicator.hide()
	var advance: Button = g._make_button(g._dialog_layer, "›", 64)
	advance.name = "Advance"
	advance.pressed.connect(g._on_screen_tap)
	d["advance"] = advance
	d["advance_frame"] = _ornament(advance,"advance")
	advance.button_down.connect(func() -> void: d["advance_frame"].modulate = Color(.8,.8,.8))
	advance.button_up.connect(func() -> void: d["advance_frame"].modulate = Color.WHITE)
	var sheet: Panel = Panel.new()
	sheet.name = "ChoiceSheet"
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g._dialog_layer.add_child(sheet)
	g._dialog_layer.move_child(sheet,g._choice_box.get_index())
	d["sheet"] = sheet
	d["sheet_frame"] = _ornament(sheet,"choices")
	d["choice_kicker"] = g._make_label(sheet,"回應時機",38,Color.WHITE)
	d["choice_title"] = g._make_label(sheet,"這句要怎麼接？",60,Color.WHITE)
	d["choice_title"].autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	d["choice_hint"] = g._make_label(sheet,"選一句回應",38,Color.WHITE)
	d["choice_count"] = g._make_label(sheet,"",38,Color.WHITE)
	d["choice_count"].horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var choice_menu: Button = g._make_button(sheet,"目錄",38)
	choice_menu.pressed.connect(g._open_menu)
	d["choice_menu"] = choice_menu
	var timer: ProgressBar = ProgressBar.new()
	timer.show_percentage = false
	timer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(timer)
	d["timer"] = timer
	# Fixed menu heading and style picker surround a scrolling list of actions.
	d["menu_frame"] = _ornament(g._menu_panel_shell,"menu")
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "MenuActions"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	g._menu_overlay.add_child(scroll)
	g._menu_panel.reparent(scroll)
	g._menu_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d["menu_scroll"] = scroll
	g._menu_style_caption.reparent(g._menu_overlay)
	g._menu_style_row.reparent(g._menu_overlay)
	d["menu_kicker"] = g._make_label(g._menu_overlay,"萬事屋・委託中",38,Color.WHITE)
	d["menu_heading"] = g._make_label(g._menu_overlay,"稍歇片刻",60,Color.WHITE)
	var resume: Button = g._make_button(g._menu_panel,"回到故事　→",46)
	resume.pressed.connect(g._close_menu)
	g._menu_panel.move_child(resume,0)
	g._menu_items["resume"] = resume
	# Bottom title card keeps story and appearance selection available.
	var title_card: Panel = Panel.new()
	title_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g._title_screen.add_child(title_card)
	g._title_screen.move_child(title_card,1)
	d["title_card"] = title_card
	d["title_frame"] = _ornament(title_card,"title")
	d["title_kicker"] = g._make_label(g._title_screen,"萬事屋的委託日常",38,Color.WHITE)
	g._title_screen.get_child(0).name = "TitleBackground"

static func unit(g: Control) -> float:
	var physical: Vector2 = Vector2(g.get_viewport().get_visible_rect().size)
	var window_size: Vector2 = Vector2(DisplayServer.window_get_size())
	if window_size.x > 0.0:
		return clampf(physical.x / window_size.x, 1.0, 5.0)
	return g._game.size.x / 390.0

static func _box(c: Control, x: float, y: float, w: float, h: float) -> void:
	c.position = Vector2(x,y)
	c.size = Vector2(maxf(0,w),maxf(0,h))

static func _font(c: Control, px: float, u: float) -> void:
	c.add_theme_font_size_override("font_size",roundi(px*u))

static func restyle(g: Control) -> void:
	if not g.has_meta("reference_ui"):
		return
	var d: Dictionary = g.get_meta("reference_ui")
	var style: String = g._ui_style_id
	var p: Dictionary = STYLES.palette(style)
	var u: float = unit(g)
	for key: String in ["dialog_frame","sheet_frame","menu_frame","title_frame","advance_frame"]:
		var art: Control = d[key]
		art.call("configure",style,art.get_meta("kind"),u)
	for panel: Panel in [g._dialog_panel,g._name_plate,d["sheet"],g._menu_panel_shell,d["title_card"],g._title_style_panel]:
		panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	for key: String in ["chapter","choice_kicker","choice_hint","menu_kicker","title_kicker"]:
		STYLES.apply_label(d[key],style,"muted")
	for key: String in ["choice_title","choice_count","menu_heading"]:
		STYLES.apply_label(d[key],style,"body")
	STYLES.apply_label(g._name_label,style,"body")
	STYLES.apply_label(g._title_screen.get_node("Logo"),style,"body")
	STYLES.apply_label(g._menu_style_caption,style,"muted")
	STYLES.apply_label(g._title_style_caption,style,"muted")
	g._title_style_caption.text = "選擇介面風格"
	g._menu_style_caption.text = "介面風格"
	var mark: Label = d["mark"]
	mark.text = {"cinema":"◇","ledger":"印","manga":"●"}[style]
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.add_theme_color_override("font_color",Color("#fff7e8") if style == "ledger" else p["accent"] if style == "cinema" else p["text"])
	var seal: StyleBoxFlat = StyleBoxFlat.new()
	seal.bg_color = p["accent"] if style == "ledger" else Color.TRANSPARENT
	seal.set_corner_radius_all(roundi(14*u))
	mark.add_theme_stylebox_override("normal",seal)
	var advance: Button = d["advance"]
	advance.text = {"cinema":"›","ledger":"續","manga":"→"}[style]
	for state: String in ["normal","hover","pressed","hover_pressed","disabled"]:
		advance.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	for state: String in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		advance.add_theme_color_override(state,p["accent"] if style == "cinema" else Color("#fff7e8"))
	for button: Button in [g._menu_button,g._log_button,g._auto_button,d["choice_menu"]]:
		STYLES.apply_button(button,style,"quickbar",button == g._auto_button and g._auto)
	for item: String in g._menu_items:
		STYLES.apply_button(g._menu_items[item],style,"menu_primary" if item == "resume" else "menu")
	STYLES.apply_button(g._menu_close,style,"quickbar")
	STAGE.apply(g._background_rect,style)
	STAGE.apply(g._title_screen.get_node("TitleBackground"),style)
	g._title_screen.get_node("TitleBackground").modulate = Color.WHITE
	for sprite: Control in g._sprites.values():
		sprite.call("set_ui_style",style)
	for index: int in range(g._choice_buttons.size()):
		var button: Button = g._choice_buttons[index]
		var number: String = ["壹","貳","參","肆"][index % 4] if style == "ledger" else "%02d" % (index+1)
		button.text = number + "　" + str(g._current_options[index].get("label",""))
		STYLES.apply_button(button,style,"choice")
	var track: StyleBoxFlat = StyleBoxFlat.new()
	track.bg_color = p["rule"]
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = p["accent"]
	d["timer"].add_theme_stylebox_override("background",track)
	d["timer"].add_theme_stylebox_override("fill",fill)

static func layout(g: Control) -> void:
	if not g.has_meta("reference_ui"):
		return
	var d: Dictionary = g.get_meta("reference_ui")
	var u: float = unit(g)
	var w: float = g._game.size.x
	var h: float = g._game.size.y
	var bottom: float = h - g._safe_bottom
	var style: String = g._ui_style_id
	var inset: float = {"cinema":0.0,"ledger":8.0,"manga":9.0}[style]*u
	var pad: float = (17.0 if style == "cinema" else 14.0)*u
	var panel_w: float = w - inset*2
	var text_w: float = panel_w-pad*2
	var font_size: int = roundi(18*u)
	var line_height: float = (30.2 if style == "cinema" else 28.4)*u
	var text_height: float = g._font.get_multiline_string_size(g._full_text,HORIZONTAL_ALIGNMENT_LEFT,text_w,font_size).y
	var lines: float = maxf(1,ceilf(text_height/g._font.get_height(font_size)))
	var copy_h: float = lines*line_height
	var interactive: bool = g._screen_mode in ["investigate","boke_round"]
	var top_pad: float = (22 if style == "cinema" else 14)*u
	var panel_h: float = top_pad+28*u+8*u+copy_h+13*u+52*u+13*u
	if interactive:
		panel_h += 58*u
	panel_h = minf(panel_h,h-100*u)
	var panel_y: float = bottom-inset-panel_h
	_box(g._dialog_panel,inset,panel_y,panel_w,panel_h)
	_box(g._text_label,pad,top_pad+36*u,text_w,copy_h)
	_font(g._text_label,18,u)
	g._text_label.add_theme_constant_override("line_spacing",maxi(0,roundi(line_height-g._font.get_height(font_size))))
	_box(g._name_plate,inset+pad,panel_y+top_pad,140*u,28*u)
	_box(d["mark"],0,0,28*u,28*u)
	_font(d["mark"],14,u)
	_box(g._name_label,37*u,0,100*u,28*u)
	_font(g._name_label,16,u)
	_box(d["chapter"],panel_w-178*u-pad,top_pad,178*u,28*u)
	_font(d["chapter"],14,u)
	var row_y: float = bottom-inset-65*u
	_box(g._quickbar,inset+pad,row_y,156*u,52*u)
	g._quickbar.add_theme_constant_override("separation",roundi(2*u))
	for button: Button in [g._menu_button,g._log_button,g._auto_button]:
		button.custom_minimum_size = Vector2(50*u,48*u)
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_font(button,14,u)
	_box(d["advance"],w-inset-pad-52*u,row_y,52*u,52*u)
	_font(d["advance"],20 if style == "ledger" else 30,u)
	d["advance"].visible = g._screen_mode in ["story","busy"] and not g._ui_hidden
	g._next_indicator.hide()
	_box(g._boke_controls,pad,panel_h-123*u,panel_w-pad*2,48*u)
	for button: Button in [g._boke_previous_button,g._boke_next_button,g._boke_listen_button,g._boke_tsukkomi_button]:
		button.custom_minimum_size = Vector2(48*u,48*u)
		_font(button,14,u)
	_box(g._investigation_continue_button,pad,panel_h-123*u,panel_w-pad*2,48*u)
	_font(g._investigation_continue_button,16,u)
	var choice: bool = g._screen_mode in ["choice","tsukkomi"] or (g._screen_mode in ["menu","save_slots","load_slots","slot_confirm","log","case_file"] and g._mode_before_overlay in ["choice","tsukkomi"])
	d["sheet"].visible = choice and not g._ui_hidden
	g._dialog_panel.visible = not choice and not g._ui_hidden
	g._name_plate.visible = not choice and not g._ui_hidden
	g._quickbar.visible = not choice and not g._ui_hidden
	if choice:
		var rows_h: float = 0
		g._choice_box.add_theme_constant_override("separation",roundi(8*u))
		for button: Button in g._choice_buttons:
			_font(button,17,u)
			var measured: float = g._font.get_multiline_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,text_w-26*u,roundi(17*u)).y
			var row_h: float = maxf(48*u,measured+22*u)
			button.custom_minimum_size = Vector2(0,row_h)
			rows_h += row_h
		rows_h += maxf(0,g._choice_buttons.size()-1)*8*u
		var title_text: String = "這句要怎麼接？" if g._command_op(g._current_command) == "boke_round" else g._full_text
		d["choice_title"].text = title_text
		var heading_h: float = maxf(29*u,g._font.get_multiline_string_size(title_text,HORIZONTAL_ALIGNMENT_LEFT,text_w-50*u,roundi(22*u)).y)
		var timed: bool = g._command_op(g._current_command) == "boke_round"
		var sheet_h: float = 14*u+22*u+heading_h+14*u+rows_h+(30*u if timed else 10*u)+48*u+12*u
		var sheet_y: float = bottom-inset-sheet_h
		_box(d["sheet"],inset,sheet_y,panel_w,sheet_h)
		_box(d["choice_kicker"],pad,14*u,text_w,20*u)
		_font(d["choice_kicker"],14,u)
		_box(d["choice_title"],pad,36*u,text_w-50*u,heading_h)
		_font(d["choice_title"],22,u)
		_box(d["choice_count"],panel_w-pad-54*u,14*u,54*u,28*u)
		d["choice_count"].text = "%d 選 1" % g._choice_buttons.size()
		_font(d["choice_count"],14,u)
		_box(g._choice_box,inset+pad,sheet_y+50*u+heading_h,text_w,rows_h)
		g._choice_box.alignment = BoxContainer.ALIGNMENT_BEGIN
		_box(d["choice_hint"],pad,sheet_h-60*u,text_w-65*u,48*u)
		_font(d["choice_hint"],14,u)
		d["choice_hint"].vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		d["choice_hint"].text = "選一句回應"
		_box(d["choice_menu"],panel_w-pad-54*u,sheet_h-60*u,54*u,48*u)
		_font(d["choice_menu"],14,u)
		d["timer"].visible = timed
		_box(d["timer"],pad,sheet_h-77*u,text_w,5*u)
		d["timer"].max_value = float(g._current_command.get("timer_seconds",8))
		d["timer"].value = g._boke_time_remaining
	_box(g._end_box,16*u,panel_y-60*u,w-32*u,48*u)
	for button: Button in [g._restart_button,g._game_over_retry_button,g._end_title_button]:
		button.custom_minimum_size.y = 48*u
		_font(button,16,u)
	_box(g._place_tag,16*u,14*u+g._safe_top,w-32*u,26*u)
	_font(g._place_tag,14,u)
	for sprite: Control in g._sprites.values():
		var ah: float = h*.62
		var aw: float = minf(w*.9,ah*float(sprite.call("art_aspect_ratio")))
		sprite.size = Vector2(aw,ah)
		sprite.position = Vector2(w*1.04-aw,h*.75-ah)
		# The approved scene has full-color art; only real speakers affect expression.
		sprite.modulate = Color.WHITE
	layout_menu(g)
	layout_title(g)
	restyle(g)

static func layout_menu(g: Control) -> void:
	if not g.has_meta("reference_ui"):
		return
	var d: Dictionary = g.get_meta("reference_ui")
	var u: float = unit(g)
	var w: float = minf(360*u,g._game.size.x-36*u)
	var h: float = minf(550*u,g._game.size.y-g._safe_top-g._safe_bottom-36*u)
	var x: float = (g._game.size.x-w)*.5
	var y: float = (g._game.size.y-h)*.5
	_box(g._menu_panel_shell,x,y,w,h)
	_box(d["menu_kicker"],x+18*u,y+16*u,w-90*u,20*u)
	_box(d["menu_heading"],x+18*u,y+37*u,w-90*u,32*u)
	_font(d["menu_kicker"],14,u)
	_font(d["menu_heading"],22,u)
	_box(g._menu_close,x+w-66*u,y+17*u,48*u,48*u)
	_font(g._menu_close,26,u)
	_box(d["menu_scroll"],x+18*u,y+82*u,w-36*u,h-182*u)
	g._menu_panel.add_theme_constant_override("separation",roundi(2*u))
	g._menu_panel.custom_minimum_size.x = w-40*u
	for button: Button in g._menu_items.values():
		button.custom_minimum_size = Vector2(0,48*u)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_font(button,17,u)
	_box(g._menu_style_caption,x+18*u,y+h-90*u,w-36*u,24*u)
	_font(g._menu_style_caption,14,u)
	_box(g._menu_style_row,x+18*u,y+h-62*u,w-36*u,48*u)
	for button: Button in g._menu_style_buttons.values():
		button.custom_minimum_size = Vector2(0,48*u)
		_font(button,14,u)

static func layout_title(g: Control) -> void:
	if not g.has_meta("reference_ui"):
		return
	var d: Dictionary = g.get_meta("reference_ui")
	var u: float = unit(g)
	var w: float = g._game.size.x
	var inset: float = (0 if g._ui_style_id == "cinema" else 12)*u
	var x: float = inset+18*u
	var inner: float = w-x*2
	var bottom: float = g._game.size.y-g._safe_bottom-inset
	var y: float = bottom-362*u
	_box(d["title_card"],inset,y,w-2*inset,362*u)
	_box(d["title_kicker"],x,y+18*u,inner,24*u)
	_font(d["title_kicker"],14,u)
	var logo: Label = g._title_screen.get_node("Logo")
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_box(logo,x,y+44*u,inner,94*u)
	_font(logo,36,u)
	_box(g._story_switch,x,y+139*u,inner,48*u)
	_font(g._story_switch,14,u)
	_box(g._title_style_panel,x,y+192*u,inner,72*u)
	_box(g._title_style_caption,0,0,inner,22*u)
	_font(g._title_style_caption,14,u)
	_box(g._title_style_row,0,24*u,inner,48*u)
	for button: Button in g._title_style_buttons.values():
		button.custom_minimum_size = Vector2(0,48*u)
		_font(button,14,u)
	_box(g._begin_button,x,y+274*u,inner,48*u)
	_font(g._begin_button,17,u)
	# Secondary actions share a row to keep the title card compact.
	_box(g._continue_button,x,y+324*u,inner*.48,32*u)
	_box(g._title_load_button,x+inner*.52,y+324*u,inner*.48,32*u)
	_font(g._continue_button,14,u)
	_font(g._title_load_button,14,u)
	g._title_screen.get_node("Version").hide()
	_box(g._title_error,x,maxf(0,y-50*u),inner,48*u)
	_font(g._title_error,14,u)
