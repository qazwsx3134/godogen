extends Node3D
## The hunting field (scenes/field.tscn). Reads the authored layout (party, monsters, props,
## bounds) into a domain Battle, turns input into battle commands, and turns battle events
## into views, effects, sound and HUD. Gameplay rules live in domain/; nothing here decides a
## hit, a drop or a death.

const Tuning = preload("res://domain/tuning.gd")
const Battle = preload("res://domain/battle.gd")
const Stepper = preload("res://domain/stepper.gd")
const ActorView = preload("res://game/actor_view.gd")
const Haptics = preload("res://addons/proto_kit/haptics.gd")
const FloatingText = preload("res://scenes/fx/floating_text.tscn")
const HitBurst = preload("res://scenes/fx/hit_burst.tscn")
const SlashArc = preload("res://scenes/fx/slash_arc.tscn")
const GroundPulse = preload("res://scenes/fx/ground_pulse.tscn")
const LightPillar = preload("res://scenes/fx/light_pillar.tscn")
const GroundWarning = preload("res://scenes/fx/ground_warning.tscn")
const Run = preload("res://domain/run.gd")
const Profile = preload("res://domain/profile.gd")
const SaveService = preload("res://domain/save_service.gd")
const CampMenu = preload("res://game/camp_menu.gd")
const Skills = preload("res://domain/skills.gd")

## Playable ground, in cells on the XZ plane (x, z, width, depth).
@export var bounds: Rect2 = Rect2(-14, -9, 28, 18)
@export var battle_seed: int = 20261024
@export_range(8.0, 40.0) var camera_distance: float = 15.0
@export var camera_distance_range: Vector2 = Vector2(11.0, 26.0)
## Screen radius (design px, 1440x900) inside which a click picks a monster.
@export var pick_radius_px: float = 72.0
@export var damage_numbers: bool = true
@export var screen_shake: bool = true
## Local save (user:// is IndexedDB on the web). Tests point this at their own file.
@export var save_path: String = "user://skybound_save.json"
@export var autosave_seconds: float = 10.0

@onready var camera_rig: Node3D = %CameraRig
@onready var camera: Camera3D = %Camera
@onready var hud: CanvasLayer = $HUD
@onready var effects: Node3D = %Effects
@onready var move_marker: Node3D = %MoveMarker
@onready var sfx: Node = %Sfx
@onready var time_control: Node = %TimeControl

var tuning: Tuning
var battle: Battle
var stepper: Stepper
var haptics := Haptics.new()
var paused: bool = false
## Portrait phones pause the fight behind a "turn sideways" panel (spec §10).
var portrait: bool = false
var views: Dictionary = {}  # unit id -> ActorView
var _setup: Dictionary
var _steer: Vector2 = Vector2.ZERO
var _drag_moving: bool = false
var _drag_repeat: float = 0.0
var _trauma: float = 0.0
var _shake_time: float = 0.0
var _marker_left: float = 0.0
var _elapsed: float = 0.0
var _end_shown: bool = false
var profile: Profile
var save_service: SaveService
var camp_menu: CampMenu
var _save_left: float = 0.0
var _camp_refresh_left: float = 0.0


func _ready() -> void:
	tuning = Tuning.load_default()
	_setup = read_layout()
	camp_menu = CampMenu.new(tuning)
	save_service = SaveService.new(save_path)
	hud.auto_toggled.connect(func(on: bool) -> void: send({"type": "auto", "on": on}))
	hud.auto_potion_toggled.connect(func(on: bool) -> void: send({"type": "auto_potion", "on": on}))
	hud.skill_pressed.connect(func() -> void: send({"type": "skill"}))
	hud.tonic_pressed.connect(func() -> void: send({"type": "tonic"}))
	hud.emergency_pressed.connect(func() -> void: send({"type": "emergency"}))
	hud.claim_pressed.connect(func() -> void: send({"type": "claim"}))
	hud.pause_toggled.connect(func(on: bool) -> void:
		paused = on
		_drag_moving = false)
	hud.restart_pressed.connect(func() -> void:
		if battle.ended:
			next_generation())
	hud.zoom_requested.connect(zoom)
	hud.setting_changed.connect(_on_setting)
	hud.retreat_pressed.connect(func() -> void: send({"type": "retreat"}))
	hud.bag_pressed.connect(func() -> void: open_camp("裝備"))
	hud.camp_pressed.connect(func() -> void: open_camp("補給"))
	hud.camp_action.connect(_on_camp_action)
	load_game()
	hud.log_line("第 %d 代冒險者抵達風庭遺跡的營地。點地面移動，點怪物攻擊，或開啟自動狩獵。" % battle.run.generation)


