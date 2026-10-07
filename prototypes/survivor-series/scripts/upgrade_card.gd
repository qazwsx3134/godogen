extends Button
signal chosen(id: StringName)
@export var definition: Resource
var id: StringName
@onready var title_label: Label = %Title
@onready var body_label: Label = %Description
@onready var tag_label: Label = %Tag
@onready var stripe: ColorRect = %Stripe

func _ready() -> void:
	pressed.connect(func() -> void: chosen.emit(id))
	if definition != null:
		setup(definition, null)

func setup(item: Resource, build: RefCounted) -> void:
	definition = item
	id = item.id
	var hidden: bool = item.slot == "fusion" and build != null and not build.discovered.has(item.id)
	title_label.text = "？？？" if hidden else item.title
	var owned: int = build.count(item.id) if build != null else 0
	body_label.text = build.card_note(item) if build != null else item.description
	if hidden:
		body_label.text = "兩把武器產生了奇妙的共鳴……選了才知道會變成什麼。"
	match item.slot:
		"weapon":
			tag_label.text = "新武器" if owned == 0 else "武器  ·  Lv.%d → %d" % [owned, owned + 1]
		"passive":
			tag_label.text = "新被動" if owned == 0 else "被動  ·  Lv.%d → %d" % [owned, owned + 1]
		"evolution":
			tag_label.text = "進化！"
		"fusion":
			tag_label.text = "隱藏融合！"
		_:
			tag_label.text = "補給"
	stripe.color = Color("b784f0") if hidden else item.accent
