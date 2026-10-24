extends "res://addons/proto_kit/test_kit.gd"
## Domain rules of the field battle (domain/battle.gd), headless and deterministic.
## Run: prototypes/godot-kit/tools/run_tests.sh skybound-blades battle

const Tuning = preload("res://domain/tuning.gd")
const Battle = preload("res://domain/battle.gd")
const Stepper = preload("res://domain/stepper.gd")

var tuning: Tuning


func _init() -> void:
	tuning = Tuning.load_default()
	test_battle_tuning_stats()
	test_battle_fps_independence()
	test_battle_head_on_obstacle()
	test_battle_enclosed_goal_reports_blocked()
	test_battle_manual_attack_kills_and_rewards()
	test_battle_companions_fight_without_auto()
	test_battle_bandage()
	test_battle_potion_priority()
	test_battle_level_up()
	test_battle_leader_down_ends_run()
	test_battle_quest_claim()
	test_battle_auto_retaliates()
	test_battle_skill()
	test_battle_swing_interval_keeps_remainder()
	test_battle_leash_returns_and_heals()
	test_battle_simultaneous_blows_both_land()
	test_battle_skill_keeps_a_locked_far_target()
	test_battle_companion_skips_unreachable_threat()
	test_battle_tonic_refusal_reasons()
	test_battle_camp_is_safe()
	test_battle_retreat_returns_party_after_delay()
	test_battle_auto_retreat_at_low_hp()
	test_battle_boss_telegraphs_before_impact()
	test_battle_boss_area_can_be_dodged()
	test_battle_guardian_cover_reduces_charged_blow()
	test_battle_boss_kill_opens_main_quest()
	_finish("BATTLE")


func _battle(monsters: Array = [], obstacles: Array = [], seed: int = 7, camp: Dictionary = {}) -> Battle:
	return Battle.new(tuning, {"seed": seed, "bounds": Rect2(-15, -10, 30, 20), "obstacles": obstacles,
		"party_spawn": Vector2(-8, 0), "monsters": monsters, "camp": camp})


const CAMP := {"pos": Vector2(-12, 0), "radius": 2.5}


func _run(b: Battle, seconds: float, until: Callable = Callable()) -> void:
	for i in int(seconds * 1000.0 / b.dt_ms):
		b.step()
		if until.is_valid() and until.call():
			return


