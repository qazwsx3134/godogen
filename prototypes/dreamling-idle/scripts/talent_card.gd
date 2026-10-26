extends PanelContainer
signal purchase_requested(id: String)
@export var talent_id: String = "might"


func _ready() -> void:
	%BuyTalent.pressed.connect(func() -> void: purchase_requested.emit(talent_id))


func refresh(game: RefCounted) -> void:
	var definition: Dictionary = game.catalog.talent(talent_id)
	var preview: Dictionary = game.talent_preview(talent_id)
	%TalentName.text = "%s  %d／%d" % [definition.name, preview.rank, definition.max_level]
	%TalentDescription.text = definition.description
	if int(preview.cost) < 0:
		%BuyTalent.text = "已滿級"
	elif not preview.available:
		%BuyTalent.text = "先購買前置天賦"
	else:
		%BuyTalent.text = "提升 · %d 金" % int(preview.cost)
	%BuyTalent.disabled = int(preview.cost) < 0 or not preview.available
	theme_type_variation = &"SelectedCard" if int(preview.rank) > 0 else &"Card"
