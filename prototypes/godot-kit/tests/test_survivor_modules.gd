extends "res://addons/proto_kit/test_kit.gd"

const AutoCaster = preload("res://addons/proto_kit/auto_caster.gd")
const Rarity = preload("res://addons/proto_kit/rarity.gd")
const RunTimeline = preload("res://addons/proto_kit/run_timeline.gd")
const TalentTiers = preload("res://addons/proto_kit/talent_tiers.gd")
const LootLedger = preload("res://addons/proto_kit/loot_ledger.gd")
const ChestShop = preload("res://addons/proto_kit/chest_shop.gd")


func _rng(seed_value: int = 7) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _foe(id: String, x: float, hp: float = 100.0, tags: Array = [], max_hp: float = 100.0) -> Dictionary:
	return {"id": id, "pos": Vector2(x, 0.0), "hp": hp, "max_hp": max_hp, "tags": tags}


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_caster_targeting()
	_test_caster_effects()
	_test_rarity()
	_test_timeline()
	_test_talents()
	_test_ledger()
	_test_chests()
	print("checks: ", checks)
	_finish("SURVIVOR MODULES TESTS")


func _hits(casts: Array, spell: String) -> Array:
	for cast: Dictionary in casts:
		if cast.spell == spell and not cast.dot:
			return cast.hits.map(func(h: Dictionary) -> String: return h.id)
	return []


func _test_caster_targeting() -> void:
	var book := AutoCaster.new()
	book.learn({"id": "strike", "cooldown": 1.0, "range": 5.0, "damage": 10.0})
	var origin := Vector2.ZERO
	_expect(book.step(0.1, origin, [_foe("far", 9.0)]).is_empty(), "nothing in range: no cast")
	var casts := book.step(0.1, origin, [_foe("far", 9.0), _foe("near", 2.0), _foe("mid", 4.0)])
	_expect(_hits(casts, "strike") == ["near"], "ready spell fires the moment a target is in range, at the nearest")
	_expect(book.step(0.5, origin, [_foe("near", 2.0)]).is_empty(), "cooldown holds")
	_expect(_hits(book.step(0.5, origin, [_foe("near", 2.0)]), "strike") == ["near"], "fires again after cooldown")
	_expect(book.rank_up("strike", {"cooldown": 0.5}) and is_equal_approx(book.effective("strike").cooldown, 0.5), "cooldown bonus shortens")
	_expect(not book.rank_up("missing"), "rank_up needs a known spell")

	var slam := AutoCaster.new()
	slam.learn({"id": "slam", "range": 7.0, "damage": 5.0, "max_targets": 2, "priority": ["boss", "elite"]})
	var foes := [_foe("a", 1.0), _foe("elite", 6.0, 100.0, ["elite"]), _foe("boss", 5.0, 100.0, ["boss"])]
	_expect(_hits(slam.step(0.0, origin, foes), "slam") == ["boss", "elite"], "priority tags before distance, in tag order")
	slam.rank_up("slam", {"targets": 1})
	slam.reset()
	_expect(_hits(slam.step(0.0, origin, foes), "slam") == ["boss", "elite", "a"], "target bonus adds a target")

	var exe := AutoCaster.new()
	exe.learn({"id": "execute", "range": 10.0, "damage": 10.0, "execute_below": 0.3, "execute_mult": 2.0})
	var cast: Dictionary = exe.step(0.0, origin, [_foe("healthy", 1.0), _foe("low", 8.0, 20.0)])[0]
	_expect(cast.hits[0].id == "low" and is_equal_approx(cast.hits[0].damage, 20.0), "execute prefers and doubles low-HP targets")

	var ring := AutoCaster.new()
	ring.learn({"id": "whirl", "range": 3.0, "damage": 4.0, "target": "all"})
	_expect(_hits(ring.step(0.0, origin, [_foe("x", 1.0), _foe("y", 2.5), _foe("z", 3.5)]), "whirl") == ["x", "y"], "all hits everything in range")
	var dead := [_foe("corpse", 1.0, 0.0)]
	_expect(ring.step(5.0, origin, dead).is_empty(), "dead targets are ignored")

	var hp := AutoCaster.new()
	hp.learn({"id": "rend", "range": 8.0, "target": "highest_hp", "max_targets": 2, "damage": 1.0})
	_expect(_hits(hp.step(0.0, origin, [_foe("small", 1.0, 30.0), _foe("big", 7.0, 90.0), _foe("mid", 2.0, 60.0)]), "rend") == ["big", "mid"], "highest_hp rule")

	var vec := AutoCaster.new()
	vec.learn({"id": "v", "range": 2.0, "damage": 1.0})
	var flying := {"id": "f", "pos": Vector3(1.0, 50.0, 0.0), "hp": 1.0, "max_hp": 1.0, "tags": []}
	_expect(_hits(vec.step(0.0, Vector3.ZERO, [flying]), "v") == ["f"], "Vector3 distance is measured on the ground")


