extends CanvasLayer
## FPS／draw call 顯示＋逐項開關，找出最花效能的設定。F1–F9 切換（不佔數字鍵，遊戲常用），畫面上列出狀態：
##   F1 太陽陰影  F2 SSAO  F3 SSIL  F4 SDFGI  F5 霧  F6 草（group "grass"）  F7 MSAA  F8 TAA  F9 後製（group "post"）
## 掛在任何 3D 場景底下即可；會自己找 WorldEnvironment 與 DirectionalLight3D。F10 隱藏。

@export var label_position := Vector2(8, 8)

var _label := Label.new()


func _ready() -> void:
	layer = 120
	_label.position = label_position
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)


func _env() -> Environment:
	var w := get_tree().root.find_children("*", "WorldEnvironment", true, false)
	return w[0].environment if w else null


func _sun() -> DirectionalLight3D:
	var s := get_tree().root.find_children("*", "DirectionalLight3D", true, false)
	return s[0] if s else null


func _unhandled_key_input(e: InputEvent) -> void:
	if not e.is_pressed() or e.is_echo():
		return
	var env := _env()
	var vp := get_viewport()
	match e.keycode:
		KEY_F1: if _sun(): _sun().shadow_enabled = not _sun().shadow_enabled
		KEY_F2: if env: env.ssao_enabled = not env.ssao_enabled
		KEY_F3: if env: env.ssil_enabled = not env.ssil_enabled
		KEY_F4: if env: env.sdfgi_enabled = not env.sdfgi_enabled
		KEY_F5: if env: env.fog_enabled = not env.fog_enabled
		KEY_F6: for g in get_tree().get_nodes_in_group(&"grass"): g.visible = not g.visible
		KEY_F7: vp.msaa_3d = Viewport.MSAA_DISABLED if vp.msaa_3d != Viewport.MSAA_DISABLED else Viewport.MSAA_2X
		KEY_F8: vp.use_taa = not vp.use_taa
		KEY_F9: for g in get_tree().get_nodes_in_group(&"post"): g.visible = not g.visible
		KEY_F10: _label.visible = not _label.visible


func _process(_d: float) -> void:
	if not _label.visible:
		return
	var env := _env()
	var vp := get_viewport()
	var on := func(b: bool) -> String: return "on " if b else "off"
	var grass := get_tree().get_nodes_in_group(&"grass")
	var post := get_tree().get_nodes_in_group(&"post")
	_label.text = "FPS %d  (%.1f ms)  draw calls %d  prims %dk\n" % [
		Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000]
	_label.text += "F1 shadow %s  F2 SSAO %s  F3 SSIL %s  F4 SDFGI %s  F5 fog %s\nF6 grass %s  F7 MSAA %s  F8 TAA %s  F9 post %s" % [
		on.call(_sun() != null and _sun().shadow_enabled), on.call(env and env.ssao_enabled), on.call(env and env.ssil_enabled),
		on.call(env and env.sdfgi_enabled), on.call(env and env.fog_enabled),
		on.call(grass.is_empty() or grass[0].visible), on.call(vp.msaa_3d != Viewport.MSAA_DISABLED), on.call(vp.use_taa),
		on.call(post.is_empty() or post[0].visible)]
