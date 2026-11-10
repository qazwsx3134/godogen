extends Node3D
## Front blades auto-swipe at close enemies. Recheck range and cover at the hit frame.
@export var reach: float = 3.6
@export var damage: float = 30.0
@export var attack_interval: float = 0.9
@export var windup_time: float = 0.12
var cooldown_left := 0.0
var windup_left := -1.0
var flash_left := 0.0
var attack_count := 0
var hit_count := 0
var swing_left := 0.0
@onready var combat: Node = get_parent()
@onready var body: CharacterBody3D = combat.get_parent()
@onready var model: Node3D = body.get_node("Model")
@onready var rest_yaw: float = model.rotation.y
const Impact = preload("res://scenes/combat_impact.tscn")

func _ready() -> void:
	$Sound.stream=preload("res://addons/proto_kit/synth.gd").click(0.14,0.45,16.0)

func candidates() -> Array[Node3D]:
	var result: Array[Node3D] = []
	var enemies := body.get_parent().get_node_or_null("Enemies")
	if not enemies: return result
	for enemy: Node in enemies.get_children():
		if not (enemy is Node3D) or not enemy.has_method("apply_damage"): continue
		if enemy.get("dead")==true or enemy.get("combat_enabled")!=true: continue
		var to: Vector3 = enemy.global_position-body.global_position
		if absf(to.y)>1.8: continue
		to.y=0
		if to.length()>reach or to.normalized().dot(body.global_basis.z)<0.35: continue
		var hit: Dictionary = combat.ray(body.global_position+Vector3.UP*1.2,enemy.global_position+Vector3.UP*1.1)
		if not hit.is_empty() and hit.collider==enemy: result.append(enemy)
	return result

func _physics_process(delta: float) -> void:
	cooldown_left=maxf(0,cooldown_left-delta)
	flash_left=maxf(0,flash_left-delta)
	swing_left=maxf(0,swing_left-delta)
	model.rotation.y=rest_yaw+(1.0 if attack_count%2 else -1.0)*sin((0.3-swing_left)/0.3*PI)*deg_to_rad(7.0) if swing_left>0 else rest_yaw
	if not body.controls_enabled or combat.health<=0:
		model.rotation.y=rest_yaw
		swing_left=0
		windup_left=-1
		flash_left=0
		$Sweeps.visible=false
		return
	if windup_left>=0:
		windup_left-=delta
		if windup_left<0:
			for enemy: Node3D in candidates():
				enemy.apply_damage(damage)
				hit_count+=1
				var effect := Impact.instantiate() as Node3D
				effect.radius=0.6
				combat.projectile_parent().add_child(effect)
				effect.global_position=enemy.global_position+Vector3.UP
			flash_left=0.18
			body.get_node("CameraRig").kick(0.07)
	elif cooldown_left<=0 and not candidates().is_empty():
		attack_count+=1
		swing_left=0.3
		windup_left=windup_time
		cooldown_left=attack_interval
		$Sound.play()
	$Sweeps.visible=windup_left>=0 or flash_left>0
	$Sweeps.rotation.y=(1.0 if attack_count%2 else -1.0)*(0.18-flash_left)*2.5
