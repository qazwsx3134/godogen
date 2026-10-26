extends "res://addons/proto_kit/test_kit.gd"

const ComboInput = preload("res://addons/proto_kit/combo_input.gd")
const RefineLadder = preload("res://addons/proto_kit/refine_ladder.gd")
const PetCare = preload("res://addons/proto_kit/pet_care.gd")


func _rng(seed_value: int = 7) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_combo()
	_test_refine()
	_test_pet()
	print("checks: ", checks)
	_finish("MMO MODULES TESTS")


func _types(events: Array) -> Array:
	return events.map(func(e: Dictionary) -> String: return e.type)


func _test_combo() -> void:
	var defs: Array[Dictionary] = [
		{"id": "triple", "steps": ["A", "S", "AS"]},
		{"id": "five", "steps": ["A", "S", "A", "A", "AD"], "finish_bonus": 0.5},
		{"id": "two", "steps": ["D", "S"]},
		{"id": "two_more", "steps": ["D", "S", "D"]},
	]
	var c := ComboInput.new(defs)
	c.press("A", 0.0)
	_expect(c.update(0.1).is_empty() and not c.running(), "no combo before the gauge is ready")
	c.add_gauge(0.6)
	_expect(c.is_ready(), "gauge ready at 0.5")
	c.press("A", 1.0)
	var e := c.update(1.1)
	_expect(_types(e) == ["start", "step"] and c.gauge == 0.0 and e[0].speed > 1.0, "first key starts and spends the gauge")
	_expect(c.candidates().size() == 2, "two combos still start with A")
	c.press("S", 1.45)
	e = c.update(1.55)
	_expect(_types(e) == ["step"] and e[0].step == 2 and is_equal_approx(e[0].mult, 1.1), "second step on the beat")
	c.press("S", 1.90)
	c.press("A", 1.93)
	e = c.update(2.0)
	_expect(_types(e) == ["step", "finish"] and e[1].combo == "triple", "chord AS finishes the triple")
	_expect(is_equal_approx(e[1].mult, 1.5) and not c.running(), "finish adds the bonus and ends")

	c.add_gauge(1.0)
	c.press("A", 10.0)
	c.update(10.1)
	c.press("S", 10.2)  # 0.25 s after: too early for a 0.45 s beat
	e = c.update(10.3)
	_expect(_types(e) == ["break"] and not c.running(), "pressing off the beat breaks")

	c.add_gauge(1.0)
	c.press("A", 20.0)
	c.update(20.1)
	c.press("D", 20.45)
	_expect(_types(c.update(20.55)) == ["break"], "a key no candidate expects breaks")

	c.add_gauge(1.0)
	c.press("A", 30.0)
	c.update(30.1)
	_expect(_types(c.update(30.7)) == ["break"], "missing the beat breaks")

	c.add_gauge(1.0)
	c.press("D", 40.0)
	c.update(40.1)
	c.press("S", 40.45)
	_expect(_types(c.update(40.55)) == ["step"], "two steps match but a longer combo can follow")
	e = c.update(41.1)
	_expect(_types(e) == ["finish"] and e[0].combo == "two", "the shorter combo finishes after its beat passes")

	var opening := ComboInput.new(defs)
	opening.add_gauge(1.0)
	opening.press("Q", 0.0)
	_expect(opening.update(0.1).is_empty() and opening.is_ready(), "a wrong opening key does nothing and keeps the gauge")


func _test_refine() -> void:
	var ladder := RefineLadder.new()
	var rng := _rng()
	_expect(ladder.max_level() == 12 and ladder.step(4).stone == "ruby", "default ladder")
	_expect(ladder.attempt(0, rng).ok and ladder.attempt(0, rng).level == 1, "crystal always works")
	_expect(is_equal_approx(ladder.chance(3, 0.2), 0.9) and ladder.chance(0, 0.5) == 1.0, "bonus adds and clamps")
	_expect(not ladder.attempt(12, rng).ok and ladder.step(12).is_empty(), "nothing above the top")
	var wins := 0
	for i in 4000:
		if ladder.attempt(3, rng).ok:
			wins += 1
	_expect(absf(wins / 4000.0 - 0.7) < 0.03, "ruby +3 succeeds about 70 %% (%d)" % wins)
	var keep := RefineLadder.new([{"stone": "s", "chance": 0.0, "fail": {"keep": 1}}])
	var r := keep.attempt(0, rng)
	_expect(not r.ok and r.level == 0 and not r.destroyed and r.stone == "s", "keep: only the stone is lost")
	var harsh: Array[Dictionary] = []
	for i in 9:
		harsh.append({"stone": "x", "chance": 0.0, "fail": {"destroy": 1}})
	harsh.append({"stone": "x", "chance": 0.0, "fail": {"drop:3": 1}})
	var hard := RefineLadder.new(harsh)
	_expect(hard.attempt(8, rng).destroyed, "destroy outcome")
	_expect(hard.attempt(9, rng).level == 3, "drop outcome")
	r = hard.attempt(8, rng, {"protect": {"floor": 7, "chance": 1.0}})
	_expect(not r.destroyed and r.level == 7, "protection turns a destroy into the floor")
	_expect(hard.attempt(5, rng, {"protect": {"floor": 7, "chance": 1.0}}).destroyed, "protection needs the item at the floor or above")
	var cost := ladder.expected_stones(0, 3, _rng())
	_expect(is_equal_approx(cost.stones.crystal, 3.0) and cost.destroy_rate == 0.0, "three crystals to +3")
	cost = ladder.expected_stones(3, 6, _rng(), 4000)
	var want := 1.0 / 0.7 + 1.0 / 0.6 + 1.0 / 0.5
	_expect(absf(cost.stones.ruby - want) < 0.2, "rubies to +6 about %.2f (%.2f)" % [want, cost.stones.ruby])