## Loads the saved Profile and Run; a missing save or a fallen run starts a new generation.
func load_game() -> void:
	var doc := save_service.load_state()
	profile = Profile.from_dict(doc.get("profile", {})) if doc.has("profile") else Profile.new()
	if doc.get("run") is Dictionary:
		_start_battle(Run.from_dict(tuning, doc.run))
	else:
		_start_battle(Run.new(tuning, "g%d" % profile.generation, profile.generation))
	save_game()


func save_game() -> void:
	var run_doc: Variant = null if battle.ended else battle.run.to_dict()
	save_service.save({"profile": profile.to_dict(), "run": run_doc})
	_save_left = autosave_seconds


## After a fallen leader: the next generation starts from the camp with issued supplies.
func next_generation() -> void:
	_start_battle(Run.new(tuning, "g%d" % profile.generation, profile.generation))
	save_game()
	hud.log_line("第 %d 代冒險者出發。倉庫裡的東西都還在。" % battle.run.generation)


## The authored scene as battle input: ground positions are (x, z) of global positions.
func read_layout() -> Dictionary:
	var monsters: Array = []
	for view: ActorView in %Monsters.get_children():
		monsters.append({"id": view.kind_id, "pos": _ground(view.global_position)})
	var obstacles: Array = []
	for prop: Node3D in %Props.get_children():
		var radius: float = prop.get("block_radius") if prop.get("block_radius") != null else 0.0
		if radius > 0.0:
			obstacles.append({"pos": _ground(prop.global_position), "radius": radius * prop.scale.x})
	var leader_view: Node3D = %Party.get_node("Leader")
	var camp: Node3D = %Camp
	return {"seed": battle_seed, "bounds": bounds, "obstacles": obstacles,
		"party_spawn": _ground(leader_view.global_position), "monsters": monsters,
		"camp": {"pos": _ground(camp.global_position), "radius": float(camp.get("radius"))}}


func _start_battle(run: Run) -> void:
	var setup := _setup.duplicate()
	setup.run = run
	setup.seed = battle_seed + run.generation * 7919
	battle = Battle.new(tuning, setup)
	stepper = Stepper.new(tuning.step_ms())
	views.clear()
	var party_views := {"leader": %Party.get_node("Leader"), "guardian": %Party.get_node("Guardian"),
		"support": %Party.get_node("Support")}
	for u: Battle.Unit in battle.party():
		views[u.id] = party_views[u.role]
	var monster_views := %Monsters.get_children()
	var monsters := battle.monsters()
	for i in monsters.size():
		views[monsters[i].id] = monster_views[i]
	for id: int in views:
		(views[id] as ActorView).bind(battle.unit(id))
	for child: Node in effects.get_children():
		child.queue_free()
	paused = false
	_drag_moving = false
	_steer = Vector2.ZERO
	_elapsed = 0.0
	_end_shown = false
	_trauma = 0.0
	move_marker.visible = false
	time_control.reset()
	hud.hide_end()
	camera_rig.global_position = views[battle.leader.id].global_position
	_place_camera()
	hud.refresh(hud_state())


## Battle commands are refused while the fight is frozen (pause menu, portrait phone): a key
## pressed behind the menu must not fire when play resumes.
func send(cmd: Dictionary) -> void:
	if battle.ended or paused or portrait:
		return
	battle.command(cmd)
	sfx.play(&"ui")


