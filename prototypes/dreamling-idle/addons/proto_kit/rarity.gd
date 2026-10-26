extends RefCounted
## Card rarity for upgrade drafts: roll a tier per offered card, and turn the tier into the card's bonus, so the same
## spell is worth more when it comes in a rarer color. Pairs with card_draft.gd (which card) and auto_caster.gd (what
## the bonus does). `const Rarity = preload("res://addons/proto_kit/rarity.gd")`
##
##   var tiers := Rarity.new()                         # five default tiers, or Rarity.new(my_tiers)
##   var tier := tiers.roll(rng, luck)                  # 0 common .. 4 legendary; luck 0.05 = a "keen eye" perk
##   book.learn(spell, tiers.bonus(tier, "new"))        # {"damage": 0.34} for an epic new spell
##   book.rank_up(id, tiers.bonus(tier, "upgrade", rng))  # damage, or cooldown, or extra targets at high tiers
##
## Tier fields: id, name, color, weight (draw weight), damage (bonus ratio), cooldown (reduction ratio), targets (+n,
## offered on upgrades from that tier up). Luck moves weight from the lowest tier to the higher ones in proportion.

const DEFAULT_TIERS: Array[Dictionary] = [
	{"id": "common", "name": "普通", "color": Color("d8d8d8"), "weight": 55.0, "damage": 0.10, "cooldown": 0.05, "targets": 0},
	{"id": "uncommon", "name": "優秀", "color": Color("1eff00"), "weight": 28.0, "damage": 0.18, "cooldown": 0.07, "targets": 0},
	{"id": "rare", "name": "精良", "color": Color("0070dd"), "weight": 11.0, "damage": 0.25, "cooldown": 0.12, "targets": 1},
	{"id": "epic", "name": "史詩", "color": Color("a335ee"), "weight": 4.5, "damage": 0.34, "cooldown": 0.17, "targets": 1},
	{"id": "legendary", "name": "傳說", "color": Color("ff8000"), "weight": 1.5, "damage": 0.45, "cooldown": 0.23, "targets": 2},
]

var tiers: Array[Dictionary]


func _init(custom: Array[Dictionary] = []) -> void:
	tiers = custom if not custom.is_empty() else DEFAULT_TIERS.duplicate(true)


func count() -> int:
	return tiers.size()


## Draw weights after luck: `luck` (0..1) of the lowest tier's weight is spread over the higher tiers by their weight.
func weights(luck: float = 0.0) -> Array[float]:
	var w: Array[float] = []
	for t in tiers:
		w.append(float(t.weight))
	var moved := w[0] * clampf(luck, 0.0, 1.0)
	var rest := 0.0
	for i in range(1, w.size()):
		rest += w[i]
	if rest > 0.0:
		w[0] -= moved
		for i in range(1, w.size()):
			w[i] += moved * w[i] / rest
	return w


func roll(rng: RandomNumberGenerator, luck: float = 0.0) -> int:
	var w := weights(luck)
	var total := 0.0
	for x in w:
		total += x
	var pick := rng.randf() * total
	for i in w.size():
		pick -= w[i]
		if pick < 0.0:
			return i
	return w.size() - 1


## The bonus a card of this tier gives. "new": damage only (a fresh spell). "upgrade": one of damage, cooldown or
## (when the tier offers targets) extra targets, picked with `rng`; without an rng, damage.
func bonus(tier: int, kind: String = "new", rng: RandomNumberGenerator = null) -> Dictionary:
	var t: Dictionary = tiers[clampi(tier, 0, tiers.size() - 1)]
	if kind != "upgrade" or rng == null:
		return {"damage": float(t.damage)}
	var options: Array[String] = ["damage", "cooldown"]
	if int(t.targets) > 0:
		options.append("targets")
	match options[rng.randi_range(0, options.size() - 1)]:
		"cooldown":
			return {"cooldown": float(t.cooldown)}
		"targets":
			return {"targets": int(t.targets), "cooldown": float(t.cooldown)}
	return {"damage": float(t.damage)}


## Rolls one tier for every offered card id: [{"id", "tier"}]. The draft decides which cards; this decides how good.
func roll_offer(ids: Array, rng: RandomNumberGenerator, luck: float = 0.0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in ids:
		out.append({"id": id, "tier": roll(rng, luck)})
	return out
