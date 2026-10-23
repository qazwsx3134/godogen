extends CanvasLayer
## Push HUD: boss HP, phase and push timer on top; at the bottom the three squad tabs (tap = select that squad), morale
## with a hint, 全員歸位 and 大招; over the field the boss's part buttons (aim the ranged squad); the banner strip, the
## 招牌技 callout and the result panel. Layout lives in scenes/hud.tscn (tools/build_hud.gd); this only fills values.

const PushSim = preload("res://domain/push_sim.gd")
const Items = preload("res://domain/items.gd")
const RewardRow = preload("res://scenes/reward_row.tscn")

## part: PushSim.Part.
signal part_pressed(part: int)
## squad: PushSim.MELEE / RANGED / SUPPORT.
signal squad_pressed(squad: int)
signal regroup_pressed
signal volley_pressed
signal skip_pressed
signal retry_pressed
signal grow_pressed
signal next_pressed
## 回營地 from the result, or 撤退 from the pause menu.
signal camp_pressed

@onready var _boss_hp: ProgressBar = %BossHp
@onready var _stage_label: Label = %StageLabel
@onready var _boss_name: Label = %BossName
@onready var _next: Button = %NextStage
@onready var _boss_hp_label: Label = %BossHpLabel
@onready var _phase: Label = %PhaseLabel
@onready var _timer: Label = %TimerLabel
@onready var _dps: Label = %DpsLabel
@onready var _morale: ProgressBar = %Morale
@onready var _banner: Label = %Banner
@onready var _strip: PanelContainer = %BannerStrip
@onready var _bang: ColorRect = %Bang
@onready var _squads: HBoxContainer = %SquadTabs
@onready var _hint: Label = %Hint
@onready var _skip: Button = %SkipMuster
@onready var _parts: Control = %Parts
@onready var _callout: Control = %SkillCallout
@onready var _regroup: Button = %Regroup
@onready var _volley: Button = %Volley
@onready var _result: Control = %Result
@onready var _result_title: Label = %ResultTitle
@onready var _result_detail: Label = %ResultDetail
@onready var _retry: Button = %Retry
@onready var _grow: Button = %GoGrow
@onready var _rewards: Label = %Rewards
@onready var _reward_grid: GridContainer = %RewardGrid
@onready var _report: VBoxContainer = %Report

var _banner_t: float = 0.0
var _coach_t: float = 0.0
var _strip_box: StyleBoxFlat


