extends RefCounted
## Ordered floating-weight selection shared by rarity, chests, encounter rosters and refinement.
## No item IDs, currency, pity or eligibility rules: caller filters candidates and owns the RNG.
## weights: finite nonnegative int/float values with a finite positive sum.
## Invalid/empty/all-zero distributions return -1; sample_index does not consume RNG on rejection.
## Valid sample_index consumes exactly one randf(), preserving the strict `< 0` legacy selection.
## Keep order stable when replaying saves; do not replace integer gacha or inclusive card_draft draws.


static func sample_index(weights: Array, rng: RandomNumberGenerator) -> int:
	var total: float = _total(weights)
	if total <= 0.0 or rng == null:
		return -1
	return _select(weights, total, rng.randf())


## Pure deterministic variant; unit_sample in [0,1]. At exactly 1 the final index is returned
## (legacy endpoint fallback, including a trailing zero weight). No mutation or random draws.
static func index_at(weights: Array, unit_sample: float) -> int:
	if not is_finite(unit_sample) or unit_sample < 0.0 or unit_sample > 1.0:
		return -1
	var total: float = _total(weights)
	return _select(weights, total, unit_sample) if total > 0.0 else -1


static func _total(weights: Array) -> float:
	var total: float = 0.0
	for value: Variant in weights:
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
			return -1.0
		var weight: float = float(value)
		if not is_finite(weight) or weight < 0.0:
			return -1.0
		total += weight
	return total if is_finite(total) else -1.0


static func _select(weights: Array, total: float, unit_sample: float) -> int:
	var remaining: float = unit_sample * total
	for i: int in weights.size():
		remaining -= float(weights[i])
		if remaining < 0.0:
			return i
	return weights.size() - 1