func _test_caster_effects() -> void:
	var origin := Vector2.ZERO
	var dot := AutoCaster.new()
	dot.learn({"id": "rend", "cooldown": 100.0, "range": 8.0, "max_targets": 3, "target": "highest_hp", "unique_dot": true,
		"dot": {"total": 70.0, "ticks": 7, "duration": 7.0}})
	var foes := [_foe("a", 1.0, 90.0), _foe("b", 2.0, 80.0)]
	dot.step(0.0, origin, foes)
	var total := 0.0
	var ticks := 0
	for i in 80:
		for cast: Dictionary in dot.step(0.1, origin, foes):
			if cast.dot:
				for h: Dictionary in cast.hits:
					total += h.damage
					ticks += 1
	_expect(ticks == 14 and is_equal_approx(total, 140.0), "dot splits its total into ticks per target (%d ticks, %.1f)" % [ticks, total])

	var unique := AutoCaster.new()
	unique.learn({"id": "rend", "cooldown": 1.0, "range": 8.0, "unique_dot": true, "dot": {"total": 10.0, "ticks": 10, "duration": 10.0}})
	_expect(_hits(unique.step(0.0, origin, foes), "rend") == ["a"], "first dot on nearest")
	_expect(_hits(unique.step(1.0, origin, foes), "rend") == ["b"], "unique dot skips the afflicted target")

	var stun := AutoCaster.new()
	stun.learn({"id": "slam", "range": 7.0, "damage": 1.0, "stun": 1.5, "target": "all"})
	var hits: Array = stun.step(0.0, origin, [_foe("mob", 1.0), _foe("boss", 2.0, 100.0, ["boss"])])[0].hits
	_expect(is_equal_approx(hits[0].stun, 1.5) and is_equal_approx(hits[1].stun, 0.375), "bosses get a quarter of the stun")

	var shout := AutoCaster.new()
	shout.learn({"id": "shout", "cooldown": 20.0, "target": "self", "trigger_range": 30.0, "buff": {"damage": 0.4, "duration": 11.0}})
	shout.learn({"id": "hit", "cooldown": 1.0, "range": 5.0, "damage": 10.0})
	_expect(shout.step(0.0, origin, []).is_empty(), "buff waits for an enemy in its trigger range")
	var casts := shout.step(0.0, origin, [_foe("x", 3.0)])
	var spells: Array = casts.map(func(c: Dictionary) -> String: return c.spell)
	_expect(spells == ["shout", "hit"], "buff then hit in learn order")
	_expect(is_equal_approx(casts[1].hits[0].damage, 14.0), "active buff raises damage")
	shout.step(11.5, origin, [])
	_expect(is_equal_approx(shout.buff_mult(), 1.0), "buff expires")

	var leech := AutoCaster.new()
	leech.learn({"id": "bloodthirst", "range": 7.0, "damage": 20.0, "heal_ratio": 0.5})
	leech.damage_mult = 1.5
	var c: Dictionary = leech.step(0.0, origin, [_foe("x", 1.0)])[0]
	_expect(is_equal_approx(c.hits[0].damage, 30.0) and is_equal_approx(c.heal, 15.0), "global damage mult and heal ratio")

	var saved := AutoCaster.new()
	saved.learn({"id": "a", "damage": 10.0}, {"damage": 0.34})
	saved.rank_up("a", {"targets": 2})
	var copy := AutoCaster.new()
	copy.from_dict(JSON.parse_string(JSON.stringify(saved.to_dict())))
	_expect(copy.rank("a") == 2 and copy.effective("a") == saved.effective("a"), "ranks and bonuses restore")


