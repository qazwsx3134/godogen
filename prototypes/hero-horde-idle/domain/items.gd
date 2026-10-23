extends RefCounted
## 道具: equipment, relics and materials as pure data (what a player holds is in progression.gd).
##   武器     職業武庫: one per class and rarity ("w<class>_<rarity>"); the class's equipped one makes every hero of
##            the class stronger (WEAPON_MULT), and its slot's level (強化, paid in 強化石) on top
##   飾品     專屬飾品: "c<k>"; one per hero (CHARM_MULT), only that hero
##   遺物     relics: shared passives, one star per first clear of a stage (and by chance on a won push), up to MAX_STARS
##   素材     突破素材 (shards) and 強化石 (stones)
## Drops (progression.gd roll_loot): a march hour may bring one item, a won push always does; the rarity table
## follows the region of the stage being pushed. Icons are placeholders cut from the round3 mockups
## (tools/crop_item_icons.py) until the items get their own art.

const RARITY_NAMES := ["N", "R", "SR", "SSR"]
## [class][rarity]: the class's weapon at each rarity.
const WEAPONS := [
	["木盾", "鐵盾", "守誓之盾", "不落壁壘"],
	["短劍", "鋼劍", "斷鋼長劍", "王者之劍"],
	["木槍", "鐵槍", "破甲長槍", "龍牙槍"],
	["短弓", "長弓", "穿雲弓", "星落長弓"],
	["木杖", "法杖", "星辰法杖", "隕星權杖"],
	["木聖徽", "銀聖徽", "黎明聖徽", "天光聖徽"],
]
const WEAPON_ICONS := ["w_shield", "w_sword", "w_spear", "w_bow", "w_staff", "w_holy"]
## Strength of the class while its weapon is equipped, by rarity.
const WEAPON_MULT := [1.05, 1.10, 1.18, 1.28]
## Each 強化 level of a class's slot (only with a weapon in it): x ARMORY_STEP more.
const ARMORY_STEP := 1.02
const ARMORY_MAX := 30
const CHARMS := [
	{"name": "狼牙項鍊", "rarity": 0, "icon": "c_tooth"},
	{"name": "葉形墜飾", "rarity": 0, "icon": "c_leaf"},
	{"name": "蒼玉銀戒", "rarity": 1, "icon": "c_blue_ring"},
	{"name": "赤結護符", "rarity": 1, "icon": "c_red_bow"},
	{"name": "暗紫戒指", "rarity": 2, "icon": "c_purple_ring"},
	{"name": "紅玉墜飾", "rarity": 2, "icon": "c_red_pendant"},
	{"name": "翡翠金戒", "rarity": 3, "icon": "c_gold_ring"},
]
const CHARM_MULT := [1.04, 1.08, 1.13, 1.20]
## Relic effects (progression.gd relic()): march_gold (march gold x (1 + v)), hp, atk (the whole roster's), exp
## (march EXP x (1 + v)); v is per star.
const RELICS := [
	{"name": "日輪聖印", "key": "march_gold", "per_star": 0.05, "text": "行軍金幣 +%d%%", "icon": "r_sun"},
	{"name": "霜晶護符", "key": "hp", "per_star": 0.03, "text": "全軍血量 +%d%%", "icon": "r_frost"},
	{"name": "炎心墜飾", "key": "atk", "per_star": 0.03, "text": "全軍攻擊 +%d%%", "icon": "r_flame"},
	{"name": "森語花冠", "key": "exp", "per_star": 0.10, "text": "行軍經驗 +%d%%", "icon": "r_leaf"},
]
const MAX_STARS := 5
## 分解: 強化石 back for one item, by rarity.
const SALVAGE := [1, 3, 8, 20]
## Rarity odds (N, R, SR, SSR) by region of the stage being pushed.
const LOOT_ODDS := [[70, 25, 5, 0], [45, 38, 15, 2], [25, 40, 28, 7]]
## A drop is a weapon this often (otherwise a charm).
const WEAPON_SHARE := 0.6
const ICON_DIR := "res://assets/ui/items/%s.png"


static func weapon_id(c: int, r: int) -> String:
	return "w%d_%d" % [c, r]


static func charm_id(k: int) -> String:
	return "c%d" % k


static func is_weapon(id: String) -> bool:
	return id.begins_with("w")


## The class of a weapon id.
static func weapon_class(id: String) -> int:
	return int(id.substr(1).get_slice("_", 0))


static func charm_index(id: String) -> int:
	return int(id.substr(1))


static func rarity(id: String) -> int:
	return int(id.get_slice("_", 1)) if is_weapon(id) else CHARMS[charm_index(id)].rarity


static func item_name(id: String) -> String:
	return WEAPONS[weapon_class(id)][rarity(id)] if is_weapon(id) else CHARMS[charm_index(id)].name


static func icon(id: String) -> Texture2D:
	return load(ICON_DIR % (WEAPON_ICONS[weapon_class(id)] if is_weapon(id) else CHARMS[charm_index(id)].icon))


static func relic_icon(k: int) -> Texture2D:
	return load(ICON_DIR % RELICS[k].icon)


static func material_icon(key: String) -> Texture2D:
	var file: String = {"shards": "m_shard", "stones": "m_stone", "tickets": "m_ticket", "gold": "m_gold"}[key]
	return load(ICON_DIR % file) if ResourceLoader.exists(ICON_DIR % file) else load(ICON_DIR % "m_stone")


## What an item does, in a line ("盾職業全員強度 +10%").
static func effect_text(id: String) -> String:
	if is_weapon(id):
		return "%s職業全員強度 +%d%%" % [["盾", "劍", "槍", "弓", "法", "補"][weapon_class(id)],
			roundi((WEAPON_MULT[rarity(id)] - 1.0) * 100.0)]
	return "這名英雄強度 +%d%%" % roundi((CHARM_MULT[rarity(id)] - 1.0) * 100.0)


static func relic_text(k: int, stars: int) -> String:
	return RELICS[k].text % roundi(RELICS[k].per_star * maxi(stars, 1) * 100.0)


## The 強化石, items and relic star in a reward (progression.gd claim_march / push_rewards), e.g.
## ["強化石 +6", "鋼劍（R）", "遺物 日輪聖印 ★+1"]; the same item twice shows as "×2".
static func drops_text(got: Dictionary) -> PackedStringArray:
	var parts := PackedStringArray()
	if got.get("stones", 0) > 0:
		parts.append("強化石 +%d" % got.stones)
	var counts: Dictionary = {}
	for id: String in got.get("items", []):
		counts[id] = counts.get(id, 0) + 1
	for id: String in counts:
		parts.append("%s（%s）%s" % [item_name(id), RARITY_NAMES[rarity(id)], " ×%d" % counts[id] if counts[id] > 1 else ""])
	if got.get("relic", -1) >= 0:
		parts.append("遺物 %s ★+1" % RELICS[got.relic].name)
	if got.get("tickets", 0) > 0:
		parts.append("招募券 +%d" % got.tickets)
	return parts
