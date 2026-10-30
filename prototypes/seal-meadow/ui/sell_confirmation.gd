extends Control
## Saved modal layout inside the HUD safe area; the list scrolls independently.
signal confirmed

var dialog_text: String = "":
	set(value):
		dialog_text = value
		if is_node_ready():
			%SaleList.text = value

func _ready() -> void:
	%SaleList.text = dialog_text
	%CancelSale.pressed.connect(hide)
	%ConfirmSale.pressed.connect(func() -> void:
		hide()
		confirmed.emit())

func popup_centered() -> void:
	show()