func _events(b: Battle, type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in b.drain_events():
		if e.type == type:
			out.append(e)
	return out


func test_battle_tuning_stats() -> void:
	var lead: Dictionary = tuning.member_stats("leader", 1)
	_expect(is_equal_approx(lead.attack, 20.0), "stats: leader L1 attack 14+6 sword")
	_expect(is_equal_approx(lead.max_hp, 135.0), "stats: leader L1 HP 120+15 coat")
	_expect(is_equal_approx(lead.attack_ms, 2000.0 / 1.12), "stats: leader swing interval from AGI 12")
	var guard: Dictionary = tuning.member_stats("guardian", 1)
	_expect(guard.shield and guard.style == "mace" and is_equal_approx(guard.block_chance, 0.1),
		"stats: guardian mace + shield, no speed penalty")
	_expect(tuning.xp_needed(1) == 200 and tuning.xp_needed(4) == 2426, "stats: EXP curve")


## Same command script, three frame rates: identical outcome.
func test_battle_fps_independence() -> void:
	var results: Array[String] = []
	for fps: float in [30.0, 60.0, 144.0]:
		var b := _battle(_pack(), [], 11)
		var stepper := Stepper.new(tuning.step_ms())
		b.command({"type": "auto", "on": true})
		var frames := int(90.0 * fps)
		for f in frames:
			for i in stepper.advance(1.0 / fps):
				b.step()
		results.append("%d|%d|%.3f|%.3f|%d" % [b.kills, b.level, b.experience, b.leader.hp, int(b.now_ms)])
	_expect(results[0] == results[1] and results[1] == results[2], "fps: same result at 30/60/144 %s" % [results])
	_expect(results[0].split("|")[0].to_int() >= 3, "fps: auto hunt actually kills (%s)" % results[0])


func _pack() -> Array:
	return [{"id": "meadow_slime", "pos": Vector2(-3, 0)}, {"id": "meadow_slime", "pos": Vector2(-2, 3)},
		{"id": "briar_boar", "pos": Vector2(2, -2)}, {"id": "ruin_hound", "pos": Vector2(5, 2)}]


func test_battle_head_on_obstacle() -> void:
	var b := _battle([], [{"pos": Vector2(-4, 0), "radius": 1.0}])
	b.leader.pos = Vector2(-7, 0)
	b.command({"type": "move", "pos": Vector2(-1, 0)})
	_run(b, 5.0, func() -> bool: return b.leader.order == 0)
	_expect(b.leader.pos.distance_to(Vector2(-1, 0)) < 0.2, "D1: walks around a rock dead ahead (at %s)" % b.leader.pos)
	_expect(_events(b, "arrived").size() == 1, "D1: arrival reported once")


func test_battle_enclosed_goal_reports_blocked() -> void:
	var ring: Array = []
	for i in 14:
		ring.append({"pos": Vector2(3, 0) + Vector2.RIGHT.rotated(TAU * i / 14.0) * 2.2, "radius": 0.8})
	var b := _battle([], ring)
	b.command({"type": "move", "pos": Vector2(3, 0)})
	_run(b, 12.0, func() -> bool: return b.leader.order == 0)
	_expect(b.leader.order == 0, "stuck: an unreachable move order is dropped")
	_expect(_events(b, "blocked").size() == 1, "stuck: blocked event tells the player")


func test_battle_manual_attack_kills_and_rewards() -> void:
	var b := _battle([{"id": "meadow_slime", "pos": Vector2(-4, 0)}])
	var slime: int = b.monsters()[0].id
	b.command({"type": "attack", "target": slime})
	_run(b, 20.0, func() -> bool: return b.kills > 0)
	_expect(b.kills == 1, "manual: clicking an enemy chases and kills it with auto off")
	_expect(not b.auto_hunt, "manual: auto stays off")
	var rewards := _events(b, "reward")
	_expect(rewards.size() == 1 and is_equal_approx(rewards[0].exp, 18.0), "manual: one reward, 18 EXP")
	_expect(b.gold == 3 and is_equal_approx(b.experience, 18.0), "manual: gold and EXP banked")
	_expect(b.run.quests[b.tracked_quest].progress == 1, "manual: slime counts toward the hunt quest")


func test_battle_companions_fight_without_auto() -> void:
	var b := _battle([{"id": "briar_boar", "pos": Vector2(-6, 0)}])
	var boar: Battle.Unit = b.monsters()[0]
	var hit_by: Dictionary = {}
	for i in 200:
		b.step()
		for e: Dictionary in b.drain_events():
			if e.type == "hit" and e.unit == boar.id:
				hit_by[e.source] = true
			if e.type == "taunt":
				hit_by["taunt"] = true
	_expect(hit_by.has(b.guardian.id), "companions: guardian fights with auto off")
	_expect(hit_by.has(b.support.id), "companions: support fights with auto off")
	_expect(hit_by.has("taunt"), "companions: guardian taunts the monster on the leader")


func test_battle_bandage() -> void:
	var b := _battle()
	b.auto_potion = false
	b.guardian.hp = b.guardian.max_hp * 0.3
	var before := int(b.inventory.bandage)
	_run(b, 2.0, func() -> bool: return int(b.inventory.bandage) < before)
	_expect(int(b.inventory.bandage) == before - 1, "bandage: support uses one bandage below 45%")
	_expect(b.guardian.hp_ratio() > 0.49, "bandage: heals 20% max HP")
	_run(b, 3.0)
	_expect(int(b.inventory.bandage) == before - 1, "bandage: 10 s cooldown")


func test_battle_potion_priority() -> void:
	var b := _battle()
	b.inventory.tonic_small = 1
	b.inventory.bandage = 0  # isolate potions: the support would otherwise bandage first
	b.leader.hp = b.leader.max_hp * 0.5
	b.guardian.hp = b.guardian.max_hp * 0.4
	b.step()
	_expect(b.guardian.hot_left_ms > 0.0 and b.leader.hot_left_ms <= 0.0, "potion: the neediest member gets the last tonic")
	_expect(int(b.inventory.tonic_small) == 0, "potion: stock never negative")
	b.guardian.hp = b.guardian.max_hp * 0.2
	var kits := int(b.inventory.emergency_kit)
	b.step()
	_expect(int(b.inventory.emergency_kit) == kits - 1, "potion: HOT running and below 30% → emergency kit")
	b.guardian.hp = b.guardian.max_hp * 0.2
	b.step()
	_expect(int(b.inventory.emergency_kit) == kits - 1, "potion: emergency kit has a cooldown and no stock left")


func test_battle_level_up() -> void:
	var b := _battle()
	b.leader.hp = 10.0
	var atk := b.leader.attack
	b._gain_exp(200.0 + 697.0 + 5.0)
	_expect(b.level == 3 and is_equal_approx(b.experience, 5.0), "level: multi-level gain keeps the remainder")
	_expect(b.leader.attack > atk and b.leader.hp == b.leader.max_hp, "level: stats rise and survivors heal")
	_expect(b.guardian.level == 3, "level: whole party shares the expedition level")


func test_battle_leader_down_ends_run() -> void:
	var b := _battle([{"id": "ruin_hound", "pos": Vector2(-7, 0)}])
	b.auto_potion = false
	b.leader.hp = 1.0
	b.guardian.alive = false
	b.support.alive = false
	_run(b, 10.0, func() -> bool: return b.ended)
	_expect(b.ended, "death: leader down ends the run")
	_expect(_events(b, "run_ended").size() == 1, "death: run_ended once")
	var t := b.now_ms
	b.step()
	_expect(b.now_ms == t, "death: the battle stops stepping")


func test_battle_quest_claim() -> void:
	var b := _battle([], [], 7, CAMP)
	b.command({"type": "claim"})
	b.step()
	_expect(_events(b, "refused").size() == 1, "quest: no claim outside camp")
	b.leader.pos = CAMP.pos
	b.run.quests[b.tracked_quest].progress = 5
	var gold := b.gold
	b.command({"type": "claim"})
	b.step()
	_expect(b.gold == gold + 30 and is_equal_approx(b.experience, 50.0), "quest: reward paid once")
	_expect(b.run.quests[b.tracked_quest].progress == 0 and not b.quest_ready(), "quest: resets and waits for the repeat cooldown")
	b.command({"type": "claim"})
	b.step()
	_expect(b.gold == gold + 30, "quest: double claim refused")


func test_battle_auto_retaliates() -> void:
	var b := _battle([{"id": "meadow_slime", "pos": Vector2(6, 0)}, {"id": "ruin_hound", "pos": Vector2(-8, 1.2)}])
	b.guardian.alive = false
	b.support.alive = false
	var far: Battle.Unit = b.monsters()[0]
	var near: Battle.Unit = b.monsters()[1]
	b.leader.target_id = far.id
	b.command({"type": "auto", "on": true})
	_run(b, 6.0, func() -> bool: return b.leader.target_id == near.id)
	_expect(b.leader.target_id == near.id, "auto: switches to the monster attacking the leader")


func test_battle_skill() -> void:
	var b := _battle([{"id": "stone_sentinel", "pos": Vector2(-7, 0)}])
	b.guardian.alive = false
	b.support.alive = false
	b.command({"type": "skill"})
	_run(b, 1.0)
	var hits := _events(b, "hit").filter(func(e: Dictionary) -> bool: return e.kind == "skill")
	_expect(hits.size() == 1, "skill: cleave lands once after its cast time")
	_expect(b.skill_ready_in_ms() > 4000.0, "skill: 6 s cooldown running")
	b.command({"type": "skill"})
	b.step()
	_expect(_events(b, "cast").is_empty(), "skill: no recast during cooldown")


func test_battle_swing_interval_keeps_remainder() -> void:
	var b := _battle([{"id": "ore_guardian", "pos": Vector2(-7, 0)}])
	b.guardian.alive = false
	b.support.alive = false
	b.auto_potion = false
	b.leader.max_hp = 1.0e6
	b.leader.hp = 1.0e6
	b.command({"type": "attack", "target": b.monsters()[0].id})
	var swings: Array[float] = []
	for i in 600:
		b.step()
		for e: Dictionary in b.drain_events():
			if e.type == "swing" and e.unit == b.leader.id:
				swings.append(e.t)
	var span := (swings[-1] - swings[0]) / (swings.size() - 1)
	_expect(absf(span - b.leader.attack_ms) < 30.0,
		"timing: average swing gap %.1f ms matches %.1f ms (no 50 ms rounding loss)" % [span, b.leader.attack_ms])


func test_battle_leash_returns_and_heals() -> void:
	var b := _battle([{"id": "briar_boar", "pos": Vector2(-8, -7)}])
	var boar: Battle.Unit = b.monsters()[0]
	boar.hp = 10.0
	boar.target_id = b.leader.id
	boar.pos = boar.spawn + Vector2(9.5, 0)
	b.leader.pos = boar.pos + Vector2(1, 0)
	b.step()
	_expect(boar.returning, "leash: chasing past 9 cells turns back")
	_run(b, 8.0, func() -> bool: return not boar.returning)
	_expect(not boar.returning and boar.hp == boar.max_hp, "leash: back home at full HP")


## R1: leader and monster kill each other on the same step: both fall, the run ends, no reward.
## Deterministic: two lethal blows queued for the same step, then landed together.
func test_battle_simultaneous_blows_both_land() -> void:
	var b := _battle([{"id": "ruin_hound", "pos": Vector2(-7, 0)}])
	var hound: Battle.Unit = b.monsters()[0]
	b.leader.hp = 5.0
	hound.hp = 5.0
	var exp_before := b.experience
	var gold_before := b.gold
	b._step_hits.append({"src": b.leader.id, "dst": hound.id, "amount": 50.0, "crit": false, "block": false, "kind": "attack"})
	b._step_hits.append({"src": hound.id, "dst": b.leader.id, "amount": 50.0, "crit": false, "block": false, "kind": "attack"})
	b._land_hits()
	_expect(not hound.alive and not b.leader.alive, "R1: both lethal blows land on the same snapshot")
	_expect(b.ended, "R1: the run ends")
	_expect(is_equal_approx(b.experience, exp_before) and b.gold == gold_before and b.kills == 0,
		"R1: a leader who falls that step earns nothing from it")


## R2: Q with a locked target out of reach keeps the target and refuses.
func test_battle_skill_keeps_a_locked_far_target() -> void:
	var b := _battle([{"id": "meadow_slime", "pos": Vector2(-3, 0)}, {"id": "meadow_slime", "pos": Vector2(-7.2, 0)}])
	var far: Battle.Unit = b.monsters()[0]
	b.leader.target_id = far.id
	b.leader.order = Battle.Unit.Order.ATTACK
	b.command({"type": "skill"})
	b.step()
	var refused := _events(b, "refused")
	_expect(b.leader.target_id == far.id or b.leader.target_id == -1 and false, "R2: the locked target stays")
	_expect(refused.size() == 1 and refused[0].reason == "too_far", "R2: refused as too far")
	_expect(b.skill_ready_in_ms() == 0.0, "R2: no cooldown spent")


## R3: a companion that cannot reach a threat skips it for the retry window.
func test_battle_companion_skips_unreachable_threat() -> void:
	var b := _battle([{"id": "briar_boar", "pos": Vector2(-8, -4)}])
	var boar: Battle.Unit = b.monsters()[0]
	boar.target_id = b.leader.id
	b.guardian.unreachable[boar.id] = b.now_ms + 5000.0
	_expect(b._companion_target(b.guardian) != boar, "R3: an unreachable threat is skipped")
	b.now_ms += 5001.0
	_expect(b._companion_target(b.guardian) == boar, "R3: and chosen again after the retry window")


## R6: the refusal says why.
func test_battle_tonic_refusal_reasons() -> void:
	var b := _battle()
	b.command({"type": "tonic"})
	b.step()
	var r := _events(b, "refused")
	_expect(r.size() == 1 and r[0].reason == "full", "R6: full HP is not 'no potions'")


func test_battle_camp_is_safe() -> void:
	var b := _battle([{"id": "ruin_hound", "pos": Vector2(-8, 0)}], [], 7, CAMP)
	var hound: Battle.Unit = b.monsters()[0]
	for m: Battle.Unit in b.party():
		m.pos = CAMP.pos + Vector2(0.3 * m.id, 0)
	var hurt := false
	for i in 200:
		b.step()
		for e: Dictionary in b.drain_events():
			if e.type == "hit" and b.unit(e.unit).team == 0:
				hurt = true
	_expect(not hurt, "camp: nobody inside the camp is hit")
	_expect(hound.pos.distance_to(CAMP.pos) >= float(CAMP.radius) - 0.01, "camp: monsters stay outside")


func test_battle_retreat_returns_party_after_delay() -> void:
	var b := _battle([], [], 7, CAMP)
	b.step()
	b.drain_events()
	b.run.record_kill(b.run.next_kill_id(), "meadow_slime", 1, b.rng, b.now_ms)
	b.command({"type": "retreat"})
	b.step()
	_expect(b.retreating() and not b.in_camp(b.leader), "retreat: takes time")
	_run(b, 1.9)
	_expect(b.retreating(), "retreat: still running before 2 s")
	_run(b, 0.3)
	_expect(not b.retreating() and b.in_camp(b.leader) and b.in_camp(b.guardian), "retreat: party in camp after 2 s")
	var returned := _events(b, "returned")
	_expect(returned.size() == 1 and int(returned[0].trip.kills) == 1, "retreat: trip summary on arrival")
	_expect(int(b.run.trip.kills) == 0, "retreat: the next trip starts empty")


func test_battle_auto_retreat_at_low_hp() -> void:
	var b := _battle([], [], 7, CAMP)
	b.auto_potion = false
	b.inventory.bandage = 0  # otherwise the support bandages the leader back above 25% first
	b.leader.hp = b.leader.max_hp * 0.2
	b.step()
	_expect(b.retreating(), "auto retreat: below 25% the party withdraws")


func _boss_battle() -> Battle:
	var b := _battle([{"id": "gatekeeper", "pos": Vector2(-5, 0)}], [], 7, CAMP)
	b.auto_potion = false
	b.auto_retreat = false
	for m: Battle.Unit in b.party():
		m.max_hp = 1.0e5
		m.hp = 1.0e5
	return b


func test_battle_boss_telegraphs_before_impact() -> void:
	var b := _boss_battle()
	var warned := {}
	var gaps: Array[float] = []
	for i in 400:
		b.step()
		for e: Dictionary in b.drain_events():
			if e.type == "telegraph":
				warned[e.move] = e.t
			if e.type == "boss_impact" and warned.has(e.move):
				gaps.append(e.t - warned[e.move])
	_expect(gaps.size() >= 2, "boss: both moves fire (%d impacts)" % gaps.size())
	_expect(gaps.all(func(g: float) -> bool: return g >= 1200.0), "boss: every impact is warned >= 1.2 s ahead %s" % [gaps])


func test_battle_boss_area_can_be_dodged() -> void:
	var b := _boss_battle()
	var boss: Battle.Unit = b.monsters()[0]
	var center := Vector2.INF
	for i in 400:
		b.step()
		for e: Dictionary in b.drain_events():
			if e.type == "telegraph" and e.move == "sweep":
				center = e.center
		if center != Vector2.INF:
			break
	# Everyone steps well outside the warned circle before it lands.
	for m: Battle.Unit in b.party():
		m.pos = center + Vector2(0, 6.5 + m.id * 0.5)
	var hit_party := false
	for i in 50:
		b.step()
		for e: Dictionary in b.drain_events():
			if e.type == "hit" and e.kind == "boss":
				hit_party = true
	_expect(not hit_party, "boss: leaving the warned circle dodges the sweep")


func test_battle_guardian_cover_reduces_charged_blow() -> void:
	var b := _boss_battle()
	var sweep_hits: Dictionary = {}
	var covered := false
	for i in 400:
		b.step()
		for e: Dictionary in b.drain_events():
			if e.type == "cover":
				covered = true
			if e.type == "hit" and e.kind == "boss":
				sweep_hits[e.unit] = e.amount
		if not sweep_hits.is_empty():
			break
	_expect(covered, "cover: the guardian covers on the charge")
	var boss: Battle.Unit = b.monsters()[0]
	var raw := boss.attack * 1.8 - b.leader.defense * 0.6
	if sweep_hits.has(b.leader.id):
		_expect(float(sweep_hits[b.leader.id]) < raw * 0.6, "cover: the leader takes a fraction of the sweep (%d vs ~%d)" % [sweep_hits[b.leader.id], raw])


func test_battle_boss_kill_opens_main_quest() -> void:
	var b := _boss_battle()
	var boss: Battle.Unit = b.monsters()[0]
	b._step_hits.append({"src": b.leader.id, "dst": boss.id, "amount": 1.0e6, "crit": false, "block": false, "kind": "attack"})
	b._land_hits()
	_expect(not boss.alive and b.run.quest_ready("seal_1", b.now_ms), "boss: first clear makes the main quest claimable")
	_expect(b.gold >= 90, "boss: pays its gold")
