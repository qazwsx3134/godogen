extends Control
## 英雄 (scenes/pages/heroes.tscn, Taskbar Hero's monster.png page). The page opens on the roster: one
## equipment_item_card per hero, filtered by race, sorted by rarity and level, with 一鍵裝備 (the bag's best pieces on
## everyone: progression.gd auto_equip). The header line counts the 圖鑑 (heroes 覺醒 by a first ascension) and its
## bonus; the bond line shows the march squad's 羈絆. Tapping a hero opens %HeroDetail over the page (the nav bar
## stays): portrait, name, Lv and tags; beside the portrait the two equipment slots (their class's 職業武庫 weapon,
## shared by the class, and their own 專屬飾品); attack, HP, 突破 and 數值明細 (%StatsPopup: progression.gd
## stat_factors); their race passive, class skill and 招牌技; then 突破 · 升級 · 上陣 · 隊長, the ones worth pressing
## now edged in gold. A slot opens %EquipPopup (the bag's pieces for it; pick one to compare, 裝備 puts it on, the worn
## one goes back to the bag; 強化武器 for the weapon). 升級 opens %LevelPopup (the EXP bar and the three 經驗藥水
## sizes: one bottle, or as many as the next level takes). Leaving the page closes all of it.

signal changed
signal open_tab(tab: StringName)
signal message(text: String)
const CARD := preload("res://scenes/components/equipment_item_card.tscn")
const BAG_CARD := preload("res://scenes/components/equipment_bag_card.tscn")
const CARD_STYLE := preload("res://ui/sao_card.tres")
const SELECTED := preload("res://ui/sao_selected.tres")
const PLAIN := preload("res://ui/sao_button.tres")
const ATTENTION := preload("res://ui/sao_attention.tres")
const INK := Color(0.30, 0.31, 0.29)
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
## -1 = every race, else Heroes.HUMAN / BEAST / ELF.
var form_filter: int = -1
## The slot %EquipPopup is open on: WEAPON or CHARM.
var slot: int = Slot.WEAPON
## The bag piece picked in %EquipPopup (its uid, -1 = none).
var picked: int = -1
var names := PackedStringArray()
var _order: Array = []
var _swaps: Array = []

enum Slot { WEAPON, CHARM }


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
			message.emit("小隊至少要留一人" if marching else "小隊滿了（%d 格）：先讓一名下陣，或在天賦頁點亮「結伴」" % progress.slots()))
	%AutoEquipButton.pressed.connect(func() -> void:
		var before: int = progress.bag.size()
		progress.auto_equip()
		var worn: int = before - progress.bag.size()
		message.emit("一鍵裝備：換上 %d 件" % worn if worn > 0 else "沒有更好的裝備可以換")
		if worn > 0:
			changed.emit())
	%CloseButton.pressed.connect(close_detail)
	%WeaponSlot.pressed.connect(_open_equip.bind(Slot.WEAPON))
	%CharmSlot.pressed.connect(_open_equip.bind(Slot.CHARM))
	%StatsButton.pressed.connect(func() -> void:
		%StatsPopup.visible = true
		_factors())
	%LevelButton.pressed.connect(func() -> void:
		%LevelPopup.visible = true
		_level())
	for pop: StringName in [&"StatsPopup", &"EquipPopup", &"LevelPopup"]:
		var popup: Control = get_node("%" + pop)
		var close := func() -> void:
			popup.visible = false
			refresh()
		get_node("%" + String(pop).replace("Popup", "Close")).pressed.connect(close)
		popup.get_node("Dim").gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed:
				close.call())
	%EquipConfirm.pressed.connect(_wear_picked)
	%UpgradeButton.pressed.connect(func() -> void:
		var c: int = Progression.base_class(selected)
		var cost: int = progress.armory_cost(c)
		if progress.upgrade_armory(c):
			message.emit("%s職業武庫強化到 Lv%d" % [PushSim.CLASS_NAMES[c], progress.armory_level[c]])
			changed.emit()
		else:
			message.emit("先裝上武器" if cost < 0 and progress.armory[c].is_empty() else "強化石不夠"))
	for k: int in Progression.POTIONS.size():
		get_node("%%UseOne%d" % k).pressed.connect(_drink.bind(k, false))
		get_node("%%UseLevel%d" % k).pressed.connect(_drink.bind(k, true))
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


