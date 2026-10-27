extends RefCounted
## One foreground-only cast. Bait and reward are committed together at completion, never on cancellation.

const DURATION := 5.0
const BAIT := "fishing_bait"
const CATCHES := ["pond_fish", "jelly_gel"]

var active: bool = false
var ends_at: float = 0.0


func start(now: float, player: Node) -> String:
	if active:
		return "casting"
	if player.dead:
		return "dead"
	if player.bag.count(BAIT) < 1:
		return "bait"
	active = true
	ends_at = now + DURATION
	return ""


func cancel() -> bool:
	var was_active := active
	active = false
	return was_active


func remaining(now: float) -> float:
	return maxf(0.0, ends_at - now) if active else 0.0


## {} while waiting; otherwise {error, item}. A stopped or previously settled cast cannot award again.
func poll(now: float, player: Node, rng: RandomNumberGenerator) -> Dictionary:
	if not active or now < ends_at:
		return {}
	active = false
	if player.dead:
		return {"error": "interrupted", "item": ""}
	var trial = player.bag.duplicate_bag()
	if not trial.remove(BAIT, 1):
		return {"error": "bait", "item": ""}
	var item: String = CATCHES[0] if rng.randf() < 0.8 else CATCHES[1]
	if not trial.add(item, 1):
		return {"error": "bag_full", "item": ""}
	player.bag.slots = trial.slots
	return {"error": "", "item": item}
