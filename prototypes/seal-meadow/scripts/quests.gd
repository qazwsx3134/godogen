extends RefCounted
## The town quest chain and the player's place in it. One quest at a time, in order; each is accepted, worked on,
## then turned in once. turn_in() is all-or-nothing: it checks the collected items and the reward space first.
## goal types: kill (monster scene name, n), collect (item id, n; taken on turn-in), equip (item id worn).

const Items = preload("res://scripts/items.gd")

const CHAIN := [
	{"id": "q_slimes", "title": "草原的果凍", "text": "鎮外的蓬蓬果凍越來越多了，去打倒 5 隻。打一隻，整群都會撲過來——試試範圍揮砍。",
		"goal": {"type": "kill", "target": "slime", "n": 5}, "reward": {"gold": 60, "xp": 120}},
	{"id": "q_gel", "title": "凝膠收購", "text": "帶 5 個蓬蓬凝膠回來，我拿來修屋頂。",
		"goal": {"type": "collect", "target": "jelly_gel", "n": 5}, "reward": {"gold": 40, "items": {"apple": 3}}},
	{"id": "q_sword", "title": "像樣的武器", "text": "在我這裡買一把鐵劍並裝備上，再來找我。",
		"goal": {"type": "equip", "target": "iron_sword", "n": 1}, "reward": {"xp": 300}},
]

## Index into CHAIN of the current quest; CHAIN.size() = all done.
var index: int = 0
var accepted: bool = false
var progress: int = 0


func current() -> Dictionary:
	return CHAIN[index] if index < CHAIN.size() else {}


func on_kill(kind: String) -> void:
	var q := current()
	if accepted and not q.is_empty() and q.goal.type == "kill" and q.goal.target == kind:
		progress = mini(progress + 1, q.goal.n)


func accept() -> bool:
	if accepted or current().is_empty():
		return false
	accepted = true
	progress = 0
	return true


## How far along, counting live state for collect/equip goals.
func count(player: Node) -> int:
	var q := current()
	if q.is_empty() or not accepted:
		return 0
	match q.goal.type:
		"kill":
			return progress
		"collect":
			return mini(player.bag.count(q.goal.target), q.goal.n)
		"equip":
			return 1 if player.equipped.values().has(q.goal.target) else 0
	return 0


func done(player: Node) -> bool:
	var q := current()
	return accepted and not q.is_empty() and count(player) >= q.goal.n


## Returns "" on success, else why not: none, not_done, bag_full.
func turn_in(player: Node) -> String:
	if current().is_empty() or not accepted:
		return "none"
	if not done(player):
		return "not_done"
	var q := current()
	var trial = player.bag.duplicate_bag()
	if q.goal.type == "collect":
		trial.remove(q.goal.target, q.goal.n)
	for id: String in q.reward.get("items", {}):
		if not trial.add(id, q.reward.items[id]):
			return "bag_full"
	player.bag.slots = trial.slots
	player.gold += int(q.reward.get("gold", 0))
	index += 1
	accepted = false
	progress = 0
	# gain_xp emits stats_changed and can checkpoint immediately: the quest must already be complete.
	if q.reward.has("xp"):
		player.gain_xp(int(q.reward.xp), "任務「%s」" % q.title)
	return ""


func to_data() -> Dictionary:
	return {"index": index, "accepted": accepted, "progress": progress}


func load_data(data: Dictionary) -> void:
	index = clampi(int(data.get("index", 0)), 0, CHAIN.size())
	accepted = bool(data.get("accepted", false)) and index < CHAIN.size()
	progress = maxi(0, int(data.get("progress", 0)))
