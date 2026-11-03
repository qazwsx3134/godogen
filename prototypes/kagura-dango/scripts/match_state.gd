class_name MatchState
extends RefCounted
## One match (three rounds) across scenes: who ate how many skewers, the score added up from round 1 to round 3,
## each round's result. Static, so reset() at the start of every match (and every test); begin_round()/restore_round()
## let a round be replayed without counting its skewers or points twice.

static var eaten := {&"gintoki": 0, &"shinpachi": 0, &"kagura": 0}
static var score := 0
static var results: Array = []
static var _round_start := {}


static func reset() -> void:
	eaten = {&"gintoki": 0, &"shinpachi": 0, &"kagura": 0}
	score = 0
	results = []
	_round_start = {}


static func begin_round() -> void:
	_round_start = {eaten = eaten.duplicate(), score = score, results = results.size()}


static func restore_round() -> void:
	if _round_start.is_empty():
		return
	eaten = _round_start.eaten.duplicate()
	score = _round_start.score
	results.resize(_round_start.results)


## A hit's points (Judge.SCORE) go onto the match score; returns them.
static func add_points(grade: StringName) -> int:
	var points: int = Judge.SCORE.get(grade, 0)
	score += points
	return points


## Points scored since the current round began.
static func round_points() -> int:
	return score - int(_round_start.get("score", 0))


static func team_total() -> int:
	return eaten[&"gintoki"] + eaten[&"shinpachi"] + eaten[&"kagura"]


## 0 at the start, 1 after about 70 skewers: how round Kagura is.
static func kagura_fullness() -> float:
	return clampf(eaten[&"kagura"] / 70.0, 0.0, 1.0)


## Gintoki and Shinpachi give up after round 1: full (1.0) at 8 skewers, what round 1 feeds each of them.
static func fullness(who: StringName) -> float:
	if who == &"kagura":
		return kagura_fullness()
	return clampf(eaten[who] / 8.0, 0.0, 1.0)


## The match is won when the average round score is not the "again" rank.
static func won() -> bool:
	return Judge.rank(final_score()) != &"again"


static func final_score() -> int:
	if results.is_empty():
		return 0
	var total := 0
	for r in results:
		total += r.score
	return roundi(float(total) / results.size())