func zoom(step: int) -> void:
	camera_distance = clampf(camera_distance + step * 2.0, camera_distance_range.x, camera_distance_range.y)


func _process(delta: float) -> void:
	var size := get_viewport().get_visible_rect().size
	if (size.x < size.y) != portrait:
		portrait = size.x < size.y
		hud.show_rotate(portrait)
	if not paused and not portrait and not battle.ended:
		_read_steer()
		var steps := stepper.advance(delta)
		for i in steps:
			for id: int in views:
				views[id].remember(battle.unit(id))
			battle.step()
		for id: int in views:
			views[id].capture(battle.unit(id))
		_elapsed += delta
		_handle_events(battle.drain_events())
		# The release may land on a HUD control that eats it: trust the button state, not the event.
		if _drag_moving and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_drag_moving = false
		if _drag_moving:
			_drag_repeat -= delta
			if _drag_repeat <= 0.0:
				_drag_repeat = 0.15
				_order_move(get_viewport().get_mouse_position(), false)
		_save_left -= delta
		if _save_left <= 0.0:
			save_game()
		if hud.camp_open():
			_camp_refresh_left -= delta
			if _camp_refresh_left <= 0.0:
				refresh_camp()
	var frozen := paused or portrait
	var frame_delta := 0.0 if frozen else delta
	var alpha := stepper.alpha() if not frozen else 1.0
	var target_id := battle.leader.target_id
	for id: int in views:
		views[id].sync(battle.unit(id), alpha, frame_delta, id == target_id)
	_follow_camera(delta)
	_marker_left = maxf(0.0, _marker_left - frame_delta)
	move_marker.visible = _marker_left > 0.0 and battle.leader.order == Battle.Unit.Order.MOVE
	hud.refresh(hud_state())
	if battle.ended and not _end_shown:
		_end_shown = true
		var run := battle.run
		hud.set_end_button("第 %d 代出發" % profile.generation)
		hud.show_end("第 %d 代冒險者在 Lv.%d 倒下 · 擊倒 %d 隻 · %s\n身上的金幣、物品與裝備都失去了。\n倉庫保留：金幣 %d、物品 %d 種、裝備 %d 件。" % [
			run.generation, run.level, run.kills, _clock(_elapsed), profile.warehouse_gold,
			profile.warehouse_items.size(), profile.warehouse_gear.size()])


# --- Camp window -------------------------------------------------------------------

func open_camp(tab: String) -> void:
	if battle.ended:
		return
	var in_camp := battle.in_camp(battle.leader)
	hud.show_camp(camp_menu.tabs(battle.run, profile, in_camp, battle.now_ms), camp_menu.header(battle.run, profile, in_camp), tab)
	_camp_refresh_left = 0.5


func refresh_camp() -> void:
	var in_camp := battle.in_camp(battle.leader)
	hud.show_camp(camp_menu.tabs(battle.run, profile, in_camp, battle.now_ms), camp_menu.header(battle.run, profile, in_camp))
	_camp_refresh_left = 0.5


func _on_camp_action(a: Dictionary) -> void:
	if battle.ended:
		return
	if a.type == "claim":
		battle.command({"type": "claim", "quest": a.quest})
		sfx.play(&"ui")
		return
	var line := camp_menu.apply(a, battle.run, profile, battle.in_camp(battle.leader))
	if a.type in ["equip", "unequip"]:
		battle.refresh_member(a.role)
	if line != "":
		hud.toast(line)
	sfx.play(&"ui")
	save_game()
	refresh_camp()


# --- Input --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom(-1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom(1)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and not paused and not battle.ended:
				var picked := pick_monster(mb.position)
				if picked >= 0:
					send({"type": "attack", "target": picked})
				else:
					_drag_moving = _order_move(mb.position, true)
					_drag_repeat = 0.15
			elif not mb.pressed:
				_drag_moving = false
	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).physical_keycode:
			KEY_SPACE: send({"type": "auto", "on": not battle.auto_hunt})
			KEY_Q: send({"type": "skill"})
			KEY_E: send({"type": "tonic"})
			KEY_R: send({"type": "emergency"})
			KEY_F: send({"type": "claim"})
			KEY_T: send({"type": "retreat"})
			KEY_B: open_camp("裝備")
			KEY_C:
				if battle.in_camp(battle.leader):
					open_camp("補給")
			KEY_ESCAPE: hud.set_paused(not paused)


