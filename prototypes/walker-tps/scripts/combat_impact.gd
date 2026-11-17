extends "res://scripts/one_shot_fx.gd"
## Layered particle impact; radius >= 2 adds fireball, ground ring, debris and light.
@export var radius: float = 1.0
## "blast" (explosion sound), "body" (heavy thud) or "wall" (ricochet ping). Blasts >= radius 2.
var surface := "blast"
## Surface normal: small hits spray their sparks out of the surface.
var normal := Vector3.UP
## The walker's cannon rounds burst on whatever they hit: grenade-like blast sound with a random
## pitch, loud close by and fading with distance (3D attenuation), instead of the thud / ping.
var explosive := false
const Synth = preload("res://addons/proto_kit/synth.gd")
static var _ping: AudioStream
var age := 0.0
var _life := 0.0

func _ready() -> void:
	var big := radius >= 2.0
	if explosive and not big:
		$Sound.stream = preload("res://assets/sound/runtime/round_impact.ogg")
		$Sound.pitch_scale = randf_range(0.8, 1.2)
		$Sound.unit_size = 9.0          # full volume within ~9 m, then the inverse falloff
		$Sound.max_distance = 110.0
		$Sound.volume_db = randf_range(-1.5, 1.5)
	elif big or surface == "blast":
		$Sound.stream = preload("res://assets/sound/runtime/explosion.ogg")
		$Sound.pitch_scale = randf_range(0.8, 1.0)
	elif surface == "body":
		$Sound.stream = preload("res://assets/sound/runtime/hit_heavy.ogg")
		$Sound.pitch_scale = randf_range(0.6, 0.75)  # low thud into armour
	else:
		if _ping == null: _ping = Synth.ramp(2600.0, 2300.0, 0.32, 0.3, 0.0, 0.45)
		$Sound.stream = _ping
		$Sound.pitch_scale = randf_range(0.85, 1.25)
	if not big and normal.length_squared() > 0.5 and absf(normal.normalized().dot(Vector3.UP)) < 0.999:
		$Fx.basis = Basis(Quaternion(Vector3.UP, normal.normalized()))
	$Fx.scale = Vector3.ONE * (radius / 1.2 if big else 0.8 * radius)
	for layer: String in ["Fireball", "Shockwave", "Debris"]: $Fx.get_node(layer).visible = big
	# Armour hit: sparks and a small orange burst, never a white glow disc (the projectile throws the parts).
	if surface == "body" and not big:
		for layer: String in ["Flash", "Flare"]: $Fx.get_node(layer).visible = false
		$Fx.get_node("Fireball").visible = true
		$Fx.scale *= 1.6
	light_energy = 6.0 if big else (2.0 if surface == "body" else 0.0)
	light_time = 0.25
	play()
	_life = duration() + 0.1
	$Sound.play()

func _process(delta: float) -> void:
	age += delta
	if age >= _life and (not $Sound.playing or age > $Sound.stream.get_length() + 0.25): queue_free()