## Opens the detail on hero i.
func open_detail(i: int) -> void:
	selected = i
	_close_popups()
	%HeroDetail.visible = true
	refresh()


func close_detail() -> void:
	_close_popups()
	%HeroDetail.visible = false
	refresh()


## The home screen calls this when another page opens: the 英雄 page always comes back on the roster.
func leave() -> void:
	_close_popups()
	%HeroDetail.visible = false


func _close_popups() -> void:
	for pop: String in ["StatsPopup", "EquipPopup", "LevelPopup"]:
		(get_node("%" + pop) as Control).visible = false


func refresh() -> void:
	if progress == null:
		return
	if names.is_empty():
		names = Names.load_names()
	_roster()
	if %HeroDetail.visible:
		_detail()
		_slots()
		if %StatsPopup.visible:
			_factors()
		if %EquipPopup.visible:
			_equip()
		if %LevelPopup.visible:
			_level()


func _detail() -> void:
	var i: int = selected
	var c: int = Progression.base_class(i)
	var f: int = Heroes.form(i)
	var r: int = progress.rarity(i)
	%DetailPortrait.texture = Portraits.hero_full(f, c)
	%PetName.text = _name(i)
	%PetLevel.text = "Lv.%d" % progress.hero_level[i]
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
	%AscendButton.text = "突破（%d）" % cost if cost > 0 else "已突破到頂"
	%AscendButton.disabled = cost < 0
	_attention(%AscendButton, cost > 0 and progress.shards >= cost)
	var capped: bool = progress.hero_level[i] >= progress.hero_cap(i)
	%LevelButton.text = "已達上限" if capped else "升級"
	_attention(%LevelButton, not capped and progress.potion_total() > 0)
	%MarchButton.text = "下陣" if progress.in_march(i) else "上陣"
	_attention(%MarchButton, not progress.in_march(i) and progress.march.size() < progress.slots())
	%CaptainButton.text = "卸下隊長" if progress.is_captain(i) else "設為隊長"
	_attention(%CaptainButton, progress.captains.is_empty() and not progress.is_captain(i))


## A button worth pressing now gets the gold edge; the rest stay plain.
func _attention(b: Button, on: bool) -> void:
	for state: StringName in [&"normal", &"hover"]:
		b.add_theme_stylebox_override(state, ATTENTION if on else PLAIN)
	for key: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		b.add_theme_color_override(key, INK)


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
	%CollectionCount.text = "覺醒 %d／100　全軍 +%.1f%%" % [progress.codex_count(), (progress.codex_mult() - 1.0) * 100.0]
	var bonds: Dictionary = progress.bonds()
	%BondLine.text = "行軍小隊 %d／%d　%s" % [progress.march.size(), progress.slots(),
		"、".join(bonds.lines) if not bonds.lines.is_empty() else "同種族 2 人以上有羈絆"]
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
				open_detail(_order[index]))
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
		_rarity_card(card, progress.rarity(i), i == selected and %HeroDetail.visible)
		card.modulate = Color.WHITE if progress.ascension[i] > 0 or progress.in_march(i) else Color(0.92, 0.92, 0.92)


## 數值明細: one label per source that changes anything (×1.00 sources are hidden).
func _factors() -> void:
	var lines := PackedStringArray()
	for f: Dictionary in progress.stat_factors(selected):
		if is_equal_approx(f.atk, 1.0) and is_equal_approx(f.hp, 1.0):
			continue
		if is_equal_approx(f.atk, f.hp):
			lines.append("%s ×%.2f" % [f.name, f.atk])
		elif is_equal_approx(f.hp, 1.0):
			lines.append("%s 攻×%.2f" % [f.name, f.atk])
		elif is_equal_approx(f.atk, 1.0):
			lines.append("%s 命×%.2f" % [f.name, f.hp])
		else:
			lines.append("%s 攻×%.2f 命×%.2f" % [f.name, f.atk, f.hp])
	var grid: GridContainer = %FactorGrid
	for k: int in grid.get_child_count():
		var l: Label = grid.get_child(k)
		l.visible = k < lines.size()
		l.text = lines[k] if l.visible else ""
		l.tooltip_text = l.text


