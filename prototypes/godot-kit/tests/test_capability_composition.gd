extends "res://addons/proto_kit/test_kit.gd"
const Numbers = preload("res://addons/proto_kit/damage_numbers_3d.tscn")
const Draft = preload("res://addons/proto_kit/card_draft.gd")
const Rarity = preload("res://addons/proto_kit/rarity.gd")
const Caster = preload("res://addons/proto_kit/auto_caster.gd")
const FixedStep = preload("res://addons/proto_kit/fixed_step.gd")
const Save = preload("res://addons/proto_kit/save_slots.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_stepper()
	_test_draft_cast_save()
	await _test_numbers()
	print("checks: ", checks)
	_finish("CAPABILITY COMPOSITION")

func _test_draft_cast_save() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var cards: Array[Dictionary] = [{"id": "slash", "kind": "skill", "max_level": 3}]
	var draft = Draft.new(cards, rng)
	var rarity = Rarity.new()
	var book = Caster.new()
	var offer: Array[Dictionary] = rarity.roll_offer(draft.offer(), rng)
	_expect(offer.size() == 1 and offer[0].id == "slash", "draft IDs flow into rarity")
	_expect(draft.pick(offer[0].id), "offered card accepted")
	book.learn({"id": "slash", "damage": 10.0, "range": 3.0}, rarity.bonus(offer[0].tier))
	var targets: Array = [{"id": "enemy", "pos": Vector3.ONE, "hp": 100.0, "max_hp": 100.0, "tags": []}]
	var casts: Array = book.step(1.0, Vector3.ZERO, targets)
	_expect(casts.size() == 1 and casts[0].hits.size() == 1, "cast contains selected target")
	_expect(casts[0].hits[0].id == "enemy" and casts[0].hits[0].damage > 10.0, "rarity bonus reaches damage")
	# Each run uses a unique temp location, never the author's user:// progress.
	var path: String = OS.get_environment("TMPDIR").path_join("kit-compose-%s.json" % OS.get_process_id())
	if OS.get_environment("TMPDIR").is_empty():
		path = "/tmp/kit-compose-%s.json" % OS.get_process_id()
	var snapshot: Dictionary = {"draft": draft.to_dict(), "caster": book.to_dict()}
	_expect(Save.save(path, snapshot, 1) == OK, "composition snapshot commits")
	var restored: Dictionary = Save.restore(path, 1)
	_expect(restored.error == "" and restored.source == "main", "JSON snapshot restores")
	var restored_draft = Draft.new(cards, RandomNumberGenerator.new())
	restored_draft.from_dict(restored.data.draft)
	var restored_book = Caster.new()
	restored_book.from_dict(restored.data.caster)
	_expect(restored_draft.level("slash") == 1 and restored_book.knows("slash"), "module state restores through JSON")
	_expect(draft.offer() == restored_draft.offer(), "restored draft continues same RNG sequence")
	DirAccess.remove_absolute(path)

func _test_numbers() -> void:
	var source_before: PackedByteArray = FileAccess.get_file_as_bytes("res://addons/proto_kit/damage_numbers_3d.tscn")
	var numbers = Numbers.instantiate()
	numbers.pool_size = 2
	numbers.jitter = 0.0
	numbers.height = 0.0
	numbers.position = Vector3(10, 2, -3)
	numbers.rotation.y = 0.5
	numbers.scale = Vector3(2, 2, 2)
	numbers.life = 1.0
	numbers.critical_scale = 1.0
	numbers.critical_color = Color(1, 0, 0, 0.4)
	# The saved representative is visible before running; user style edits survive ready.
	_expect(numbers.get_node("Preview").visible, "editor has representative object")
	numbers.get_node("Preview").font_size = 55
	root.add_child(numbers)
	await process_frame
	_expect(numbers.get_child_count() == 2, "fixed capacity includes saved label")
	_expect(numbers.get_node("Preview").font_size == 55, "editor font adjustment survives runtime")
	_expect(not numbers.show_hit(Vector3.ZERO, 0.1), "small hits suppressed")
	_expect(not numbers.show_hit(Vector3.ZERO, NAN), "invalid amount rejected")
	_expect(numbers.show_hit(Vector3(1, 2, 3), 12.0, true), "hit accepted")
	var first: Label3D = numbers.get_node("Preview")
	_expect(first.global_position.is_equal_approx(Vector3(1, 2, 3)), "world position under transformed pool")
	numbers.step(0.8)
	_expect(is_equal_approx(first.modulate.a, 0.2), "critical alpha preserved even at scale 1")
	_expect(first.global_position.y > 2.0, "rises in world up")
	numbers.step(-1.0)
	_expect(numbers.active_count() == 1, "negative time ignored")
	numbers.show_hit(Vector3.ZERO, 2.0)
	numbers.show_hit(Vector3.ZERO, 99.0)
	_expect(numbers.active_count() == 2 and first.text == "99", "oldest slot reused without allocating")
	numbers.step(1.0)
	_expect(numbers.active_count() == 0, "expiry hides pool")
	seed(919)
	var expected_global: float = randf()
	seed(919)
	numbers.show_hit(Vector3.ZERO, 1.0)
	_expect(randf() == expected_global, "cosmetic RNG does not consume gameplay global RNG")
	numbers.clear()
	_expect(numbers.active_count() == 0, "clear resets all visible numbers")
	_expect(FileAccess.get_file_as_bytes("res://addons/proto_kit/damage_numbers_3d.tscn") == source_before, "runtime never writes scene")
	numbers.free()

func _test_stepper() -> void:
	var stepper = FixedStep.new()
	_expect(stepper.configure(0.1, 2, "retain") == OK, "configure fixed step")
	_expect(stepper.advance(0.35) == 2, "work is bounded per frame")
	_expect(is_equal_approx(stepper.backlog_seconds(), 0.15), "idle policy keeps backlog")
	_expect(stepper.advance(0.0) == 1, "retained backlog drains without new time")
	_expect(is_equal_approx(stepper.alpha(), 0.5), "fraction supports interpolation")
	_expect(stepper.configure(0.0) == ERR_INVALID_PARAMETER, "invalid config rejected")
	_expect(is_equal_approx(stepper.backlog_seconds(), 0.05), "failed configure preserves state")
	_expect(stepper.advance(NAN) == 0 and stepper.advance(-1.0) == 0, "bad delta rejected")
	_expect(stepper.configure(0.1, 2, "drop") == OK, "combat drop policy explicit")
	_expect(stepper.advance(0.55) == 2, "drop still caps work")
	_expect(is_equal_approx(stepper.dropped_seconds(), 0.3), "discarded time observable")
	_expect(is_equal_approx(stepper.backlog_seconds(), 0.05), "drop preserves interpolation remainder")
	stepper.reset()
	_expect(stepper.advance(0.5) == 2 and is_zero_approx(stepper.backlog_seconds()), "exact boundary leaves no phantom step")
	stepper.reset()
	_expect(stepper.backlog_seconds() == 0.0 and stepper.dropped_seconds() == 0.0, "reset clears clock state")
