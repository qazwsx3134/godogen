extends Resource
## One stretch of the run timeline: from `start` seconds until the next phase starts.
@export var start: float = 0.0
@export var interval: float = 1.0
@export var batch: int = 2
## Spawn weights per Street.enemy_scenes index (smoker, bike, car, fatty).
@export var weights: PackedFloat32Array = [1.0, 0.0, 0.0, 0.0]
@export var hp_scale: float = 1.0
@export var max_alive: int = 40
## Smokers spawned in a ring around the hero when the phase begins.
@export var ring: int = 0
## Enemy index of an elite spawned when the phase begins; -1 for none.
@export var elite: int = -1
