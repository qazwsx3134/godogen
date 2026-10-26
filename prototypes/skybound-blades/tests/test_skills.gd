extends "res://addons/proto_kit/test_kit.gd"
## Skill chains (design/skill-links.md): learning, slots, the tag interface, seals, and chains in battle.
## Run: prototypes/godot-kit/tools/run_tests.sh prototypes/skybound-blades skills

const Tuning = preload("res://domain/tuning.gd")
const Run = preload("res://domain/run.gd")
const Battle = preload("res://domain/battle.gd")
const Skills = preload("res://domain/skills.gd")

var tuning: Tuning


func _init() -> void:
	tuning = Tuning.load_default()
	test_skills_start_with_cleave_in_slot_one()
	test_skills_learning_needs_level_and_previous_mastery()
	test_skills_mastery_rises_with_casts()
	test_skills_link_follows_the_interface()
	test_skills_link_needs_seals_and_mastery()
	test_skills_chain_length_capped()
	test_skills_unlink_does_not_refund()
	test_skills_equip_other_slots_keeps_the_chain()
	test_skills_seals_pay_once()
	test_skills_chain_fires_in_battle()
	test_skills_chain_breaks_on_cooldown()
	test_skills_mastery_only_on_hit()
	test_skills_save_round_trip()
	_finish("SKILLS")


## A run at `level` that knows cleave, rising and whirl at mastery 2, with `seals` seals.
func _ready_run(level: int = 9, seals: int = 2) -> Run:
	var r := Run.new(tuning, "s1")
	r.level = level
	r.learned.leader = {"cleave": {"level": 3, "exp": 0.0}, "rising": {"level": 2, "exp": 0.0}, "whirl": {"level": 2, "exp": 0.0}}
	r.seals = seals
	return r


func test_skills_start_with_cleave_in_slot_one() -> void:
	var r := Run.new(tuning, "s0")
	_expect(r.slots.leader == ["cleave"] and Skills.chain(r, "leader") == ["cleave"], "start: cleave in slot 1, chain of one")
	_expect(Skills.slot_count(tuning, 1) == 1 and Skills.slot_count(tuning, 10) == 2 and Skills.slot_count(tuning, 25) == 3,
		"start: slots open at Lv1/10/25")


func test_skills_learning_needs_level_and_previous_mastery() -> void:
	var r := Run.new(tuning, "s2")
	_expect(Skills.learn_block(tuning, r, "leader", "rising").contains("Lv.3"), "learn: rising needs Lv3")
	r.level = 3
	_expect(Skills.learn_block(tuning, r, "leader", "rising").contains("熟練 2"), "learn: rising needs cleave mastery 2")
	r.learned.leader.cleave.level = 2
	_expect(Skills.learn(tuning, r, "leader", "rising") == "" and Skills.mastery_level(r, "leader", "rising") == 1,
		"learn: learned at mastery 1")


func test_skills_mastery_rises_with_casts() -> void:
	var r := Run.new(tuning, "s3")
	var rose := 0
	for i in 20:
		rose = maxi(rose, Skills.add_mastery(tuning, r, "leader", "cleave"))
	_expect(rose == 2 and Skills.mastery_level(r, "leader", "cleave") == 2, "mastery: 20 casts x 5 = 100 = level 2")
	_expect(is_equal_approx(Skills.power_ratio(tuning, 2), 1.05) and is_equal_approx(Skills.cooldown_ratio(2), 0.98),
		"mastery: +5% power, -2% cooldown per level")


func test_skills_link_follows_the_interface() -> void:
	var r := _ready_run()
	_expect(Skills.link_block(tuning, r, "leader", "whirl").contains("需要「浮空」"),
		"link: whirl cannot follow cleave (needs launched, cleave leaves opening)")
	_expect(Skills.link(tuning, r, "leader", "rising") == "", "link: cleave -> rising")
	_expect(Skills.link(tuning, r, "leader", "whirl") == "", "link: rising -> whirl")
	_expect(Skills.chain(r, "leader") == ["cleave", "rising", "whirl"] and r.seals == 0, "link: chain of three, two seals spent")
	var r2 := _ready_run()
	r2.learned.leader.parry = {"level": 2, "exp": 0.0}
	_expect(Skills.link_block(tuning, r2, "leader", "parry").contains("起手招"), "link: a starter cannot follow")


func test_skills_link_needs_seals_and_mastery() -> void:
	var r := _ready_run(9, 0)
	_expect(Skills.link_block(tuning, r, "leader", "rising").contains("連攜印"), "link: no seal, no link")
	var r2 := _ready_run(9, 1)
	r2.learned.leader.rising.level = 1
	_expect(Skills.link_block(tuning, r2, "leader", "rising").contains("熟練度要 2"), "link: mastery 2 required")


func test_skills_chain_length_capped() -> void:
	var r := _ready_run(9, 5)
	Skills.link(tuning, r, "leader", "rising")
	Skills.link(tuning, r, "leader", "whirl")
	r.learned.leader["break"] = {"level": 2, "exp": 0.0}
	_expect(Skills.link_block(tuning, r, "leader", "break").contains("最多 3 招"), "cap: no fourth skill")


func test_skills_unlink_does_not_refund() -> void:
	var r := _ready_run(9, 1)
	Skills.link(tuning, r, "leader", "rising")
	_expect(Skills.unlink_last(tuning, r, "leader") == "" and Skills.chain(r, "leader") == ["cleave"] and r.seals == 0,
		"unlink: back to one skill, the seal is gone")
	_expect(Skills.equip_block(tuning, r, "leader", "rising", 0).contains("連招") == false, "unlink: slot 1 free to change again")


