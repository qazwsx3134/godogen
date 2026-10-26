extends Control
const ACTOR = preload("res://scenes/world/unit_actor.tscn")
const NUMBER = preload("res://scenes/world/floating_number.tscn")
var model: RefCounted
var _views: Dictionary = {}
var _roster_signature: String = ""
var _travel: float = 0.0
@onready var actor_root: Node2D = %Actors
@onready var number_root: Control = %Numbers
@onready var far_layer: TextureRect = %FarLayer
@onready var mid_layer: TextureRect = %MidLayer
@onready var sky: TextureRect = %Sky


func bind(game: RefCounted) -> void:
	model = game
	_sync()


func _process(delta: float) -> void:
	if model == null: return
	_sync()
	if not model.paused and model.phase == "advance":
		_travel += delta * 42.0
	# UV offsets are presentation only; Control geometry stays authored in the scene.
	if far_layer.material is ShaderMaterial:
		far_layer.material.set_shader_parameter("scroll", _travel * 0.0007)
		mid_layer.material.set_shader_parameter("scroll", _travel * 0.002)


func _sync() -> void:
	var ids: Array[String] = []
	for actor: Dictionary in model.actors: ids.append(actor.uid)
	var signature: String = ",".join(ids)
	if signature != _roster_signature:
		for node: Node in actor_root.get_children():
			actor_root.remove_child(node)
			node.queue_free()
		_views.clear()
		for actor: Dictionary in model.actors:
			var view: Node2D = ACTOR.instantiate()
			actor_root.add_child(view)
			view.configure(model.catalog.units[actor.species], actor.friendly, actor.boss)
			_views[actor.uid] = view
		_roster_signature = signature
	var width: float = size.x / 1224.0
	for actor: Dictionary in model.actors:
		var view: Node2D = _views[actor.uid]
		var march: float = 0.0
		if model.phase == "advance" and actor.friendly: march = (1.35 - model.phase_left) * 90.0
		view.position = Vector2((float(actor.x) + march) * width, size.y - 24.0)
		view.apply(actor, model.tick_number)
	var color: Color = Color(model.catalog.stages[int(model.state.stage)].theme)
	sky.modulate = color


func display(event: Dictionary) -> void:
	var kind: String = str(event.kind)
	if kind not in ["attack", "heal", "reaction", "gold"]: return
	var target: String = str(event.get("target", ""))
	if not _views.has(target) or number_root.get_child_count() >= 24: return
	var view: Node2D = _views[target]
	if kind == "attack" or kind == "reaction": view.flash(model.tick_number)
	var label: Label = NUMBER.instantiate()
	number_root.add_child(label)
	var tint: Color = Color("f4ddd4")
	var prefix: String = ""
	match kind:
		"heal": tint = Color("9ce4b8"); prefix = "+"
		"reaction": tint = Color("c4b2ff"); prefix = "甘霖 "
		"gold": tint = Color("edce8e"); prefix = "+"
	var vertical: float = -180.0 if kind == "gold" else -125.0
	label.show_value(prefix + str(event.amount), view.position + Vector2(-18 + (int(event.tick) % 3) * 12, vertical), tint)
