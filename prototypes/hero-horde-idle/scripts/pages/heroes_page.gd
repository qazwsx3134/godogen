extends Control
## 英雄 (scenes/pages/heroes.tscn, Taskbar Hero's monster.png page): the selected hero (portrait, level, attack, HP,
## power, their form's passive, class skill and 招牌技 or charm) with 突破, 上陣行軍 and 設為隊長, then the roster:
## one equipment_item_card per hero, filtered by form, sorted by rarity and level. The header line counts the 圖鑑
## (heroes 覺醒 by a first ascension) and its bonus; the bond line shows the march squad's 羈絆.

signal changed
signal open_tab(tab: StringName)
signal message(text: String)

const CARD := preload("res://scenes/components/equipment_item_card.tscn")
const Progression = preload("res://domain/progression.gd")
const PushSim = preload("res://domain/push_sim.gd")
const MarchSim = preload("res://domain/march_sim.gd")
const Heroes = preload("res://domain/heroes.gd")
const Items = preload("res://domain/items.gd")
const Portraits = preload("res://scripts/portraits.gd")
const UiArt = preload("res://scripts/ui_art.gd")
const Names = preload("res://domain/push_report.gd")

## Each class's 主動技能 (SR and up) and R passive, in a line.
const SKILLS := ["守護：本團受到的傷害減半 5 秒", "爆發：對王一次重擊", "爆發：對王一次重擊", "爆發：遠程重擊", "爆發：法術重擊",
	"群療：治療身邊所有人"]
const PASSIVES := ["生命 +15%", "攻擊 +15%", "攻擊 +15%", "攻擊 +15%", "攻擊 +15%", "治療 +15%"]

var progress: RefCounted = null
var selected: int = 13
## -1 = every form, else Heroes.HUMAN / MONSTER / DREAM.
var form_filter: int = -1
var names := PackedStringArray()
var _order: Array = []


func _ready() -> void:
	for k: int in %FormFilter.get_child_count():
		(%FormFilter.get_child(k) as Button).pressed.connect(func() -> void:
			form_filter = k - 1
			refresh())
	%AscendButton.pressed.connect(func() -> void:
		var cost: int = progress.ascend_cost(selected)
		if progress.ascend(selected):
			message.emit("%s 突破到 %d 階" % [_name(selected), progress.ascension[selected]])
			changed.emit()
		else:
			message.emit("已經突破到頂" if cost < 0 else "突破素材不夠（要 %d）" % cost))
	%MarchButton.pressed.connect(func() -> void:
		var marching: bool = progress.in_march(selected)
		if progress.toggle_march(selected):
			message.emit("%s %s" % [_name(selected), "下陣休息" if marching else "加入行軍小隊"])
			changed.emit()
		else:
			message.emit("小隊至少要留一人" if marching else "小隊滿了（%d 格）：先讓一名下陣，或在訓練頁練「結伴」" % progress.slots()))
	%CaptainButton.pressed.connect(func() -> void:
		if progress.toggle_captain(selected):
			changed.emit()
		else:
			message.emit("隊長最多 %d 名" % Progression.MAX_CAPTAINS))


func _name(i: int) -> String:
	return Names.hero_name(names, i)


func select(i: int) -> void:
	selected = i
	refresh()


func refresh() -> void:
	if progress == null:
		return
	if names.is_empty():
		names = Names.load_names()
	_detail()
	_roster()