## Monster unit id under a screen point, or -1. Screen-space picking on the sprite's body.
func pick_monster(at: Vector2) -> int:
	var ui_scale := get_viewport().get_visible_rect().size.y / 900.0
	var best := -1
	var best_d := pick_radius_px * ui_scale
	for u: Battle.Unit in battle.monsters():
		if not u.alive:
			continue
		var view: Node3D = views[u.id]
		var body := view.global_position + Vector3(0.0, 0.8, 0.0)
		if camera.is_position_behind(body):
			continue
		var d := camera.unproject_position(body).distance_to(at)
		if d < best_d:
			best_d = d
			best = u.id
	return best


func _order_move(at: Vector2, show_marker: bool) -> bool:
	var origin := camera.project_ray_origin(at)
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, camera.project_ray_normal(at))
	if hit == null:
		return false
	var ground := _ground(hit)
	battle.command({"type": "move", "pos": ground})
	move_marker.global_position = Vector3(ground.x, 0.02, ground.y)
	if show_marker:
		_marker_left = 1.2
		sfx.play(&"ui")
	return true


func _read_steer() -> void:
	var input := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): input.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): input.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): input.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): input.x += 1.0
	var steer := Vector2.ZERO
	if input != Vector2.ZERO:
		var cam := camera.global_basis
		var forward := Vector2(-cam.z.x, -cam.z.z).normalized()
		var right := Vector2(cam.x.x, cam.x.z).normalized()
		steer = (right * input.x - forward * input.y).normalized()
	if steer != _steer:
		_steer = steer
		battle.command({"type": "steer", "vec": steer})


# --- Camera -------------------------------------------------------------------

func _follow_camera(delta: float) -> void:
	var leader_view: Node3D = views[battle.leader.id]
	camera_rig.global_position = camera_rig.global_position.lerp(leader_view.global_position, 1.0 - exp(-delta * 6.0))
	_place_camera()
	_trauma = maxf(0.0, _trauma - delta * 1.6)
	_shake_time += delta
	var amount := _trauma * _trauma if screen_shake else 0.0
	camera.h_offset = amount * 0.35 * sin(_shake_time * 37.0)
	camera.v_offset = amount * 0.3 * sin(_shake_time * 29.0 + 1.3)


func _place_camera() -> void:
	var pitch := deg_to_rad(camera.get_meta("pitch_deg", 38.0))
	camera.position = Vector3(0.0, sin(pitch), cos(pitch)) * camera_distance
	camera.look_at(camera_rig.global_position + Vector3(0.0, 0.6, 0.0), Vector3.UP)


func add_trauma(amount: float, cap: float = 1.0) -> void:
	if _trauma < cap:
		_trauma = minf(cap, _trauma + amount)


# --- Events -------------------------------------------------------------------

