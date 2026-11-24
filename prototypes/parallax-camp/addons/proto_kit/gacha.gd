extends RefCounted
## Gacha rolls with pity (保底) and a featured (限時) pick, on a random stream the game owns:
## `const Gacha = preload("res://addons/proto_kit/gacha.gd")`. Pure functions: the game keeps the pity counter,
## the pools and the stream (saved with its progress, so a reload does not reroll), and the rates it shows on its
## 機率說明 page are the same array it passes here.
##
##   var tier := Gacha.tier(rng, RATES, pity >= PITY)       # RATES = [55, 30, 12, 3]: N, R, SR, SSR in percent
##   pity = 0 if tier == RATES.size() - 1 else pity + 1
##   var hero := Gacha.pick(rng, pools[tier], featured if tier == RATES.size() - 1 else -1, 0.5)
##
## Use a RandomNumberGenerator of its own, never the global randf(): other systems drawing from the same stream
## would shift every pull, and fixed-seed tests and balance runs would move with them.
## Draw order per pull (keep it if you save rng.state): one randi_range for the tier (none when pity forces it),
## then for a featured tier one randf, then one randi_range for the pick unless the featured unit was drawn.


## A tier index for one pull: `weights` low to high (percents, or any whole-number weights); a forced pull
## (`pity_reached`) is the top tier without drawing.
static func tier(rng: RandomNumberGenerator, weights: Array, pity_reached: bool = false) -> int:
	var top: int = weights.size() - 1
	if pity_reached:
		return top
	var total: int = 0
	for w: int in weights:
		total += w
	var roll: int = rng.randi_range(1, total)
	var t: int = 0
	while t < top and roll > weights[t]:
		roll -= weights[t]
		t += 1
	return t


## One unit from `pool`. With `featured` >= 0 it comes `share` of the time, and otherwise one of the others, so the
## featured unit is exactly `share` of the tier (it is left out of the even draw). -1 when the pool is empty.
static func pick(rng: RandomNumberGenerator, pool: PackedInt32Array, featured: int = -1, share: float = 0.0) -> int:
	var choices: PackedInt32Array = pool
	if featured >= 0:
		if rng.randf() < share:
			return featured
		choices = PackedInt32Array(Array(pool).filter(func(unit: int) -> bool: return unit != featured))
	if choices.is_empty():
		return -1
	return choices[rng.randi_range(0, choices.size() - 1)]

