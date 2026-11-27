extends SceneTree
## 製作工具：只在要重建時手動跑，會覆蓋 fantasy_* 的 scene、Theme 與合成貼圖。存好後 scene 就是來源檔。
## godot --headless --path . -s tools/build_fantasy.gd
## 第一次跑會先合成 panel-dark-000.png 等貼圖；接著 `godot --headless --path . --editor --import` 再跑一次，Theme 才會引用匯入後的貼圖。
## 素材：Kenney Fantasy UI Borders 1.0（assets/kenney/fantasy/）、Development Essentials 1.1 的 gradient-radial。

const DIR := "res://assets/kenney/fantasy/"
const INK := Color("1d2326")        ## 白底按鈕上的字
const TEXT := Color("e9e7e2")       ## 深色面板上的字
const MUTED := Color("9aa3a6")
const QUEST := Color("a9cf8a")
const PANEL_FILL := Color(0.075, 0.09, 0.1, 0.9)


func _own(n: Node, root: Node) -> void:
	for c in n.get_children():
		c.owner = root
		if c.scene_file_path == "":
			_own(c, root)


func _save(root: Node, path: String) -> void:
	_own(root, root)
	var p := PackedScene.new()
	assert(p.pack(root) == OK)
	assert(ResourceSaver.save(p, path) == OK)
	print("saved ", path)


## Dark shaped fill + white ornament frame baked into one PNG, so a panel is a single StyleBoxTexture.
func _bake_panel(fill: String, frame: String, out: String) -> Texture2D:
	var base := Image.load_from_file(ProjectSettings.globalize_path(DIR + fill))
	var edge := Image.load_from_file(ProjectSettings.globalize_path(DIR + frame))
	base.convert(Image.FORMAT_RGBA8)
	edge.convert(Image.FORMAT_RGBA8)
	for y in base.get_height():
		for x in base.get_width():
			var c := base.get_pixel(x, y)
			base.set_pixel(x, y, Color(PANEL_FILL, PANEL_FILL.a * c.a))
	base.blend_rect(edge, Rect2i(Vector2i.ZERO, edge.get_size()), Vector2i.ZERO)
	base.save_png(ProjectSettings.globalize_path(DIR + out))
	return _import(DIR + out)


func _bake_flip(src: String, out: String) -> Texture2D:
	var img := Image.load_from_file(ProjectSettings.globalize_path(DIR + src))
	img.flip_x()
	img.save_png(ProjectSettings.globalize_path(DIR + out))
	return _import(DIR + out)


## Freshly written PNGs are not imported yet inside this run; load them as ImageTexture saved beside the scene.
func _import(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	var tex := ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(path)))
	tex.resource_path = path
	return tex


func _box(tex: Texture2D, tint := Color.WHITE, pad := Vector4(22, 10, 22, 12)) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.set_texture_margin_all(16)
	sb.modulate_color = tint
	sb.content_margin_left = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_right = pad.z
	sb.content_margin_bottom = pad.w
	return sb


