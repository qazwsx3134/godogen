extends Control
## 裝備 (scenes/pages/equipment.tscn, Taskbar Hero's equipment.png page). Top: the 職業武庫, one weapon slot per class
## (every hero of the class shares it) with its 強化 level, paid in 強化石. Middle: the 專屬飾品 of one march hero
## (picked from the squad). Bottom: the bag's pieces; 裝備 puts the selected one on: a weapon in its class's slot, a
## charm on the picked hero. The replaced piece goes back to the bag.

signal changed
signal open_tab(tab: StringName)
signal message(text: String)

const CARD := preload("res://scenes/components/equipment_bag_card.tscn")
const Progression = preload("res://domain/progression.gd")
const PushSim = preload("res://domain/push_sim.gd")
const Items = preload("res://domain/items.gd")
const Heroes = preload("res://domain/heroes.gd")
const Portraits = preload("res://scripts/portraits.gd")
const UiArt = preload("res://scripts/ui_art.gd")
const Names = preload("res://domain/push_report.gd")

enum Filter { ALL, WEAPON, CHARM }

var progress: RefCounted = null
var selected_class: int = 1
var holder_slot: int = 0
var selected_uid: int = -1
var filter: int = Filter.ALL
var names := PackedStringArray()
var _pieces: Array = []


func _ready() -> void:
	for c: int in %ArmoryGrid.get_child_count():
		(%ArmoryGrid.get_child(c) as Button).pressed.connect(func() -> void:
			selected_class = c
			refresh())
	for k: int in 5:
		(get_node("%%SquadPick%d" % k) as Button).pressed.connect(func() -> void:
			holder_slot = k
			refresh())
	for k: int in 3:
		(%EquipFilter.get_child(k) as Button).pressed.connect(func() -> void:
			filter = k
			refresh())
	%UpgradeArmoryButton.pressed.connect(func() -> void:
		var cost: int = progress.armory_cost(selected_class)
		if progress.upgrade_armory(selected_class):
			message.emit("%s職業武庫強化到 Lv%d" % [PushSim.CLASS_NAMES[selected_class], progress.armory_level[selected_class]])
			changed.emit()
		else:
			message.emit("先裝上武器" if cost < 0 and progress.armory[selected_class].is_empty() else "強化石不夠"))
	%EquipButton.pressed.connect(_equip)


func _holder() -> int:
	return progress.march[mini(holder_slot, progress.march.size() - 1)]


func _equip() -> void:
	var k: int = progress.bag_index(selected_uid)
	if k < 0:
		message.emit("先點選背包裡的一件裝備")
		return
	var item: Dictionary = progress.bag[k]
	var ok: bool
	if Items.is_weapon(item.id):
		ok = progress.equip_weapon(selected_uid)
		selected_class = Items.weapon_class(item.id)
	else:
		ok = progress.equip_charm(_holder(), selected_uid)
	if ok:
		message.emit("裝上 %s" % Items.item_name(item.id))
		selected_uid = -1
		changed.emit()


func refresh() -> void:
	if progress == null:
		return
	if names.is_empty():
		names = Names.load_names()
	_armory()
	_charm()
	_bag()


func _armory() -> void:
	for c: int in %ArmoryGrid.get_child_count():
		var b: Button = %ArmoryGrid.get_child(c)
		var w: Dictionary = progress.armory[c]
		b.text = "%s\n%s" % [PushSim.CLASS_NAMES[c], "未裝備" if w.is_empty() else "%s %s" % [Items.RARITY_NAMES[Items.rarity(w.id)],
			"Lv%d" % progress.armory_level[c]]]
		b.modulate = Color("fff1b8") if c == selected_class else Color.WHITE
	var item: Dictionary = progress.armory[selected_class]
	%ArmoryIcon.texture = UiArt.tex(UiArt.WEAPONS[selected_class]) if item.is_empty() else UiArt.item_icon(item.id)
	%ArmoryIcon.modulate = Color(1, 1, 1, 0.4) if item.is_empty() else Color.WHITE
	%ArmoryLevel.text = "強化 Lv%d" % progress.armory_level[selected_class]
	%ArmoryHeading.text = "%s職業武庫" % PushSim.CLASS_NAMES[selected_class]
	var lines: Array = _piece_lines(item, "這個職業還沒有武器")
	var cost: int = progress.armory_cost(selected_class)
	lines.resize(6)
	lines[4] = "強化 ×%.2f" % pow(Items.ARMORY_STEP, progress.armory_level[selected_class] - 1) if not item.is_empty() else ""
	lines[5] = ("強化：%d 強化石（有 %d）" % [cost, progress.stones]) if cost > 0 else ""
	for k: int in 6:
		(get_node("%%ArmoryLine%d" % k) as Label).text = str(lines[k]) if lines[k] != null else ""
	%UpgradeArmoryButton.disabled = cost < 0 or progress.stones < cost


