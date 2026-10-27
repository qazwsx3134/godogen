extends SceneTree
## One-time authoring tool for the 推王戰報: writes scenes/report_row.tscn and scenes/push_report.tscn (with preview
## text, so the layout is visible in the editor) and puts the report into hud.tscn's result panel, between the detail
## line and the retry button. Existing scenes are skipped; hud.tscn only while it has no Report node.
##   godot --headless --path prototypes/hero-horde-idle --script res://tools/build_report.gd

const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")
const ROW := "res://scenes/report_row.tscn"
const REPORT := "res://scenes/push_report.tscn"
const HUD := "res://scenes/hud.tscn"
const GOLD := Color(1.0, 0.85, 0.35)
const DIM := Color(0.78, 0.8, 0.9)
const WARN := Color(1.0, 0.62, 0.55)
const PREVIEW := [["卡琳娜", "2.4萬"], ["溫嘉", "1.9萬"], ["羅珀", "1.6萬"]]


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var ok: bool = SceneBuilder.save_scene(_row(), ROW).ok
	ok = ok and SceneBuilder.save_scene(_report(), REPORT, {"expected_refs": [ROW]}).ok
	ok = ok and _patch_hud()
	quit(0 if ok else 1)


func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "ReportRow"
	row.set_script(load("res://scripts/report_row.gd"))
	row.add_theme_constant_override(&"separation", 8)
	var rank := _label("1", 22, GOLD)
	rank.custom_minimum_size = Vector2(22, 0)
	SceneBuilder.add(row, SceneBuilder.unique(rank), "Rank")
	var hero := _label("卡琳娜", 22, Color.WHITE)
	hero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.clip_text = true
	SceneBuilder.add(row, SceneBuilder.unique(hero), "HeroName")
	SceneBuilder.add(row, SceneBuilder.unique(_label("2.4萬", 22, DIM)), "Value")
	return row


func _report() -> VBoxContainer:
	var report := VBoxContainer.new()
	report.name = "PushReport"
	report.set_script(load("res://scripts/push_report_view.gd"))
	report.add_theme_constant_override(&"separation", 14)

	var mvp := SceneBuilder.add(report, HBoxContainer.new(), "Mvp") as HBoxContainer
	mvp.add_theme_constant_override(&"separation", 14)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(96, 96)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var preview := AtlasTexture.new()
	preview.atlas = load("res://assets/heroes/heroes.png")
	preview.region = Rect2(4 * 48, 5 * 48, 48, 48)
	portrait.texture = preview
	SceneBuilder.add(mvp, SceneBuilder.unique(portrait), "Portrait")
	var text := SceneBuilder.add(mvp, VBoxContainer.new(), "MvpText") as VBoxContainer
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	SceneBuilder.add(text, SceneBuilder.unique(_label("MVP　嘉特", 32, GOLD)), "MvpName")
	var line := _label("SSR 補　承傷 873　治療 7036　救援 5 次", 22, DIM)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	SceneBuilder.add(text, SceneBuilder.unique(line), "MvpLine")

	var boards := SceneBuilder.add(report, SceneBuilder.unique(HBoxContainer.new()), "Boards") as HBoxContainer
	boards.add_theme_constant_override(&"separation", 16)
	for title: String in ["輸出", "承傷", "治療"]:
		var column := SceneBuilder.add(boards, VBoxContainer.new(), "Board_" + title) as VBoxContainer
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		SceneBuilder.add(column, _label(title, 24, GOLD), "Title")
		var rows := SceneBuilder.add(column, VBoxContainer.new(), "Rows") as VBoxContainer
		for k: int in 3:
			var row: Node = SceneBuilder.instance(ROW)
			SceneBuilder.add(rows, row, "Row_%d" % (k + 1))

	var diagnosis := _label("被「落石」打倒 30 人\n近2 最慘：倒下 18 人\n建議：紅區一出現就移區，落下後再全員歸位\n建議養成：補（撐住王的攻擊）", 22, WARN)
	diagnosis.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	SceneBuilder.add(report, SceneBuilder.unique(diagnosis), "Diagnosis")
	return report


func _patch_hud() -> bool:
	var hud: Node = (load(HUD) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var box: Node = hud.get_node("Root/Result/Center/Panel/PanelBox")
	if box.get_node_or_null("Report") != null:
		print("skip (already has Report): ", HUD)
		hud.free()
		return true
	var report: Node = SceneBuilder.instance(REPORT)
	SceneBuilder.add(box, SceneBuilder.unique(report), "Report")
	box.move_child(report, box.get_node("Retry").get_index())
	return SceneBuilder.save_scene(hud, HUD, {"overwrite": true, "expected_refs": [REPORT]}).ok


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	return label
