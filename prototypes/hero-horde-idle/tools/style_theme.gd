extends SceneTree
## Puts the pixel-art frames (assets/ui/frame, tools/make_ui_frames.py) into ui/theme.tres: secondary and primary
## buttons get the notched double-line frames, and a Dialog variation of PanelContainer frames the pop-up dialogs
## (tools/style_dialogs.gd gives it to them). It loads the theme and changes only those entries, so other tuning in
## the editor stays. Applied 2026-10-22; running it again is harmless.
##   godot --headless --path prototypes/hero-horde-idle --script res://tools/style_theme.gd
## Type variations added:
##   Dialog      PanelContainer of a pop-up (離線戰報, 暫停, 結算, 設定, 招募's overlays, the test ad)

const NineSlice = preload("res://addons/proto_kit/nine_slice.gd")
const PATH := "res://ui/theme.tres"
const FRAMES := "res://assets/ui/frame/%s.png"


func _initialize() -> void:
	var theme: Theme = load(PATH)
	# Pressed states sink the content 2 px; hover_pressed shares the pressed frame (godot-kit nine_slice).
	var ok: bool = NineSlice.button_states(theme, &"Button", FRAMES % "button%s", 14, Vector4(20, 8, 20, 8))
	ok = NineSlice.button_states(theme, &"PrimaryButton", FRAMES % "primary%s", 14, Vector4(20, 8, 20, 8)) and ok
	theme.set_type_variation(&"Dialog", &"PanelContainer")
	theme.set_stylebox(&"panel", &"Dialog", NineSlice.box(load(FRAMES % "dialog"), 24, Vector4(34, 26, 34, 30)))
	var error: Error = ResourceSaver.save(theme, PATH) if ok else FAILED
	print("theme: ", error_string(error))
	quit(0 if error == OK else 1)
