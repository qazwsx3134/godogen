extends SceneTree
## Applied 2026-10-28: the 裝備 tab folds into the 英雄 page (its detail's 裝備欄位, tools/build_hero_detail.gd), so the
## nav bar keeps five buttons (天賦 背包 英雄 冒險 商店), spread over the bar's width with their red dots, and
## home.tscn drops the 裝備 page. Skips a scene already changed.
##   godot --headless --path prototypes/hero-horde-idle --script res://tools/build_nav5.gd

const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")
const NAV := "res://scenes/components/navigation.tscn"
const HOME := "res://scenes/home.tscn"
const LEFT := 12.0
const WIDTH := 172.0
const GAP := 12.0
const DOT := 34.0


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var ok: bool = _nav()
	ok = _home() and ok
	quit(0 if ok else 1)


func _nav() -> bool:
	var opened: Dictionary = SceneBuilder.open_scene(NAV)
	var root: Control = opened.root
	var gone: Node = root.get_node_or_null("EquipmentButton")
	if gone == null:
		root.free()
		return true
	gone.free()
	var k: int = 0
	for b: Node in root.get_children():
		if not b is Button:
			continue
		var button := b as Button
		var grow: float = (WIDTH - button.size.x) / 2.0
		button.position.x = LEFT + k * (WIDTH + GAP)
		button.size.x = WIDTH
		for child: Node in button.get_children():
			(child as Control).position.x += grow
		k += 1
	return SceneBuilder.save_scene(root, NAV, {"overwrite": true, "expected_refs": opened.refs}).ok


func _home() -> bool:
	var opened: Dictionary = SceneBuilder.open_scene(HOME)
	var root: Control = opened.root
	var page: Node = root.get_node_or_null("Pages/Equipment")
	if page == null:
		root.free()
		return true
	page.free()
	var dots: Node = root.get_node("NavDots")
	dots.get_node("Dot5").free()
	for k: int in dots.get_child_count():
		var dot: Control = dots.get_child(k)
		dot.position.x = LEFT + k * (WIDTH + GAP) + WIDTH - DOT
	var refs: Array = opened.refs.filter(func(r: String) -> bool: return r != "res://scenes/pages/equipment.tscn")
	return SceneBuilder.save_scene(root, HOME, {"overwrite": true, "expected_refs": refs}).ok
