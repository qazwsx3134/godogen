extends Control

const Canvas = preload("res://ui/pixel_room.gd")
const CANVAS_SIZE := Vector2i(144, 104)
var canvas: Control
var display: TextureRect
var viewport: SubViewport

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(maxf(custom_minimum_size.x, 288), maxf(custom_minimum_size.y, 208))
	viewport = SubViewport.new()
	viewport.size = CANVAS_SIZE
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	canvas = Canvas.new()
	canvas.size = Vector2(CANVAS_SIZE)
	viewport.add_child(canvas)
	display = TextureRect.new()
	display.texture = viewport.get_texture()
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(display)
	resized.connect(_fit)
	_fit()

func _fit() -> void:
	if not is_instance_valid(display):
		return
	var screen_scale: float = maxf(get_viewport().get_final_transform().get_scale().x, 0.01)
	var physical_factor: float = maxf(1.0, floorf(minf(size.x / CANVAS_SIZE.x, size.y / CANVAS_SIZE.y) * screen_scale + 0.001))
	var factor: float = physical_factor / screen_scale
	display.size = Vector2(CANVAS_SIZE) * factor
	display.position = ((size - display.size) / 2.0).floor()

func update_state(state: Dictionary) -> void:
	canvas.pet = state.get("pet", {}).duplicate(true)
	canvas.egg = state.get("egg", {}).duplicate(true)

func play(action: String) -> void:
	canvas.play(action)

func arena(species: String) -> void:
	canvas.battle = true
	canvas.enemy_species = species
