extends CanvasLayer
## Push HUD: boss HP, phase and push timer on top; at the bottom the selected squad, 全員歸位, and morale with 大招;
## over the field the boss's part buttons (aim the ranged squad); banners and the result panel.
## Layout lives in scenes/hud.tscn; this only fills values.

const PushSim = preload("res://domain/push_sim.gd")

## part: PushSim.Part.
signal part_pressed(part: int)
signal regroup_pressed
signal volley_pressed
signal skip_pressed
signal retry_pressed

@onready var _boss_hp: ProgressBar = %BossHp
@onready var _boss_hp_label: Label = %BossHpLabel
@onready var _phase: Label = %PhaseLabel
@onready var _timer: Label = %TimerLabel
@onready var _dps: Label = %DpsLabel
@onready var _morale: ProgressBar = %Morale
@onready var _banner: Label = %Banner
@onready var _skip: Button = %SkipMuster
@onready var _zone_label: Label = %ZoneLabel
@onready var _parts: Control = %Parts
@onready var _regroup: Button = %Regroup
@onready var _volley: Button = %Volley
@onready var _result: Control = %Result
@onready var _result_title: Label = %ResultTitle
@onready var _result_detail: Label = %ResultDetail
@onready var _retry: Button = %Retry
@onready var _report: VBoxContainer = %Report

var _banner_t: float = 0.0


func _ready() -> void:
	for button: Node in _parts.get_children():
		button.pressed.connect(func() -> void: part_pressed.emit(button.part_index))
		button.visible = false
	_regroup.pressed.connect(regroup_pressed.emit)
	_volley.pressed.connect(volley_pressed.emit)
	_skip.pressed.connect(skip_pressed.emit)
	_retry.pressed.connect(retry_pressed.emit)
	_banner.visible = false
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
	if selected >= 0:
		_zone_label.text = "%s　%d 人　（拖旗子，或點地面移動）" % [PushSim.SQUAD_NAMES[selected], sim.squad_living(selected)]
	else:
		_zone_label.text = "點一團選取，拖旗子移動"
	_regroup.disabled = not fighting
	_volley.disabled = not fighting or sim.morale < PushSim.MORALE_MAX
	if _banner_t > 0.0:
		_banner_t -= dt
		_banner.visible = _banner_t > 0.0


func banner(text: String, color: Color, seconds: float = 1.4) -> void:
	_banner.text = text
	_banner.modulate = color
	_banner.visible = true
	_banner_t = seconds


## The part buttons follow their parts on the boss; `points` are viewport points in PushSim.Part order.
func place_parts(sim: PushSim, points: Array, shown: bool) -> void:
	for button: Node in _parts.get_children():
		var p: int = button.part_index
		button.visible = shown
		if shown:
			button.position = points[p] - button.size / 2.0
			button.show_part(PushSim.PART_NAMES[p], sim.part_hp[p] / PushSim.PART_HP[p], sim.aim == p)


## The result panel; with a push_report.gd report (and the MVP's class for the portrait) it shows the 推王戰報 too.
func show_result(won: bool, detail: String, report: Dictionary = {}, mvp_class: int = 0) -> void:
	_result_title.text = "推王成功！" if won else "推王失敗……"
	_result_detail.text = detail
	_report.visible = not report.is_empty()
	if not report.is_empty():
		_report.show_report(report, mvp_class)
	_result.visible = true
	for button: Node in _parts.get_children():
		button.visible = false
	_banner_t = 0.0
	_banner.visible = false


func hide_result() -> void:
	_result.visible = false
