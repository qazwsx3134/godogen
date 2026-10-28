extends Control
## 背包 (scenes/pages/backpack.tscn, Taskbar Hero's backpack.png page): the unequipped pieces (weapons, charms; 新
## until seen), the relics with their stars and the materials, one inventory_card each, filtered by the tabs. A
## selected piece shows its rarity, affixes and effect, and can be 分解 into 強化石. 自動分解 sets which rarities a
## new drop that beats nothing equipped turns into 強化石 at once (progression.gd auto_salvage).

signal changed
signal open_tab(tab: StringName)
signal message(text: String)

const CARD := preload("res://scenes/components/inventory_card.tscn")
const Items = preload("res://domain/items.gd")
const Progression = preload("res://domain/progression.gd")
const UiArt = preload("res://scripts/ui_art.gd")

## inventory_card's drawn size (its root has no minimum of its own).
const CARD_SIZE := Vector2(162, 194)

enum Filter { ALL, WEAPON, CHARM, RELIC, MATERIAL }

var progress: RefCounted = null
var filter: int = Filter.ALL
## The selected entry: {kind: "piece"|"relic"|"material", ...} ({} = none).
var selected: Dictionary = {}
var _entries: Array = []


func _ready() -> void:
	for k: int in %FilterRow.get_child_count():
		(%FilterRow.get_child(k) as Button).pressed.connect(func() -> void:
			filter = k
			selected = {}
			refresh())
	%SalvageButton.pressed.connect(_salvage)
	%AutoSalvageButton.pressed.connect(func() -> void:
		progress.auto_salvage = progress.auto_salvage + 1 if progress.auto_salvage < 1 else -1
		message.emit("自動分解：" + Items.AUTO_SALVAGE_NAMES[progress.auto_salvage + 1])
		changed.emit())


func _salvage() -> void:
	if selected.get("kind", "") != "piece":
		return
	var item: Dictionary = selected.item
	if progress.salvage(item.uid):
		message.emit("%s 分解成 %d 強化石" % [Items.item_name(item.id), Items.SALVAGE[Items.rarity(item.id)]])
		selected = {}
		changed.emit()


func refresh() -> void:
	if progress == null:
		return
	_entries = _list()
	for k: int in %FilterRow.get_child_count():
		(%FilterRow.get_child(k) as Button).modulate = Color.WHITE if k == filter else Color(1, 1, 1, 0.65)
	var grid: GridContainer = %ItemsGrid
	while grid.get_child_count() < _entries.size():
		var card: Control = CARD.instantiate()
		card.custom_minimum_size = CARD_SIZE
		grid.add_child(card)
		var index: int = grid.get_child_count() - 1
		(card.get_node("InspectButton") as Button).pressed.connect(func() -> void:
			if index < _entries.size():
				selected = _entries[index]
				_show_info())
	for k: int in grid.get_child_count():
		var card: Control = grid.get_child(k)
		card.visible = k < _entries.size()
		if card.visible:
			_fill(card, _entries[k])
	%EmptyState.visible = _entries.is_empty()
	%AutoSalvageButton.text = "自動分解：" + Items.AUTO_SALVAGE_NAMES[progress.auto_salvage + 1]
	_show_info()


## The home screen leaves this page: the pieces were seen, they lose their 新 mark.
func leave() -> void:
	if progress != null:
		progress.fresh.clear()


func _list() -> Array:
	var out: Array = []
	if filter in [Filter.ALL, Filter.WEAPON, Filter.CHARM]:
		var pieces: Array = progress.bag.filter(func(item: Dictionary) -> bool:
			return filter == Filter.ALL or (Items.is_weapon(item.id) == (filter == Filter.WEAPON)))
		pieces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Items.score(a) > Items.score(b))
		for item: Dictionary in pieces:
			out.append({"kind": "piece", "item": item})
	if filter in [Filter.ALL, Filter.RELIC]:
		for k: int in Items.RELICS.size():
			if progress.relic_stars[k] > 0 or filter == Filter.RELIC:
				out.append({"kind": "relic", "index": k})
	if filter in [Filter.ALL, Filter.MATERIAL]:
		for k: int in Progression.POTIONS.size():
			out.append({"kind": "potion", "index": k})
		for key: String in ["shards", "stones", "tickets"]:
			out.append({"kind": "material", "key": key})
	return out


func _fill(card: Control, e: Dictionary) -> void:
	var icon: TextureRect = card.get_node("Icon")
	var title: Label = card.get_node("Title")
	var count: Label = card.get_node("Quantity")
	var stripe: ColorRect = card.get_node("RarityBar")
	stripe.visible = e.kind == "piece"
	match e.kind:
		"piece":
			var item: Dictionary = e.item
			icon.texture = UiArt.item_icon(item.id)
			title.text = Items.item_name(item.id)
			count.text = ("新 " if progress.fresh.has(item.uid) else "") + Items.RARITY_NAMES[Items.rarity(item.id)]
			stripe.color = UiArt.rarity_color(Items.rarity(item.id))
		"relic":
			icon.texture = UiArt.relic_icon(e.index)
			title.text = Items.RELICS[e.index].name
			count.text = "★%d" % progress.relic_stars[e.index]
		"potion":
			icon.texture = UiArt.potion_icon(e.index)
			title.text = Progression.POTIONS[e.index].name
			count.text = "×%d" % progress.potions[e.index]
		"material":
			icon.texture = UiArt.material_icon(e.key)
			title.text = {"shards": "突破素材", "stones": "強化石", "tickets": "招募券"}[e.key]
			count.text = "×%d" % progress.get(e.key)
	card.modulate = Color(1, 1, 1, 0.5) if e.kind == "relic" and progress.relic_stars[e.index] == 0 else Color.WHITE


func _show_info() -> void:
	%SalvageButton.disabled = selected.get("kind", "") != "piece"
	match selected.get("kind", ""):
		"piece":
			var item: Dictionary = selected.item
			%InfoName.text = "%s（%s）" % [Items.item_name(item.id), Items.RARITY_NAMES[Items.rarity(item.id)]]
			var lines := PackedStringArray([Items.effect_text(item.id)])
			lines.append_array(Items.affix_lines(item))
			lines.append("分解得 %d 強化石" % Items.SALVAGE[Items.rarity(item.id)])
			%InfoText.text = "\n".join(lines)
		"relic":
			var k: int = selected.index
			%InfoName.text = "%s ★%d／%d" % [Items.RELICS[k].name, progress.relic_stars[k], Items.MAX_STARS]
			%InfoText.text = Items.relic_text(k, progress.relic_stars[k]) + "\n首次登上樓層與打贏樓層王時可能得到星星。"
		"potion":
			var pk: int = selected.index
			%InfoName.text = "%s ×%d" % [Progression.POTIONS[pk].name, progress.potions[pk]]
			%InfoText.text = "一瓶給一名英雄 %d 經驗（到等級上限為止），沒在行軍的英雄也能養。在英雄頁點英雄→升級使用。行軍與打贏樓層王會得到。" % Progression.POTIONS[pk].exp
		"material":
			%InfoName.text = {"shards": "突破素材", "stones": "強化石", "tickets": "招募券"}[selected.key]
			%InfoText.text = {"shards": "英雄突破用。樓層王必掉，招募與行軍也會得到。",
				"stones": "職業武庫強化用。分解裝備、打贏樓層王、行軍都會得到。",
				"tickets": "商店招募用。首次登上樓層得 10 張。"}[selected.key]
		_:
			%InfoName.text = "點選物品看詳情"
			%InfoText.text = "背包 %d／%d 件" % [progress.bag.size(), Items.BAG_MAX]
