extends Node2D

const CameraRig = preload("res://scripts/camera_rig.gd")
const CameraZone = preload("res://scripts/camera_zone.gd")
const CameraZoneDebug = preload("res://scripts/camera_zone_debug.gd")

const NIGHT_PHASE := 5.0 / 6.0
const NIGHT_AMBIENT := Color(0.40, 0.44, 0.60)
const NIGHT_LAYER_BRIGHTNESS: Array[float] = [0.94, 0.80, 0.65, 0.51, 0.38, 0.26]

@export_range(1.0, 300.0, 1.0, "suffix:s") var cycle_seconds := 60.0

@onready var _ambient: CanvasModulate = %Ambient
@onready var _layers: Array[Parallax2D] = [%Sky, %Far, %Mid, %Near, %Closest, %FgOccluder]
@onready var _night_sky: Sprite2D = %NightSky
@onready var _fire: PointLight2D = %FireLight
@onready var _lamps: Array[PointLight2D] = [%LampWest/Light, %LampEast/Light, %RidgeLamp/Light, %TrailEndLamp/Light]
@onready var _smoke: CPUParticles2D = %Smoke
@onready var _supplies: PanelContainer = %Supplies
@onready var _phase_label: Label = %Phase
@onready var _stoke_timer: Timer = %StokeTimer
@onready var _sfx = %Sfx
@onready var _rig: CameraRig = %CameraRig
@onready var _player: CharacterBody2D = %Player
@onready var _zone_debug: CameraZoneDebug = %CameraZoneDebug
@onready var _zone_button: Button = %CameraZonesButton
@onready var _zone_status: Label = %CameraZoneStatus

var _phase := 0.0
var _elapsed := 0.0
var _darkness := 0.0


func _ready() -> void:
	%Player.sound_requested.connect(_sfx.play)
	%FirePoint.activated.connect(_stoke)
	%ItemPoint.activated.connect(_inspect)
	%CookPoint.activated.connect(_cook)
	%ItemPoint.body_exited.connect(_close_supplies)
	_setup_camera()
	set_darkness(0.0)


func _process(delta: float) -> void:
	_elapsed += delta
	_set_phase(_phase + delta / cycle_seconds)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"advance_time"):
		var advanced := _phase + 0.25
		if _phase < NIGHT_PHASE and advanced > NIGHT_PHASE:
			advanced = NIGHT_PHASE
		_set_phase(advanced)


func _set_phase(value: float) -> void:
	_phase = fposmod(value, 1.0)
	var progress := _phase / NIGHT_PHASE if _phase <= NIGHT_PHASE else (1.0 - _phase) / (1.0 - NIGHT_PHASE)
	set_darkness(progress)


func set_darkness(value: float) -> void:
	_darkness = clampf(value, 0.0, 1.0)
	_ambient.color = Color.WHITE.lerp(NIGHT_AMBIENT, _darkness)
	for i: int in range(_layers.size()):
		var brightness := lerpf(1.0, NIGHT_LAYER_BRIGHTNESS[i], _darkness)
		_layers[i].modulate = Color(brightness, brightness, brightness)
	_night_sky.self_modulate.a = smoothstep(0.30, 0.96, _darkness)

	var flicker := 0.06 * sin(_elapsed * 13.0) + 0.04 * sin(_elapsed * 23.0)
	var boost := 0.0 if _stoke_timer.is_stopped() else 1.35 * _stoke_timer.time_left / _stoke_timer.wait_time
	_fire.energy = lerpf(0.42, 1.42, _darkness) + flicker + boost
	for lamp: PointLight2D in _lamps:
		lamp.energy = 1.45 * smoothstep(0.25, 0.92, _darkness)

	_phase_label.text = "NIGHT" if _darkness > 0.72 else ("DUSK" if _darkness > 0.28 else "DAYLIGHT")


func _stoke(_point: Area2D) -> void:
	_stoke_timer.start()
	_sfx.play(&"stoke")


func _inspect(_point: Area2D) -> void:
	_supplies.visible = not _supplies.visible
	_sfx.play(&"inspect")


func _close_supplies(_body: Node2D) -> void:
	_supplies.hide()


func _cook(_point: Area2D) -> void:
	_smoke.restart()
	_smoke.emitting = true
	_sfx.play(&"cook")


func _setup_camera() -> void:
	_rig.follow(_player)
	_player.landed.connect(_rig.on_landed)
	for zone: CameraZone in %CameraZones.get_children():
		zone.body_entered.connect(_zone_body_entered.bind(zone))
		zone.body_exited.connect(_zone_body_exited.bind(zone))
		_zone_debug.zones.append(zone)
	if OS.is_debug_build():
		_zone_debug.rig = _rig
		_zone_button.show()
		_zone_button.toggled.connect(_toggle_camera_zones)
		_rig.active_zone_changed.connect(_show_active_zone)


func _zone_body_entered(body: Node2D, zone: CameraZone) -> void:
	if body == _player:
		_rig.push_zone(zone)


func _zone_body_exited(body: Node2D, zone: CameraZone) -> void:
	if body == _player:
		_rig.pop_zone(zone)


func _toggle_camera_zones(enabled: bool) -> void:
	_zone_debug.visible = enabled
	_zone_status.visible = enabled
	_show_active_zone(_rig.active_zone)


func _show_active_zone(zone: CameraZone) -> void:
	_zone_status.text = "%s  [%d]" % [zone.name, zone.zone_priority] if zone else "Default follow"