## 裝備欄位 beside the portrait: the class's weapon (with its 強化 level) and the hero's charm.
func _slots() -> void:
	var c: int = Progression.base_class(selected)
	_fill_slot(%WeaponSlot, progress.armory[c], UiArt.tex(UiArt.WEAPONS[c]), "%s職業武器" % PushSim.CLASS_NAMES[c],
		"全體%s職業共用・強化 Lv%d" % [PushSim.CLASS_NAMES[c], progress.armory_level[c]])
	_fill_slot(%CharmSlot, progress.charm[selected], null, "專屬飾品", "只有%s能用" % _name(selected))


func _fill_slot(b: Button, item: Dictionary, empty_icon: Texture2D, kind: String, note: String) -> void:
	var icon: TextureRect = b.get_node("Icon")
	icon.texture = empty_icon if item.is_empty() else UiArt.item_icon(item.id)
	icon.modulate = Color(1, 1, 1, 0.35) if item.is_empty() else Color.WHITE
	(b.get_node("Title") as Label).text = "%s：未裝備（點一下換裝）" % kind if item.is_empty() else "%s（%s）" % [
		Items.item_name(item.id), Items.RARITY_NAMES[Items.rarity(item.id)]]
	(b.get_node("Note") as Label).text = note if item.is_empty() else "%s　%s" % [Items.effect_text(item.id), note]


func _open_equip(which: int) -> void:
	slot = which
	picked = -1
	%EquipPopup.visible = true
	_equip()


## %EquipPopup: the worn piece, the bag's pieces for the slot (best first), the comparison of the picked one.
func _equip() -> void:
	var c: int = Progression.base_class(selected)
	var weapon: bool = slot == Slot.WEAPON
	var worn: Dictionary = progress.armory[c] if weapon else progress.charm[selected]
	%EquipTitle.text = "更換%s職業武器" % PushSim.CLASS_NAMES[c] if weapon else "更換%s的飾品" % _name(selected)
	%CurrentIcon.texture = (UiArt.tex(UiArt.WEAPONS[c]) if weapon else null) if worn.is_empty() else UiArt.item_icon(worn.id)
	%CurrentIcon.modulate = Color(1, 1, 1, 0.35) if worn.is_empty() else Color.WHITE
	%CurrentName.text = "目前：未裝備" if worn.is_empty() else "目前：%s（%s）" % [Items.item_name(worn.id),
		Items.RARITY_NAMES[Items.rarity(worn.id)]]
	%CurrentText.text = "" if worn.is_empty() else _piece_text(worn)
	_swaps = progress.bag.filter(func(item: Dictionary) -> bool:
		return Items.is_weapon(item.id) and Items.weapon_class(item.id) == c if weapon else not Items.is_weapon(item.id))
	_swaps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Items.score(a) > Items.score(b))
	var grid: GridContainer = %CandidateGrid
	while grid.get_child_count() < _swaps.size():
		var card: Control = BAG_CARD.instantiate()
		grid.add_child(card)
		var index: int = grid.get_child_count() - 1
		(card.get_node("SelectButton") as Button).pressed.connect(func() -> void:
			if index < _swaps.size():
				picked = _swaps[index].uid
				_equip())
	var pick: Dictionary = {}
	for k: int in grid.get_child_count():
		var card: Control = grid.get_child(k)
		card.visible = k < _swaps.size()
		if not card.visible:
			continue
		var item: Dictionary = _swaps[k]
		if item.uid == picked:
			pick = item
		(card.get_node("Icon") as TextureRect).texture = UiArt.item_icon(item.id)
		(card.get_node("Title") as Label).text = Items.item_name(item.id)
		(card.get_node("Level") as Label).text = Items.RARITY_NAMES[Items.rarity(item.id)]
		(card.get_node("EquippedBy") as Label).text = "較好" if Items.score(item) > Items.score(worn) else ""
		_rarity_card(card, Items.rarity(item.id), item.uid == picked)
	%CandidateEmpty.visible = _swaps.is_empty()
	if pick.is_empty():
		%CompareText.text = "點上面的一件裝備，這裡會比較它和目前裝備的差別。" if not _swaps.is_empty() else ""
	else:
		var change: String = ""
		if not worn.is_empty() and Items.score(worn) > 0.0:
			var pct: float = (Items.score(pick) / Items.score(worn) - 1.0) * 100.0
			change = "　整體強度 %s%d%%" % ["+" if pct >= 0.0 else "", roundi(pct)]
		%CompareText.text = "換上：%s（%s）%s\n%s" % [Items.item_name(pick.id), Items.RARITY_NAMES[Items.rarity(pick.id)], change,
			_piece_text(pick)]
	%EquipConfirm.disabled = pick.is_empty()
	%UpgradeButton.visible = weapon
	var cost: int = progress.armory_cost(c)
	%UpgradeButton.text = "強化武器（%d／%d 強化石）" % [cost, progress.stones] if cost > 0 else \
		("先裝上武器才能強化" if worn.is_empty() else "武器已強化到頂")
	%UpgradeButton.disabled = cost < 0 or progress.stones < cost


