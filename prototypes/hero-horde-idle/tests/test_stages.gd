extends "res://addons/proto_kit/test_kit.gd"
## The 關卡 ladder (domain/stages.gd) with the growth loop: one round = push the next stage, take the rewards, 行軍
## 1 小時, 一鍵養成 (the test_progression round). Idle and good bots climb all COUNT stages; for each stage the round
## it first falls is measured:
##   every stage falls, each later than the one before (growth carries the player up the ladder)
##   no stage is a wall: at most MAX_GAP rounds from one stage to the next, for either bot
##   推薦戰力 is enough to clear without playing (idle), and good play clears below it
##   good stays ahead of idle all the way: at every stage at least 2 rounds sooner and at most 85% of idle's rounds
##   (good's lead grows up the ladder: it earns more per push and opens each stage's first-clear bonus sooner)
##   godot --headless --path prototypes/hero-horde-idle --script res://tests/test_stages.gd

const PushSim = preload("res://domain/push_sim.gd")
const PushBots = preload("res://tests/push_bots.gd")
const Progression = preload("res://domain/progression.gd")
const Stages = preload("res://domain/stages.gd")
const MAX_ROUNDS := 80
const MAX_GAP := 6
const SEED := 3


func _init() -> void:
	var idle: PackedInt32Array = _climb(PushBots.IDLE)
	var idle_power: PackedFloat32Array = _power
	var good: PackedInt32Array = _climb(PushBots.GOOD)
	var good_power: PackedFloat32Array = _power
	print("stage  idle  good   team_power at the clear: idle  good   recommended")
	for n: int in range(1, Stages.COUNT + 1):
		print("%-5s  %4d  %4d   %10.2f  %5.2f   %5.2f" % [Stages.label(n), idle[n], good[n], idle_power[n], good_power[n],
			Stages.recommended(n)])
	for curve: Array in [["idle", idle], ["good", good]]:
		var rounds: PackedInt32Array = curve[1]
		for n: int in range(1, Stages.COUNT + 1):
			_expect(rounds[n] > 0, "%s clears %s" % [curve[0], Stages.label(n)])
			if n > 1 and rounds[n] > 0 and rounds[n - 1] > 0:
				_expect(rounds[n] > rounds[n - 1] and rounds[n] - rounds[n - 1] <= MAX_GAP,
					"%s: %s falls 1-%d rounds after %s (%d -> %d)" % [curve[0], Stages.label(n), MAX_GAP,
					Stages.label(n - 1), rounds[n - 1], rounds[n]])
	for n: int in range(1, Stages.COUNT + 1):
		_expect(idle[n] - good[n] >= 2 and good[n] <= idle[n] * 0.85,
			"good is ahead of idle at %s (good %d, idle %d)" % [Stages.label(n), good[n], idle[n]])
	# 推薦戰力 (Stages.recommended): idle play clears at it, good play near or below it. Late on good clears a stage a
	# round, so the power it clears at holds a whole round's growth: up to x1.25.
	for n: int in range(1, Stages.COUNT + 1):
		_expect(idle_power[n] >= Stages.recommended(n) * 0.9 and good_power[n] <= Stages.recommended(n) * 1.25,
			"%s: 推薦 %.2f lies between good (%.2f) and idle (%.2f)" % [Stages.label(n), Stages.recommended(n),
			good_power[n], idle_power[n]])
	_finish("STAGE TESTS")


## The team power each stage first fell at, from the last _climb().
var _power := PackedFloat32Array()


## The round each stage first fell (index = stage, 0 = never).
func _climb(bot: Dictionary) -> PackedInt32Array:
	var p := Progression.new(SEED)
	_power = PackedFloat32Array()
	_power.resize(Stages.COUNT + 1)
	var first := PackedInt32Array()
	first.resize(Stages.COUNT + 1)
	for round: int in range(1, MAX_ROUNDS + 1):
		var n: int = p.next_stage()
		var opts: Dictionary = bot.duplicate()
		opts.roster = p.roster()
		opts.stage = Stages.stage(n)
		var sim: PushSim = PushBots.play(SEED * 1000 + round, opts).sim
		var got: Dictionary = p.push_rewards(sim, n)
		if got.first:
			first[n] = round
			_power[n] = p.team_power()
			if n == Stages.COUNT:
				break
		p.march_hour()
		p.auto_spend()
	return first