func _test_rarity() -> void:
	var r := Rarity.new()
	var base := r.weights()
	var lucky := r.weights(0.5)
	var sum_a := 0.0
	var sum_b := 0.0
	for i in base.size():
		sum_a += base[i]
		sum_b += lucky[i]
	_expect(is_equal_approx(sum_a, sum_b), "luck keeps the total weight")
	_expect(lucky[0] < base[0] and lucky[4] > base[4], "luck moves weight up")
	var a := _rng(3)
	var b := _rng(3)
	var counts := [0, 0, 0, 0, 0]
	for i in 20000:
		var tier := r.roll(a)
		_expect(tier == r.roll(b), "seeded roll %d" % i) if i < 20 else null
		counts[tier] += 1
	_expect(absf(counts[0] / 20000.0 - 0.55) < 0.02 and counts[4] > 100 and counts[4] < 500, "roll follows weights %s" % [counts])
	_expect(r.bonus(3) == {"damage": 0.34}, "new card bonus is damage")
	var seen := {}
	var rng := _rng(5)
	for i in 200:
		for key in r.bonus(0, "upgrade", rng):
			seen[key] = true
	_expect(seen.has("damage") and seen.has("cooldown") and not seen.has("targets"), "common upgrades never add targets")
	seen.clear()
	for i in 200:
		for key in r.bonus(4, "upgrade", rng):
			seen[key] = true
	_expect(seen.has("targets"), "legendary upgrades can add targets")
	_expect(r.roll_offer(["x", "y", "z"], _rng()).size() == 3, "one tier per offered card")


func _test_timeline() -> void:
	_expect(is_equal_approx(RunTimeline.sample([[0, 1.0], [10, 3.0]], 5.0), 2.0) and RunTimeline.sample([[0, 1.0], [10, 3.0]], 99.0) == 3.0, "sample interpolates and clamps")
	var config := {"duration": 120.0, "rate": [[0, 2.0]], "max_alive": 1000,
		"events": [{"at": 60, "id": "boss", "kind": "boss"}, {"at": 30, "id": "rush", "kind": "event"}],
		"roster": [{"kind": "kobold", "from": 0, "to": 50}, {"kind": "wolf", "from": 50}], "elite": [[0, 0.0], [100, 1.0]]}
	var run := RunTimeline.new(config, _rng())
	_expect(run.next_event().id == "rush" and run.next_event("boss").id == "boss", "next event by time and kind")
	var spawns: Array = []
	var events: Array = []
	for i in 600:
		var out := run.step(0.1)
		spawns.append_array(out.spawns)
		events.append_array(out.events.map(func(e: Dictionary) -> String: return e.id))
	_expect(events == ["rush", "boss"], "events fire once, in time order")
	_expect(spawns.size() == 120, "budget spawns rate x time (%d)" % spawns.size())
	_expect(spawns.slice(0, 90).all(func(s: Dictionary) -> bool: return s.kind == "kobold"), "roster window early")
	_expect(spawns.slice(110).all(func(s: Dictionary) -> bool: return s.kind == "wolf"), "roster window late")
	_expect(spawns.slice(0, 10).all(func(s: Dictionary) -> bool: return not s.elite), "no elites at chance 0")
	var capped := RunTimeline.new({"rate": [[0, 10.0]], "max_alive": 5, "roster": [{"kind": "k"}]}, _rng())
	_expect(capped.step(1.0, 0).spawns.size() == 5, "max_alive caps a burst")
	_expect(capped.step(10.0, 5).spawns.is_empty() and capped.step(0.1, 0).spawns.size() <= 5, "no budget builds while full")
	var x := RunTimeline.new(config, _rng(9))
	x.step(33.3)
	var y := RunTimeline.new(config, _rng(1))
	y.from_dict(JSON.parse_string(JSON.stringify(x.to_dict())))
	_expect(x.step(10.0) == y.step(10.0), "restored timeline continues identically")
	var end := RunTimeline.new({"duration": 1.0}, _rng())
	end.step(2.0)
	_expect(end.finished() and end.step(1.0).spawns.is_empty(), "finished run stops")


