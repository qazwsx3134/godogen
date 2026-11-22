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
## A heavy ground strike spreads its dust and shockwave across the marked area.
var ground_wave_radius := 0.0
const Synth = preload("res://addons/proto_kit/synth.gd")
static var _ping: AudioStream
var age := 0.0
var _life := 0.0
const AudioMix := preload("res://addons/audio_tuner/mix.gd")

func _ready() -> void:
	var big := radius >= 2.0
	if explosive:
		$Sound.stream = preload("res://assets/sound/runtime/round_impact.ogg")
		$Sound.pitch_scale = randf_range(0.75, 0.95) if big else randf_range(0.8, 1.2)
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
	if surface == "body":
		for layer: String in ["Flash", "Flare"]: $Fx.get_node(layer).visible = false
		$Fx.get_node("Fireball").visible = true
		if not big: $Fx.scale *= 1.8
		_configure_armor_sparks()
	if ground_wave_radius > 0.0:
		_configure_ground_wave()
	light_energy = 6.0 if big else (3.5 if surface == "body" else 0.0)
	light_time = 0.25
	play()
	_life = duration() + 0.1
	AudioMix.play($Sound, $Sound.pitch_scale, $Sound.volume_db)

func _configure_ground_wave() -> void:
	$Fx/Fireball.visible = false
	$Fx/Flare.visible = false
	var shockwave: GPUParticles3D = $Fx/Shockwave
	var ring := shockwave.process_material.duplicate() as ParticleProcessMaterial
	var diameter: float = ground_wave_radius * 2.0 / $Fx.scale.x
	ring.scale_min = diameter
	ring.scale_max = diameter
	ring.color = Color(1.0, 0.78, 0.55, 0.78)
	shockwave.process_material = ring
	shockwave.lifetime = 0.55

	var dust: GPUParticles3D = $Fx/Smoke
	var cloud := dust.process_material.duplicate() as ParticleProcessMaterial
	cloud.direction = Vector3.UP
	cloud.spread = 84.0
	cloud.emission_sphere_radius = 1.2
	cloud.initial_velocity_min = 4.0
	cloud.initial_velocity_max = 8.0
	cloud.color = Color(0.66, 0.50, 0.36, 0.85)
	dust.process_material = cloud
	dust.amount = 26
	dust.lifetime = 1.7
	$Fx/Debris.amount = 24
	$Sound.pitch_scale = 0.66


## Armour throws a fast, directional fan and a slower shower of hot fragments.
func _configure_armor_sparks() -> void:
	var sparks: GPUParticles3D = $Fx/Sparks
	var material := sparks.process_material.duplicate() as ParticleProcessMaterial
	material.spread = 68.0
	material.initial_velocity_min = 9.0
	material.initial_velocity_max = 29.0
	material.scale_min = 0.72
	material.scale_max = 1.28
	material.color = Color(1.0, 0.72, 0.31, 1.0)
	sparks.process_material = material
	sparks.amount = 32
	sparks.lifetime = 0.63
	sparks.visibility_aabb = AABB(Vector3(-20, -20, -20), Vector3.ONE * 40)
	var streak := sparks.draw_pass_1.duplicate() as QuadMesh
	streak.size = Vector2(0.095, 1.15)
	sparks.draw_pass_1 = streak

	var fragments: GPUParticles3D = $Fx/Debris
	fragments.visible = true
	fragments.amount = 8
	fragments.lifetime = 0.75
	var hot := fragments.process_material.duplicate() as ParticleProcessMaterial
	hot.color = Color(0.95, 0.36, 0.10, 1.0)
	hot.spread = 75.0
	fragments.process_material = hot


func _process(delta: float) -> void:
	age += delta
	if age >= _life and (not $Sound.playing or age > $Sound.stream.get_length() + 0.25): queue_free()
