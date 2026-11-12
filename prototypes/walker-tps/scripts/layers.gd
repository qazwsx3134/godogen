extends RefCounted
## Physics layers (named in project.godot [layer_names]). Masks for rays and shapes.
const TERRAIN := 1  # ground, ruins, wrecks: what feet stand on
const PLAYER := 2   # the walker
const ENEMY := 4    # scouts
const SOLID := TERRAIN | PLAYER | ENEMY
