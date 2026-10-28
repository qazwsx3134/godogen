extends Control
## A party member's card: diamond portrait, name, the health gauge and an optional status line.


func set_member(member_name: String, portrait: Texture2D, ratio: float, status: String = "") -> void:
	%MemberName.text = member_name
	%Portrait.texture = portrait
	%Gauge.set_ratio(ratio)
	%Status.text = status
	%Status.visible = status != ""
