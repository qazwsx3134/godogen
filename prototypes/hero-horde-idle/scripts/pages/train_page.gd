extends Control
## 訓練 (scenes/pages/train.tscn, Taskbar Hero's train.png page): one training_row per talent (domain/talents.gd),
## bought with gold at once. A row that is not open yet says what it waits for.

signal changed
signal open_tab(tab: StringName)
signal message(text: String)

const Talents = preload("res://domain/talents.gd")
const UiArt = preload("res://scripts/ui_art.gd")

var progress: RefCounted = null


func _ready() -> void:
	for k: int in mini(%TrainingList.get_child_count(), Talents.count()):
		var row: Control = %TrainingList.get_child(k)
		(row.get_node("TrainButton") as Button).pressed.connect(_buy.bind(k))


func _buy(k: int) -> void:
	if progress.level_talent(k):
		message.emit("%s 升到 Lv%d" % [Talents.ROWS[k].name, progress.talent[k]])
		changed.emit()
	elif not progress.talent_open(k):
		message.emit("還不能訓練：需要 " + Talents.need_text(k, progress.talent))
	elif progress.talent_cost(k) < 0:
		message.emit("已經練到最高等級")
	else:
		message.emit("金幣不夠")


func refresh() -> void:
	if progress == null:
		return
	for k: int in %TrainingList.get_child_count():
		var row: Control = %TrainingList.get_child(k)
		row.visible = k < Talents.count()
		if not row.visible:
			continue
		var r: Dictionary = Talents.ROWS[k]
		var lv: int = progress.talent[k]
		var cost: int = progress.talent_cost(k)
		var open: bool = progress.talent_open(k)
		(row.get_node("Icon") as TextureRect).texture = UiArt.talent_icon(k)
		(row.get_node("Title") as Label).text = r.name
		(row.get_node("TrainingLevel") as Label).text = "Lv. %d／%d" % [lv, r.max]
		(row.get_node("Description") as Label).text = Talents.effect_text(k, progress.talent)
		(row.get_node("CurrentValue") as Label).text = "" if open else "需要 " + Talents.need_text(k, progress.talent)
		(row.get_node("NextCost") as Label).text = "已滿級" if cost < 0 else "%s 金幣" % _short(cost)
		var button: Button = row.get_node("TrainButton")
		button.text = "訓練" if open else "未開放"
		button.disabled = cost < 0 or not open or progress.gold < cost
		row.modulate = Color.WHITE if open else Color(1, 1, 1, 0.7)


static func _short(v: int) -> String:
	if v >= 100_000_000:
		return "%.1f 億" % (v / 100_000_000.0)
	if v >= 10_000:
		return "%.1f 萬" % (v / 10_000.0)
	return str(v)
