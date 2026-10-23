extends SceneTree
## Screenshots of the first stage of every region (its light and boss colour) a few seconds into the fight, for
## reviewing the 關卡 look. Needs a display:
##   godot --path prototypes/hero-horde-idle --resolution 390x844 --script res://tools/capture_regions.gd -- <out dir>

const Progression = preload("res://domain/progression.gd")
const Stages = preload("res://domain/stages.gd")
const Screenshot = preload("res://addons/proto_kit/screenshot.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out: String = Screenshot.out_dir()
	for region: Dictionary in Stages.REGIONS:
		seed(7)
		var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
		var progress := Progression.new()
		progress.class_level.fill(12)
		progress.cleared = Stages.COUNT
		main.progress = progress
		main.save_path = "user://progress_shots.json"
		main.stage_n = region.first
		root.add_child(main)
		await _frames(2)
		main.sim.skip_muster()
		await _frames(150)
		Screenshot.save(root, out, "stage_" + Stages.label(region.first))
		main.queue_free()
		await _frames(2)
	quit(0)


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame
