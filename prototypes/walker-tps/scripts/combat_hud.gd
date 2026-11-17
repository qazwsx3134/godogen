extends CanvasLayer
@onready var session: Node = get_parent()
@onready var combat: Node = session.get_node("Walker/Combat")
@onready var camera: Camera3D = session.get_node("Walker/CameraRig/Pitch/Arm/Camera")

var hurt_left := 0.0

func _ready() -> void:
	combat.damaged.connect(func() -> void: hurt_left=0.2)
	$Modal/Panel/Margin/Rows/Action.pressed.connect(_action)
	$Controls.visible=DisplayServer.is_touchscreen_available()

func _action() -> void:
	if session.match_state=="briefing": session.start_match()
	else: session.retry()

func _process(_delta: float) -> void:
	hurt_left=maxf(0,hurt_left-_delta)
	$DamageFlash.visible=hurt_left>0
	$Status.text="HULL %d / %d   |   %s %d / %d   |   %02d:%02d"%[combat.health,combat.max_health,session.objective_name,session.kills,session.total,int(session.time_left)/60,int(session.time_left)%60]
	$Weapon.text=("RELOADING %.1fs"%combat.magazine_left if combat.magazine_left>0 else "AMMO %d / %d"%[combat.ammo,combat.magazine_size])+"   |   HOOK: "+combat.grapple.message+(" %.1fs"%combat.grapple.cooldown_left if combat.grapple.cooldown_left>0 else "")
	var blades: Node = combat.get_node("AutoBlades")
	$Weapon.text+=" | BLADES "+("AUTO" if blades.cooldown_left<=0 else "%.1fs"%blades.cooldown_left)
	var playing: bool = session.match_state=="playing"
	$Modal.visible=not playing
	$Controls.visible=playing and DisplayServer.is_touchscreen_available()
	var sights: bool = playing and not get_tree().has_group("death_show")  # a Boss death show is a cutscene
	$Crosshair.visible=sights
	$GunReticle.visible=sights and not camera.is_position_behind(combat.gun_point)
	if $GunReticle.visible: $GunReticle.position=camera.unproject_position(combat.gun_point)-Vector2(10,10)
	if not playing:
		var briefing: bool = session.match_state=="briefing"
		$Modal/Panel/Margin/Rows/Title.text="GREEN RUST / SORTIE" if briefing else ("MISSION COMPLETE" if session.match_state=="victory" else "MISSION FAILED")
		var objective := "Destroy the Boss and 3 scouts." if session.objective_name == "TARGETS" else "Destroy 3 scouts."
		$Modal/Panel/Margin/Rows/Description.text=objective+" Twin grapples reel light targets in; terrain and heavy targets pull you forward.\nLMB fire / RMB aim / G grapple / Q aim toggle\nShift boost / Space jump / Enter deploy" if briefing else "Targets destroyed: %d / %d\nPress R or RETRY to return to briefing."%[session.kills,session.total]
		$Modal/Panel/Margin/Rows/Action.text="DEPLOY" if briefing else "RETRY"

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