func _charm() -> void:
	for k: int in 5:
		var pick: Button = get_node("%%SquadPick%d" % k)
		pick.visible = k < progress.march.size()
		if pick.visible:
			pick.text = Names.hero_name(names, progress.march[k])
			pick.modulate = Color("fff1b8") if k == holder_slot else Color.WHITE
	var i: int = _holder()
	var c: int = Progression.base_class(i)
	%CharmHolderPortrait.texture = Portraits.hero_full(Heroes.form(i), c)
	%CharmHolderLevel.text = "Lv.%d" % progress.hero_level[i]
	var item: Dictionary = progress.charm[i]
	%CharmSlot.text = "飾品\n%s" % ("未裝備" if item.is_empty() else Items.item_name(item.id))
	%CharmHeading.text = "%s 的專屬飾品" % Names.hero_name(names, i)
	var lines: Array = _piece_lines(item, "背包裡的飾品可以裝給他")
	lines.resize(6)
	for k: int in 6:
		(get_node("%%CharmLine%d" % k) as Label).text = str(lines[k]) if lines[k] != null else ""


## A piece's lines for a stats panel: name and rarity, effect, affixes.
func _piece_lines(item: Dictionary, empty: String) -> Array:
	if item.is_empty():
		return [empty]
	var out: Array = ["%s（%s）" % [Items.item_name(item.id), Items.RARITY_NAMES[Items.rarity(item.id)]], Items.effect_text(item.id)]
	out.append_array(Array(Items.affix_lines(item)))
	return out


func _bag() -> void:
	for k: int in 3:
		(%EquipFilter.get_child(k) as Button).modulate = Color.WHITE if k == filter else Color(1, 1, 1, 0.65)
	_pieces = progress.bag.filter(func(item: Dictionary) -> bool:
		return filter == Filter.ALL or Items.is_weapon(item.id) == (filter == Filter.WEAPON))
	_pieces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Items.score(a) > Items.score(b))
	var grid: GridContainer = %EquipGrid
	while grid.get_child_count() < _pieces.size():
		var card: Control = CARD.instantiate()
		grid.add_child(card)
		var index: int = grid.get_child_count() - 1
		(card.get_node("SelectButton") as Button).pressed.connect(func() -> void:
			if index < _pieces.size():
				selected_uid = _pieces[index].uid
				refresh())
	for k: int in grid.get_child_count():
		var card: Control = grid.get_child(k)
		card.visible = k < _pieces.size()
		if not card.visible:
			continue
		var item: Dictionary = _pieces[k]
		(card.get_node("Icon") as TextureRect).texture = UiArt.item_icon(item.id)
		(card.get_node("Title") as Label).text = Items.item_name(item.id)
		(card.get_node("Level") as Label).text = Items.RARITY_NAMES[Items.rarity(item.id)]
		var better: bool = item.uid == progress.better_weapon(Items.weapon_class(item.id)) if Items.is_weapon(item.id) \
			else Items.score(item) > Items.score(progress.charm[_holder()])
		(card.get_node("EquippedBy") as Label).text = "較好" if better else ""
		(card.get_node("Frame") as Control).self_modulate = Color("ffd76a") if item.uid == selected_uid \
			else UiArt.rarity_color(Items.rarity(item.id)).lerp(Color.WHITE, 0.5)
	%EquipEmpty.visible = _pieces.is_empty()
	var k: int = progress.bag_index(selected_uid)
	if k >= 0:
		var item: Dictionary = progress.bag[k]
		%SelectedItemInfo.text = "%s（%s）%s" % [Items.item_name(item.id), Items.RARITY_NAMES[Items.rarity(item.id)],
			Items.effect_text(item.id)]
		%SelectedItemCost.text = "　".join(Items.affix_lines(item))
	else:
		%SelectedItemInfo.text = "點選一件裝備"
		%SelectedItemCost.text = ""
	%EquipButton.disabled = k < 0
