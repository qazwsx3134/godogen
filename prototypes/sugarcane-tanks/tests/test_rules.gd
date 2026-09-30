extends "res://addons/proto_kit/test_kit.gd"
## Ability stacking, damage penalties, EXP curve and card drawing.

const HeroStats = preload("res://domain/hero_stats.gd")

func _init() -> void:
	var defs: Array = _defs()
	_expect(defs.size() == 15, "15 ability cards exist")

	var stats: RefCounted = HeroStats.new()
	_expect(stats.volley_pattern().size() == 1 and stats.volleys() == 1, "starts with one cane per attack")
	_expect(is_equal_approx(stats.projectile_damage(), 50.0), "base damage 50")

	stats.add_ability(&"front")
	_expect(stats.volley_pattern().size() == 2, "front +1 throws two canes side by side")
	_expect(is_equal_approx(stats.projectile_damage(), 37.5), "front +1 costs 25% damage per cane")
	var offsets: Array = stats.volley_pattern().map(func(shot: Dictionary) -> float: return shot["offset"])
	_expect(is_equal_approx(offsets[0], -offsets[1]), "front canes are centred on the aim line")

	stats.add_ability(&"multishot")
	_expect(stats.volleys() == 2, "multishot adds a second volley")
	_expect(is_equal_approx(stats.projectile_damage(), 37.5 * 0.85), "multishot costs 15% on top")

	stats.add_ability(&"diagonal")
	stats.add_ability(&"side")
	stats.add_ability(&"rear")
	_expect(stats.volley_pattern().size() == 2 + 2 + 2 + 1, "diagonal, side and rear add 5 canes")
	var angles: Array = stats.volley_pattern().map(func(shot: Dictionary) -> float: return shot["angle"])
	_expect(angles.has(PI), "rear cane flies backwards")

	var tough: RefCounted = HeroStats.new()
	tough.take_damage(300)
	tough.add_ability(&"hp_boost")
	_expect(tough.max_hp == 720 and tough.hp == 420, "HP boost raises max and current HP by 120")
	tough.add_ability(&"heal")
	_expect(tough.hp == 708, "heal restores 40% of max HP")
	tough.heal(9999)
	_expect(tough.hp == tough.max_hp, "healing never exceeds max HP")
	_expect(tough.take_damage(9999) == 720 and tough.hp == 0, "damage stops at zero")

	var fast: RefCounted = HeroStats.new()
	fast.add_ability(&"attack_speed")
	fast.add_ability(&"attack_boost")
	_expect(fast.attack_interval() < HeroStats.BASE_ATTACK_INTERVAL, "attack speed shortens the interval")
	_expect(is_equal_approx(fast.attack(), 60.0), "attack boost is +20%")
	_expect(fast.ricochets() == 0 and fast.wall_bounces() == 0 and not fast.pierces(), "no special canes by default")
	fast.add_ability(&"ricochet")
	fast.add_ability(&"wall_bounce")
	_expect(fast.ricochets() == 3 and fast.wall_bounces() == 2, "ricochet 3, wall bounce 2")

	var leveling: RefCounted = HeroStats.new()
	_expect(HeroStats.exp_to_next(1) == 10, "level 2 needs 10 EXP")
	_expect(leveling.gain_exp(9) == 0 and leveling.level == 1, "9 EXP is not enough")
	_expect(leveling.gain_exp(1) == 1 and leveling.level == 2 and leveling.experience == 0, "10 EXP gives level 2")
	_expect(leveling.gain_exp(14 + 18 + 5) == 2 and leveling.level == 4 and leveling.experience == 5, "big EXP gives several levels and keeps the rest")

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var fresh: RefCounted = HeroStats.new()
	for i: int in 50:
		var picks: Array = fresh.draw_choices(defs, rng)
		var ids: Dictionary = {}
		for def: Resource in picks:
			ids[def.id] = true
		_expect(picks.size() == 3 and ids.size() == 3, "three distinct cards")
		_expect(not ids.has(&"heal"), "heal is not offered at full HP")
	var maxed: RefCounted = HeroStats.new()
	for def: Resource in defs:
		for n: int in def.max_stacks:
			if def.id != &"heal":
				maxed.add_ability(def.id)
	_expect(maxed.draw_choices(defs, rng).is_empty(), "nothing is offered once everything is maxed and HP is full")
	maxed.take_damage(100)
	var last: Array = maxed.draw_choices(defs, rng)
	_expect(last.size() == 1 and last[0].id == &"heal", "only heal is left when hurt")

	_finish("RULES TESTS")

func _defs() -> Array:
	var defs: Array = []
	for file: String in DirAccess.get_files_at("res://data/abilities"):
		if file.ends_with(".tres"):
			defs.append(load("res://data/abilities/" + file))
	return defs
