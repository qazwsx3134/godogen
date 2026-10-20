extends SceneTree
## Authors act 4 (處刑台, docs/one-piece-marineford/acts.md) as editable scenes:
##   scenes/acts/act_4.tscn                 triggers along the route with their Beat children
##   scenes/cutscenes/act4_hormone.tscn     Ivankov's tension hormone
##   scenes/cutscenes/act4_execution.tscn   the execution order, Luffy's shout
##   scenes/cutscenes/act4_golden_fist.tscn the golden fist on the platform
## Each scene carries a `Reference` route instance for placing things in the editor (freed at run time).
## One-time tool: existing scenes are skipped; edit them in the editor.
##   godot --headless --path prototypes/luffy-marineford --script res://tools/build_act4.gd

const Builder = preload("res://addons/proto_kit/scene_builder.gd")
const ROUTE := "res://scenes/route.tscn"
const ACTOR := "res://scenes/cast_actor.tscn"
const DECK := 27.4
const PLATFORM_Z := -263.0


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var ok: bool = true
	for f: Callable in [_hormone, _execution, _golden_fist, _act]:
		ok = f.call() and ok
	quit(0 if ok else 1)


func _reference(root: Node) -> void:
	Builder.add(root, Builder.instance(ROUTE), "Reference")


func _actor(root: Node, node_name: String, character: String, at: Vector3, facing: Vector3, anim: StringName) -> Node3D:
	var actor: Node3D = Builder.instance(ACTOR)
	actor.set(&"character", character)
	actor.set(&"facing", facing)
	actor.set(&"anim", anim)
	actor.position = at
	Builder.add(root, actor, node_name)
	return actor


func _look(from: Vector3, at: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, from).looking_at(at, Vector3.UP)


## A cutscene root with Shot and Anim; `shots` are [time, eye, look, fov]; `calls` are [time, node path, method, args].
func _cutscene(scene_name: String, length: float, shots: Array, calls: Array, extra: Callable) -> bool:
	var root := Node3D.new()
	root.name = scene_name.to_pascal_case()
	root.set_script(load("res://scripts/cutscene.gd"))
	_reference(root)
	var shot := Camera3D.new()
	shot.transform = _look(shots[0][1], shots[0][2])
	shot.fov = shots[0][3]
	shot.far = 600.0
	Builder.add(root, Builder.unique(shot), "Shot")
	extra.call(root)
	var anim := Animation.new()
	anim.length = length
	var pose: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(pose, NodePath("Shot:transform"))
	# Linear: a cubic camera swings wildly through a cut (two keys 0.02 s apart).
	anim.track_set_interpolation_type(pose, Animation.INTERPOLATION_LINEAR)
	var lens: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(lens, NodePath("Shot:fov"))
	for key: Array in shots:
		anim.track_insert_key(pose, key[0], _look(key[1], key[2]))
		anim.track_insert_key(lens, key[0], key[3])
	# A call is [time, node path, method, args]; method "@value" keys the property path c[1] to c[3] instead.
	var tracks: Dictionary = {}
	for c: Array in calls:
		var path: String = c[1]
		var is_value: bool = c[2] == "@value"
		if not tracks.has(path):
			tracks[path] = anim.add_track(Animation.TYPE_VALUE if is_value else Animation.TYPE_METHOD)
			anim.track_set_path(tracks[path], NodePath(path))
		if is_value:
			anim.track_insert_key(tracks[path], c[0], c[3])
		else:
			anim.track_insert_key(tracks[path], c[0], {"method": StringName(c[2]), "args": c[3]})
	var library := AnimationLibrary.new()
	library.add_animation(&"main", anim)
	var player := AnimationPlayer.new()
	player.add_animation_library(&"", library)
	Builder.add(root, Builder.unique(player), "Anim")
	var result: Dictionary = Builder.save_scene(root, "res://scenes/cutscenes/%s.tscn" % scene_name,
		{"expected_refs": [ROUTE, ACTOR]})
	print(scene_name, ": ", result)
	return result.ok


func _hormone() -> bool:
	return _cutscene("act4_hormone", 5.6, [
		[0.0, Vector3(3.4, 2.4, 22.5), Vector3(0.9, 1.3, 29.0), 50.0],
		[5.6, Vector3(2.5, 1.9, 24.5), Vector3(0.9, 1.3, 29.0), 46.0],
	], [
		[0.3, ".", "say", ["伊萬科夫", "草帽小子！再撐一次吧——緊張荷爾蒙！", 2.4]],
		[2.5, "Ivankov", "play", [&"attack"]],
		[2.7, ".", "flash", [0.5]],
		[2.7, ".", "shake", [0.35]],
		[3.0, ".", "say", ["魯夫", "謝啦，伊萬醬！艾斯，等我！", 2.4]],
	], func(root: Node) -> void:
		_actor(root, "Ivankov", "ivankov", Vector3(2.4, 0.0, 28.6), Vector3(-1, 0, 0), &"idle"))


