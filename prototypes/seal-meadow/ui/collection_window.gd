extends Control
## The saved collection scene displays the book; rewards are committed by CollectionBook.

signal rows_updated

const Book = preload("res://scripts/collection_book.gd")
const Row = preload("res://ui/achievement_row.tscn")

@onready var fame_text: Label = %FameText
@onready var monsters_text: Label = %MonstersText
@onready var rows: VBoxContainer = %AchievementRows
@onready var status_text: Label = %CollectionStatus
@onready var close_button: Button = %CollectionClose

var player: Node3D
var main: Node
var _built_key: String = ""


func _ready() -> void:
	close_button.pressed.connect(func() -> void: visible = false)


func bind(p: Node3D, m: Node) -> void:
	player = p
	main = m
	player.stats_changed.connect(_refresh_if_visible)


func show_book() -> void:
	visible = true
	_built_key = ""
	status_text.text = ""
	refresh()


func _refresh_if_visible() -> void:
	if visible:
		refresh()


func refresh() -> void:
	if player == null:
		return
	var book = player.collection
	var key := var_to_str([book.to_data(), player.quests.index, player.pet.stage])
	if key == _built_key:
		return
	_built_key = key
	var fame: int = book.fame()
	fame_text.text = "聲望 %d　稱號：%s" % [fame, book.rank_name()]
	for rank: Dictionary in Book.RANKS:
		if rank.at > fame:
			fame_text.text += "　下一稱號：%s（%d）" % [rank.name, rank.at]
			break
	var lines: PackedStringArray = []
	for monster: Dictionary in Book.MONSTERS:
		var count: int = int(book.kills.get(monster.id, 0))
		lines.append("%s　擊敗 %d" % [monster.name, count] if count > 0 else "？？？　提示：%s" % monster.where)
	monsters_text.text = "\n".join(lines)
	for child: Node in rows.get_children():
		child.queue_free()
	for definition: Dictionary in Book.ACHIEVEMENTS:
		var row: Node = Row.instantiate()
		rows.add_child(row)
		var amount: int = mini(book.progress(definition, player), int(definition.need))
		var state: String = "claimed" if definition.id in book.claimed else ("ready" if amount >= definition.need else "locked")
		var rewards: PackedStringArray = ["聲望 +%d" % definition.fame]
		if definition.has("gold"):
			rewards.append("金幣 +%d" % definition.gold)
		if definition.has("items"):
			rewards.append("精煉水晶 ×%d" % definition.items.crystal)
		row.setup(definition.name, "%s（%d/%d）\n%s" % [definition.hint, amount, definition.need, "、".join(rewards)], state)
		var id: String = definition.id
		row.claim_pressed.connect(func() -> void: _claim(id))
	rows_updated.emit()


func _claim(id: String) -> void:
	var result: String = player.collection.claim(player, id)
	main.town_action(result)
	status_text.text = "獎勵已領取。" if result == "" else ("背包已滿，請先整理背包。" if result == "bag_full" else "這個獎勵目前無法領取。")
	refresh()
