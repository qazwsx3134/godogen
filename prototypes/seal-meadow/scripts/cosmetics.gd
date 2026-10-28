extends RefCounted
## Presentation-only choices. Ownership comes from already claimed single-player achievements.

const OUTFITS := {
	"": {"name": "裝備原貌", "requires": ""},
	"meadow_tunic": {"name": "草原布衣", "requires": "first_quest",
		"sheet": "res://resources/sheets/test_chibi_tunic.tres"},
}
const AURAS := {
	"": {"name": "無光環", "requires": ""},
	"meadow_ring": {"name": "草原光環", "requires": "first_slime"},
}


static func known(outfit: String, aura: String) -> bool:
	return OUTFITS.has(outfit) and AURAS.has(aura)


static func allowed(outfit: String, aura: String, claimed: Array) -> bool:
	if not known(outfit, aura):
		return false
	for required: String in [OUTFITS[outfit].requires, AURAS[aura].requires]:
		if not required.is_empty() and required not in claimed:
			return false
	return true
