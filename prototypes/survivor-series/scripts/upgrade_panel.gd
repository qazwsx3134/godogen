extends Control
signal chosen(id: StringName, generation: int)
signal reroll_requested
@export var card_scene: PackedScene
@onready var options: VBoxContainer = %Options
@onready var reroll: Button = %Reroll

func _ready() -> void:
	reroll.pressed.connect(func() -> void: reroll_requested.emit())

func present(build: RefCounted, offers: Array[Resource], generation: int) -> void:
	for child: Node in options.get_children():
		options.remove_child(child)
		child.queue_free()
	%Level.text = "LEVEL %d" % build.level
	%Note.text = "戰鬥已暫停，還有 %d 次選擇。" % build.pending_choices if build.pending_choices > 1 else "戰鬥已暫停，選好再繼續揍。"
	for item: Resource in offers:
		var card: Button = card_scene.instantiate()
		options.add_child(card)
		card.setup(item, build)
		card.chosen.connect(func(id: StringName) -> void: chosen.emit(id, generation))
	reroll.text = "重抽（剩 %d 次）" % build.rerolls
	reroll.disabled = build.rerolls <= 0
	show()
