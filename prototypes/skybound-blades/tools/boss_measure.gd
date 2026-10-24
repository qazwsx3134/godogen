extends SceneTree
## Gatekeeper fight, party at the recommended level, leader auto-hunting, for each dodge_roles variant over N seeds.
##   godot --headless --path . -s res://tools/boss_measure.gd [-- <seeds> [<move power scale>]]
## Prints one row per variant: wins, leader downs, member downs, damage taken, supplies used, kill time.
const Tuning = preload("res://domain/tuning.gd")
const Battle = preload("res://domain/battle.gd")

const VARIANTS := [[], ["guardian", "support"], ["leader", "guardian", "support"], ["support"], ["leader", "support"]]


func fight(t: Tuning, seed: int) -> Dictionary:
	var boss_def: Dictionary = t.bosses["gatekeeper"]
	var b := Battle.new(t, {"seed": seed, "bounds": Rect2(-15, -10, 30, 20), "obstacles": [],
		"party_spawn": Vector2(-8, 0), "monsters": [{"id": "gatekeeper", "pos": Vector2(-5, 0)}],
		"camp": {"pos": Vector2(-14, 8), "radius": 1.0}})
	b.auto_retreat = false
	b.auto_hunt = true
	while b.level < int(boss_def.recommended_level):
		b._gain_exp(b.xp_needed())
	var boss: Battle.Unit = b.monsters()[0]
	var downs := 0
	for i in 4000:  # 200 s
		b.step()
		for e: Dictionary in b.drain_events():
			if e.type == "down" and b.unit(e.unit).team == 0:
				downs += 1
		if not boss.alive or b.ended:
			break
	var taken := 0.0
	for k: String in b.run.trip.taken:
		taken += float(b.run.trip.taken[k])
	var used := 0
	for k: String in b.run.trip.used:
		used += int(b.run.trip.used[k])
	return {"win": not boss.alive, "leader_down": b.ended, "downs": downs, "taken": taken, "used": used,
		"s": b.now_ms / 1000.0}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n: int = int(args[0]) if args.size() > 0 else 20
	var t := Tuning.load_default()
	var scale: float = float(args[1]) if args.size() > 1 else 1.0
	for move: Dictionary in t.bosses["gatekeeper"].moves:
		move.power = float(move.power) * scale
	print("move power x%.2f" % scale)
	print("roles | wins | leader down | member downs | avg taken | avg supplies | avg kill s")
	for roles: Array in VARIANTS:
		t.section("automation").dodge_roles = roles
		var sum := {"win": 0, "leader_down": 0, "downs": 0, "taken": 0.0, "used": 0, "s": 0.0}
		for seed in range(1, n + 1):
			var r := fight(t, seed)
			for k: String in sum:
				sum[k] += r[k] if typeof(r[k]) != TYPE_BOOL else int(r[k])
			if not r.win:
				sum.s -= r.s
		print("%s | %d/%d | %d | %d | %d | %.1f | %.1f" % ["+".join(roles) if not roles.is_empty() else "none",
			sum.win, n, sum.leader_down, sum.downs, sum.taken / n, float(sum.used) / n, sum.s / maxi(1, sum.win)])
	quit()
