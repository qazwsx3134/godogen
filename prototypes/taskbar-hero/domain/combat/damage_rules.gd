extends RefCounted

const BASE_DEFENSE: float = 100.0

static func mitigation(defense: float) -> float:
	return BASE_DEFENSE / (BASE_DEFENSE + maxf(defense, 0.0))

static func final_damage(attack: float, defense: float, skill_ratio: float = 1.0) -> int:
	var raw_damage: float = maxf(attack, 0.0) * maxf(skill_ratio, 0.0)
	return maxi(roundi(raw_damage * mitigation(defense)), 1)

static func attack_interval(attacks_per_second: float) -> float:
	return 1.0 / maxf(attacks_per_second, 0.1)
