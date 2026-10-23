extends Control
## 道具 page (scenes/items.tscn, a page of scenes/home.tscn): gold and 強化石 with 一鍵裝備; three tabs:
##   裝備  the 職業武庫 (one slot per class: its weapon and 強化 level), the 專屬飾品 the 行軍小隊 wear (one slot per
##         march hero, with their picture: the author's pick, round3 A_items.png), then the bag (weapons and 專屬飾品
##         from bosses and the march, best first, 新 on the ones not seen yet)
##   遺物  the relics, lit with their stars once found
##   素材  突破素材, 強化石 and 招募券
## Tapping a cell shows it in the detail panel at the bottom with what can be done: 換上 / 強化 for an armory slot, 換上 for a march hero's charm,
## 裝備 (a weapon to its class, a charm to the first hero who has a worse one, progression.gd charm_order) and 分解 for
## an item. The 新 marks clear when the player leaves the page. Saved after every change. Layout lives in
## scenes/items.tscn (tools/build_items.gd); the cells are scenes/item_cell.tscn instances.

const PushSim = preload("res://domain/push_sim.gd")
const PushReport = preload("res://domain/push_report.gd")
const Progression = preload("res://domain/progression.gd")
const Items = preload("res://domain/items.gd")
const ItemCell = preload("res://scenes/item_cell.tscn")
const Portraits = preload("res://scripts/portraits.gd")
const TABS := [&"equip", &"relic", &"material"]

## Set before the page enters the tree to use other progress (tests); otherwise the App's.
var progress: RefCounted = null
## "" = the App's progress_path (the player's save), or Progression.SAVE_PATH without the App.
var save_path: String = ""
var tab: StringName = &"equip"
## The cell shown in the detail panel ({} = none): {kind: "armory", cls} / {kind: "charm", slot} (a march slot) /
## {kind: "item", id} / {kind: "relic", k} / {kind: "material", key}.
var selected: Dictionary = {}

var _names: PackedStringArray = PushReport.load_names()

@onready var _gold: Label = %Gold
@onready var _stones: Label = %Stones
@onready var _tabs: HBoxContainer = %Tabs
@onready var _armory: Control = %Armory
@onready var _armory_slots: HBoxContainer = %ArmorySlots
@onready var _charms: Control = %Charms
@onready var _charm_slots: HBoxContainer = %CharmSlots
@onready var _section: Label = %SectionTitle
@onready var _note: Label = %SectionNote
@onready var _cells: GridContainer = %Cells
@onready var _empty: Label = %Empty
@onready var _detail: Control = %Detail
@onready var _detail_cell: Button = %DetailCell
@onready var _detail_name: Label = %DetailName
@onready var _detail_kind: Label = %DetailKind
@onready var _detail_effect: Label = %DetailEffect
@onready var _detail_note: Label = %DetailNote
@onready var _main: Button = %DetailMain
@onready var _salvage: Button = %DetailSalvage
@onready var _toast: Label = %Toast


func _ready() -> void:
	if progress == null:
		var app: Node = get_node_or_null(^"/root/App")
		progress = app.progress() if app != null and save_path == "" else Progression.load_from(_save_path())
	for k: int in TABS.size():
		(_tabs.get_child(k) as Button).pressed.connect(show_tab.bind(TABS[k]))
	for c: int in _armory_slots.get_child_count():
		(_armory_slots.get_child(c) as Button).pressed.connect(select.bind({"kind": "armory", "cls": c}))
	for k: int in _charm_slots.get_child_count():
		(_charm_slots.get_child(k) as Button).pressed.connect(select.bind({"kind": "charm", "slot": k}))
	for child: Node in _cells.get_children():
		child.free()  # the editor preview cells
	_main.pressed.connect(_main_pressed)
	_salvage.pressed.connect(_salvage_pressed)
	%AutoEquip.pressed.connect(func() -> void:
		progress.auto_equip()
		_done("一鍵裝備：每個職業換上最好的武器，飾品給行軍小隊優先"))
	visibility_changed.connect(func() -> void:
		if not visible and not progress.fresh.is_empty():
			progress.fresh.clear()
			progress.save(_save_path()))
	_toast.text = ""
	show_tab(&"equip")


