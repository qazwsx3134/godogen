extends Control
## 天賦 (scenes/pages/train.tscn, on Taskbar Hero's train.png page): the talent star map. Each talent_node in
## %TalentTree is one talent (domain/talents.gd); scripts/talent_links.gd draws the edges. A node shows its level and
## how far along it is: locked (dim), open (bright ring, pulsing when the gold covers it), lit (gold ring), full (gold
## fill). Tapping a node shows it below; 點亮 buys its next level at once.

signal changed
signal open_tab(tab: StringName)
signal message(text: String)

const Talents = preload("res://domain/talents.gd")
const UiArt = preload("res://scripts/ui_art.gd")
const RING_DARK := Color("2f3446")
const RING_EDGE := Color("8a7f6a")
const GOLD := Color("e8b850")
const GOLD_FILL := Color("8a6418")

var progress: RefCounted = null
var selected: int = Talents.SWORD
var _t: float = 0.0


func _ready() -> void:
	for k: int in Talents.count():
		var node: Button = _node(k)
		if node != null:
			node.pressed.connect(func() -> void:
				selected = k
				refresh())
	%LightButton.pressed.connect(_light)


func _node(k: int) -> Button:
	return %TalentTree.get_node_or_null("Node%d" % k)


func _light() -> void:
	var k: int = selected
	if progress.level_talent(k):
		message.emit("點亮 %s Lv%d" % [Talents.ROWS[k].name, progress.talent[k]])
		changed.emit()
	elif not progress.talent_open(k):
		message.emit("還不能點亮：需要 " + progress.talent_need(k))
	elif progress.talent_cost(k) < 0:
		message.emit("已經點滿了")
	else:
		message.emit("金幣不夠")


func _process(delta: float) -> void:
	_t += delta
	if progress == null or not is_visible_in_tree():
		return
	# Nodes the gold covers pulse.
	var glow: float = 0.75 + 0.25 * sin(_t * 5.0)
	for k: int in Talents.count():
		var node: Button = _node(k)
		if node != null and _affordable(k):
			(node.get_node("Ring") as Control).self_modulate = Color(1, 1, 1).lerp(Color("fff1b8"), glow)


func _affordable(k: int) -> bool:
	var cost: int = progress.talent_cost(k)
	return cost >= 0 and progress.talent_open(k) and progress.gold >= cost


func refresh() -> void:
	if progress == null:
		return
	for k: int in Talents.count():
		var node: Button = _node(k)
		if node == null:
			continue
		var lv: int = progress.talent[k]
		var full: bool = progress.talent_cost(k) < 0
		var open: bool = progress.talent_open(k)
		var ring: Panel = node.get_node("Ring")
		var box := (ring.get_theme_stylebox(&"panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
		box.bg_color = GOLD_FILL if full else RING_DARK
		box.border_color = GOLD if lv > 0 else (Color("d8cfb8") if open else RING_EDGE)
		box.set_border_width_all(10 if k == selected else 6)
		ring.add_theme_stylebox_override(&"panel", box)
		ring.self_modulate = Color.WHITE
		(node.get_node("Icon") as TextureRect).texture = UiArt.talent_icon(k)
		(node.get_node("Title") as Label).text = Talents.ROWS[k].name
		(node.get_node("Level") as Label).text = "%d/%d" % [lv, Talents.ROWS[k].max]
		node.modulate = Color.WHITE if open else Color(1, 1, 1, 0.45)
	%TalentTree.levels = progress.talent
	%TalentTree.queue_redraw()
	var k: int = selected
	var cost: int = progress.talent_cost(k)
	%DetailIcon.texture = UiArt.talent_icon(k)
	%DetailName.text = "%s　Lv. %d／%d" % [Talents.ROWS[k].name, progress.talent[k], Talents.ROWS[k].max]
	%DetailText.text = Talents.effect_text(k, progress.talent)
	%DetailNeed.text = "" if progress.talent_open(k) else "需要 " + progress.talent_need(k)
	%DetailCost.text = "已點滿" if cost < 0 else "%s 金幣" % _short(cost)
	%LightButton.disabled = not _affordable(k)
	%LightButton.text = "點亮" if progress.talent_open(k) else "未開放"


static func _short(v: int) -> String:
	if v >= 100_000_000:
		return "%.1f 億" % (v / 100_000_000.0)
	if v >= 10_000:
		return "%.1f 萬" % (v / 10_000.0)
	return str(v)
