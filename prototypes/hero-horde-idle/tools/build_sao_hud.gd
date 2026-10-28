extends SceneTree
## Applied 2026-10-28: puts the SAO kit (scenes/ui_kit/) into the battle screens. The 行軍 fighters' HP bar becomes
## %HealthBar (sao_unit_bar) and the leader plate goes (every fighter has its own bar); the push HUD's top shows only
## the 樓層王's name and bar (%BossBar, sao_boss_bar) beside 暫停, and the countdown as %TimerBar (sao_timer_bar). The
## old top labels stay in the scene, hidden (hud.gd still fills them; the tests read them). Skips what is done.
##   godot --headless --path prototypes/hero-horde-idle --script res://tools/build_sao_hud.gd

const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")
const UNIT := "res://scenes/march_unit.tscn"
const ARENA := "res://scenes/march_arena.tscn"
const HUD := "res://scenes/hud.tscn"
const KIT := "res://scenes/ui_kit/%s.tscn"
const HIDDEN := ["StageLabel", "BossName", "PhasePill", "TimerBox"]


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var ok: bool = _unit()
	ok = _arena() and ok
	ok = _hud() and ok
	quit(0 if ok else 1)


func _refs(opened: Dictionary, add: Array = [], drop: Array = []) -> Array:
	var refs: Array = opened.refs.filter(func(r: String) -> bool: return not drop.has(r))
	for r: String in add:
		if not refs.has(r):
			refs.append(r)
	return refs


func _unit() -> bool:
	var opened: Dictionary = SceneBuilder.open_scene(UNIT)
	var root: Node2D = opened.root
	if root.get_node_or_null("HealthBar") != null:
		root.free()
		return true
	for n: String in ["HealthBackground", "HealthFill"]:
		root.get_node(n).free()
	var bar: Control = SceneBuilder.add(root, SceneBuilder.unique(SceneBuilder.instance(KIT % "sao_unit_bar")), "HealthBar")
	bar.position = Vector2(-36, -118)
	root.move_child(bar, root.get_node("DamageFeedback").get_index())
	return SceneBuilder.save_scene(root, UNIT, {"overwrite": true, "expected_refs": _refs(opened, [KIT % "sao_unit_bar"])}).ok


func _arena() -> bool:
	var opened: Dictionary = SceneBuilder.open_scene(ARENA)
	var root: Node2D = opened.root
	var plate: Node = root.get_node_or_null("LeaderPlate")
	if plate == null:
		root.free()
		return true
	plate.free()
	var wave: Label = root.get_node("WaveLabel")
	wave.position = Vector2(20, -350)
	wave.size = Vector2(700, 40)
	wave.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var refs: Array = _refs(opened, [], ["res://scenes/leader_plate.tscn"])
	return SceneBuilder.save_scene(root, ARENA, {"overwrite": true, "expected_refs": refs}).ok


func _hud() -> bool:
	var opened: Dictionary = SceneBuilder.open_scene(HUD)
	var root: Node = opened.root
	var box: Node = root.get_node("Root/Top/TopPanel/TopBox")
	if box.get_node_or_null("TimerBar") != null:
		root.free()
		return true
	(root.get_node("Root/Top/TopPanel") as Control).add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	var row: Node = box.get_node("TitleRow")
	for n: String in HIDDEN:
		(row.get_node(n) as Control).visible = false
	for n: String in ["BossHp", "DpsLabel"]:
		(box.get_node(n) as Control).visible = false
	var boss: Control = SceneBuilder.add(row, SceneBuilder.unique(SceneBuilder.instance(KIT % "sao_boss_bar")), "BossBar")
	boss.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss.custom_minimum_size = Vector2(0, 84)
	row.move_child(boss, row.get_node("Pause").get_index() + 1)
	(row.get_node("Pause") as Control).size_flags_vertical = Control.SIZE_SHRINK_END
	var timer: Control = SceneBuilder.add(box, SceneBuilder.unique(SceneBuilder.instance(KIT % "sao_timer_bar")), "TimerBar")
	timer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timer.custom_minimum_size = Vector2(0, 16)
	box.move_child(timer, row.get_index() + 1)
	var refs: Array = _refs(opened, [KIT % "sao_boss_bar", KIT % "sao_timer_bar"])
	return SceneBuilder.save_scene(root, HUD, {"overwrite": true, "expected_refs": refs}).ok