func test_skills_equip_other_slots_keeps_the_chain() -> void:
	# Arrange: Lv.10 (two slots), cleave in slot 1 with a paid rising link
	var r := _ready_run(10, 1)
	Skills.link(tuning, r, "leader", "rising")
	# Act / Assert
	_expect(Skills.equip(tuning, r, "leader", "whirl", 1) == "" and Skills.chain(r, "leader") == ["cleave", "rising"]
		and r.slots.leader == ["cleave", "whirl"], "equip: slot 2 changes without touching the chain (%s)" % [r.chains.leader])
	_expect(Skills.equip(tuning, r, "leader", "cleave", 1).contains("連招起手") and r.slots.leader[0] == "cleave",
		"equip: a linked head cannot move out of slot 1")
	Skills.unlink_last(tuning, r, "leader")
	_expect(Skills.equip(tuning, r, "leader", "whirl", 0) == "" and r.slots.leader == ["whirl"] and Skills.chain(r, "leader") == ["whirl"],
		"equip: an unlinked head can be replaced and the new skill heads the chain")


func test_skills_seals_pay_once() -> void:
	var r := Run.new(tuning, "s4")
	var rng := RandomNumberGenerator.new()
	var first := r.record_kill(r.next_kill_id(), "gatekeeper", 5, rng)
	var second := r.record_kill(r.next_kill_id(), "gatekeeper", 5, rng)
	_expect(int(first.seals) == 1 and int(second.get("seals", 0)) == 0 and r.seals == 1, "seals: first guardian kill per run only")
	r.quests.seal_1.progress = 1
	_expect(int(r.claim("seal_1", 0.0).seals) == 1 and r.seals == 2, "seals: the main quest pays one")


func _battle(r: Run, monster: String = "stone_sentinel") -> Battle:
	var b := Battle.new(tuning, {"seed": 4, "bounds": Rect2(-15, -10, 30, 20), "obstacles": [], "party_spawn": Vector2(-8, 0),
		"monsters": [{"id": monster, "pos": Vector2(-7, 0)}], "run": r})
	b.guardian.alive = false
	b.support.alive = false
	b.auto_potion = false
	b.auto_retreat = false
	b.leader.max_hp = 1.0e5
	b.leader.hp = 1.0e5
	b.leader.target_id = b.monsters()[0].id
	b.leader.order = Battle.Unit.Order.ATTACK
	_combat_hits_always(b)
	return b


func _combat_hits_always(b: Battle) -> void:
	b._combat = b._combat.duplicate()
	b._combat.base_hit = 0.99
	b._combat.min_hit = 0.99
	b._combat.max_hit = 0.99
	b.rng.seed = 12


func test_skills_chain_fires_in_battle() -> void:
	var r := _ready_run()
	Skills.link(tuning, r, "leader", "rising")
	Skills.link(tuning, r, "leader", "whirl")
	var b := _battle(r)
	b.command({"type": "skill"})
	var casts: Array = []
	for i in 80:
		b.step()
		for e: Dictionary in b.drain_events():
			if e.type == "cast":
				casts.append([e.skill, int(e.step)])
	_expect(casts.size() >= 3 and casts.slice(0, 3) == [["cleave", 0], ["rising", 1], ["whirl", 2]],
		"chain: cleave, rising, whirl fire in order (%s)" % [casts])
	_expect(b.leader.cooldowns.has("rising") and b.leader.cooldowns.has("whirl"), "chain: every step starts its own cooldown")


func test_skills_chain_breaks_on_cooldown() -> void:
	var r := _ready_run()
	Skills.link(tuning, r, "leader", "rising")
	var b := _battle(r)
	b.leader.cooldowns["rising"] = 1.0e9
	b.command({"type": "skill"})
	var reasons: Array = []
	for i in 40:
		b.step()
		for e: Dictionary in b.drain_events():
			if e.type == "chain_break":
				reasons.append(e.reason)
	_expect(reasons == ["cooldown"], "chain: a follow-up on cooldown breaks the chain with a reason (%s)" % [reasons])


func test_skills_mastery_only_on_hit() -> void:
	var r := _ready_run()
	var b := _battle(r)
	b._combat.base_hit = 0.0
	b._combat.min_hit = 0.0
	b._combat.max_hit = 0.0
	var before := float(r.learned.leader.cleave.exp)
	b.command({"type": "skill"})
	for i in 30:
		b.step()
	_expect(is_equal_approx(float(r.learned.leader.cleave.exp), before), "mastery: a missed cast pays nothing")
	var b2 := _battle(_ready_run())
	b2.command({"type": "skill"})
	for i in 30:
		b2.step()
	_expect(is_equal_approx(float(b2.run.learned.leader.cleave.exp), 5.0), "mastery: a landed cast pays 5 once")


func test_skills_save_round_trip() -> void:
	var r := _ready_run(9, 2)
	Skills.link(tuning, r, "leader", "rising")
	r.grant_seal("boss:gatekeeper", 1)
	var back: Run = Run.from_dict(tuning, JSON.parse_string(JSON.stringify(r.to_dict())))
	_expect(Skills.chain(back, "leader") == ["cleave", "rising"] and back.seals == r.seals
		and Skills.mastery_level(back, "leader", "whirl") == 2 and back.grant_seal("boss:gatekeeper", 1) == 0,
		"save: chain, seals, mastery and seal receipts survive a save")