func _label(text: String, variation: String) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _theme(panel: Texture2D) -> Theme:
	var th := Theme.new()
	var fill: Texture2D = load(DIR + "panel-009.png")
	var outline: Texture2D = load(DIR + "panel-border-009.png")
	var outline_fill: Texture2D = load(DIR + "panel-transparent-center-009.png")
	var slot: Texture2D = load(DIR + "panel-transparent-center-002.png")
	var slot_on: Texture2D = load(DIR + "panel-002.png")
	# Button：白底實心（主要行動，例如 Accept quest）
	th.set_stylebox("normal", "Button", _box(fill, Color(0.94, 0.94, 0.92)))
	th.set_stylebox("hover", "Button", _box(fill, Color(1, 0.97, 0.86)))
	th.set_stylebox("pressed", "Button", _box(fill, Color(0.74, 0.76, 0.76)))
	th.set_stylebox("disabled", "Button", _box(fill, Color(0.5, 0.53, 0.54, 0.7)))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		th.set_color(c, "Button", INK)
	th.set_color("font_disabled_color", "Button", Color(INK, 0.6))
	th.set_font_size("font_size", "Button", 22)
	# OutlineButton：白框透明底（次要行動，例如 Continue）
	th.set_type_variation("OutlineButton", "Button")
	th.set_stylebox("normal", "OutlineButton", _box(outline, Color(0.92, 0.92, 0.9)))
	th.set_stylebox("hover", "OutlineButton", _box(outline_fill, Color(1, 1, 1, 0.9)))
	th.set_stylebox("pressed", "OutlineButton", _box(outline_fill, Color(0.7, 0.72, 0.72)))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		th.set_color(c, "OutlineButton", TEXT)
	# TextButton：只有字（New game、Options）
	th.set_type_variation("TextButton", "Button")
	for st in ["normal", "hover", "pressed", "disabled"]:
		var e := StyleBoxEmpty.new()
		e.content_margin_left = 12; e.content_margin_right = 12; e.content_margin_top = 4; e.content_margin_bottom = 4
		th.set_stylebox(st, "TextButton", e)
	th.set_color("font_color", "TextButton", MUTED)
	th.set_color("font_hover_color", "TextButton", TEXT)
	th.set_color("font_focus_color", "TextButton", TEXT)
	th.set_color("font_pressed_color", "TextButton", Color(TEXT, 0.7))
	th.set_color("font_hover_pressed_color", "TextButton", TEXT)
	th.set_font_size("font_size", "TextButton", 20)
	# FantasySlot：道具格，未選灰、選中亮
	th.set_type_variation("FantasySlot", "Button")
	var slot_pad := Vector4(10, 10, 10, 10)
	th.set_stylebox("normal", "FantasySlot", _box(slot, Color(0.55, 0.58, 0.6), slot_pad))
	th.set_stylebox("hover", "FantasySlot", _box(slot, Color(0.75, 0.78, 0.8), slot_pad))
	th.set_stylebox("pressed", "FantasySlot", _box(slot_on, Color(0.86, 0.87, 0.86), slot_pad))
	th.set_stylebox("hover_pressed", "FantasySlot", _box(slot_on, Color(0.95, 0.96, 0.95), slot_pad))
	th.set_stylebox("focus", "FantasySlot", StyleBoxEmpty.new())
	# FantasyPanel：深色底＋花邊框
	th.set_type_variation("FantasyPanel", "PanelContainer")
	th.set_stylebox("panel", "FantasyPanel", _box(panel, Color.WHITE, Vector4(40, 26, 40, 30)))
	# Label 變體
	th.set_color("font_color", "Label", TEXT)
	th.set_font_size("font_size", "Label", 20)
	for v in [["PanelTitle", QUEST, 24], ["PanelHeader", TEXT, 22], ["BannerSmall", TEXT, 16],
			["BannerBig", Color.WHITE, 40], ["SlotCount", Color.WHITE, 18]]:
		th.set_type_variation(v[0], "Label")
		th.set_color("font_color", v[0], v[1])
		th.set_font_size("font_size", v[0], v[2])
	th.set_color("font_outline_color", "SlotCount", Color("1d2326"))
	th.set_constant("outline_size", "SlotCount", 6)
	assert(ResourceSaver.save(th, "res://scenes/fantasy_theme.tres") == OK)
	return load("res://scenes/fantasy_theme.tres")


## Button + juicy_button.gd + Shadow, styled only by the Theme (no overrides), so a type variation restyles it.
func _button_scene(shadow_tex: Texture2D) -> PackedScene:
	var btn := Button.new()
	btn.name = "FantasyButton"
	btn.set_script(load("res://scripts/juicy_button.gd"))
	btn.text = "Button"
	var sh := NinePatchRect.new()
	sh.name = "Shadow"; sh.unique_name_in_owner = true
	sh.texture = shadow_tex
	sh.patch_margin_left = 16; sh.patch_margin_right = 16; sh.patch_margin_top = 16; sh.patch_margin_bottom = 16
	sh.set_anchors_preset(Control.PRESET_FULL_RECT)
	sh.show_behind_parent = true
	sh.self_modulate = Color(0, 0, 0, 0.5)
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(sh)
	_save(btn, "res://scenes/fantasy_button.tscn")
	return load("res://scenes/fantasy_button.tscn")


func _slot_scene() -> PackedScene:
	var slot := Button.new()
	slot.name = "FantasySlot"
	slot.theme_type_variation = "FantasySlot"
	slot.toggle_mode = true
	slot.custom_minimum_size = Vector2(76, 76)
	slot.expand_icon = true
	slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cnt := _label("0", "SlotCount")
	cnt.name = "Count"; cnt.unique_name_in_owner = true
	cnt.set_script(load("res://addons/proto_kit/ui_anim/tween_once.gd"))
	cnt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	cnt.offset_left = -20; cnt.offset_right = 20; cnt.offset_top = -14; cnt.offset_bottom = 12
	cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(cnt)
	_save(slot, "res://scenes/fantasy_slot.tscn")
	return load("res://scenes/fantasy_slot.tscn")


