extends CanvasLayer
## Push HUD: boss HP, phase and push timer on top; at the bottom the selected zone, 全員歸位, and morale with 大招;
## over the field the selected zone's ◀ ▶ move arrows and the weak point button; banners and the result panel.
## Layout lives in scenes/hud.tscn; this only fills values.

const PushSim = preload("res://domain/push_sim.gd")

## side: -1 = ◀ (to the 遠 column), +1 = ▶ (to the 近 column).
signal arrow_pressed(side: int)
signal regroup_pressed
signal volley_pressed
signal weak_point_pressed
signal skip_pressed
signal retry_pressed

@onready var _boss_hp: ProgressBar = %BossHp
@onready var _boss_hp_label: Label = %BossHpLabel
@onready var _phase: Label = %PhaseLabel
@onready var _timer: Label = %TimerLabel
@onready var _dps: Label = %DpsLabel
@onready var _morale: ProgressBar = %Morale
@onready var _banner: Label = %Banner
@onready var _weak: Button = %WeakPoint
@onready var _skip: Button = %SkipMuster
@onready var _zone_label: Label = %ZoneLabel
@onready var _arrow_left: Button = %ArrowLeft
@onready var _arrow_right: Button = %ArrowRight
@onready var _regroup: Button = %Regroup
@onready var _volley: Button = %Volley
@onready var _result: Control = %Result
@onready var _result_title: Label = %ResultTitle
@onready var _result_detail: Label = %ResultDetail
@onready var _report: Label = %Report
@onready var _retry: Button = %Retry

var _banner_t: float = 0.0


func _ready() -> void:
	_arrow_left.pressed.connect(arrow_pressed.emit.bind(-1))
	_arrow_right.pressed.connect(arrow_pressed.emit.bind(1))
	_arrow_left.visible = false
	_arrow_right.visible = false
	_regroup.pressed.connect(regroup_pressed.emit)
	_volley.pressed.connect(volley_pressed.emit)
	_weak.pressed.connect(weak_point_pressed.emit)
	_skip.pressed.connect(skip_pressed.emit)
	_retry.pressed.connect(retry_pressed.emit)
	_banner.visible = false
	_weak.visible = false
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
		_zone_label.text = "選區：%s　%d 人　（◀ ▶ 或拖曳移動）" % [PushSim.ZONE_NAMES[selected], sim.living_in(selected)]
	else:
		_zone_label.text = "點一區選取，拖到另一區移動"
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


## The weak point follows the boss on screen (a runtime effect, like a damage number); `at` is a viewport point.
func place_weak_point(at: Vector2, shown: bool) -> void:
	_weak.visible = shown
	if shown:
		_weak.position = at - _weak.size / 2.0


## A move arrow beside the selected zone; `at` is a viewport point, `side` -1 = ◀, +1 = ▶.
func place_arrow(side: int, at: Vector2, shown: bool) -> void:
	var arrow: Button = _arrow_left if side < 0 else _arrow_right
	arrow.visible = shown
	if shown:
		arrow.position = at - arrow.size / 2.0


## report = the 推王戰報 text (rankings, falls, advice); it scrolls inside the result panel.
func show_result(won: bool, detail: String, report: String = "") -> void:
	_result_title.text = "推王成功！" if won else "推王失敗……"
	_result_detail.text = detail
	_report.text = report
	_report.get_parent().visible = report != ""
	_result.visible = true
	_weak.visible = false
	_arrow_left.visible = false
	_arrow_right.visible = false
	_banner_t = 0.0
	_banner.visible = false


func hide_result() -> void:
	_result.visible = false
