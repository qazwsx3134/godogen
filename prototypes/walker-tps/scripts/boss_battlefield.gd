extends Node3D
## Attack and repeatable load controls for the Boss battlefield.
## The first ten armor instances are saved in the scene; extras are instances of
## the same editable scenes and are created only when a higher load is selected.

const MELEE := preload("res://scenes/melee_display.tscn")
const TANK := preload("res://scenes/tank_display.tscn")
const PHIDO := preload("res://scenes/phido_display.tscn")

@onready var boss: Node3D = %Boss
@onready var armor: Node3D = $Armor
@onready var stress_units: Node3D = $StressUnits
@onready var idle_button: Button = %BossIdle
@onready var fly_button: Button = %BossFly
@onready var fire_button: Button = %BossFire
@onready var load_10: Button = %Load10
@onready var load_40: Button = %Load40
@onready var load_80: Button = %Load80
@onready var load_label: Label = %LoadCount
@onready var shadow_toggle: CheckButton = %ArmorShadows
var _shadows_enabled := true


func _ready() -> void:
	idle_button.pressed.connect(_show_idle)
	fly_button.pressed.connect(_show_fly)
	fire_button.pressed.connect(_show_fire)
	load_10.pressed.connect(func() -> void: set_armor_count(10))
	load_40.pressed.connect(func() -> void: set_armor_count(40))
	load_80.pressed.connect(func() -> void: set_armor_count(80))
	shadow_toggle.toggled.connect(set_armors_shadows)
	_shadows_enabled = shadow_toggle.button_pressed


func _show_idle() -> void:
	boss.try_attack("beam")


func _show_fly() -> void:
	boss.try_attack("pillars")


func _show_fire() -> void:
	boss.try_attack("tail")


## Total is restricted to the three measured configurations.
func set_armor_count(total: int) -> void:
	if total not in [10, 40, 80]:
		return
	var target: int = total - armor.get_child_count()
	while stress_units.get_child_count() > target:
		var unit: Node = stress_units.get_child(stress_units.get_child_count() - 1)
		stress_units.remove_child(unit)
		unit.queue_free()
	while stress_units.get_child_count() < target:
		var i: int = stress_units.get_child_count()
		var packed: PackedScene = PHIDO if i % 5 == 0 else (MELEE if i % 2 == 0 else TANK)
		var unit := packed.instantiate() as Node3D
		var x: float = -18.0 + float(i % 7) * 6.0
		var z: float = -69.0 + float(floori(float(i) / 7.0)) * 4.0
		var ray := PhysicsRayQueryParameters3D.create(Vector3(x, 100, z), Vector3(x, -100, z), 1)
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
		unit.position = Vector3(x, float(hit.position.y) + 0.05 if not hit.is_empty() else 0.0, z)
		unit.rotation.y = PI
		unit.set("shadows_enabled", _shadows_enabled)
		unit.set("animation_phase", fmod(float(i) * .23, 1.8))
		stress_units.add_child(unit)
	load_label.text = "LOAD %d" % total


func set_armors_shadows(enabled: bool) -> void:
	_shadows_enabled = enabled
	shadow_toggle.set_pressed_no_signal(enabled)
	for group: Node3D in [armor, stress_units]:
		for unit: Node in group.get_children():
			unit.set_shadows_enabled(enabled)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1: _show_idle()
			KEY_2: _show_fly()
			KEY_3: _show_fire()
			KEY_4: set_armor_count(10)
			KEY_5: set_armor_count(40)
			KEY_6: set_armor_count(80)
			KEY_7: set_armors_shadows(not _shadows_enabled)
