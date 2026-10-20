@tool
extends "res://addons/proto_kit/sprite3d_actor.gd"
## A named member of the cast (cutscenes, companions, bosses, blockers): loads its sheet by `character` id from the
## sprite set at run time and sizes its blob shadow by height. scenes/cast_actor.tscn is the scene to instance.

const SpriteSet = preload("res://scripts/sprite_set.gd")

@export var character: String = "luffy"
## Blob shadow width as a share of the character's height.
@export var shadow_share: float = 0.55


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	var found: Resource = SpriteSet.sheet(character)
	if found == null:
		push_warning("cast_actor: no sheet for '%s'" % character)
		return
	sheet = found
	var blob := get_node_or_null(^"Blob") as Node3D
	if blob:
		var w: float = SpriteSet.height(character) * shadow_share
		blob.scale = Vector3(w, w, w)