func _execution() -> bool:
	return _cutscene("act4_execution", 6.6, [
		[0.0, Vector3(0.0, 3.5, -134.0), Vector3(0.0, 20.0, PLATFORM_Z), 45.0],
		[2.2, Vector3(0.0, 30.0, -246.0), Vector3(0.0, DECK + 0.6, PLATFORM_Z), 40.0],
		[4.38, Vector3(0.0, 29.6, -248.0), Vector3(0.0, DECK + 0.6, PLATFORM_Z), 40.0],
		[4.4, Vector3(0.0, 5.0, -134.0), Vector3(0.0, 1.0, -146.0), 50.0],
		[6.6, Vector3(0.0, 6.5, -132.0), Vector3(0.0, 1.0, -146.0), 54.0],
	], [
		[0.4, ".", "say", ["海軍", "時間到了！執行死刑——！", 1.9]],
		[2.4, "ExecutionerL", "play", [&"raise"]],
		[2.4, "ExecutionerR", "play", [&"raise"]],
		[2.6, "Ace", "play", [&"struggle"]],
		[4.4, ".", "say", ["魯夫", "住手——！！", 2.0]],
		[4.4, ".", "shake", [0.6]],
	], func(root: Node) -> void:
		_actor(root, "Ace", "ace_chained", Vector3(0.0, DECK, PLATFORM_Z), Vector3(0, 0, 1), &"kneel")
		_actor(root, "ExecutionerL", "executioner", Vector3(-1.7, DECK, PLATFORM_Z - 0.6), Vector3(1, 0, 0.4), &"idle")
		_actor(root, "ExecutionerR", "executioner", Vector3(1.7, DECK, PLATFORM_Z - 0.6), Vector3(-1, 0, 0.4), &"idle"))


func _golden_fist() -> bool:
	return _cutscene("act4_golden_fist", 6.0, [
		[0.0, Vector3(0.0, DECK + 4.0, PLATFORM_Z + 19.0), Vector3(0.0, DECK + 3.0, PLATFORM_Z), 50.0],
		[6.0, Vector3(0.0, DECK + 6.0, PLATFORM_Z + 22.0), Vector3(0.0, DECK + 3.0, PLATFORM_Z), 54.0],
	], [
		[0.3, ".", "say", ["魯夫", "艾斯！我來了！", 1.6]],
		[1.2, "Sengoku", "play", [&"strike"]],
		[0.0, "GoldenFist:position", "@value", Vector3(0.0, DECK + 14.0, PLATFORM_Z + 2.0)],
		[1.6, "GoldenFist:position", "@value", Vector3(0.0, DECK + 14.0, PLATFORM_Z + 2.0)],
		[2.6, "GoldenFist:position", "@value", Vector3(0.0, DECK + 1.3, PLATFORM_Z + 3.0)],
		[1.4, ".", "say", ["戰國", "休想得逞！", 1.4]],
		[2.6, ".", "flash", [1.0]],
		[2.6, ".", "shake", [1.0]],
		[2.7, "Luffy", "play", [&"down"]],
		[3.4, ".", "say", ["魯夫", "嗚……艾斯……", 2.2]],
	], func(root: Node) -> void:
		_actor(root, "Ace", "ace_chained", Vector3(0.0, DECK, PLATFORM_Z), Vector3(0, 0, 1), &"kneel")
		_actor(root, "Luffy", "luffy", Vector3(0.0, DECK, PLATFORM_Z + 3.0), Vector3(0, 0, -1), &"idle")
		_actor(root, "Sengoku", "sengoku_buddha", Vector3(0.0, DECK, PLATFORM_Z - 4.0), Vector3(0, 0, 1), &"idle")
		var fist := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(3.0, 2.6, 3.0)
		fist.mesh = box
		var gold := ShaderMaterial.new()
		gold.shader = load("res://shaders/toon_solid.gdshader")
		gold.set_shader_parameter(&"albedo", Color("f2c14e"))
		fist.material_override = gold
		fist.position = Vector3(0.0, DECK + 14.0, PLATFORM_Z + 2.0)
		Builder.add(root, fist, "GoldenFist"))


