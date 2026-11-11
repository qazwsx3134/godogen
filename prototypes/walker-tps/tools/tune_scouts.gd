extends SceneTree
## One-time authoring: gives battlefield.tscn's heavy scout (Scout2) its own fighting numbers, so the
## light and heavy scouts play differently (scout.gd exports; the light ones keep the defaults), and
## turns on NavigationAgent3D avoidance in scout.tscn so scouts walk around each other.
##   godot --headless --path . --script res://tools/tune_scouts.gd
## Afterwards the scene is the source: tune the values in the editor (Enemies/Scout2, Weapon/Movement).
const B = preload("res://addons/proto_kit/scene_builder.gd")
const HEAVY := {
	"chase_speed": 2.0, "attack_range": 45.0, "lead_accuracy": 0.85, "aim_spread": 0.4,
	"shot_damage": 18.0, "shot_speed": 50.0, "windup_time": 1.0, "fire_cooldown": 3.0, "repositions": false,
}

func _initialize() -> void:
	var opened := B.open_scene("res://scenes/battlefield.tscn")
	var heavy: Node = opened.root.get_node("Enemies/Scout2")
	for key: String in HEAVY: heavy.set(key, HEAVY[key])
	var ok: bool = B.save_scene(opened.root, "res://scenes/battlefield.tscn", {"overwrite": true, "expected_refs": opened.refs}).ok
	var scout := B.open_scene("res://scenes/scout.tscn")
	var agent: NavigationAgent3D = scout.root.get_node("NavigationAgent")
	agent.avoidance_enabled = true
	agent.radius = 1.4  # body capsule is 0.9; keep a little air between hulls
	ok = B.save_scene(scout.root, "res://scenes/scout.tscn", {"overwrite": true, "expected_refs": scout.refs}).ok and ok
	quit(0 if ok else 1)
