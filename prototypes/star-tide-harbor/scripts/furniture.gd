extends Node2D
const KINDS = ["lamp", "plant", "chair", "shelf"]
var kind := 0
var flipped := false
func configure(value: int, mirror: bool = false) -> void:
	kind=clampi(value,0,KINDS.size()-1);flipped=mirror
	$Art.texture=load("res://assets/prop_%s.svg"%KINDS[kind])
	$Art.flip_h=flipped
	$Glow.visible=kind==0
	z_index=int(position.y)