func _handle_events(events: Array[Dictionary]) -> void:
	for e: Dictionary in events:
		match e.type:
			"hit": _on_hit(e)
			"miss":
				_float(e.unit, "MISS", Color("c9c4b8"), 0.8)
				sfx.play(&"miss")
			"swing":
				var src: Battle.Unit = battle.unit(e.unit)
				if src.team == 0:
					sfx.play(&"swing", 0.06)
					_spawn_slash(src, battle.unit(e.target))
			"cast":
				var caster: Battle.Unit = battle.unit(e.unit)
				var step := int(e.get("step", 0))
				_spawn_at(GroundPulse, views[caster.id].global_position, Color("ffd479") if step == 0 else Color("ff9df0"))
				sfx.play(&"skill")
				var skill_name := Skills.skill_name(tuning, e.skill)
				if step > 0:
					_float(caster.id, "連招 %d　%s" % [step + 1, skill_name], Color("ffb3f2"), 1.15)
					hud.log_line("連招 %d／%d：%s！" % [step + 1, int(e.chain_len), skill_name])
					add_trauma(0.1, 0.3)
				else:
					hud.log_line("%s！" % skill_name)
			"chain_break":
				var why := {"cooldown": "還在冷卻", "too_far": "目標太遠", "tag_gone": "標記消失", "miss": "沒有命中",
					"whiff": "打空了", "moved": "移動取消", "dodge": "閃避預警"}
				hud.toast("連招中斷：%s %s" % [Skills.skill_name(tuning, e.skill), why.get(e.reason, e.reason)])
			"mastery_up":
				hud.log_line("%s 熟練度提升到 %d。" % [Skills.skill_name(tuning, e.skill), int(e.level)], "level")
				_float(e.unit, "熟練 Lv.%d" % int(e.level), Color("9fe0ff"), 0.9)
			"down": _on_down(e)
			"reward": _on_reward(e)
			"level_up":
				for m: Battle.Unit in battle.party():
					if m.alive:
						_spawn_at(LightPillar, views[m.id].global_position, Color("ffe7a3"))
				_float(battle.leader.id, "LEVEL UP!", Color("ffe08a"), 1.5)
				hud.log_line("等級提升至 Lv.%d！隊伍全員回復。" % e.level, "level")
				sfx.play(&"level_up", 0.0)
				haptics.buzz(1)
			"heal":
				_float(e.unit, "+%d" % e.amount, Color("9cf08a"), 1.0)
				_spawn_at(GroundPulse, views[e.unit].global_position, Color("9cf08a"))
				sfx.play(&"heal")
				if e.kind == "bandage":
					hud.log_line("%s 為 %s 包紮，回復 %d。" % [battle.support.display_name, battle.unit(e.unit).display_name, e.amount])
			"potion":
				_float(e.unit, "回復中", Color("9cf08a"), 0.9)
				sfx.play(&"potion")
				hud.log_line("%s 喝下回復藥水%s。" % [battle.unit(e.unit).display_name, "（自動）" if e.auto else ""])
			"taunt":
				_spawn_at(GroundPulse, views[e.unit].global_position, Color("8fd3ff"))
				_float(e.unit, "挑釁！", Color("8fd3ff"), 1.1)
				sfx.play(&"taunt")
			"blocked":
				if e.unit == battle.leader.id:
					hud.toast("路被擋住了")
					sfx.play(&"blocked")
			"refused": _on_refused(e)
			"quest_claimed":
				hud.log_line("委託回報：+%d EXP、+%d 金幣。" % [e.exp, e.gold], "loot")
				if battle.run.seal_receipts.has("quest:" + String(e.get("quest", ""))) and int(battle.run.seals) > 0:
					_announce_seals()
				hud.toast("委託完成")
				sfx.play(&"quest", 0.0)
				save_game()
				if hud.camp_open():
					refresh_camp()
			"auto":
				hud.toast("自動狩獵：開" if e.on else "自動狩獵：關")
			"leash":
				pass
			"run_ended":
				sfx.play(&"run_end", 0.0)
				haptics.buzz(2)
				add_trauma(0.6)
				_record_death()
			"telegraph":
				var warn: Node3D = GroundWarning.instantiate()
				effects.add_child(warn)
				warn.duration = float(e.warning_ms) / 1000.0
				warn.global_position = Vector3(e.center.x, 0.0, e.center.y)
				warn.scale = Vector3(e.radius, 1.0, e.radius)
				warn.play(Color("ff4a2e"))
				hud.toast("%s：%s！" % [battle.unit(e.unit).display_name, e.name])
				sfx.play(&"taunt")
			"boss_impact":
				_spawn_at(GroundPulse, Vector3(e.center.x, 0.0, e.center.y), Color("ff8a5c"))
				add_trauma(0.45)
				haptics.buzz(1)
				sfx.play(&"enemy_down")
			"dodge":
				_float(e.unit, "閃避！", Color("c9f0ff"), 0.9)
			"cover":
				_spawn_at(GroundPulse, views[e.unit].global_position, Color("8fd3ff"))
				_float(e.unit, "掩護！", Color("8fd3ff"), 1.1)
			"retreat_started":
				hud.toast("撤退中… 2 秒後回到營地" if e.reason == "manual" else "生命危險，自動撤退！")
				sfx.play(&"blocked")
			"retreated":
				for m: Battle.Unit in battle.party():
					_spawn_at(LightPillar, views[m.id].global_position, Color("9fe0ff"))
			"returned":
				_show_trip(e.trip)
				save_game()