func show_tab(which: StringName) -> void:
	tab = which
	selected = {}
	refresh()


func select(what: Dictionary) -> void:
	selected = what
	if what.get("kind", "") == "item":
		var at: int = progress.fresh.find(what.id)
		if at >= 0:
			progress.fresh.remove_at(at)
	refresh()


func refresh() -> void:
	if progress == null:
		return
	_gold.text = "%d" % progress.gold
	_stones.text = "%d" % progress.stones
	for k: int in TABS.size():
		(_tabs.get_child(k) as Button).button_pressed = TABS[k] == tab
	_armory.visible = tab == &"equip"
	_charms.visible = tab == &"equip"
	var entries: Array = _entries()
	if selected.is_empty():
		selected = {"kind": "armory", "cls": 0} if tab == &"equip" else entries[0]
	for c: int in _armory_slots.get_child_count():
		_show_armory(_armory_slots.get_child(c), c)
	for k: int in _charm_slots.get_child_count():
		_show_charm(_charm_slots.get_child(k), k)
	while _cells.get_child_count() < entries.size():
		var cell: Button = ItemCell.instantiate()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_cells.add_child(cell)
		cell.pressed.connect(func() -> void: select(cell.entry))
	for k: int in _cells.get_child_count():
		var cell: Button = _cells.get_child(k)
		cell.visible = k < entries.size()
		if k < entries.size():
			_show_entry(cell, entries[k])
	_empty.visible = entries.is_empty()
	_section.text = {&"equip": "背包", &"relic": "遺物", &"material": "素材"}[tab]
	_note.text = {&"equip": "關卡王與行軍掉落", &"relic": "全隊共用，首次通關取得", &"material": "養成用"}[tab]
	_show_detail()


## The grid's cells on this tab, in order.
func _entries() -> Array:
	var out: Array = []
	if tab == &"equip":
		var ids: Array = progress.bag.keys()
		ids.sort_custom(func(a: String, b: String) -> bool:
			if Items.rarity(a) != Items.rarity(b):
				return Items.rarity(a) > Items.rarity(b)
			if Items.is_weapon(a) != Items.is_weapon(b):
				return Items.is_weapon(a)
			return a < b)
		for id: String in ids:
			out.append({"kind": "item", "id": id})
	elif tab == &"relic":
		for k: int in Items.RELICS.size():
			out.append({"kind": "relic", "k": k})
	else:
		out.append({"kind": "material", "key": "shards"})
		out.append({"kind": "material", "key": "stones"})
		out.append({"kind": "material", "key": "tickets"})
	return out


func _show_armory(cell: Button, c: int) -> void:
	var r: int = progress.armory[c]
	var icon: Texture2D = load(Items.ICON_DIR % Items.WEAPON_ICONS[c])
	cell.show_item({"kind": "armory", "cls": c}, icon, r, "Lv.%d" % progress.armory_level[c] if r >= 0 else "",
		PushSim.CLASS_NAMES[c])
	cell.button_pressed = selected.get("kind", "") == "armory" and selected.cls == c


## March slot k's hero and their charm (faded when they wear none).
func _show_charm(cell: Button, k: int) -> void:
	var i: int = progress.march[k]
	var worn: int = progress.charm[i]
	var icon: Texture2D = Items.icon(Items.charm_id(worn if worn >= 0 else 0))
	cell.show_item({"kind": "charm", "slot": k}, icon, Items.CHARMS[worn].rarity if worn >= 0 else -1, "",
		PushReport.hero_name(_names, i))
	var c: int = Progression.base_class(i)
	cell.show_face(Portraits.card(c), Portraits.tint(i, c), Portraits.material(progress.rarity(i)))
	cell.button_pressed = selected.get("kind", "") == "charm" and selected.slot == k


