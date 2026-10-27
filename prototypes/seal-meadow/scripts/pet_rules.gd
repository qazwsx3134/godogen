extends RefCounted
## The pet's tuning (D09: mobile-friendly). Hunger drains only in the meadow (paused in the village and while the
## app is in the background, because the tree is paused); an empty bar costs XP but the pet never dies or leaves.
## Seed egg, two foods, one evolution recipe with two outcomes.

const OPTIONS := {
	"egg": "seed", "foods": ["apple", "jelly_gel", "pond_fish"], "drain": 1.0 / 480.0, "can_run_away": false, "max_stage": 2,
	"types": {"": {"atk": 1}, "leaf": {"atk": 3, "hp": 10}, "thorn": {"atk": 5}},
}
const RECIPES := [
	{"materials": ["clover", "boar_tusk"], "chance": 0.9, "types": {"leaf": 3.0, "thorn": 1.0}, "rare": 0.05},
]
const TYPE_NAMES := {"": "蓬蓬幼苗", "leaf": "葉子精靈", "thorn": "荊棘精靈"}
