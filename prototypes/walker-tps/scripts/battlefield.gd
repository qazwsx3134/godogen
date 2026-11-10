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
	walker.get_node("Combat").cancel_hook("ROUND OVER")
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
		walker.get_node("Combat").cancel_hook("OUT OF BOUNDS")
		walker.global_position=spawn.global_position
		walker.velocity=Vector3.ZERO
		walker.get_node("Gait").replant()
		walker.get_node("CameraRig").global_position=walker.global_position+Vector3.UP*3.3

func play_radio(contact: bool = true) -> bool:
	if match_state!="playing" or radio_wait>0 or $Radio.playing: return false
	$Radio.stream=preload("res://assets/sound/runtime/ai_radio.ogg") if contact else preload("res://assets/sound/runtime/ai_boot.ogg")
	$Radio.play()
	radio_wait=6.0
	radio_count+=1
	return true