func _init() -> void:
	var panel := _bake_panel("panel-000.png", "panel-border-000.png", "panel-dark-000.png")
	var divider: Texture2D = load(DIR + "divider-fade-003.png")
	var divider_flip := _bake_flip("divider-fade-003.png", "divider-fade-003-flip.png")
	var theme := _theme(panel)
	var button_scene := _button_scene(load(DIR + "panel-009.png"))
	var slot_scene := _slot_scene()
	var container_tween: Script = load("res://addons/proto_kit/ui_anim/container_tween.gd")
	var appear: AudioStream = load("res://assets/sfx/appear.ogg")

	var root := Control.new()
	root.name = "FantasyDemo"
	root.theme = theme
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.set_script(load("res://scripts/fantasy_demo.gd"))
	var bg := ColorRect.new(); bg.name = "Bg"; bg.color = Color("22313a")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var glow := TextureRect.new(); glow.name = "Glow"
	glow.texture = load("res://assets/kenney/gradient-radial.png")
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	glow.modulate = Color(0.55, 0.72, 0.74, 0.35)
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(glow)

	var margin := MarginContainer.new(); margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 120)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_bottom", 40)
	root.add_child(margin)
	var layout := VBoxContainer.new(); layout.name = "Layout"
	layout.add_theme_constant_override("separation", 36)
	layout.set_script(container_tween)
	layout.set("appear_sound", appear)
	margin.add_child(layout)

	# --- Quest
	var quest := PanelContainer.new(); quest.name = "Quest"
	quest.theme_type_variation = "FantasyPanel"
	quest.custom_minimum_size = Vector2(620, 0)
	quest.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	layout.add_child(quest)
	var qv := VBoxContainer.new(); qv.name = "Body"
	qv.add_theme_constant_override("separation", 18)
	quest.add_child(qv)
	var qt := _label("Quest", "PanelTitle"); qt.name = "Title"; qt.unique_name_in_owner = true
	qv.add_child(qt)
	var qd := _label("Gather moon apples in the orchard, guarded by wolves.\nReturn for a bountiful reward!", "Label")
	qd.name = "Description"; qd.unique_name_in_owner = true
	qd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	qv.add_child(qd)
	var accept := button_scene.instantiate(); accept.name = "Accept"; accept.unique_name_in_owner = true
	accept.text = "Accept quest"; accept.shadow_dir = 2
	accept.custom_minimum_size = Vector2(170, 0)
	accept.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	qv.add_child(accept)

	# --- 下排：背包、地點與選單
	var row := HBoxContainer.new(); row.name = "Row"
	row.add_theme_constant_override("separation", 56)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(row)
	var inv := PanelContainer.new(); inv.name = "Inventory"
	inv.theme_type_variation = "FantasyPanel"
	inv.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(inv)
	var iv := VBoxContainer.new(); iv.name = "Body"
	iv.add_theme_constant_override("separation", 14)
	inv.add_child(iv)
	var ih := _label("Inventory", "PanelHeader"); ih.name = "Title"
	iv.add_child(ih)
	var slots := HBoxContainer.new(); slots.name = "Slots"; slots.unique_name_in_owner = true
	slots.add_theme_constant_override("separation", 12)
	slots.set_script(container_tween)
	slots.set("delay_between_element", 0.05)
	iv.add_child(slots)
	var group := ButtonGroup.new()
	# ButtonGroup 預設 local_to_scene：寫在子場景實例上時每格會各複製一份，就不互斥了
	group.resource_local_to_scene = false
	for item in [["Sword", "short_sword_01", 3], ["Book", "book_01", 0], ["Crystal", "crystal_01", 0]]:
		var s := slot_scene.instantiate(); s.name = item[0]
		s.icon = load("res://assets/items/%s.png" % item[1])
		s.button_group = group
		s.button_pressed = item[0] == "Sword"
		slots.add_child(s)
		root.set_editable_instance(s, true)  # 讓實例內 Count 的數字存進 scene
		s.get_node("Count").text = str(item[2])

	var side := VBoxContainer.new(); side.name = "Side"
	side.add_theme_constant_override("separation", 28)
	row.add_child(side)
	var banner := HBoxContainer.new(); banner.name = "Location"
	banner.add_theme_constant_override("separation", 14)
	side.add_child(banner)
	for part in ["Left", "Text", "Right"]:
		if part == "Text":
			var tv := VBoxContainer.new(); tv.name = "Text"
			tv.add_theme_constant_override("separation", -4)
			tv.alignment = BoxContainer.ALIGNMENT_CENTER
			var small := _label("Location discovered", "BannerSmall"); small.name = "Caption"
			var big := _label("Mystic Vale", "BannerBig"); big.name = "Place"; big.unique_name_in_owner = true
			tv.add_child(small); tv.add_child(big)
			banner.add_child(tv)
			continue
		# 分隔線：十字端貼著文字，淡出端往外拉長；只拉伸淡出段，十字端維持原尺寸
		var line := NinePatchRect.new(); line.name = part
		line.texture = divider if part == "Left" else divider_flip
		line.custom_minimum_size = Vector2(150, 18)
		line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if part == "Left":
			line.patch_margin_right = 22
		else:
			line.patch_margin_left = 22
		banner.add_child(line)
	var menu := VBoxContainer.new(); menu.name = "Menu"
	menu.add_theme_constant_override("separation", 6)
	menu.set_script(container_tween)
	menu.set("anim_type", 1)
	menu.set("delay_between_element", 0.06)
	side.add_child(menu)
	for m in [["Continue", "OutlineButton"], ["NewGame", "TextButton"], ["Options", "TextButton"]]:
		var b := button_scene.instantiate(); b.name = m[0]; b.unique_name_in_owner = true
		b.text = "New game" if m[0] == "NewGame" else m[0]
		b.theme_type_variation = m[1]
		b.custom_minimum_size = Vector2(150, 0)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.shadow_dir = 2
		menu.add_child(b)
		if m[1] == "TextButton":
			root.set_editable_instance(b, true)
			b.get_node("Shadow").visible = false
	_save(root, "res://scenes/fantasy_demo.tscn")
	quit()
