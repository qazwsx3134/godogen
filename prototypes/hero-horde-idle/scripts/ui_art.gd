extends RefCounted
## The home screen's icons, all regions of the Taskbar Hero reference art (assets/atlas, AtlasTexture resources),
## mapped to this game's things: the classes' weapons, the charms, the relics, the materials, the 訓練 rows. Rarity
## colours for frames and names. Changing an icon is changing a path here.

const Items = preload("res://domain/items.gd")
const DIR := "res://assets/atlas/%s.tres"
const WEAPONS := ["shield", "item_5", "equipment_item_12", "equipment_item_1", "equipment_item_2", "equipment_item_13"]
const CHARMS := ["equipment_item_7", "equipment_item_10", "equipment_item_6", "equipment_item_11", "equipment_item_9",
	"equipment_item_8", "equipment_item_6"]
const RELICS := ["product_0", "product_1", "product_3", "item_6"]
const MATERIALS := {"gold": "item_2", "shards": "item_8", "stones": "item_7", "tickets": "shop_gem"}
## 經驗藥水 by size (progression.gd POTIONS).
const POTION_ICONS := ["item_0", "item_0", "product_3"]
const TALENTS := ["training_0", "training_1", "training_2", "training_3", "paw", "shop_coin", "shield", "equipment_item_1",
	"equipment_item_13", "gear", "gem", "portrait", "practice_dummy", "gift", "nav_0", "heart", "item_5", "item_3"]
const RARITY_COLORS := [Color("8a8170"), Color("3f7fbf"), Color("8e52c6"), Color("d08a16")]
const FORM_ICONS := ["portrait", "monster_1", "monster_2"]


static func tex(name: String) -> Texture2D:
	return load(DIR % name)


static func item_icon(id: String) -> Texture2D:
	if Items.is_weapon(id):
		return tex(WEAPONS[Items.weapon_class(id)])
	return tex(CHARMS[Items.charm_index(id)])


static func relic_icon(k: int) -> Texture2D:
	return tex(RELICS[k])


static func material_icon(key: String) -> Texture2D:
	return tex(MATERIALS[key])


static func potion_icon(k: int) -> Texture2D:
	return tex(POTION_ICONS[k])


static func talent_icon(k: int) -> Texture2D:
	return tex(TALENTS[k])


static func rarity_color(r: int) -> Color:
	return RARITY_COLORS[clampi(r, 0, 3)]