func _show_entry(cell: Button, what: Dictionary) -> void:
	match what.kind:
		"item":
			var n: int = progress.bag[what.id]
			cell.show_item(what, Items.icon(what.id), Items.rarity(what.id), "×%d" % n if n > 1 else "", "",
				progress.fresh.has(what.id))
		"relic":
			var stars: int = progress.relic_stars[what.k]
			cell.show_item(what, Items.relic_icon(what.k), 3 if stars > 0 else -1, "★%d" % stars if stars > 0 else "")
		"material":
			cell.show_item(what, Items.material_icon(what.key), {"shards": 2, "stones": 1, "tickets": 3}[what.key],
				"%d" % _material_count(what.key))
	cell.button_pressed = what == selected


func _show_detail() -> void:
	_detail.visible = not selected.is_empty()
	if selected.is_empty():
		return
	_main.visible = true
	_salvage.visible = false
	match selected.kind:
		"armory":
			var c: int = selected.cls
			var r: int = progress.armory[c]
			_show_armory(_detail_cell, c)
			_detail_name.text = Items.WEAPONS[c][r] if r >= 0 else "%s職業武庫" % PushSim.CLASS_NAMES[c]
			_detail_kind.text = "職業武庫　%s　Lv.%d" % [Items.RARITY_NAMES[r], progress.armory_level[c]] if r >= 0 \
				else "職業武庫　還沒有武器"
			_detail_effect.text = "%s職業全員強度 ×%.2f" % [PushSim.CLASS_NAMES[c], progress.weapon_mult(c)]
			_detail_note.text = "同職業英雄共用；強化等級換武器也會保留"
			var better: String = progress.better_weapon(c)
			if better != "":
				_main.text = "換上 %s" % Items.item_name(better)
				_main.disabled = false
			elif progress.armory_cost(c) > 0:
				_main.text = "強化　%d 強化石" % progress.armory_cost(c)
				_main.disabled = progress.stones < progress.armory_cost(c)
			else:
				_main.text = "強化已滿" if r >= 0 else "等武器掉落"
				_main.disabled = true
		"charm":
			var i: int = progress.march[selected.slot]
			var worn: int = progress.charm[i]
			_show_charm(_detail_cell, selected.slot)
			var who: String = PushReport.hero_name(_names, i)
			_detail_name.text = Items.CHARMS[worn].name if worn >= 0 else "%s 沒有飾品" % who
			_detail_kind.text = "專屬飾品　%s　配戴：%s" % [Items.RARITY_NAMES[Items.CHARMS[worn].rarity], who] \
				if worn >= 0 else "專屬飾品　行軍小隊"
			_detail_effect.text = Items.effect_text(Items.charm_id(worn)) if worn >= 0 else "飾品只加配戴的英雄"
			_detail_note.text = "行軍小隊才拿經驗，先給他們最好的飾品"
			var better: String = progress.better_charm(i)
			_main.text = "換上 %s" % Items.item_name(better) if better != "" else "沒有更好的飾品"
			_main.disabled = better == ""
		"item":
			var id: String = selected.id
			if not progress.bag.has(id):
				selected = {}
				_detail.visible = false
				return
			_show_entry(_detail_cell, selected)
			_detail_name.text = Items.item_name(id)
			_detail_effect.text = Items.effect_text(id)
			if Items.is_weapon(id):
				var c: int = Items.weapon_class(id)
				_detail_kind.text = "%s　%s職業武器　背包 ×%d" % [Items.RARITY_NAMES[Items.rarity(id)], PushSim.CLASS_NAMES[c],
					progress.bag[id]]
				var now: int = progress.armory[c]
				_detail_note.text = "目前裝備：%s" % (Items.WEAPONS[c][now] if now >= 0 else "無")
				_main.text = "裝備到%s武庫" % PushSim.CLASS_NAMES[c]
				_main.disabled = now == Items.rarity(id)
			else:
				_detail_kind.text = "%s　專屬飾品　背包 ×%d" % [Items.RARITY_NAMES[Items.rarity(id)], progress.bag[id]]
				var who: int = _charm_target(id)
				_detail_note.text = "每名英雄一格，只加那名英雄"
				_main.text = "給 %s" % PushReport.hero_name(_names, who) if who >= 0 else "沒有人需要"
				_main.disabled = who < 0
			_salvage.visible = true
			_salvage.text = "分解　+%d 強化石" % Items.SALVAGE[Items.rarity(id)]
		"relic":
			var k: int = selected.k
			var stars: int = progress.relic_stars[k]
			_show_entry(_detail_cell, selected)
			_detail_name.text = Items.RELICS[k].name
			_detail_kind.text = "遺物　★%d／%d" % [stars, Items.MAX_STARS]
			_detail_effect.text = Items.relic_text(k, stars) if stars > 0 else "每顆星：%s" % Items.relic_text(k, 1)
			_detail_note.text = "首次通關取得，之後打倒關卡王有機會升星"
			_main.visible = false
		"material":
			_show_entry(_detail_cell, selected)
			var key: String = selected.key
			_detail_name.text = {"shards": "突破素材", "stones": "強化石", "tickets": "招募券"}[key]
			_detail_kind.text = "素材　持有 %d" % _material_count(key)
			_detail_effect.text = {"shards": "英雄頁的突破用", "stones": "職業武庫強化用", "tickets": "招募用，一張單抽"}[key]
			_detail_note.text = {"shards": "打倒關卡王必掉，行軍有機會掉，招募到的英雄也會化為素材",
				"stones": "行軍、打倒關卡王與分解裝備取得", "tickets": "首次通關每關給一疊，也可以在商店買"}[key]
			_main.visible = false