func _on_hit(e: Dictionary) -> void:
	var dst: Battle.Unit = battle.unit(e.unit)
	var view: ActorView = views[dst.id]
	view.hurt(e.amount)
	var color := Color("fff3d6") if dst.team == 1 else Color("ff8a7a")
	var size := 1.0
	var text := str(e.amount)
	if e.crit:
		color = Color("ffb347") if dst.team == 1 else Color("ff5f4f")
		size = 1.45
		text += "!"
	if e.block:
		text = "格擋 " + text
		sfx.play(&"block")
	_float(dst.id, text, color, size)
	_spawn_at(HitBurst, view.global_position + Vector3(0.0, 0.9, 0.0), Color("ffe2a8") if not e.crit else Color("ffb347"))
	sfx.play(&"crit" if e.crit else &"hit")
	if dst == battle.leader:
		add_trauma(0.22 if not e.crit else 0.4, 0.5)
		haptics.buzz(0 if not e.crit else 1)
	elif e.crit and battle.unit(e.source).team == 0:
		time_control.hit_stop(0.05)
		add_trauma(0.12, 0.3)


func _on_down(e: Dictionary) -> void:
	var u: Battle.Unit = battle.unit(e.unit)
	if u.team == 1:
		sfx.play(&"enemy_down")
		time_control.hit_stop(0.06)
		haptics.buzz(0)
	else:
		hud.log_line("%s 倒下了。" % u.display_name, "warn")
		add_trauma(0.4)


func _on_reward(e: Dictionary) -> void:
	var m: Battle.Unit = battle.unit(e.unit)
	var text := "擊倒 %s：+%d EXP、+%d 金幣" % [m.display_name, int(e.exp), e.gold]
	if e.material != "":
		text += "、%s ×1" % tuning.items[e.material].name
		sfx.play(&"loot")
	if int(e.get("seals", 0)) > 0:
		_announce_seals()
	if e.get("gear", "") != "":
		var inst: Dictionary = battle.run.gear[e.gear]
		text += "、裝備「%s」" % camp_menu.gear_name(inst)
		_float(m.id, camp_menu.gear_name(inst), Color("ffd87a") if inst.quality == "plain" else Color("b48cff"), 1.0)
		sfx.play(&"quest", 0.0)
	hud.log_line(text, "loot")
	var tracked: Dictionary = tuning.quests[battle.tracked_quest]
	if battle.quest_ready() and m.kind_id == tracked.objective.target \
			and battle.run.quest_progress(battle.tracked_quest) == int(tracked.objective.count):
		hud.toast("委託達成，可以回報")


func _on_refused(e: Dictionary) -> void:
	var lines := {
		"retreat": {"in_camp": "已經在營地", "already": "撤退中"},
		"skill": {"no_target": "附近沒有可攻擊的敵人", "too_far": "目標太遠，靠近一點再施放"},
		"tonic": {"hot": "藥效還在持續", "none": "沒有回復藥水", "full": "生命已經全滿"},
		"emergency": {"cooldown": "急救包冷卻中", "none": "急救包用完了", "full": "生命已經全滿"},
		"claim": {"not_ready": "委託還沒完成", "not_in_camp": "回到營地才能回報委託"},
	}
	hud.toast(lines.get(e.what, {}).get(e.reason, "現在不能這麼做"))


