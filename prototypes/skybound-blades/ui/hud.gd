extends CanvasLayer
## Field HUD. Owns its own nodes (%names resolve inside hud.tscn only); the field talks to it
## through these signals and refresh()/log_line()/toast()/show_end(). Layout lives in the scene.

signal auto_toggled(on: bool)
signal auto_potion_toggled(on: bool)
signal skill_pressed
signal tonic_pressed
signal emergency_pressed
signal claim_pressed
signal pause_toggled(on: bool)
signal restart_pressed
signal zoom_requested(step: int)
signal setting_changed(key: String, value: bool)
signal retreat_pressed
signal bag_pressed
signal camp_pressed
signal camp_action(action: Dictionary)
signal camp_closed

const PartyRow = preload("res://ui/party_row.gd")

@onready var _party_rows: Array[Node] = %PartyList.get_children()
@onready var _feed: Array[Node] = %Feed.get_children()

var _feed_lines: Array[Dictionary] = []
var _toast_left: float = 0.0
var _last: Dictionary = {}


func _ready() -> void:
	%AutoButton.toggled.connect(func(on: bool) -> void: auto_toggled.emit(on))
	%AutoPotionButton.toggled.connect(func(on: bool) -> void: auto_potion_toggled.emit(on))
	%SkillButton.pressed.connect(func() -> void: skill_pressed.emit())
	%TonicButton.pressed.connect(func() -> void: tonic_pressed.emit())
	%EmergencyButton.pressed.connect(func() -> void: emergency_pressed.emit())
	%ClaimButton.pressed.connect(func() -> void: claim_pressed.emit())
	%PauseButton.pressed.connect(func() -> void: set_paused(true))
	%ResumeButton.pressed.connect(func() -> void: set_paused(false))
	%RestartButton.pressed.connect(func() -> void: restart_pressed.emit())
	%PauseRestartButton.pressed.connect(func() -> void: restart_pressed.emit())
	%ZoomInButton.pressed.connect(func() -> void: zoom_requested.emit(-1))
	%ZoomOutButton.pressed.connect(func() -> void: zoom_requested.emit(1))
	%RetreatButton.pressed.connect(func() -> void: retreat_pressed.emit())
	%BagButton.pressed.connect(func() -> void: bag_pressed.emit())
	%CampButton.pressed.connect(func() -> void: camp_pressed.emit())
	%TripClose.pressed.connect(func() -> void: %TripPanel.hide())
	var camp_panel: Node = %CampLayer.get_node("CampPanel")
	camp_panel.action.connect(func(a: Dictionary) -> void: camp_action.emit(a))
	camp_panel.closed.connect(func() -> void:
		%CampLayer.hide()
		camp_closed.emit())
	# Restarting a generation by hand would undo a death: only the end panel starts the next one.
	%PauseRestartButton.hide()
	for check: CheckButton in [%DamageNumbersCheck, %ShakeCheck, %HapticsCheck, %AutoRetreatCheck]:
		var key: String = check.get_meta("setting")
		check.toggled.connect(func(on: bool) -> void: setting_changed.emit(key, on))
	%EndPanel.hide()
	%PausePanel.hide()
	%RotatePanel.hide()
	%TripPanel.hide()
	%CampLayer.hide()
	%Toast.modulate.a = 0.0
	for label: Label in _feed:
		label.text = ""


func _process(delta: float) -> void:
	_toast_left = maxf(0.0, _toast_left - delta)
	%Toast.modulate.a = clampf(_toast_left / 0.4, 0.0, 1.0)
	var now := Time.get_ticks_msec()
	for i in _feed.size():
		var label: Label = _feed[i]
		if i < _feed_lines.size():
			var age := (now - int(_feed_lines[i].at)) / 1000.0
			label.modulate.a = clampf(1.0 - (age - 6.0) / 2.0, 0.25, 1.0)


func show_preferences(settings: Dictionary) -> void:
	for check: CheckButton in [%DamageNumbersCheck, %ShakeCheck, %HapticsCheck, %AutoRetreatCheck]:
		check.set_pressed_no_signal(bool(settings.get(String(check.get_meta("setting")), true)))


