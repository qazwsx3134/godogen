extends SceneTree
## 製作工具：只在要重建時手動跑。scene 存好後就是來源檔，可直接在編輯器改。
## godot --headless --path . -s tools/build_scenes.gd

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

func _init() -> void:
	var frame: Texture2D = load("res://assets/kenney/button_frame.png")
	# --- juicy_button.tscn
	var sb := StyleBoxTexture.new()
	sb.texture = frame
	sb.set_texture_margin_all(6)
	sb.set_content_margin_all(12)
	sb.content_margin_left = 20; sb.content_margin_right = 20
	ResourceSaver.save(sb, "res://scenes/button_frame.tres")
	sb = load("res://scenes/button_frame.tres")
	var btn := Button.new()
	btn.name = "JuicyButton"
	btn.set_script(load("res://scripts/juicy_button.gd"))
	btn.text = "Button"
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(st, sb if st != "focus" else StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(c, Color("3b2a1e"))
	btn.add_theme_font_size_override("font_size", 22)
	var sh := NinePatchRect.new()
	sh.name = "Shadow"; sh.unique_name_in_owner = true
	sh.texture = frame
	sh.patch_margin_left = 6; sh.patch_margin_right = 6; sh.patch_margin_top = 6; sh.patch_margin_bottom = 6
	sh.set_anchors_preset(Control.PRESET_FULL_RECT)
	sh.show_behind_parent = true
	sh.self_modulate = Color(0, 0, 0, 0.45)
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(sh)
	_save(btn, "res://scenes/juicy_button.tscn")

	# --- card.tscn
	var card := Button.new(); card.name = "Card"
	card.set_script(load("res://scripts/card.gd"))
	card.size = Vector2(110, 150); card.text = "1"
	for st in ["normal", "hover", "pressed", "disabled"]:
		card.add_theme_stylebox_override(st, sb)
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		card.add_theme_color_override(c, Color("3b2a1e"))
	card.add_theme_font_size_override("font_size", 36)
	_save(card, "res://scenes/card.tscn")

	# --- item_slot.tscn
	var slot := Button.new(); slot.name = "ItemSlot"
	slot.set_script(load("res://scripts/item_slot.gd"))
	slot.custom_minimum_size = Vector2(72, 72)
	slot.expand_icon = true; slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var slot_sb := sb.duplicate() as StyleBoxTexture  # 道具圖留白多，內距縮小讓 icon 夠大
	slot_sb.set_content_margin_all(0)
	for st in ["normal", "hover", "pressed", "disabled"]:
		slot.add_theme_stylebox_override(st, slot_sb)
	slot.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var cnt := Label.new(); cnt.name = "Count"; cnt.unique_name_in_owner = true
	cnt.set_script(load("res://addons/proto_kit/ui_anim/tween_once.gd"))
	cnt.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	cnt.offset_left = -40; cnt.offset_top = -30; cnt.offset_right = -8; cnt.offset_bottom = -4
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cnt.add_theme_font_size_override("font_size", 18)
	cnt.add_theme_color_override("font_color", Color("3b2a1e"))
	cnt.add_theme_color_override("font_outline_color", Color("fff3d6"))
	cnt.add_theme_constant_override("outline_size", 6)
	cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(cnt)
	_save(slot, "res://scenes/item_slot.tscn")

	# --- inventory.tscn
	var jb0: PackedScene = load("res://scenes/juicy_button.tscn")
	var inv := PanelContainer.new(); inv.name = "Inventory"
	inv.set_script(load("res://scripts/inventory.gd"))
	inv.add_theme_stylebox_override("panel", sb)
	var items := ["apple_red_01", "potion_red_01", "potion_blue_01", "short_sword_01", "bow_unloaded_01",
		"bomb_01", "book_01", "crystal_01", "gold-coin_pile-S_01", "carrot_01", "shovel_01", "katana_01"]
	var texs: Array[Texture2D] = []
	for it in items:
		texs.append(load("res://assets/items/%s.png" % it))
	inv.set("start_items", texs.slice(0, 7))
	inv.set("start_counts", [5, 3, 1, 1, 1, 12, 1] as Array[int])
	inv.set("loot_pool", texs)
	var iv := VBoxContainer.new(); iv.name = "VBox"; iv.add_theme_constant_override("separation", 12)
	inv.add_child(iv)
	var ihead := HBoxContainer.new(); ihead.name = "Header"; ihead.add_theme_constant_override("separation", 12)
	iv.add_child(ihead)
	var bag := TextureRect.new(); bag.name = "BagIcon"
	bag.texture = load("res://assets/items/backpack_LVL_01.png")
	bag.custom_minimum_size = Vector2(48, 48)
	bag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; bag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ihead.add_child(bag)
	var ht := Label.new(); ht.name = "Title"; ht.text = "Backpack"
	ht.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ht.add_theme_font_size_override("font_size", 28); ht.add_theme_color_override("font_color", Color("3b2a1e"))
	ihead.add_child(ht)
	for bn in ["Loot", "Close"]:
		var b := jb0.instantiate(); b.name = bn; b.text = bn; b.unique_name_in_owner = true
		b.shadow_dir = 2; b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ihead.add_child(b)
	var grid := GridContainer.new(); grid.name = "Grid"; grid.unique_name_in_owner = true
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6); grid.add_theme_constant_override("v_separation", 6)
	grid.set_script(load("res://addons/proto_kit/ui_anim/container_tween.gd"))
	grid.set("trigger", 1); grid.set("delay_between_element", 0.015)
	iv.add_child(grid)
	var sl: PackedScene = load("res://scenes/item_slot.tscn")
	for i in 24:
		var c := sl.instantiate(); c.name = "Slot%d" % i
		grid.add_child(c)
	_save(inv, "res://scenes/inventory.tscn")

	# --- demo.tscn
	var jb: PackedScene = load("res://scenes/juicy_button.tscn")
	var root := Control.new(); root.name = "Demo"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.set_script(load("res://scripts/demo.gd"))
	var bg := ColorRect.new(); bg.name = "Bg"; bg.color = Color("e8dcc4")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(bg)
	var center := CenterContainer.new(); center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(center)
	var hb := HBoxContainer.new(); hb.name = "Columns"
	hb.add_theme_constant_override("separation", 64); center.add_child(hb)

	var title := VBoxContainer.new(); title.name = "Title"
	title.set_script(load("res://addons/proto_kit/ui_anim/container_tween.gd"))
	title.add_theme_constant_override("separation", 18)
	title.set("appear_sound", load("res://assets/sfx/appear.ogg"))
	hb.add_child(title)
	var lbl := Label.new(); lbl.name = "TitleLabel"; lbl.text = "GODOT UI"
	lbl.add_theme_font_size_override("font_size", 48)
	lbl.add_theme_color_override("font_color", Color("3b2a1e"))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_child(lbl)
	var defs := [["Bag", 0, null, "Bag"], ["Menu", 1, null, "MenuToggle"],
		["+1", 2, load("res://assets/kenney/mouse_left.png"), "Plus"],
		["A Much Longer Button", 0, null, "Long"], ["Draw Card", 2, null, "Draw"]]
	for d in defs:
		var b := jb.instantiate()
		b.name = d[3]; b.unique_name_in_owner = true
		b.text = d[0]; b.shadow_dir = d[1]
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if d[2]: b.icon = d[2]; b.expand_icon = false
		title.add_child(b)
	var counter := Label.new(); counter.name = "Counter"; counter.unique_name_in_owner = true
	counter.set_script(load("res://addons/proto_kit/ui_anim/tween_once.gd"))
	counter.text = "0"; counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	counter.add_theme_font_size_override("font_size", 40)
	counter.add_theme_color_override("font_color", Color("3b2a1e"))
	title.add_child(counter)

	# 設定面板浮在最上層的 overlay：不進任何既有 Container，開關不影響原本版面
	var overlay := Control.new(); overlay.name = "Overlay"; overlay.unique_name_in_owner = true
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT); overlay.visible = false
	var dim := ColorRect.new(); dim.name = "Dim"; dim.unique_name_in_owner = true
	dim.color = Color(0, 0, 0, 0.45); dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var oc := CenterContainer.new(); oc.name = "Center"; oc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	oc.set_anchors_preset(Control.PRESET_FULL_RECT); overlay.add_child(oc)
	var menu := PanelContainer.new(); menu.name = "Menu"; menu.unique_name_in_owner = true
	menu.add_theme_stylebox_override("panel", load("res://scenes/button_frame.tres"))
	menu.custom_minimum_size = Vector2(260, 0)
	oc.add_child(menu)
	var mv := VBoxContainer.new(); mv.name = "Items"
	mv.set_script(load("res://addons/proto_kit/ui_anim/container_tween.gd"))
	mv.set("trigger", 1); mv.set("anim_type", 1)
	mv.set("appear_sound", load("res://assets/sfx/appear.ogg"))
	mv.add_theme_constant_override("separation", 12)
	menu.add_child(mv)
	var head := Label.new(); head.name = "MenuHead"; head.text = "Settings"
	head.add_theme_font_size_override("font_size", 28)
	head.add_theme_color_override("font_color", Color("3b2a1e"))
	var at := Node.new(); at.name = "AutoTween"; at.set_script(load("res://addons/proto_kit/ui_anim/auto_tween.gd"))
	head.add_child(at)
	mv.add_child(head)
	for t in ["Audio", "Video", "Back"]:
		var b := jb.instantiate(); b.name = t; b.text = t
		b.unique_name_in_owner = t == "Back"
		b.shadow_dir = 2
		mv.add_child(b)
	center.set_anchors_preset(Control.PRESET_TOP_WIDE); center.offset_bottom = 520
	var hand := HBoxContainer.new(); hand.name = "Hand"; hand.unique_name_in_owner = true
	hand.set_script(load("res://scripts/card_hand.gd"))
	hand.set("card_scene", load("res://scenes/card.tscn"))
	hand.alignment = BoxContainer.ALIGNMENT_CENTER
	hand.add_theme_constant_override("separation", 0)
	hand.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hand.offset_top = -200; hand.offset_bottom = -50
	root.add_child(hand)
	root.add_child(overlay)
	var bo := Control.new(); bo.name = "BagOverlay"; bo.unique_name_in_owner = true
	bo.set_anchors_preset(Control.PRESET_FULL_RECT); bo.visible = false
	var bdim := ColorRect.new(); bdim.name = "Dim"
	bdim.color = Color(0, 0, 0, 0.45); bdim.set_anchors_preset(Control.PRESET_FULL_RECT)
	bo.add_child(bdim)
	var bc := CenterContainer.new(); bc.name = "Center"; bc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bc.set_anchors_preset(Control.PRESET_FULL_RECT); bo.add_child(bc)
	var invi := (load("res://scenes/inventory.tscn") as PackedScene).instantiate()
	invi.unique_name_in_owner = true
	bc.add_child(invi)
	root.add_child(bo)
	_save(root, "res://scenes/demo.tscn")
	quit()
