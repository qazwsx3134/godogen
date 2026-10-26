extends Node2D
var time:=0.0
func _process(delta: float) -> void:
	time+=delta
	for i in range(get_child_count()):
		var mote:Node2D=get_child(i)
		var base:Vector2=mote.get_meta("origin")
		mote.position=base+Vector2(sin(time*.3+i)*12,cos(time*.5+i*1.8)*8)
		mote.modulate.a=.25+(sin(time*.8+i)+1)*.3