func set_paused(on: bool) -> void:
	%PausePanel.visible = on
	pause_toggled.emit(on)


## state: see field.gd hud_state().
func refresh(s: Dictionary) -> void:
	_last = s
	%ExpeditionStatus.text = s.get("expedition_status", "")
	%LevelLabel.text = "Lv.%d" % s.level
	%GoldLabel.text = "%d" % s.gold
	%MaterialLabel.text = "%d" % s.material
	%ExpBar.max_value = s.exp_need
	%ExpBar.value = s.exp
	%ExpLabel.text = "EXP %d / %d" % [int(s.exp), s.exp_need]
	for i in _party_rows.size():
		(_party_rows[i] as PartyRow).show_member(s.party[i] if i < s.party.size() else {})
	var target: Dictionary = s.target
	%TargetFrame.visible = not target.is_empty()
	if not target.is_empty():
		%TargetName.text = "%s  Lv.%d" % [target.name, target.level]
		%TargetBar.max_value = target.max
		%TargetBar.value = target.hp
	var quest: Dictionary = s.quest
	%QuestProgress.text = "%s  %d / %d" % [quest.target_name, quest.progress, quest.count]
	%QuestReward.text = "報酬  %d EXP · %d 金幣" % [quest.exp, quest.gold]
	%ClaimButton.disabled = not quest.ready
	%ClaimButton.text = "回報委託" if quest.cooldown_s <= 0.0 else "冷卻 %d:%02d" % [int(quest.cooldown_s) / 60, int(quest.cooldown_s) % 60]
	%AutoButton.set_pressed_no_signal(s.auto)
	%AutoLabel.text = "自動\n狩獵中" if s.auto else "自動\n狩獵"
	%AutoPotionButton.set_pressed_no_signal(s.auto_potion)
	%SkillCooldown.max_value = s.skill_total
	%SkillName.text = s.skill_label
	%SkillCooldown.value = s.skill_cd
	%SkillTime.text = "%.1f" % (s.skill_cd / 1000.0) if s.skill_cd > 0.0 else ""
	%SkillButton.disabled = s.ended
	# Ready: a gold rim tells the player the skill can fire now.
	%SkillButton.modulate = Color(1.0, 0.93, 0.7) if s.skill_cd <= 0.0 and not s.ended else Color.WHITE
	%TonicCount.text = "×%d" % s.tonic
	%TonicButton.disabled = s.ended or s.tonic <= 0
	%EmergencyCount.text = "×%d" % s.emergency
	%EmergencyButton.disabled = s.ended or s.emergency <= 0 or s.emergency_cd > 0.0
	%StatusLabel.text = s.status
	%CampButton.visible = s.in_camp
	%RetreatButton.disabled = s.ended or s.in_camp or s.retreating
	%RetreatButton.text = "撤退中…" if s.retreating else "撤退 T"


func log_line(text: String, kind: String = "") -> void:
	_feed_lines.push_front({"text": text, "kind": kind, "at": Time.get_ticks_msec()})
	_feed_lines.resize(mini(_feed_lines.size(), _feed.size()))
	var colors := {"loot": Color("f3d27a"), "level": Color("9fe0ff"), "warn": Color("ff9e8a"), "": Color("eae3d2")}
	for i in _feed.size():
		var label: Label = _feed[i]
		label.text = _feed_lines[i].text if i < _feed_lines.size() else ""
		if i < _feed_lines.size():
			label.add_theme_color_override(&"font_color", colors.get(_feed_lines[i].kind, colors[""]))


func toast(text: String) -> void:
	%Toast.text = text
	_toast_left = 1.6


## tabs = {page name: {"rows": [...]}}; tab = page to select ("" keeps the current one).
func show_camp(tabs: Dictionary, header: String, tab: String = "") -> void:
	var panel: Node = %CampLayer.get_node("CampPanel")
	panel.show_tabs(tabs, header)
	if tab != "":
		panel.select_tab(tab)
	%CampLayer.show()
	panel.show()


