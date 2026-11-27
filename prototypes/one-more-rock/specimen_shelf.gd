extends StaticBody3D

@onready var displays: Node3D = %Displays
@onready var tally: Label3D = %Tally

var collected := 0


func register_sample(index: int) -> void:
	if index < 0 or index >= displays.get_child_count():
		return
	var bay := displays.get_child(index)
	var sample := bay.get_node("Sample") as Node3D
	if sample.visible:
		return
	sample.show()
	(bay.get_node("Name") as Label3D).text = bay.get_meta("mineral")
	collected += 1
	tally.text = "圖鑑　%d／%d" % [collected, displays.get_child_count()]
	var motion := create_tween()
	motion.tween_property(sample, "scale", sample.scale, 0.24).from(sample.scale * 0.72).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
