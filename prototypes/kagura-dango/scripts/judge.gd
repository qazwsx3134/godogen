class_name Judge
extends RefCounted
## Grades a tap by how far it is from the beat it answers, and turns the grades of a level into a score and a rank.
## Windows are seconds either side of the beat, wide enough for phone touch screens.

const ACE := 0.035
const GOOD := 0.075
const BARELY := 0.12
const POINTS := {&"ace": 100, &"good": 85, &"barely": 50, &"miss": 0}
## Points a hit adds to the match score (MatchState.score), shown counting up in the HUD.
const SCORE := {&"ace": 1000, &"good": 700, &"barely": 300}
const RANK_TEXT := {&"superb": "大胃王", &"ok": "吃飽了", &"again": "再來一盤"}


## &"ace", &"good" or &"barely"; &"" when the tap is too far from the beat to count as an answer to it.
static func grade(offset: float) -> StringName:
	var d := absf(offset)
	if d <= ACE:
		return &"ace"
	if d <= GOOD:
		return &"good"
	if d <= BARELY:
		return &"barely"
	return &""


## Average points of every cue (a missed cue is 0), rounded; 0 for an empty level.
static func score(grades: Array) -> int:
	if grades.is_empty():
		return 0
	var total := 0
	for g in grades:
		total += POINTS[g]
	return roundi(float(total) / grades.size())


static func rank(points: int) -> StringName:
	if points >= 80:
		return &"superb"
	if points >= 60:
		return &"ok"
	return &"again"


## 12345 → "12,345".
static func format_points(value: int) -> String:
	var digits := str(value)
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += ","
		out += digits[i]
	return out
