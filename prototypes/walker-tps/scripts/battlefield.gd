extends Node3D
signal match_finished(result: String)
@export var playable_half_extents := Vector2(116,106)
@export var fall_limit: float = -12.0
@export var match_seconds: float = 300.0
var match_state := "briefing"
var time_left: float
var kills := 0
var total := 0
var radio_wait := 0.0
var radio_count := 0
## Where any scout last saw the player, and when (match seconds); scouts that have not seen the
## player themselves come to look when the report is fresh.
var contact_position := Vector3.ZERO
var contact_time := -100.0
## Degrees between neighbouring scouts around the player, so one wall cannot cover them all.
@export var surround_spacing_deg: float = 50.0
@onready var walker: CharacterBody3D = $Walker
@onready var spawn: Marker3D = $Map/RouteMarkers/PlayerSpawn

func _ready() -> void:
	time_left=match_seconds
	walker.controls_enabled=false
	walker.get_node("Combat").destroyed.connect(func() -> void: finish("defeat"))
	for enemy: Node in $Enemies.get_children():
		enemy.ai_enabled=false
		enemy.destroyed.connect(_enemy_destroyed)
		total+=1

func start_match() -> void:
	if match_state!="briefing": return
	match_state="playing"
	walker.controls_enabled=true
	for enemy: Node in $Enemies.get_children(): enemy.ai_enabled=true
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	play_radio(false)

func _enemy_destroyed(_enemy: Node) -> void:
	if match_state!="playing": return
	kills+=1
	if kills>=total: finish("victory")

func finish(result: String) -> void:
	if match_state!="playing": return
	match_state=result
	walker.controls_enabled=false
	walker.get_node("Combat/Grapple").cancel_hook("ROUND OVER")
	walker.get_node("Combat/MuzzleFlash").visible=false
	for enemy: Node in $Enemies.get_children(): enemy.ai_enabled=false
	for projectile: Node in $Projectiles.get_children():
		if projectile.is_in_group("live_projectile"): projectile.queue_free()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	for action: StringName in InputMap.get_actions(): Input.action_release(action)
	match_finished.emit(result)

func retry() -> void:
	get_tree().change_scene_to_file.call_deferred("res://scenes/battlefield.tscn")

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_R and match_state in ["victory","defeat","timeout"]: retry()
		if event.physical_keycode==KEY_ENTER and match_state=="briefing": start_match()

func _physics_process(delta: float) -> void:
	if match_state=="playing":
		radio_wait=maxf(0,radio_wait-delta)
		time_left=maxf(0,time_left-delta)
		if time_left<=0: finish("timeout")
	var p := walker.global_position
	if absf(p.x)>playable_half_extents.x or absf(p.z)>playable_half_extents.y or p.y<fall_limit:
		walker.get_node("Combat/Grapple").cancel_hook("OUT OF BOUNDS")
		walker.global_position=spawn.global_position
		walker.velocity=Vector3.ZERO
		walker.get_node("Gait").replant()
		walker.get_node("CameraRig").global_position=walker.global_position+Vector3.UP*3.3

func match_time() -> float:
	return match_seconds-time_left

func report_contact(at: Vector3) -> void:
	contact_position=at
	contact_time=match_time()

## Where `scout` should stand to fight: on a ring of `radius` m around the walker, spread with the other
## engaged scouts around the bearing of their group. Slots go out in the order the scouts already stand
## around the walker, so nobody has to walk through a teammate to reach its place.
func slot_for(scout: Node3D, radius: float) -> Vector3:
	var engaged: Array[Node3D] = []
	for other: Node in $Enemies.get_children():
		if other.get("dead")!=true and other.has_method("is_engaged") and other.is_engaged():
			engaged.append(other)
	if scout not in engaged: engaged.append(scout)
	var centroid := Vector3.ZERO
	for member: Node3D in engaged: centroid+=member.global_position
	centroid/=engaged.size()
	var base := centroid-walker.global_position
	var base_angle := atan2(base.x,base.z)
	var offset := func(member: Node3D) -> float:
		var to := member.global_position-walker.global_position
		return angle_difference(base_angle, atan2(to.x,to.z))
	engaged.sort_custom(func(a: Node3D, b: Node3D) -> bool: return offset.call(a)<offset.call(b))
	var angle := base_angle+deg_to_rad(surround_spacing_deg)*(engaged.find(scout)-(engaged.size()-1)*0.5)
	var want := walker.global_position+Vector3(sin(angle),0,cos(angle))*radius
	var map := get_world_3d().navigation_map
	return NavigationServer3D.map_get_closest_point(map,want) if NavigationServer3D.map_get_iteration_id(map)>0 else want

func play_radio(contact: bool = true) -> bool:
	if match_state!="playing" or radio_wait>0 or $Radio.playing: return false
	$Radio.stream=preload("res://assets/sound/runtime/ai_radio.ogg") if contact else preload("res://assets/sound/runtime/ai_boot.ogg")
	$Radio.play()
	radio_wait=6.0
	radio_count+=1
	return true
