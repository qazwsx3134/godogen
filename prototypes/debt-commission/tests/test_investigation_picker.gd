extends "res://addons/proto_kit/test_kit.gd"
const Picker = preload("res://scripts/investigation_picker.gd")
class Spot extends Control:
	var found := false

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _frames(1)
	var large := Spot.new()
	large.size = Vector2(180, 180)
	var small := Spot.new()
	small.position = Vector2(40, 40)
	small.size = Vector2(10, 10)
	var back := Spot.new()
	back.size = Vector2(180, 180)
	var front := Spot.new()
	front.size = Vector2(180, 180)
	for node: Control in [large, small, back, front]:
		root.add_child(node)
	var spots := {"large": large, "small": small, "back": back, "front": front}
	var definitions := {"large": {}, "small": {}, "back": {"character": "back"}, "front": {"character": "front"}}
	var sprites := {"back": back, "front": front}
	var at := Vector2(45, 45)
	_expect(Picker.pick(at, spots, definitions, sprites, 48) == "small", "small object wins over larger objects and portraits")
	small.found = true
	_expect(Picker.pick(at, spots, definitions, sprites, 48) == "large", "found one-shot object is skipped")
	definitions.small = {"lines": ["repeat"]}
	_expect(Picker.pick(at, spots, definitions, sprites, 48) == "small", "found repeating object can still answer")
	large.found = true
	definitions.small = {}
	_expect(Picker.pick(at, spots, definitions, sprites, 48) == "front", "front portrait wins when no object is eligible")
	front.hide()
	_expect(Picker.pick(at, spots, definitions, sprites, 48) == "back", "hidden portrait cannot win over a visible one")
	back.hide()
	_expect(Picker.pick(at, spots, definitions, sprites, 48).is_empty(), "hidden portraits leave no clickable target")
	front.show()
	back.show()
	_expect(Picker.pick(Vector2(500, 500), spots, definitions, sprites, 48).is_empty(), "outside all targets returns none")
	var rect := Picker.hit_rect(small, 48)
	_expect(rect.size == Vector2(48, 48) and rect.get_center() == small.get_global_rect().get_center(), "touch expansion preserves target centre")
	_expect(small.size == Vector2(10, 10) and small.found, "selection does not mutate layout or found state")
	for node: Control in [large, small, back, front]:
		node.free()
	_finish("INVESTIGATION PICKER TESTS")
