extends HBoxContainer

signal claim_pressed

@onready var title: Label = %AchievementTitle
@onready var detail: Label = %AchievementDetail
@onready var claim_button: Button = %AchievementClaim


func _ready() -> void:
	claim_button.pressed.connect(func() -> void: claim_pressed.emit())


func setup(name_text: String, description: String, state: String) -> void:
	title.text = name_text
	detail.text = description
	claim_button.text = "已領取" if state == "claimed" else ("領取" if state == "ready" else "未完成")
	claim_button.disabled = state != "ready"
