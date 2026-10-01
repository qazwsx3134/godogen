extends Node
## Shows one spot: binds the HUD to the spot's Viewer and applies the device quality tier.

const Quality = preload("res://viewer/quality.gd")


func _ready() -> void:
	var spot: Node3D = %Spot
	Quality.apply(get_viewport(), spot.get_sun(), Quality.pick())
	%HUD.bind(spot, spot.get_viewer())