func _float(unit_id: int, text: String, color: Color, size: float) -> void:
	if not damage_numbers and (text.is_valid_int() or text.ends_with("!")):
		return
	var label: Label3D = FloatingText.instantiate()
	effects.add_child(label)
	var view: Node3D = views[unit_id]
	label.global_position = view.global_position + Vector3(randf_range(-0.25, 0.25), 2.0, 0.0)
	label.text = text
	label.modulate = color
	label.scale = Vector3.ONE * size * 0.6
	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector3.ONE * size, 0.08)
	tween.parallel().tween_property(label, "position:y", label.position.y + 1.0, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "modulate:a", 0.0, 0.25)
	tween.tween_callback(label.queue_free)


func _spawn_at(scene: PackedScene, at: Vector3, color: Color) -> void:
	var fx: Node3D = scene.instantiate()
	effects.add_child(fx)
	fx.global_position = at
	fx.play(color)


func _spawn_slash(src: Battle.Unit, dst: Battle.Unit) -> void:
	if dst == null:
		return
	var fx: Node3D = SlashArc.instantiate()
	effects.add_child(fx)
	var from: Vector3 = views[src.id].global_position
	var to: Vector3 = views[dst.id].global_position
	fx.global_position = from.lerp(to, 0.6) + Vector3(0.0, 0.9, 0.0)
	fx.play(Color("fff1c9"), (to - from).x >= 0.0)


func _on_setting(key: String, value: bool) -> void:
	match key:
		"damage_numbers": damage_numbers = value
		"screen_shake": screen_shake = value
		"haptics": haptics.enabled = value


# --- HUD state ----------------------------------------------------------------

func hud_state() -> Dictionary:
	var party: Array = []
	for m: Battle.Unit in battle.party():
		party.append({"name": m.display_name, "hp": m.hp, "max": m.max_hp, "alive": m.alive, "hot": m.hot_left_ms > 0.0})
	var target := {}
	var t: Battle.Unit = battle.unit(battle.leader.target_id)
	if t != null and t.alive:
		target = {"name": t.display_name, "level": t.level, "hp": t.hp, "max": t.max_hp}
	var qid := battle.tracked_quest
	var q: Dictionary = tuning.quests[qid]
	var state: Dictionary = battle.run.quests[qid]
	var cooldown := maxf(0.0, (float(state.available_at_ms) - battle.now_ms) / 1000.0)
	var material_id: String = tuning.data.zones[0].material_id
	return {
		"level": battle.level, "exp": battle.experience, "exp_need": battle.xp_needed(), "gold": battle.gold,
		"material": battle.run.count(material_id),
		"party": party, "target": target,
		"quest": {"target_name": tuning.monsters[q.objective.target].name,
			"progress": battle.run.quest_progress(qid) if cooldown <= 0.0 else 0,
			"count": int(q.objective.count), "ready": battle.quest_ready(), "cooldown_s": cooldown,
			"exp": int(q.reward.exp), "gold": int(q.reward.gold)},
		"auto": battle.auto_hunt, "auto_potion": battle.auto_potion,
		"skill_cd": battle.skill_ready_in_ms(),
		"skill_total": battle.skill_cooldown_ms(battle.leader, battle.slot_skill(0)) if battle.slot_skill(0) != "" else 1.0,
		"skill_label": _skill_label(),
		"tonic": int(battle.inventory.get("tonic_small", 0)), "emergency": int(battle.inventory.get("emergency_kit", 0)),
		"emergency_cd": maxf(0.0, float(battle.leader.cooldowns.get("emergency_kit", 0.0)) - battle.now_ms),
		"ended": battle.ended, "status": _status(),
		"in_camp": battle.in_camp(battle.leader), "retreating": battle.retreating(),
	}


func _status() -> String:
	if battle.ended:
		return "冒險結束"
	if paused or portrait:
		return "暫停中"
	if battle.retreating():
		return "撤退中"
	if battle.in_camp(battle.leader) and battle.leader.order != Battle.Unit.Order.MOVE:
		return "營地（安全）"
	var leader := battle.leader
	if leader.steer != Vector2.ZERO or leader.order == Battle.Unit.Order.MOVE:
		return "移動中"
	var t: Battle.Unit = battle.unit(leader.target_id)
	if t != null and t.alive:
		return "攻擊 %s" % t.display_name
	return "自動狩獵：搜尋中" if battle.auto_hunt else "待命"