func _talent_defs() -> Array[Dictionary]:
	return [
		{"id": "a1", "tree": "arms", "row": 0, "max_rank": 5, "effect": {"damage": 0.01}},
		{"id": "a2", "tree": "arms", "row": 1, "max_rank": 3, "effect": {"crit": 0.02}},
		{"id": "a3", "tree": "arms", "row": 2, "max_rank": 1, "requires": "a2"},
		{"id": "f1", "tree": "fury", "row": 0, "max_rank": 5, "effect": {"damage": 0.02}},
	]


func _test_talents() -> void:
	var xp := TalentTiers.run_xp({"seconds": 128, "kills": 195, "bosses": 1, "victory": false})
	_expect(is_equal_approx(xp, 128 * 0.2 + 195 * 0.1 + 15.0), "run xp formula")
	_expect(is_equal_approx(TalentTiers.run_xp({"victory": true}, {}, 2.0), 120.0), "zone multiplier")
	var t := TalentTiers.new(_talent_defs(), {"max_points": 51, "milestones": {"arms": {5: "deep_wounds", 10: "sweep"}},
		"xp_curve": {"base": 10, "growth": 1.0}})
	_expect(t.add_xp(95.0) == 9 and is_equal_approx(t.xp, 5.0), "xp buys points on the curve")
	_expect(not t.can_add("a2"), "row 1 locked with 0 points above")
	for i in 4:
		t.add("a1")
	_expect(not t.can_add("a2"), "row 1 still locked at 4")
	t.add("a1")
	_expect(t.can_add("a2") and t.add("a2"), "row 1 opens at 5")
	_expect(not t.can_add("a3"), "requires: a2 must be maxed (and row 2 needs 10)")
	t.add("a2")
	t.add("a2")
	_expect(not t.can_add("a3"), "row 2 needs 10 points above (8)")
	t.add("f1")
	_expect(t.spent("arms") == 8 and t.spent() == 9 and t.available() == 0, "points accounting")
	_expect(not t.add("f1"), "no points left")
	_expect(not t.can_remove("a1") , "removing a1 would strand a2")
	_expect(t.can_remove("a2") and t.remove("a2"), "removing the bottom talent is fine")
	_expect(t.milestones() == ["deep_wounds"], "milestone at 5 arms points")
	var stats := t.stats()
	_expect(is_equal_approx(stats.damage, 0.07) and is_equal_approx(stats.crit, 0.04), "stats sum ranks x effects")
	t.use_loadout(1)
	_expect(t.spent() == 0 and t.available() == 9, "loadouts are separate")
	t.use_loadout(0)
	var copy := TalentTiers.new(_talent_defs(), {"xp_curve": {"base": 10, "growth": 1.0}})
	copy.from_dict(JSON.parse_string(JSON.stringify(t.to_dict())))
	_expect(copy.rank("a1") == 5 and copy.rank("a2") == 2 and copy.points_earned == 9, "talents restore")
	t.reset()
	_expect(t.spent() == 0, "reset is free")


func _zones() -> Array:
	return [
		{"id": "forest", "tier": 0, "bosses": [
			{"id": "hogger", "at": 180, "chance": 1.0, "item": {"id": "helm", "slot": "head", "stats": {"hp": 20}}},
			{"id": "fangmother", "at": 360, "chance": 0.0, "item": {"id": "pauldrons", "slot": "shoulder", "stats": {"armor": 5}}},
			{"id": "vancleef", "at": 960, "final": true, "chance": 1.0, "item": {"id": "sword", "slot": "main_hand", "stats": {"damage": 0.05}}}]},
		{"id": "duskwood", "tier": 1, "bosses": [
			{"id": "stitches", "at": 180, "chance": 1.0, "item": {"id": "helm2", "slot": "head", "stats": {"hp": 40}}}]},
	]


