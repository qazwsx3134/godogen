extends RefCounted

## main.gd 的第一次教學（data/tutorials.json）：何時出現、框住哪個按鈕、看過的記錄。

const ATOMIC_FILE: Script = preload("res://addons/proto_kit/atomic_file.gd")

var m: DebtMain


func _init(main: DebtMain) -> void:
	m = main


func _build_tutorial() -> void:
	m._tutorial = preload("res://scenes/ui/tutorial_overlay.tscn").instantiate()
	m._popup_layer.add_child(m._tutorial)  # last child: above every other popup
	m._tutorial.visible = false
	m._tutorial.connect("finished", _on_tutorial_finished)
	m._apply_ui_style_recursive(m._tutorial)
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(m.tutorials_path)) \
		if FileAccess.file_exists(m.tutorials_path) else null  # a plain JSON file ships as-is (export include_filter)
	m._tutorials = (data as Dictionary).get("tutorials", []) if data is Dictionary else []


## Guides show for players only. ponytail: headless runs (the test suites) and ?qa=1 browser checks skip them unless
## DEBT_TUTORIAL=1 / &tutorial=1 asks, so the 40-odd existing suites need no per-file switch.
func _tutorials_on() -> bool:
	if not m.tutorials_enabled or int(m._settings.get("tutorial", 0)) != 0:
		return false
	if DisplayServer.get_name() == "headless" and OS.get_environment("DEBT_TUTORIAL") != "1":
		return false
	if m._qa_enabled and not bool(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('tutorial') === '1'")):
		return false
	return true


## The guide for `trigger` (a screen mode), once: only if that screen is still up and nothing else covers it.
func _maybe_tutorial(trigger: String) -> void:
	if m._screen_mode != trigger or m._tutorial.visible or not _tutorials_on():
		return
	if trigger == "boke_round" and not m._boke_controls.visible:
		return  # combo lines open their slot at once; the guide waits for a round the player reads
	var seen: Array = _tutorials_seen()
	for def: Dictionary in m._tutorials:
		if str(def.get("trigger", "")) == trigger and str(def.get("id", "")) not in seen:
			m._set_auto(false)
			m._set_skip(false)
			m._tutorial.call("start", str(def.id), def.get("steps", []), _tutorial_target)
			m._qa_ctl._publish_qa_state()
			return


func _tutorial_target(target: String) -> Control:
	match target:
		"boke_switch": return m._boke_previous_button.get_parent() as Control
		"boke_listen": return m._boke_listen_button
		"boke_tsukkomi": return m._boke_tsukkomi_button
		"investigate_scene": return m._stage_area  # the picture above the reading box
		"investigate_collapse": return m._dialog_panel.collapse_tab
		"investigate_continue": return m._investigation_continue_button
	return null


func _on_tutorial_finished(id: String, _skipped: bool) -> void:
	var seen: Array = _tutorials_seen()
	if id not in seen:
		seen.append(id)
	_write_tutorials_seen(seen)
	m._qa_ctl._publish_qa_state()


func _tutorials_seen() -> Array:
	var config: ConfigFile = ConfigFile.new()
	if config.load(m.progress_path) != OK:
		return []
	var seen: Variant = config.get_value("tutorial", "seen", [])
	return (seen as Array).duplicate() if seen is Array else []


## Writes [tutorial] seen into progress_path, keeping its other sections ([cleared], endings).
func _write_tutorials_seen(seen: Array) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(m.progress_path)
	config.set_value("tutorial", "seen", seen)
	if ATOMIC_FILE.write_text(m.progress_path, config.encode_to_text()) != OK:
		m._show_toast("教學進度無法儲存")


## 設定 → 重看教學: every guide shows again the next time its screen opens.
func _replay_tutorials() -> void:
	_write_tutorials_seen([])
	m._show_toast("下次進入吐槽與調查時會再顯示教學")
