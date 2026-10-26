@tool
extends Node3D
## How one creature looks: the 2D sprite standing in the 3D world (kit sprite3d_actor), its nameplate,
## HP bar and target ring, plus procedural body motion. The player and monster scripts drive it.

const Sheet = preload("res://addons/proto_kit/sprite3d_sheet.gd")

@export var sheet: Resource:
	set(value):
		sheet = value
		if is_node_ready() and Engine.is_editor_hint():
			_preview_in_editor()
@export var display_name: String = "名稱":
	set(value):
		display_name = value
		if is_node_ready():
			nameplate.text = value
@export var nameplate_color: Color = Color("f4ead2")
@export var show_nameplate: bool = true
## Monsters dissolve away when they fall; the player lies down.
@export var dissolve_on_down: bool = true
## Top of the sprite (m): the nameplate and HP bar sit above it.
@export var head_height: float = 2.0
## Paper-doll layers drawn over `sheet` (the body), bottom to top: hair, weapon... Each must share the body sheet's
## grid (tools/blender/pack_layers.py output); only the atlas differs. Swap one at run time with set_layer().
@export var layer_sheets: Array[Resource] = []

## Each layer sits this much closer to the camera than the one under it (the sprites write depth).
const LAYER_STEP_M := 0.03

@onready var visual: Node3D = $Visual
@onready var nameplate: Label3D = $Nameplate
@onready var hp_bar: MeshInstance3D = $HpBar
@onready var select_ring: MeshInstance3D = $SelectRing

var moving: bool = false
var dead: bool = false
var targeted: bool = false
var hp_ratio: float = 1.0

var _trail: float = 1.0
var _hp_show_left: float = 0.0
var _action_left: float = 0.0
var _action_total: float = 0.3
var _squash: float = 0.0
var _clock: float = 0.0
var _phase: float = 0.0
var _sprite: Node3D
var _sprite_base: Vector3
var _layers: Array[MeshInstance3D] = []


func _ready() -> void:
	nameplate.text = display_name
	nameplate.position.y = head_height + 0.32
	hp_bar.position.y = head_height + 0.08
	if Engine.is_editor_hint():
		_preview_in_editor()
		return
	if sheet != null:
		visual.sheet = sheet
	visual.auto_advance = false
	hp_bar.material_override = hp_bar.material_override.duplicate()
	_sprite = visual.get_node(^"Sprite")
	_sprite_base = _sprite.scale
	_build_layers()
	_phase = float(get_instance_id() % 997) * 0.37
	nameplate.modulate = nameplate_color
	nameplate.visible = show_nameplate
	hp_bar.visible = false
	select_ring.visible = false


## Replaces one paper-doll layer (null hides it). The new sheet must share the body sheet's grid.
func set_layer(index: int, layer_sheet: Resource) -> void:
	layer_sheets[index] = layer_sheet
	_apply_layer(index)


## One sprite per layer, copied from the body sprite at run time (which layers exist is equipment data). The kit
## actor drives them as ghosts: same cell and facing as the body every frame.
func _build_layers() -> void:
	var ghosts: Array[NodePath] = []
	for i in layer_sheets.size():
		var layer := (_sprite as MeshInstance3D).duplicate() as MeshInstance3D
		layer.name = "Layer%d" % (i + 1)
		layer.material_override = (_sprite as MeshInstance3D).material_override.duplicate()
		visual.add_child(layer)
		_layers.append(layer)
		ghosts.append(NodePath(layer.name))
		_apply_layer(i)
	visual.ghost_paths = ghosts


func _apply_layer(index: int) -> void:
	var layer := _layers[index]
	var layer_sheet: Resource = layer_sheets[index]
	layer.visible = layer_sheet != null
	if layer_sheet == null:
		return
	var m := layer.material_override as ShaderMaterial
	layer_sheet.apply(m)
	m.set_shader_parameter(&"toward_camera", (index + 1) * LAYER_STEP_M)


func face(direction: Vector3) -> void:
	if Vector2(direction.x, direction.z).length_squared() > 0.0001:
		visual.facing = Vector3(direction.x, 0.0, direction.z)


func attack() -> void:
	var a: Dictionary = sheet.resolve(&"attack") if sheet != null else {}
	_action_left = maxf(0.3, Sheet.length_ticks(a) / 60.0)
	_action_total = _action_left
	visual.play(&"attack", true)


