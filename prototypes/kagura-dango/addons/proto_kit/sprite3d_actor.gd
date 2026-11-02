@tool
extends Node3D
## One sprite actor (player, boss, ally, NPC): picks the direction row from the camera and plays an animation of a
## sprite3d_sheet. Crowds do not use this: they fill a MultiMesh with the same sheet math.
## Spec: skill sprite-actors-3d.
##
##   Actor (Node3D, this script)
##   ├── Sprite  MeshInstance3D: QuadMesh center_offset (0, 0.5, 0), ShaderMaterial sprite3d.gdshader, cast_shadow off
##   ├── Shadow  MeshInstance3D: PlaneMesh 1x1, ShaderMaterial sprite3d_shadow.gdshader
##   └── Xray    MeshInstance3D (optional, the player): same QuadMesh, sprite3d_xray.gdshader, render_priority 1
##
##   actor.facing = velocity          # world direction; keep it when the actor stops
##   actor.play(&"attack")            # restarts only when the animation changes; one-shots hold their last frame
##   actor.flash = 1.0                # the script does not fade it: whoever hits fades it
##
## Time: by default the actor advances itself in _process (Engine time: follows Engine.time_scale and pausing).
## A game whose simulation has its own clock (hit stop or a level-up pause that only slows its own delta) sets
## `auto_advance = false` and calls `step(game_delta)` from its update, so animation frames stay in step with hits.
##
## Materials: at run time each actor draws with its own copies (made in _ready), so many instances of one scene can
## show different frames and stand at different heights. In the editor the actor never touches its materials or
## nodes on its own: the scene shows what is saved in it (set the preview `frame` on the material). Setting `sheet` in
## the editor is an authoring step: it gives this actor its own copies of the materials (an actor sharing a material
## or a .tres is left alone), writes the atlas, grid and foot strip into them and, with `size_from_sheet`, the quad
## size; all of it is saved with the scene.

const Sheet = preload("res://addons/proto_kit/sprite3d_sheet.gd")

@export var sheet: Resource:
	set(value):
		sheet = value
		if is_inside_tree():
			_apply_sheet()
@export var anim: StringName = &"idle"
## World-space facing (only XZ is used).
@export var facing: Vector3 = Vector3(0.0, 0.0, 1.0)
@export var outline: Color = Color(1.0, 1.0, 1.0, 0.0)
@export var auto_advance: bool = true
@export var sprite_path: NodePath = ^"Sprite"
@export var xray_path: NodePath = ^"Xray"
@export var shadow_path: NodePath = ^"Shadow"
@export var ghost_paths: Array[NodePath] = []
## Sets the quad (and xray, shadow) size from the sheet when the sheet is set. Off: keep the sizes in the scene.
@export var size_from_sheet: bool = true

var flash: float = 0.0
var dissolve: float = 0.0
## Ticks since the animation started (1 tick = 1/60 s of the clock that advances the actor).
var ticks: float = 0.0
## Current direction index (keeps the hysteresis); -1 until the first frame.
var direction: int = -1
## Vector2i(cell, facing) drawn this frame.
var drawn: Vector2i = Vector2i.ZERO

var _ready_done: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for node: GeometryInstance3D in _parts(true):
		if node.material_override is ShaderMaterial:
			node.material_override = node.material_override.duplicate()
	_ready_done = true
	_apply_sheet()
	_draw_frame()


func _process(delta: float) -> void:
	if auto_advance and _ready_done:
		step(delta)


## Advances the animation by `delta` seconds of game time and redraws. 0 keeps the frame (a paused world).
func step(delta: float) -> void:
	ticks += maxf(delta, 0.0) * 60.0
	_draw_frame()


## Starts an animation (no restart when it is already playing, unless `restart`).
func play(anim_name: StringName, restart: bool = false) -> void:
	if anim_name != anim or restart:
		anim = anim_name
		ticks = 0.0


## True once a one-shot animation has shown its last frame for its full time. Loops never finish.
func finished() -> bool:
	if sheet == null:
		return true
	var a: Dictionary = sheet.resolve(anim)
	if a.is_empty():
		return true
	return not a.get("loop", true) and ticks >= Sheet.length_ticks(a)


func _draw_frame() -> void:
	if sheet == null or Engine.is_editor_hint():
		return
	var camera := get_viewport().get_camera_3d()
	var angle: float = Sheet.view_angle(facing, camera.global_basis) if camera else 0.0
	direction = sheet.direction(angle, direction)
	drawn = sheet.cell(anim, direction, int(ticks))
	for node: GeometryInstance3D in _parts(false):
		var m := node.material_override as ShaderMaterial
		if m:
			m.set_shader_parameter(&"frame", float(drawn.x))
			m.set_shader_parameter(&"facing", float(drawn.y))
	var sprite := get_node_or_null(sprite_path) as GeometryInstance3D
	if sprite and sprite.material_override is ShaderMaterial:
		var m: ShaderMaterial = sprite.material_override
		m.set_shader_parameter(&"flash", flash)
		m.set_shader_parameter(&"dissolve", dissolve)
		m.set_shader_parameter(&"outline", outline)


func _apply_sheet() -> void:
	if sheet == null:
		return
	if Engine.is_editor_hint():
		for node: GeometryInstance3D in _parts(true):
			if node.material_override is ShaderMaterial:
				node.material_override = node.material_override.duplicate()
	for node: GeometryInstance3D in _parts(false):
		if node.material_override is ShaderMaterial:
			sheet.apply(node.material_override)
	var sprite := get_node_or_null(sprite_path) as Node3D
	if size_from_sheet and sprite:
		var s: float = sheet.size_m()
		for path: NodePath in [sprite_path, xray_path, shadow_path]:
			var part := get_node_or_null(path) as Node3D
			if part:
				part.scale = Vector3(s, s, s)


## Sprite, xray and ghosts (they take the sheet and frame); with `with_shadow`, the shadow too (copied, not drawn).
func _parts(with_shadow: bool) -> Array[GeometryInstance3D]:
	var parts: Array[GeometryInstance3D] = []
	var paths: Array[NodePath] = [sprite_path, xray_path]
	paths.append_array(ghost_paths)
	if with_shadow:
		paths.append(shadow_path)
	for path: NodePath in paths:
		var node := get_node_or_null(path) as GeometryInstance3D
		if node:
			parts.append(node)
	return parts