## Phone layout (field.gd fit_screen draws the UI for a 600-high screen): offsets [left, top, right, bottom] that
## replace the scene's own while compact, so the corners do not overlap. The desktop layout stays in hud.tscn.
const COMPACT_OFFSETS := {
	"TopRight": [-366.0, 20.0, -24.0, 124.0],
	"TopLeft": [24.0, 20.0, 372.0, 520.0],  # narrower party column, leaves the top centre to the target bar
	"TopCenter": [-200.0, 20.0, 200.0, 140.0],
	"QuestPanel": [-388.0, 128.0, -24.0, 128.0],  # top-anchored under the zoom/pause row; grows to its content
	"Feed": [390.0, -220.0, 860.0, -52.0],
	"ActionCluster": [-420.0, -362.0, -24.0, -44.0],
	"ActionCluster/SkillButton": [232.0, 154.0, 396.0, 318.0],
	"ActionCluster/AutoButton": [92.0, 194.0, 216.0, 318.0],
	"ActionCluster/TonicButton": [118.0, 58.0, 228.0, 168.0],
	"ActionCluster/EmergencyButton": [262.0, 14.0, 372.0, 124.0],  # bottom centre, between the menu buttons and the skill buttons
}


func set_compact(on: bool) -> void:
	%CampLayer.get_node("CampPanel").set_compact(on)
	for button: Control in $Frame/TopRight.get_children():
		if not button.has_meta("desk_minimum"):
			button.set_meta("desk_minimum", button.custom_minimum_size)
		button.custom_minimum_size = Vector2(104, 104) if on else button.get_meta("desk_minimum")
	for node_name: String in COMPACT_OFFSETS:
		var node: Control = $Frame.get_node(node_name)
		if not node.has_meta("desk_layout"):
			node.set_meta("desk_layout", [node.anchor_top, node.anchor_bottom,
				node.offset_left, node.offset_top, node.offset_right, node.offset_bottom])
		if node_name == "ActionCluster":
			if not node.has_meta("desk_anchor_x"):
				node.set_meta("desk_anchor_x", [node.anchor_left, node.anchor_right])
			var anchors: Array = node.get_meta("desk_anchor_x")
			node.anchor_left = 1.0 if on else anchors[0]
			node.anchor_right = 1.0 if on else anchors[1]
		if node_name.begins_with("ActionCluster/"):
			if not node.has_meta("desk_minimum"):
				node.set_meta("desk_minimum", node.custom_minimum_size)
			node.custom_minimum_size = Vector2.ZERO if on else node.get_meta("desk_minimum")
			node.theme_type_variation = &"RoundButton" if on else &""
		var desk: Array = node.get_meta("desk_layout")
		var o: Array = COMPACT_OFFSETS[node_name] if on else desk.slice(2)
		if node_name == "QuestPanel":
			node.anchor_top = 0.0 if on else desk[0]
			node.anchor_bottom = 0.0 if on else desk[1]
		node.offset_left = o[0]
		node.offset_top = o[1]
		node.offset_right = o[2]
		node.offset_bottom = o[3]
	# Quests are handed in from the camp's 委託 tab; on a phone the button would sit on the skill buttons, and the
	# title takes the body size so the panel ends above them.
	%ClaimButton.visible = not on
	$Frame/QuestPanel/Rows/QuestTitle.theme_type_variation = &"" if on else &"TitleLabel"


func camp_open() -> bool:
	return %CampLayer.visible


func camp_tab() -> String:
	return %CampLayer.get_node("CampPanel").current_tab_name()


func hide_camp() -> void:
	%CampLayer.hide()


func show_trip(text: String) -> void:
	%TripSummary.text = text
	%TripPanel.show()


func show_rotate(on: bool) -> void:
	%RotatePanel.visible = on


func show_end(summary: String) -> void:
	%EndSummary.text = summary
	%EndPanel.show()


func hide_end() -> void:
	%EndPanel.hide()
	%PausePanel.hide()
	%TripPanel.hide()
	%CampLayer.hide()


func set_end_button(text: String) -> void:
	%RestartButton.text = text