func _detail() -> void:
	var i: int = selected
	var c: int = Progression.base_class(i)
	var f: int = Heroes.form(i)
	var r: int = progress.rarity(i)
	%DetailPortrait.texture = Portraits.hero_full(f, c)
	%PetName.text = _name(i)
	%PetLevel.text = "Lv.%d" % progress.hero_level[i]
	var need: int = Progression.EXP_PER_LEVEL * progress.hero_level[i]
	var capped: bool = progress.hero_level[i] >= progress.hero_cap(i)
	%PetExperience.max_value = need
	%PetExperience.value = need if capped else progress.hero_exp[i]
	%PetExperienceText.text = "上限 %d" % progress.hero_cap(i) if capped else "%d / %d" % [progress.hero_exp[i], need]
	var tags := PackedStringArray(["%s %s%s" % [PushSim.RARITY_NAMES[r], Heroes.FORM_NAMES[f], PushSim.CLASS_NAMES[c]],
		PushSim.SQUAD_NAMES[PushSim.CLASS_SQUAD[c]]])
	if progress.in_march(i):
		tags.append("行軍中")
	if progress.is_captain(i):
		tags.append("隊長")
	%PetStatus.text = "　".join(tags)
	var base: Vector2 = PushSim.base_stats(c, r)
	%Stat0.text = "攻擊　%d" % roundi(base.y * progress.atk_mult(i) * MarchSim.SCALE)
	%Stat1.text = "生命　%d" % roundi(base.x * progress.hp_mult(i) * MarchSim.SCALE)
	%Stat2.text = "突破　%d／%d" % [progress.ascension[i], Progression.MAX_ASCEND]
	%Skill0.text = "%s：%s" % [Heroes.PASSIVE_NAMES[f], Heroes.PASSIVE_TEXT[f]]
	%Skill0.tooltip_text = %Skill0.text
	if r >= PushSim.SR:
		%Skill1.text = SKILLS[c]
	elif r >= PushSim.R:
		%Skill1.text = "被動：" + PASSIVES[c]
	else:
		%Skill1.text = "N：突破兩次升 R"
	var sig: int = _signature(i)
	if sig >= 0:
		%Skill2.text = "招牌技：%s" % PushSim.SIG_NAMES[sig]
	elif not progress.charm[i].is_empty():
		%Skill2.text = "飾品：%s" % Items.item_name(progress.charm[i].id)
	else:
		%Skill2.text = "飾品：未裝備"
	var cost: int = progress.ascend_cost(i)
	%AscendButton.text = "突破（%d 素材）" % cost if cost > 0 else "已突破到頂"
	%AscendButton.disabled = cost < 0 or progress.shards < cost
	%MarchButton.text = "下陣" if progress.in_march(i) else "上陣行軍"
	%CaptainButton.text = "卸下隊長" if progress.is_captain(i) else "設為隊長"
	%CollectionCount.text = "覺醒 %d／100　全軍 +%.1f%%" % [progress.codex_count(), (progress.codex_mult() - 1.0) * 100.0]
	var bonds: Dictionary = progress.bonds()
	%BondLine.text = "行軍小隊 %d／%d　%s" % [progress.march.size(), progress.slots(),
		"、".join(bonds.lines) if not bonds.lines.is_empty() else "同形態 2 人以上有羈絆"]


## The 招牌技 of SSR i (-1 for none): PushSim gives every SSR its class's move in roster order.
func _signature(i: int) -> int:
	if Progression.base_rarity(i) != PushSim.SSR:
		return -1
	var c: int = Progression.base_class(i)
	var k: int = 0
	for j: int in i:
		if Progression.base_class(j) == c and Progression.base_rarity(j) == PushSim.SSR:
			k += 1
	return PushSim.CLASS_SIGS[c][mini(k, PushSim.CLASS_SIGS[c].size() - 1)]


func _roster() -> void:
	for k: int in %FormFilter.get_child_count():
		(%FormFilter.get_child(k) as Button).button_pressed = k - 1 == form_filter
	_order = range(Progression.HEROES).filter(func(i: int) -> bool: return form_filter < 0 or Heroes.form(i) == form_filter)
	_order.sort_custom(func(a: int, b: int) -> bool:
		if progress.in_march(a) != progress.in_march(b):
			return progress.in_march(a)
		if progress.rarity(a) != progress.rarity(b):
			return progress.rarity(a) > progress.rarity(b)
		if progress.hero_level[a] != progress.hero_level[b]:
			return progress.hero_level[a] > progress.hero_level[b]
		return a < b)
	var grid: GridContainer = %HeroGrid
	while grid.get_child_count() < _order.size():
		var card: Control = CARD.instantiate()
		grid.add_child(card)
		var index: int = grid.get_child_count() - 1
		(card.get_node("SelectButton") as Button).pressed.connect(func() -> void:
			if index < _order.size():
				select(_order[index]))
	for k: int in grid.get_child_count():
		var card: Control = grid.get_child(k)
		card.visible = k < _order.size()
		if not card.visible:
			continue
		var i: int = _order[k]
		var c: int = Progression.base_class(i)
		var icon: TextureRect = card.get_node("Icon")
		icon.texture = Portraits.hero_sprite(Heroes.form(i), c)
		icon.self_modulate = Portraits.tint(i, c)
		(card.get_node("Title") as Label).text = _name(i)
		(card.get_node("Level") as Label).text = "%s Lv%d" % [PushSim.RARITY_NAMES[progress.rarity(i)], progress.hero_level[i]]
		var tag: String = "行軍中" if progress.in_march(i) else ""
		if progress.is_captain(i):
			tag = "隊長" if tag == "" else tag + "・隊長"
		(card.get_node("EquippedBy") as Label).text = tag
		var frame: Control = card.get_node("Frame")
		frame.self_modulate = Color("ffd76a") if i == selected else UiArt.rarity_color(progress.rarity(i)).lerp(Color.WHITE, 0.5)
		card.modulate = Color.WHITE if progress.ascension[i] > 0 or progress.in_march(i) else Color(0.92, 0.92, 0.92)