func _test_ledger() -> void:
	var l := LootLedger.new(_zones())
	_expect(l.is_unlocked("forest") and not l.is_unlocked("duskwood"), "first zone open")
	var rng := _rng()
	var helm := l.roll_drop("forest", "hogger", rng)
	_expect(helm.id == "helm" and helm.tier == 0, "sure drop")
	_expect(l.roll_drop("forest", "fangmother", rng).is_empty(), "zero chance misses")
	_expect(not l.roll_drop("forest", "fangmother", rng, 1.0).is_empty(), "luck adds to the chance")
	_expect(l.collect("helm") and l.owns("helm") and not l.collect("helm"), "collect once")
	_expect(l.roll_drop("forest", "hogger", rng).is_empty(), "owned items do not drop again")
	_expect(l.worn() == {"head": "helm"} and l.worn_stats() == {"hp": 20.0}, "first item in a slot is worn")
	_expect(l.wanted().map(func(i: Dictionary) -> String: return i.id) == ["pauldrons", "sword"], "wanted: unlocked zones, boss order")
	_expect(l.defeat_final("forest") == "duskwood" and l.is_unlocked("duskwood"), "final boss opens the next zone")
	_expect(l.defeat_final("forest") == "", "opening twice does nothing")
	l.collect("helm2")
	_expect(l.worn().head == "helm" and l.wear("helm2") and is_equal_approx(l.worn_stats().hp, 40.0), "wear swaps the slot")
	_expect(l.progress() == Vector2i(2, 4) and l.progress(1) == Vector2i(1, 1), "progress overall and per tier")
	var copy := LootLedger.new(_zones())
	copy.from_dict(JSON.parse_string(JSON.stringify(l.to_dict())))
	_expect(copy.unlocked == 2 and copy.owns("helm2") and copy.worn().head == "helm2", "ledger restores")


func _test_chests() -> void:
	var pool: Array[Dictionary] = [{"id": "potion", "weight": 3.0}, {"id": "tome", "weight": 1.0, "max": 2}]
	var shop := ChestShop.new(pool, _rng(), {"base": 20, "growth": 1.5})
	_expect([shop.price(0), shop.price(1), shop.price(2), shop.price(3)] == [20, 30, 45, 68], "price grows by growth")
	_expect(ChestShop.new(pool, _rng(), {"base": 10, "growth": 1.0, "step": 5}).price(3) == 25, "step adds a flat amount")
	_expect(ChestShop.new(pool, _rng(), {"base": 20, "growth": 2.0, "max_price": 100}).price(5) == 100, "max_price caps")
	var poor := shop.open(19)
	_expect(not poor.ok and poor.gold == 19 and shop.opened == 0 and shop.price() == 20, "not enough gold changes nothing")
	var r := shop.open(100)
	_expect(r.ok and r.spent == 20 and r.gold == 80 and shop.opened == 1 and shop.price() == 30, "open spends and raises the price")
	var counts := {"potion": 0, "tome": 0}
	var many := ChestShop.new(pool, _rng(11), {"base": 0, "growth": 1.0})
	for i in 400:
		var got := many.open(0)
		counts[got.reward.id] += 1
	_expect(counts.tome == 2 and counts.potion == 398, "per-run max limits a reward (%s)" % [counts])
	var only_capped: Array[Dictionary] = [{"id": "tome", "max": 1}]
	var capped := ChestShop.new(only_capped, _rng(), {"base": 0, "growth": 1.0})
	_expect(capped.open(0).ok and not capped.can_open(999) and not capped.open(999).ok, "empty pool cannot be opened")
	capped.reset()
	_expect(capped.opened == 0 and capped.open(0).ok, "reset starts a new run")
	var a := ChestShop.new(pool, _rng(5), {"base": 0, "growth": 1.0})
	a.open(0)
	a.open(0)
	var b := ChestShop.new(pool, _rng(99), {"base": 0, "growth": 1.0})
	b.from_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
	for i in 10:
		_expect(a.open(0).reward.id == b.open(0).reward.id, "restored shop continues identically %d" % i)