func _ground(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)


func _clock(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]


func _show_trip(trip: Dictionary) -> void:
	if int(trip.kills) == 0 and (trip.gear as Array).is_empty() and (trip.get("dealt", {}) as Dictionary).is_empty():
		return
	var lines := PackedStringArray(["擊倒 %d 隻 · +%d EXP · +%d 金幣" % [int(trip.kills), int(trip.exp), int(trip.gold)]])
	for item_id: String in trip.items:
		lines.append("%s ×%d" % [camp_menu.item_name(item_id), int(trip.items[item_id])])
	for gid: String in trip.gear:
		if battle.run.gear.has(gid):
			lines.append("裝備：%s" % camp_menu.gear_name(battle.run.gear[gid]))
	var used := PackedStringArray()
	for item_id: String in trip.used:
		used.append("%s ×%d" % [camp_menu.item_name(item_id), int(trip.used[item_id])])
	if not used.is_empty():
		lines.append("用掉：" + "、".join(used))
	lines.append_array(trip_damage_lines(trip))
	hud.show_trip("\n".join(lines))


## 本趟輸出（累積、有效傷害、不含溢出）by member and source, then damage taken and boss warnings.
## Trips saved before these stats existed have no keys and show nothing.
func trip_damage_lines(trip: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var dealt: Dictionary = trip.get("dealt", {})
	var total := 0.0
	for k: String in dealt:
		total += float(dealt[k])
	if total > 0.0:
		var names := {"leader": "隊長", "guardian": "盾衛", "support": "援護"}
		var parts := PackedStringArray()
		for role: String in ["leader", "guardian", "support"]:
			var mine := 0.0
			var by_source := PackedStringArray()
			for k: String in dealt:
				if k.begins_with(role + ":"):
					mine += float(dealt[k])
					var sid := k.get_slice(":", 1)
					by_source.append("%s %d%%" % ["普攻" if sid == "attack" else Skills.skill_name(tuning, sid),
						roundi(100.0 * float(dealt[k]) / total)])
			if mine > 0.0:
				parts.append("%s %d%%%s" % [names[role], roundi(100.0 * mine / total),
					"（%s）" % "、".join(by_source) if by_source.size() > 1 else ""])
		out.append("本趟輸出 %d：%s" % [roundi(total), " · ".join(parts)])
	var taken: Dictionary = trip.get("taken", {})
	if not taken.is_empty():
		out.append("承受：隊長 %d · 盾衛 %d · 援護 %d" % [roundi(float(taken.get("leader", 0.0))),
			roundi(float(taken.get("guardian", 0.0))), roundi(float(taken.get("support", 0.0)))])
	var w: Dictionary = trip.get("warned", {})
	if int(w.get("dodged", 0)) + int(w.get("hit", 0)) > 0:
		out.append("守層者預警：閃過 %d · 被擊中 %d" % [int(w.dodged), int(w.hit)])
	return out


## Tombstone first, then the profile (memorial, generation) and a save with no live run.
func _record_death() -> void:
	save_service.mark_dead(battle.run.id)
	var killer := ""
	var leader := battle.leader
	if battle.unit(leader.last_attacker) != null:
		killer = battle.unit(leader.last_attacker).display_name
	profile.record_death(battle.run, killer)
	save_game()


## "裂空斬 +2" for the chain in slot 1.
func _skill_label() -> String:
	var head := battle.slot_skill(0)
	if head == "":
		return "技能\nQ"
	var chain := Skills.chain(battle.run, "leader")
	var name := Skills.skill_name(tuning, head)
	return ("%s +%d\nQ" % [name, chain.size() - 1]) if chain.size() > 1 else ("%s\nQ" % name)


func _announce_seals() -> void:
	hud.toast("獲得連攜印（共 %d）：到營地「技能」頁串連招" % int(battle.run.seals))
	sfx.play(&"level_up", 0.0)
