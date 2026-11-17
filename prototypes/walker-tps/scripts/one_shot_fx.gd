extends Node3D
## Restarts every one-shot GPUParticles3D layer under this node and flickers the
## optional Light child (the muzzle is often hidden behind the turret; the light is not).
@export var light_energy := 0.0
@export var light_time := 0.1

func play() -> void:
	for layer: Node in find_children("*", "GPUParticles3D", true, false):
		(layer as GPUParticles3D).restart()
	var light := find_child("Light", true, false) as Light3D
	if light and light_energy > 0.0:
		light.light_energy = light_energy
		create_tween().tween_property(light, "light_energy", 0.0, light_time)

## Longest visible layer lifetime, for freeing the effect after it finishes.
func duration() -> float:
	var longest := 0.0
	for layer: Node in find_children("*", "GPUParticles3D", true, false):
		if (layer as GPUParticles3D).visible: longest = maxf(longest, (layer as GPUParticles3D).lifetime)
	return longest