func _ready() -> void:
	for button: Node in _parts.get_children():
		button.pressed.connect(func() -> void: part_pressed.emit(button.part_index))
		button.visible = false
	_regroup.pressed.connect(regroup_pressed.emit)
	_volley.pressed.connect(volley_pressed.emit)
	_skip.pressed.connect(skip_pressed.emit)
	_retry.pressed.connect(retry_pressed.emit)
	_grow.pressed.connect(grow_pressed.emit)
	_next.pressed.connect(next_pressed.emit)
	%ResultCamp.pressed.connect(camp_pressed.emit)
	%Pause.pressed.connect(pause)
	%Resume.pressed.connect(resume)
	%Retreat.pressed.connect(func() -> void:
		resume()
		camp_pressed.emit())
	%PauseSettings.pressed.connect(func() -> void:
		%PausePanel.visible = false
		%SettingsPanel.visible = true)
	%SettingsPanel.closed.connect(func() -> void:
		%SettingsPanel.visible = false
		%PausePanel.visible = true)
	for s: int in _squads.get_child_count():
		(_squads.get_child(s) as Button).pressed.connect(func() -> void: squad_pressed.emit(s))
	_strip_box = (_strip.get_theme_stylebox(&"panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	_strip.add_theme_stylebox_override(&"panel", _strip_box)
	_strip.visible = false
	_result.visible = false


func show_state(sim: PushSim, selected: int, dt: float) -> void:
	_boss_hp.value = sim.hp_ratio() * 100.0
	_boss_hp_label.text = "%d%%" % ceili(sim.hp_ratio() * 100.0)
	_phase.text = "第二階段" if sim.phase2 else "第一階段"
	_timer.text = "%d" % ceili(sim.time_left())
	_timer.modulate = Color(1.0, 0.4, 0.35) if sim.time_left() <= 20.0 and sim.fighting() else Color.WHITE
	_dps.text = "存活 %d／%d   總輸出 %d／秒" % [sim.living(), sim.cls.size(), roundi(sim.dps)]
	_morale.value = sim.morale
	_skip.visible = sim.phase == PushSim.Phase.MUSTER
	var fighting: bool = sim.fighting()
	for s: int in _squads.get_child_count():
		var tab: Button = _squads.get_child(s)
		tab.text = "%s\n%d 人" % [PushSim.SQUAD_NAMES[s], sim.squad_living(s)]
		tab.button_pressed = s == selected
	_hint.text = "拖旗子，或點地面移動" if selected >= 0 else "點一團選取"
	_regroup.disabled = not fighting
	_volley.disabled = not fighting or sim.morale < PushSim.MORALE_MAX
	if _banner_t > 0.0:
		_banner_t -= dt
		_strip.visible = _banner_t > 0.0
	if _coach_t > 0.0:
		_coach_t -= dt
		%Coach.visible = _coach_t > 0.0


## A first-push hint for `seconds` of game time.
func coach(text: String, seconds: float = 5.0) -> void:
	%CoachText.text = text
	%Coach.visible = true
	_coach_t = seconds


## 暫停: stops the push (the whole tree pauses; the menu keeps running).
func pause() -> void:
	get_tree().paused = true
	%PauseMenu.visible = true
	%PausePanel.visible = true
	%SettingsPanel.visible = false


func resume() -> void:
	get_tree().paused = false
	%PauseMenu.visible = false


## The 關卡 being pushed: its label (1-1) and its boss.
func set_stage(label: String, boss: String) -> void:
	_stage_label.text = label
	_boss_name.text = boss


## The banner strip: `color` frames it and fills its "!" square (red for a telegraph, gold for good news).
func banner(text: String, color: Color, seconds: float = 1.4) -> void:
	_banner.text = text
	_strip_box.border_color = color
	_strip_box.bg_color = Color(color.darkened(0.82), 0.9)
	_bang.color = color.darkened(0.15)
	_strip.visible = true
	_banner_t = seconds


## The part buttons follow their parts on the boss; `points` are viewport points in PushSim.Part order.
func place_parts(sim: PushSim, points: Array, shown: bool) -> void:
	for button: Node in _parts.get_children():
		var p: int = button.part_index
		button.visible = shown
		if shown:
			button.position = points[p] - button.size / 2.0
			button.show_part(PushSim.PART_NAMES[p], sim.part_hp[p] / sim.part_max_hp[p], sim.aim == p)


## An SSR's 招牌技 slides in under the banner; `face` is the hero's portrait.
func skill_callout(face: Texture2D, skill_name: String, hero_line: String, desc: String) -> void:
	_callout.show_skill(face, skill_name, hero_line, desc)


## The result panel; with a push_report.gd report (and the MVP's class for the portrait) it shows the 推王戰報 too, and
## with progression.gd push_rewards() what the push paid.
## next_label: the stage 挑戰下一關 opens ("" hides the button).
func show_result(won: bool, detail: String, report: Dictionary = {}, mvp_class: int = 0, rewards: Dictionary = {},
		next_label: String = "") -> void:
	_result_title.text = ("首次通關！" if rewards.get("first", false) else "推王成功！") if won else "推王失敗……"
	_result_detail.text = detail
	_rewards.visible = not rewards.is_empty()
	_reward_grid.visible = not rewards.is_empty()
	for child: Node in _reward_grid.get_children():
		_reward_grid.remove_child(child)
		child.queue_free()
	if not rewards.is_empty():
		for line: Array in _reward_lines(rewards):
			var row: Node = RewardRow.instantiate()
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_reward_grid.add_child(row)
			row.show_row(line[0], line[1], line[2], line[3])
	_next.visible = next_label != ""
	_next.text = "挑戰下一關　%s" % next_label
	# One main action: 挑戰下一關 after a win, 前往養成 after a loss.
	_grow.theme_type_variation = &"" if _next.visible else &"PrimaryButton"
	_report.visible = not report.is_empty()
	if not report.is_empty():
		_report.show_report(report, mvp_class)
	_result.visible = true
	_callout.hide_now()
	for button: Node in _parts.get_children():
		button.visible = false
	_banner_t = 0.0
	_strip.visible = false


## What a push paid, as reward_row lines: [icon, rarity (-1 = plain), name, amount].
func _reward_lines(got: Dictionary) -> Array:
	var out: Array = [[Items.material_icon("gold"), -1, "金幣", "+%d" % got.gold]]
	for spec: Array in [["shards", "突破素材"], ["stones", "強化石"], ["tickets", "招募券"]]:
		if got.get(spec[0], 0) > 0:
			out.append([Items.material_icon(spec[0]), -1, spec[1], "+%d" % got[spec[0]]])
	for id: String in got.get("items", []):
		out.append([Items.icon(id), Items.rarity(id), Items.item_name(id), ""])
	if got.get("relic", -1) >= 0:
		out.append([Items.relic_icon(got.relic), 3, Items.RELICS[got.relic].name, "★+1"])
	return out


func hide_result() -> void:
	_result.visible = false
	_coach_t = 0.0
	%Coach.visible = false
