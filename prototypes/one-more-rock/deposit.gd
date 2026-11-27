extends StaticBody3D

@export var rare := false
@export_range(1, 8) var hardness := 4
@export_range(1, 6) var yield_count := 4

var remaining_hits := 0
var remaining_stones := 0
var loot_ready := false
var feedback: Tween

@onready var shell: MeshInstance3D = %Shell
@onready var shell_home := shell.position
@onready var loose: Node3D = %Loose
@onready var hitbox: CollisionShape3D = %Hitbox
@onready var scar: MeshInstance3D = %Scar
@onready var pickup_mark: MeshInstance3D = %PickupMark


func _ready() -> void:
	remaining_hits = hardness
	remaining_stones = yield_count


func mine(power: int) -> void:
	remaining_hits = maxi(0, remaining_hits - power)
	if feedback:
		feedback.kill()
	if remaining_hits == 0:
		_release_ore()
	else:
		feedback = create_tween()
		feedback.tween_property(shell, "position", shell_home, 0.16).from(shell_home + Vector3.FORWARD * 0.055)


func _release_ore() -> void:
	shell.hide()
	scar.show()
	# Move the loose-ore display to the foot of the seam on the quarry floor.
	loose.top_level = true
	var landing := global_position + global_basis.z * 0.62
	landing.y = 0.16
	loose.global_basis = Basis.IDENTITY
	loose.global_position = landing
	loose.show()
	for piece in loose.get_children():
		piece.visible = piece != pickup_mark and piece.get_index() < yield_count
	feedback = create_tween()
	feedback.tween_property(loose, "global_position", landing, 0.25).from(
		global_position + global_basis.z * 0.21
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	feedback.tween_callback(func():
		hitbox.global_transform = Transform3D(Basis.IDENTITY, landing + Vector3.UP * 0.07)
		var pickup_shape := SphereShape3D.new()
		pickup_shape.radius = 0.48
		hitbox.shape = pickup_shape
		loot_ready = true
		pickup_mark.show()
	)


func take_one() -> Vector3:
	remaining_stones -= 1
	var piece := loose.get_child(remaining_stones) as Node3D
	piece.hide()
	if remaining_stones == 0:
		loot_ready = false
		pickup_mark.hide()
		collision_layer = 0
	return piece.global_position