func _act() -> bool:
	var root := Node3D.new()
	root.name = "Act4"
	root.set_script(load("res://scripts/act.gd"))
	root.set(&"number", 4)
	root.set(&"number_text", "第四幕")
	root.set(&"title", "處刑台")
	root.set(&"start_z", 30.0)
	root.set(&"heading", -1.0)
	# Played on its own, an act starts with its chapter's standard kit (README 跨關成長, C6 row): the Rocket is the
	# dash button, Haki comes from the story.
	root.set(&"kit", PackedStringArray(["pistol:3", "gatling:3", "gear2:1", "gigant:1"]))
	root.set(&"unlocked", PackedStringArray())
	root.set(&"companions", PackedStringArray(["ivankov"]))
	_reference(root)
	var opening := _trigger(root, "Opening", 30.0, "", true)
	_beat(opening, {"kind": Beat.Kind.CALL, "method": &"bridge", "arg": "closed", "wait": false})
	_beat(opening, {"kind": Beat.Kind.TITLE})
	_beat(opening, {"kind": Beat.Kind.CUTSCENE, "cutscene": load("res://scenes/cutscenes/act4_hormone.tscn")})
	_beat(opening, {"kind": Beat.Kind.CALL, "method": &"unlock", "arg": "hormone", "wait": false})
	_beat(opening, {"kind": Beat.Kind.TOAST, "speaker": "伊萬科夫", "text": "緊張荷爾蒙：倒下也能再站起來一次", "portrait": "ivankov", "color": Color("ff7ac0")})
	var coby := _trigger(root, "Coby", -70.0, "克比")
	_beat(coby, {"kind": Beat.Kind.LINE, "speaker": "克比", "text": "魯夫先生，請停下來！", "seconds": 2.2})
	_beat(coby, {"kind": Beat.Kind.CALL, "method": &"blocker", "arg": "coby:2", "wait": true})
	_beat(coby, {"kind": Beat.Kind.LINE, "speaker": "魯夫", "text": "抱歉了，克比！", "seconds": 1.8})
	var plaza := _trigger(root, "Plaza", -146.0, "廣場")
	_beat(plaza, {"kind": Beat.Kind.CUTSCENE, "cutscene": load("res://scenes/cutscenes/act4_execution.tscn")})
	_beat(plaza, {"kind": Beat.Kind.CALL, "method": &"haki", "wait": true})
	_beat(plaza, {"kind": Beat.Kind.TOAST, "speaker": "白鬍子", "text": "全員掩護魯夫！", "portrait": "whitebeard", "color": Color("f0e9d9")})
	_beat(plaza, {"kind": Beat.Kind.CALL, "method": &"bridge", "arg": "rise", "wait": true})
	_beat(plaza, {"kind": Beat.Kind.LINE, "speaker": "魯夫", "text": "路通了！艾斯——！", "seconds": 2.0})
	var garp := _trigger(root, "Garp", -226.0, "卡普")
	_beat(garp, {"kind": Beat.Kind.SAY, "speaker": "卡普", "text": "魯夫！想過去，就先打倒我！", "portrait": "garp", "color": Color("9fc3ff")})
	_beat(garp, {"kind": Beat.Kind.SAY, "speaker": "魯夫", "text": "爺爺……讓開！", "portrait": "luffy_resolve"})
	_beat(garp, {"kind": Beat.Kind.CALL, "method": &"blocker", "arg": "garp:8", "wait": true})
	_beat(garp, {"kind": Beat.Kind.LINE, "speaker": "卡普", "text": "……臭小子。", "seconds": 2.0})
	var platform := _trigger(root, "Platform", -249.5, "處刑台")
	_beat(platform, {"kind": Beat.Kind.CUTSCENE, "cutscene": load("res://scenes/cutscenes/act4_golden_fist.tscn")})
	_beat(platform, {"kind": Beat.Kind.WIN})
	var result: Dictionary = Builder.save_scene(root, "res://scenes/acts/act_4.tscn", {"expected_refs": [ROUTE]})
	print("act_4: ", result)
	return result.ok


func _trigger(root: Node, node_name: String, z: float, goal: String, on_start: bool = false) -> Node:
	var t := Marker3D.new()
	t.set_script(load("res://scripts/act_trigger.gd"))
	t.position = Vector3(0.0, 0.0, z)
	t.set(&"goal_name", goal)
	t.set(&"on_start", on_start)
	Builder.add(root, t, node_name)
	return t


func _beat(trigger: Node, fields: Dictionary) -> void:
	var b := Node.new()
	b.set_script(load("res://scripts/beat.gd"))
	for key: String in fields:
		b.set(key, fields[key])
	var label: String = Beat.Kind.keys()[fields.kind]
	if fields.has("text"):
		label += " " + String(fields.text).left(10)
	elif fields.has("method"):
		label += " " + String(fields.method) + (" " + String(fields.arg) if fields.has("arg") else "")
	Builder.add(trigger, b, "%02d %s" % [trigger.get_child_count() + 1, label.validate_node_name()])
