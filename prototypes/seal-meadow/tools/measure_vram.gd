extends SceneTree
## Prints the texture memory the main scene uses after it settles (needs a real renderer: run under xvfb-run).
##   xvfb-run -a godot --path . -s res://tools/measure_vram.gd

func _init() -> void:
	var m: Node = load("res://scenes/main.tscn").instantiate()
	m.save_path = "user://measure_vram/save.json"
	root.add_child(m)
	for i in 30:
		await process_frame
	print("VRAM texture MB: %.1f" % (Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0))
	print("VRAM total MB: %.1f" % (Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0))
	quit()