## A piece's effect and affixes, in one line.
func _piece_text(item: Dictionary) -> String:
	var parts := PackedStringArray([Items.effect_text(item.id)])
	parts.append_array(Items.affix_lines(item))
	return "　".join(parts)


func _wear_picked() -> void:
	var k: int = progress.bag_index(picked)
	if k < 0:
		return
	var item: Dictionary = progress.bag[k]
	var ok: bool = progress.equip_weapon(item.uid) if slot == Slot.WEAPON else progress.equip_charm(selected, item.uid)
	if ok:
		picked = -1
		message.emit("裝上 %s" % Items.item_name(item.id))
		changed.emit()


## %LevelPopup: the hero's EXP towards the next level and the three potion sizes.
func _level() -> void:
	var i: int = selected
	var lv: int = progress.hero_level[i]
	var capped: bool = lv >= progress.hero_cap(i)
	var need: int = Progression.EXP_PER_LEVEL * lv
	%LevelLine.text = "%s　Lv.%d（上限 %d）" % [_name(i), lv, progress.hero_cap(i)]
	%ExpBar.max_value = need
	%ExpBar.value = need if capped else progress.hero_exp[i]
	%ExpText.text = "已達等級上限：先突破才能再升級" if capped else "經驗 %d / %d（還差 %d）" % [progress.hero_exp[i], need,
		need - progress.hero_exp[i]]
	for k: int in Progression.POTIONS.size():
		var held: int = progress.potions[k]
		(get_node("%%PotionIcon%d" % k) as TextureRect).texture = UiArt.potion_icon(k)
		(get_node("%%PotionName%d" % k) as Label).text = Progression.POTIONS[k].name
		(get_node("%%PotionInfo%d" % k) as Label).text = "+%d 經驗　有 %d 瓶" % [Progression.POTIONS[k].exp, held]
		for b: Button in [get_node("%%UseOne%d" % k), get_node("%%UseLevel%d" % k)]:
			b.disabled = held <= 0 or capped


## Drinks size k: one bottle, or (`to_level`) as many as the next level takes.
func _drink(k: int, to_level: bool) -> void:
	var i: int = selected
	var count: int = 1
	if to_level:
		var missing: int = Progression.EXP_PER_LEVEL * progress.hero_level[i] - progress.hero_exp[i]
		count = maxi(1, ceili(float(missing) / Progression.POTIONS[k].exp))
	var got: Dictionary = progress.use_potions(i, k, count)
	if got.used == 0:
		return
	message.emit("用了 %d 瓶%s%s" % [got.used, Progression.POTIONS[k].name,
		"，升到 Lv%d" % progress.hero_level[i] if got.levels > 0 else ""])
	changed.emit()


## A white card: its rarity on the left stripe and the rarity line's colour; gold-framed when chosen.
func _rarity_card(card: Control, rarity: int, chosen: bool) -> void:
	var color: Color = UiArt.rarity_color(rarity)
	(card.get_node("RarityBar") as ColorRect).color = color
	(card.get_node("Level") as Label).add_theme_color_override(&"font_color", color.darkened(0.15))
	(card.get_node("Frame") as Panel).add_theme_stylebox_override(&"panel", SELECTED if chosen else CARD_STYLE)