func hurt() -> void:
	visual.flash = 1.0
	_squash = 1.0
	_hp_show_left = 3.0


func set_dead(value: bool) -> void:
	dead = value
	if not dead:
		visual.dissolve = 0.0
		visual.flash = 0.0
		_trail = 1.0
		nameplate.visible = show_nameplate
		visual.play(&"idle", true)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	visual.flash = move_toward(visual.flash, 0.0, delta * 6.0)
	_hp_show_left = maxf(0.0, _hp_show_left - delta)
	_action_left = maxf(0.0, _action_left - delta)
	if dead:
		visual.play(&"down")
		if dissolve_on_down:
			visual.dissolve = minf(1.0, visual.dissolve + delta * 1.6)
		nameplate.visible = false
	elif _action_left > 0.0:
		pass
	elif moving:
		visual.play(&"walk")
	else:
		visual.play(&"idle")
	visual.step(delta)
	_animate_body(delta)
	hp_bar.visible = not dead and (targeted or hp_ratio < 0.999 or _hp_show_left > 0.0)
	_trail = hp_ratio if hp_ratio > _trail else move_toward(_trail, hp_ratio, delta * 0.6)
	var bar := hp_bar.material_override as ShaderMaterial
	bar.set_shader_parameter(&"ratio", hp_ratio)
	bar.set_shader_parameter(&"trail", _trail)
	select_ring.visible = targeted and not dead


## Breathing at rest, a bounce while walking, a lunge on attack, a squash when hit.
func _animate_body(delta: float) -> void:
	_clock += delta
	_squash = move_toward(_squash, 0.0, delta * 5.0)
	var offset := Vector3.ZERO
	var stretch := 0.0
	if dead:
		pass
	elif _action_left > 0.0:
		var t := 1.0 - _action_left / maxf(_action_total, 0.01)
		var swing := sin(clampf(t * 1.6, 0.0, 1.0) * PI)
		# Lunge along the screen only: moving into depth would sink the sprite behind its own ground shadow.
		var camera := get_viewport().get_camera_3d()
		var right := Vector3(camera.global_basis.x.x, 0.0, camera.global_basis.x.z).normalized() if camera else Vector3.RIGHT
		offset = right * visual.facing.normalized().dot(right) * swing * 0.32
		stretch = -swing * 0.03
	elif moving:
		offset.y = absf(sin(_clock * 9.5 + _phase)) * 0.07
		stretch = sin(_clock * 19.0 + _phase) * 0.025
	else:
		stretch = sin(_clock * 2.3 + _phase) * 0.018
	stretch -= _squash * 0.12
	_sprite.position = offset
	_sprite.scale = Vector3(_sprite_base.x * (1.0 - stretch * 0.6), _sprite_base.y * (1.0 + stretch), _sprite_base.z)
	var body_material := (_sprite as MeshInstance3D).material_override as ShaderMaterial
	for layer in _layers:
		layer.position = _sprite.position
		layer.scale = _sprite.scale
		var m := layer.material_override as ShaderMaterial
		m.set_shader_parameter(&"flash", body_material.get_shader_parameter(&"flash"))
		m.set_shader_parameter(&"dissolve", body_material.get_shader_parameter(&"dissolve"))


## Editor preview: shows the idle cell on this instance's own material (nothing is written back to actor.tscn).
func _preview_in_editor() -> void:
	nameplate.text = display_name
	nameplate.position.y = head_height + 0.32
	hp_bar.position.y = head_height + 0.08
	var sprite := visual.get_node_or_null(^"Sprite") as MeshInstance3D
	if sheet == null or sprite == null or not sprite.material_override is ShaderMaterial:
		return
	var material := (sprite.material_override as ShaderMaterial).duplicate() as ShaderMaterial
	material.set_shader_parameter(&"atlas", sheet.get("atlas"))
	material.set_shader_parameter(&"frames", Vector2(sheet.get("columns"), sheet.get("rows")))
	material.set_shader_parameter(&"foot_gutter", float(sheet.get("foot_px")) / float(sheet.get("cell_px")))
	material.set_shader_parameter(&"frame", 0.0)
	sprite.material_override = material
	var size: float = float(sheet.get("cell_px")) * float(sheet.get("meters_per_px"))
	sprite.scale = Vector3.ONE * size
	var shadow := visual.get_node_or_null(^"Shadow") as Node3D
	if shadow != null:
		shadow.scale = Vector3.ONE * size