## Who a charm would go to: the first hero (march squad first) whose charm is worse; -1 when nobody's is.
func _charm_target(id: String) -> int:
	for i: int in progress.charm_order():
		if progress.charm[i] < 0 or Items.CHARMS[progress.charm[i]].rarity < Items.rarity(id):
			return i
	return -1


func _material_count(key: String) -> int:
	return {"shards": progress.shards, "stones": progress.stones, "tickets": progress.tickets}[key]


func _main_pressed() -> void:
	match selected.get("kind", ""):
		"charm":
			var i: int = progress.march[selected.slot]
			var better: String = progress.better_charm(i)
			if better != "" and progress.equip_charm(i, better):
				_done("%s戴上了%s" % [PushReport.hero_name(_names, i), Items.item_name(better)])
		"armory":
			var c: int = selected.cls
			var better: String = progress.better_weapon(c)
			if better != "":
				if progress.equip_weapon(better):
					_done("%s職業武庫換上 %s" % [PushSim.CLASS_NAMES[c], Items.item_name(better)])
			elif progress.upgrade_armory(c):
				_done("%s職業武庫強化到 Lv.%d" % [PushSim.CLASS_NAMES[c], progress.armory_level[c]])
		"item":
			var id: String = selected.id
			if Items.is_weapon(id):
				if progress.equip_weapon(id):
					selected = {"kind": "armory", "cls": Items.weapon_class(id)}
					_done("%s裝備到%s職業武庫" % [Items.item_name(id), PushSim.CLASS_NAMES[Items.weapon_class(id)]])
			else:
				var who: int = _charm_target(id)
				if who >= 0 and progress.equip_charm(who, id):
					_done("%s戴上了%s" % [PushReport.hero_name(_names, who), Items.item_name(id)])


func _salvage_pressed() -> void:
	var id: String = selected.get("id", "")
	if id != "" and progress.salvage(id):
		_done("分解 %s：強化石 +%d" % [Items.item_name(id), Items.SALVAGE[Items.rarity(id)]])


func _done(text: String) -> void:
	_toast.text = text
	progress.save(_save_path())
	refresh()


func _save_path() -> String:
	if save_path == "":
		var app: Node = get_node_or_null(^"/root/App")
		save_path = app.progress_path if app != null else Progression.SAVE_PATH
	return save_path
