extends CanvasLayer

const SORTIES := {
	"GreenRust": "res://scenes/battlefield.tscn",
	"RuinedDistrict": "res://scenes/ruined_district.tscn",
	"ShatteredPlaza": "res://scenes/shattered_plaza.tscn",
}
@onready var session: Node = get_parent()
@onready var combat: Node = session.get_node("Walker/Combat")
@onready var camera: Camera3D = session.get_node("Walker/CameraRig/Pitch/Arm/Camera")

@export_range(0.0, 40.0) var hud_drift_limit := 21.0
@export_range(2.0, 30.0) var hud_follow_speed := 9.0
var _previous_view := Vector3.ZERO
var _cannon_marker := Vector2.ZERO
var _sight_started := false

var hurt_left := 0.0
var radar_refresh_left := 0.0

func _ready() -> void:
	combat.damaged.connect(func() -> void: hurt_left=0.2)
	$Modal/Panel/Margin/Rows/Action.pressed.connect(_action)
	var current_path: String = session.scene_file_path if not session.scene_file_path.is_empty() and not session.get_parent().has_node("Boss") else session.get_parent().scene_file_path
	for button: Button in $Modal/Panel/Margin/Rows/Sorties.get_children():
		var path: String = SORTIES[button.name]
		button.disabled = current_path == path
		button.pressed.connect(get_tree().change_scene_to_file.bind(path), CONNECT_DEFERRED)
	$Controls.visible=DisplayServer.is_touchscreen_available()
	$Radar/Range.text = "RADAR  %d m" % $Radar.detection_range
	$Radar.track_terrain(combat.get_parent())

func _action() -> void:
	if session.match_state=="briefing": session.start_match()
	else: session.retry()

func _process(_delta: float) -> void:
	hurt_left=maxf(0,hurt_left-_delta)
	$DamageFlash.visible=hurt_left>0
	var playing: bool = session.match_state == "playing"
	var sights: bool = playing and not get_tree().has_group("death_show")
	$Modal.visible = not playing
	$Controls.visible = sights and DisplayServer.is_touchscreen_available()
	$Telemetry.visible = sights
	$Hull.visible = sights
	$Readouts.visible = sights
	$Heading.visible = sights
	$Radar.visible = sights
	$Crosshair.visible = sights
	$GunReticle.visible = sights
	if sights:
		_update_sight_motion(_delta)
		_update_instruments(_delta)
	else:
		_sight_started = false
	if not playing:
		var briefing: bool = session.match_state=="briefing"
		$Modal/Panel/Margin/Rows/Title.text=(session.sortie_title + " / SORTIE") if briefing else ("MISSION COMPLETE" if session.match_state=="victory" else "MISSION FAILED")
		var scout_count: int = session.total
		var objective := ""
		if session.objective_name == "TARGETS":
			scout_count -= 1
			objective = "Destroy the Boss and %d scouts." % scout_count if scout_count > 0 else "Destroy the Boss."
		else:
			objective = "Destroy %d scouts." % scout_count
		$Modal/Panel/Margin/Rows/Description.text=objective+" Twin grapples reel light targets in; terrain and heavy targets pull you forward.\nLMB fire / RMB aim / G grapple / Q aim toggle\nShift boost / Space jump / Enter deploy" if briefing else "Targets destroyed: %d / %d\nPress R or RETRY to return to briefing."%[session.kills,session.total]
		$Modal/Panel/Margin/Rows/Action.text="DEPLOY" if briefing else "RETRY"

func _update_sight_motion(delta: float) -> void:
	var basis := camera.global_basis.orthonormalized()
	var forward := -basis.z
	var bounds := camera.get_viewport().get_visible_rect()
	var target := bounds.get_center()
	var point: Vector3 = combat.gun_point
	if camera.is_position_behind(point):
		point = combat.muzzle.global_position + combat.muzzle.global_basis.z.normalized() * 160.0
	if not camera.is_position_behind(point):
		var projected := camera.unproject_position(point)
		var margin := Vector2(22, 22)
		target = projected.clamp(bounds.position + margin, bounds.end - margin)
	if _sight_started:
		var previous_in_view := basis.inverse() * _previous_view
		var turn := Vector2(previous_in_view.x, -previous_in_view.y)
		var drift: Vector2 = ($Crosshair.drift + turn * 420.0).limit_length(hud_drift_limit)
		$Crosshair.drift = drift.lerp(Vector2.ZERO, 1.0 - exp(-hud_follow_speed * delta))
		_cannon_marker = _cannon_marker.lerp(target, 1.0 - exp(-19.0 * delta))
	else:
		_sight_started = true
		$Crosshair.drift = Vector2.ZERO
		_cannon_marker = target
	_previous_view = forward
	$GunReticle.position = _cannon_marker - $GunReticle.size * 0.5


func _update_instruments(delta: float) -> void:
	var seconds := maxi(0, int(session.time_left))
	@warning_ignore("integer_division")
	$Readouts/Timer.text = "◂  %02d:%02d  ▸" % [seconds / 60, seconds % 60]
	$Telemetry/Status.text = "%s    %d / %d" % [session.objective_name, session.kills, session.total]
	$Hull/Integrity.text = "HULL  %d / %d" % [combat.health, combat.max_health]
	$Hull.fraction = combat.health / combat.max_health
	var ammo := "▱  AMMO  %02d / %02d  ▱" % [combat.ammo, combat.magazine_size]
	if combat.magazine_left > 0.0:
		ammo = "▱  RELOAD  %.1fs  ▱" % combat.magazine_left
	$Readouts/Ammo.text = ammo
	var forward := -camera.global_basis.z
	var bearing := posmod(roundi(rad_to_deg(atan2(forward.x, -forward.z))), 360)
	$Heading/Bearing.text = "HDG  %03d°" % bearing
	$Crosshair.heading_degrees = bearing
	var velocity: Vector3 = session.walker.velocity
	var speed := Vector2(velocity.x, velocity.z).length()
	$Readouts/Speed.text = "SPD\n%04.1f m/s" % speed
	var distance: float = combat.aim_distance
	$Readouts/Range.text = "RNG\n%03d m" % roundi(distance) if distance >= 0.0 else "RNG\n—"
	radar_refresh_left -= delta
	if radar_refresh_left <= 0.0:
		radar_refresh_left = 0.08
		var targets: Array[Node] = session.get_node("Enemies").get_children()
		var boss := session.get_parent().get_node_or_null("Boss")
		if boss != null:
			targets.append(boss)
		forward.y = 0.0
		$Radar.set_contacts(session.walker.global_position, forward.normalized(), targets)


var fire_finger := -1
func _input(event: InputEvent) -> void:
	if session.match_state!="playing": return
	if event is InputEventScreenTouch:
		if event.pressed and Rect2($Controls/Fire.global_position,Vector2(120,100)).has_point(event.position):
			fire_finger=event.index
		elif not event.pressed and fire_finger==event.index: fire_finger=-1
	elif event is InputEventScreenDrag and event.index==fire_finger:
		session.walker.get_node("CameraRig").look(event.relative*session.walker.touch_sensitivity)

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT: fire_finger=-1
