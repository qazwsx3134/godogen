extends CanvasLayer
@onready var session: Node = get_parent()
@onready var combat: Node = session.get_node("Walker/Combat")
@onready var camera: Camera3D = session.get_node("Walker/CameraRig/Pitch/Arm/Camera")

var hurt_left := 0.0
var radar_refresh_left := 0.0

func _ready() -> void:
	combat.damaged.connect(func() -> void: hurt_left=0.2)
	$Modal/Panel/Margin/Rows/Action.pressed.connect(_action)
	$Controls.visible=DisplayServer.is_touchscreen_available()
	$Radar/Range.text = "RADAR  %d m" % $Radar.detection_range

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
	$GunReticle.visible = sights and not camera.is_position_behind(combat.gun_point)
	if $GunReticle.visible:
		$GunReticle.position = camera.unproject_position(combat.gun_point) - $GunReticle.size * 0.5
	if sights:
		_update_instruments(_delta)
	if not playing:
		var briefing: bool = session.match_state=="briefing"
		$Modal/Panel/Margin/Rows/Title.text="GREEN RUST / SORTIE" if briefing else ("MISSION COMPLETE" if session.match_state=="victory" else "MISSION FAILED")
		var objective := "Destroy the Boss and 3 scouts." if session.objective_name == "TARGETS" else "Destroy 3 scouts."
		$Modal/Panel/Margin/Rows/Description.text=objective+" Twin grapples reel light targets in; terrain and heavy targets pull you forward.\nLMB fire / RMB aim / G grapple / Q aim toggle\nShift boost / Space jump / Enter deploy" if briefing else "Targets destroyed: %d / %d\nPress R or RETRY to return to briefing."%[session.kills,session.total]
		$Modal/Panel/Margin/Rows/Action.text="DEPLOY" if briefing else "RETRY"

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
