extends Control
signal chosen(id: StringName, generation: int)
@export var card_scene: PackedScene
@onready var options: VBoxContainer = %Options

func present(build: RefCounted, offers: Array[Resource], generation: int) -> void:
	for child: Node in options.get_children():
		options.remove_child(child)
		child.queue_free()
	%Level.text = "LEVEL %d  /  揍飛成長" % build.level
	%Note.text = "戰鬥已暫停，還有 %d 次選擇。" % build.pending_choices if build.pending_choices > 1 else "戰鬥已暫停，選好再繼續揍。"
	for item: Resource in offers:
		var card: Button = card_scene.instantiate()
		options.add_child(card)
		card.setup(item, build.count(item.id))
		card.chosen.connect(func(id: StringName) -> void: chosen.emit(id, generation))
	show()
