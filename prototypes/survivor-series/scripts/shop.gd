extends Control
## Between-run shop: one card per permanent upgrade, plus the achievement list.
signal closed
@export var item_scene: PackedScene
var meta: Node
@onready var items: VBoxContainer = %Items

func _ready() -> void:
	%Back.pressed.connect(func() -> void: closed.emit())

func present(source: Node) -> void:
	meta = source
	refresh()
	show()

func refresh() -> void:
	%Wallet.text = "金幣  %d" % meta.coins
	for child: Node in items.get_children():
		items.remove_child(child)
		child.queue_free()
	for entry: Resource in meta.catalogue.shop:
		var card: Button = item_scene.instantiate()
		items.add_child(card)
		card.setup(entry, meta.level_of(entry.id), meta.price(entry.id), meta.coins)
		card.pressed.connect(func() -> void:
			if meta.buy(entry.id):
				refresh())
	var lines: PackedStringArray = []
	for goal: Resource in meta.catalogue.achievements:
		lines.append("%s %s：%s → %s" % ["【已解鎖】" if meta.is_unlocked(goal.id) else "【未解鎖】", goal.title, goal.description, goal.reward])
	%Goals.text = "\n".join(lines)