func _test_pet() -> void:
	var foods := ["apple", "fish", "bread"]
	var pet := PetCare.new({"egg": "seed", "foods": foods, "drain": 0.01,
		"types": {"warrior": {"damage": 2.0}}}, _rng())
	_expect(pet.xp_to_next() == 30, "seed stage 1 needs 30")
	pet.level = 5
	_expect(pet.xp_to_next() == 45, "each level costs 10 % more")
	pet.level = 0
	_expect(PetCare.new({"egg": "piya"}, _rng()).xp_to_next() == 120, "piya starts at group C")
	_expect([PetCare.food_xp({"price": 10}), PetCare.food_xp({"price": 45}), PetCare.food_xp({"price": 190}),
		PetCare.food_xp({"price": 5000, "kind": "equipment"})] == [1, 4, 11, 6], "feeding XP from the sell price")

	_expect(pet.tick(100.0, true).is_empty() and pet.hunger == 1.0, "towns pause hunger")
	var e := pet.tick(30.0)
	_expect(e.is_empty() and is_equal_approx(pet.hunger, 0.7), "drains in the field")
	e = pet.tick(10.0)
	_expect(e.size() == 1 and e[0].type == "hungry" and e[0].wants in foods, "asks once for a food when hungry")
	_expect(pet.tick(1.0).is_empty(), "does not ask again while still hungry")
	var wanted := pet.wants
	pet.hunger = 0.1  # one feeding (+0.35) leaves it still hungry
	var plain := pet.feed({"id": "rock", "price": 45})
	_expect(plain.xp == 4 and not plain.wanted and pet.wants == wanted, "plain food; still hungry, still wants it")
	var got := pet.feed({"id": wanted, "price": 45})
	_expect(got.wanted and got.xp == 8, "wanted food gives double")
	_expect(not pet.is_hungry() and pet.wants == "", "fed enough: no longer asks")
	pet.xp = 25
	var up := pet.feed({"id": "cake", "price": 190})
	_expect(up.level_up and pet.level == 1 and pet.xp == 3, "level up; spare XP does not roll over")
	pet.reequip()
	_expect(pet.xp == 0 and pet.level == 1, "re-equipping loses the level's XP")

	pet.xp = 20
	pet.hunger = 0.001
	e = pet.tick(1.0)
	_expect(e.back().type == "starved" and pet.hunger == 1.0 and pet.xp < 20, "starving costs XP and refills the bar")
	pet.xp = 0
	pet.hunger = 0.001
	e = pet.tick(1.0)
	_expect(e.back().type == "ran_away" and not pet.alive, "starving with no XP left: it runs away")
	_expect(pet.feed({"id": "apple", "price": 45}).xp == 0, "a lost pet cannot be fed")

	var grow := PetCare.new({"egg": "seed", "types": {"warrior": {"damage": 2.0}}}, _rng())
	_expect(not grow.can_evolve(), "needs +9 and full XP")
	grow.level = 9
	grow.xp = grow.xp_to_next()
	_expect(grow.can_evolve(), "ready at +9 100 %")
	var fail := grow.evolve(["junk"], [{"materials": ["herb"], "chance": 1.0, "types": {"warrior": 1.0}}])
	var tries := 0
	while fail.ok and tries < 50:  # the fallback recipe still succeeds 20 % of the time
		grow.stage = 1
		grow.level = 9
		grow.xp = grow.xp_to_next()
		fail = grow.evolve(["junk"], [{"materials": ["herb"], "chance": 1.0, "types": {"warrior": 1.0}}])
		tries += 1
	_expect(not fail.ok and grow.stage == 1 and grow.xp == 0, "failed evolution keeps the stage and empties XP")
	grow.xp = grow.xp_to_next()
	var ok := grow.evolve(["herb", "junk"], [{"materials": ["herb"], "chance": 1.0, "types": {"warrior": 1.0}}])
	_expect(ok.ok and grow.stage == 2 and grow.level == 0 and grow.type == "warrior", "recipe evolves into its type")
	_expect(grow.stats() == {"damage": 4.0}, "stats scale with the stage")
	var copy := PetCare.new({"egg": "bird"}, _rng())
	copy.from_dict(JSON.parse_string(JSON.stringify(grow.to_dict())))
	_expect(copy.stage == 2 and copy.type == "warrior" and copy.egg == "seed", "pet restores")
