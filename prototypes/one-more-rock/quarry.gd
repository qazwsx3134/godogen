extends Node3D

const Inventory = preload("res://quarry_inventory.gd")
const Player = preload("res://player.gd")
const Workbench = preload("res://workbench.gd")
const StockPile = preload("res://stock_pile.gd")
const PickupOre := preload("res://scenes/pickup_ore.tscn")
const MinedGlint := preload("res://assets/mined_glint.tres")
const SpecimenShelf = preload("res://specimen_shelf.gd")
const RockVolume = preload("res://rock_volume.gd")
const EmbeddedMineral = preload("res://embedded_mineral.gd")
const MineralScene := preload("res://scenes/embedded_mineral.tscn")
const Excavation = preload("res://excavation.gd")
const Debris = preload("res://excavation_debris.gd")
const Automation = preload("res://quarry_automation.gd")
const Upgrades = preload("res://workshop_upgrades.gd")
const WorkshopMenu = preload("res://workshop_menu.gd")
const ROUTE_ARROWS: Array[String] = ["↑", "↗", "→", "↘", "↓", "↙", "←", "↖"]
const DRAG_THRESHOLD := 10.0
const DRILL_INTERVAL := 0.21
const POWER_COOLDOWN := 8.0
const UPGRADED_PACK_CAPACITY := 10
const UPGRADED_STORAGE_CAPACITY := 60

enum Action { NONE, MINE, PICK_RARE, HITCH, PARK, UPGRADE, COLLECTION }

@export_range(0.25, 1.0, 0.005) var mine_interval := 0.56
@export_range(0.5, 3.0, 0.05) var pickup_radius := 2.10
@export_range(0.5, 3.0, 0.05) var unload_radius := 1.85
@export var mining_particles := true
@export var mining_haptics := true

@onready var player: Player = %Player
@onready var bench: Workbench = %Workbench
@onready var cart: StaticBody3D = %Cart
@onready var load_groups: Node3D = cart.get_node("%LoadGroups")
@onready var cart_body: Node3D = cart.get_node("%CartBody")
@onready var cart_socket: Marker3D = cart.get_node("%CartSocket")
@onready var workshop_entry: Area3D = %WorkshopEntry
@onready var workshop_exit: Marker3D = %WorkshopExit
@onready var unload_box: StaticBody3D = %UnloadBox
@onready var stock_pile: StockPile = unload_box.get_node("%StockPile")
@onready var upgrade: StaticBody3D = %PackUpgrade
@onready var excavation: Excavation = %Excavation
@onready var controls: Control = %Controls
@onready var leave_button: Button = %Leave
@onready var action_button: Button = %Action
@onready var rotate_hint: Control = %RotateHint
@onready var run_button: Button = %Run
@onready var jump_button: Button = %Jump
@onready var power_button: Button = %PowerMine
@onready var shelf: SpecimenShelf = %Shelf
@onready var route: Label = %Route
@onready var crosshair: Label = %Crosshair
@onready var crosshair_color := crosshair.get_theme_color("font_color")
@onready var mining_waypoint: Marker3D = %MiningWaypoint
@onready var workshop: WorkshopMenu = %WorkshopMenu
@onready var automation: Automation = %Automation

var inventory := Inventory.new()
var exposed_minerals: Dictionary[RockVolume, EmbeddedMineral] = {}
var cuts_to_mineral := 3
var next_mineral := 2
var upgrades := Upgrades.new()
var workshop_mouse := Input.MOUSE_MODE_VISIBLE
var workshop_touch_emulation := false
var at_bench := false
var pushing := false
var unloading := false
var mobile := false
var stick_finger := -1
var action_finger := -1
var look_finger := -1
var movement_buttons: Array[int] = []
var stick_origin := Vector2.ZERO
var look_origin := Vector2.ZERO
var looking := false
var mouse_swing := false
var touch_swing := false
var mine_delay := 0.0
var power_remaining := 0.0
var drill_boost := 0.0
var status_time := 0.0
var proximity_delay := 0.0
var in_unload_zone := false
var near_dropped_ore := false
var view_clearance := 2.5
var bonus_ore := 0
var pickup_flight_time := 0.62


func _enter_tree() -> void:
	# The child resets its station in _ready, so give it its stock source first.
	var workbench: Workbench = %Workbench
	workbench.take_raw_stone = _take_stored


func _ready() -> void:
	bench.set_station_active(false)
	workshop_entry.body_entered.connect(_on_workshop_entry)
	player.eyes.make_current()
	mobile = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	leave_button.pressed.connect(_leave_bench)
	action_button.button_down.connect(_begin_action)
	action_button.button_up.connect(_end_action)
	run_button.pressed.connect(_toggle_run)
	jump_button.pressed.connect(player.request_jump)
	power_button.pressed.connect(_use_power_mine)
	bench.wallet_displayed_changed.connect(func(_total: int): _update_stock_label())
	bench.specimen_opened.connect(_on_specimen_opened)
	bench.sample_collected.connect(shelf.register_sample)
	bench.coins_changed.connect(func(_total: int): _refresh_workshop())
	workshop.close_requested.connect(_close_workshop)
	workshop.purchase_requested.connect(_purchase_upgrade)
	workshop.tool_requested.connect(_equip_mining_tool)
	workshop.automation_toggled.connect(_toggle_automation)
	automation.inventory = inventory
	automation.excavation = excavation
	automation.stock_pile = stock_pile
	automation.inventory_changed.connect(_update_inventory)
	automation.ore_delivered.connect(func(): %UnloadSound.play())
	automation.ore_crushed.connect(_pay_automatic_ore)
	get_viewport().size_changed.connect(_layout_changed)
	_layout_changed()
	_update_inventory()
	_update_route()
	for rock: RockVolume in get_tree().get_nodes_in_group("quarry_rock"):
		rock.chipped.connect(_rock_chipped)
		rock.detached.connect(excavation.spawn_section)
	excavation.ore_landed.connect(_landslide)
	excavation.section_unstable.connect(_warn_collapse)
	# ponytail: first-ever dust draw renders black for one frame; burst once out of sight to warm it up.
	for burst: CPUParticles3D in [%MiningDust, %CollapseDust]:
		burst.global_position = player.global_position + Vector3.DOWN * 30.0
		burst.restart()
	if OS.is_debug_build() and (OS.has_feature("editor") or OS.has_feature("developer")):
		load("res://quarry_dev_panel.gd").mount(self)


func _physics_process(delta: float) -> void:
	power_remaining = maxf(0.0, power_remaining - delta)
	var power_label := "礦震 %.1f" % power_remaining if power_remaining > 0.0 else ("礦震" if mobile else "右鍵　礦震")
	if power_button.text != power_label:
		power_button.text = power_label
		power_button.disabled = power_remaining > 0.0
	if at_bench or rotate_hint.visible or workshop.visible:
		return
	if pushing:
		_cart_follow()
	proximity_delay -= delta
	if proximity_delay <= 0.0:
		proximity_delay = 0.10
		_check_proximity()
		_update_route()
	var target := _aimed_target()
	player.settle_pickaxe(0.55 if target == shelf else view_clearance, delta)
	var held := mouse_swing or touch_swing
	if player.using_drill:
		_drive_drill(held, delta)
	elif held:
		mine_delay -= delta
		if mine_delay <= 0.0 and not player.swinging:
			_swing()
			mine_delay = _swing_interval()
	if status_time > 0.0:
		status_time -= delta
	_show_context(target)


func _input(event: InputEvent) -> void:
	if workshop.visible:
		if event.is_action_pressed("ui_cancel"):
			_close_workshop()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		mouse_swing = false
	if rotate_hint.visible and not event is InputEventScreenTouch:
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		if at_bench:
			_leave_bench()
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			_clear_touch()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if not mobile:
				mobile = true
				_layout_changed()
			if rotate_hint.visible:
				get_viewport().set_input_as_handled()
			elif at_bench and leave_button.get_global_rect().has_point(event.position):
				_leave_bench()
				get_viewport().set_input_as_handled()
			elif run_button.is_visible_in_tree() and run_button.get_global_rect().has_point(event.position):
				movement_buttons.append(event.index)
				_toggle_run()
				get_viewport().set_input_as_handled()
			elif jump_button.is_visible_in_tree() and jump_button.get_global_rect().has_point(event.position):
				movement_buttons.append(event.index)
				player.request_jump()
				get_viewport().set_input_as_handled()
			elif power_button.is_visible_in_tree() and power_button.get_global_rect().has_point(event.position):
				movement_buttons.append(event.index)
				_use_power_mine()
				get_viewport().set_input_as_handled()
			elif action_button.is_visible_in_tree() and action_button.get_global_rect().has_point(event.position):
				if action_finger == -1 and not action_button.disabled:
					action_finger = event.index
					_begin_action()
				get_viewport().set_input_as_handled()
		elif movement_buttons.has(event.index):
			movement_buttons.erase(event.index)
			get_viewport().set_input_as_handled()
		elif event.index == action_finger:
			action_finger = -1
			_end_action()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and (event.index == action_finger or movement_buttons.has(event.index)):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if at_bench or rotate_hint.visible or workshop.visible:
		return
	if event is InputEventScreenTouch:
		_touch(event)
	elif event is InputEventScreenDrag:
		_drag(event)
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.look(event.relative, false)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		mouse_swing = true
		_swing()
		mine_delay = 0.13 if player.using_drill else _swing_interval()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_use_power_mine()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("jump"):
		player.request_jump()
	elif event.is_action_pressed("interact"):
		_begin_action(false)
	elif event.is_action_released("interact"):
		_end_action()


func _touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		var size := get_viewport().get_visible_rect().size
		if event.position.x < size.x * 0.5 and event.position.y > size.y * 0.55:
			if stick_finger == -1:
				stick_finger = event.index
				stick_origin = event.position
				%Stick.position = stick_origin - controls.global_position - %Stick.size * 0.5
				%Stick.show()
		elif event.position.x >= size.x * 0.5 and look_finger == -1:
			look_finger = event.index
			look_origin = event.position
			looking = false
	elif event.index == stick_finger:
		stick_finger = -1
		player.touch_move = Vector2.ZERO
		%Stick.hide()
	elif event.index == look_finger:
		look_finger = -1


func _drag(event: InputEventScreenDrag) -> void:
	if event.index == stick_finger:
		var travel := (event.position - stick_origin).limit_length(65.0)
		player.touch_move = travel / 65.0 if travel.length() >= 7.0 else Vector2.ZERO
		%Knob.position = (%Stick.size - %Knob.size) * 0.5 + travel * 0.48
	elif event.index == look_finger:
		if looking or event.position.distance_to(look_origin) > DRAG_THRESHOLD:
			looking = true
			player.look(event.relative, true)


func _aimed_target() -> PhysicsBody3D:
	return _aim_hit().get("collider") as PhysicsBody3D


func _aim_hit() -> Dictionary:
	var direct := player.hit_at(get_viewport().get_visible_rect().get_center())
	view_clearance = 2.5 if direct.is_empty() else player.eyes.global_position.distance_to(direct.position)
	return direct


func _action_for(target: PhysicsBody3D) -> Action:
	if target is RockVolume or target is EmbeddedMineral:
		return Action.MINE
	if target is Debris and target.rare and target.usable():
		return Action.PICK_RARE
	if target == cart and not pushing:
		return Action.HITCH
	if target == upgrade:
		return Action.UPGRADE
	if target == shelf:
		return Action.COLLECTION
	return Action.PARK if pushing and not unloading else Action.NONE


func _begin_action(allow_swing := true) -> void:
	if at_bench or rotate_hint.visible:
		return
	var target := _aimed_target()
	match _action_for(target):
		Action.NONE, Action.MINE:
			if allow_swing:
				touch_swing = true
				_swing()
				mine_delay = 0.13 if player.using_drill else _swing_interval()
		Action.PICK_RARE:
			if not _collect_piece(target, 0):
				_feedback("推車已滿" if pushing else "背包已滿")
		Action.HITCH:
			pushing = true
			cart.collision_layer = 0
			_feedback("已接上推車")
		Action.PARK:
			_park_cart()
		Action.UPGRADE:
			_open_workshop()
		Action.COLLECTION:
			_feedback("已收錄 %d／%d 種礦物" % [shelf.collected, shelf.displays.get_child_count()])
	if not at_bench:
		_show_context(_aimed_target())


func _end_action() -> void:
	touch_swing = false


func _swing() -> void:
	if player.using_drill:
		mine_delay = 0.13
	else:
		player.swing_pickaxe(_pickaxe_aim, _mine_impact, view_clearance)


func _swing_interval() -> float:
	return DRILL_INTERVAL if player.using_drill else mine_interval


func _drive_drill(held: bool, delta: float) -> void:
	var boosted := drill_boost > 0.0
	drill_boost = maxf(0.0, drill_boost - delta)
	if not held and not boosted:
		player.stop_drill()
		return
	var hit := _pickaxe_aim()
	player.drive_drill(hit, delta)
	if not held or hit.is_empty():
		return
	mine_delay -= delta
	if mine_delay <= 0.0:
		_mine_impact(hit)
		mine_delay = DRILL_INTERVAL


func _use_power_mine() -> void:
	if power_remaining > 0.0 or at_bench or workshop.visible or rotate_hint.visible or player.swinging:
		return
	var hit := _pickaxe_aim()
	if hit.is_empty():
		_feedback("瞄準岩面使用礦震")
		return
	if player.using_drill:
		power_remaining = POWER_COOLDOWN
		drill_boost = 0.38
		mine_delay = DRILL_INTERVAL
		_mine_impact(hit, true)
	else:
		player.swing_pickaxe(_pickaxe_aim, _power_impact, view_clearance, true)


func _power_impact(hit: Dictionary) -> void:
	power_remaining = POWER_COOLDOWN
	_mine_impact(hit, true)


func _pickaxe_aim() -> Dictionary:
	var hit := player.mining_hit()
	var target: Object = hit.get("collider")
	return hit if target is RockVolume or target is EmbeddedMineral else {}


func _mine_impact(hit: Dictionary, heavy := false) -> void:
	var target: Node3D = hit.collider
	if not is_instance_valid(target):
		return
	var contact: Vector3 = hit.position
	var normal: Vector3 = hit.normal
	var power := 3 if heavy else player.mining_power
	if target is EmbeddedMineral:
		_strike_mineral(target, contact, power)
	else:
		if heavy or not player.using_drill:
			%MineSound.pitch_scale = 0.67 if heavy else randf_range(0.86, 1.12)
			%MineSound.play()
		var rock := target as RockVolume
		if rock.chip(contact, normal, power):
			var exposed: EmbeddedMineral = exposed_minerals.get(rock)
			if is_instance_valid(exposed) and not rock.solid.has(exposed.anchor_cell):
				_release_mineral(exposed, exposed.global_position)
			if not exposed_minerals.has(rock):
				cuts_to_mineral = maxi(0, cuts_to_mineral - 1)
				if cuts_to_mineral == 0:
					_expose_mineral(rock, contact, player.eyes.global_position)
	if mining_particles:
		for burst: CPUParticles3D in [%MiningChips, %MiningDust]:
			burst.scale = Vector3.ONE * (1.55 if heavy else 1.0)
			burst.global_position = contact + normal * 0.04
			burst.direction = (normal + Vector3.UP * 0.38).normalized()
			burst.restart()
	player.kick(2.4 if heavy else (0.36 if player.using_drill else float(player.mining_power)))
	var pulse := crosshair.create_tween()
	pulse.tween_property(crosshair, "scale", Vector2.ONE, 0.14).from(Vector2.ONE * 1.45)
	if mobile and mining_haptics:
		Input.vibrate_handheld(45 if heavy else (10 if player.using_drill else 22))


func _rock_chipped(point: Vector3, normal: Vector3, amount: int) -> void:
	excavation.spawn_ore(point, normal, amount + bonus_ore)
	var cues := create_tween()
	cues.tween_interval(0.045)
	cues.tween_callback(%RockBreakSound.play)
	cues.tween_interval(0.085)
	cues.tween_callback(%OreFoundSound.play)


func _expose_mineral(rock: RockVolume, contact: Vector3, view_origin: Vector3) -> void:
	# The original and fractured collision shapes swap after the current physics step.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if cuts_to_mineral != 0 or not is_instance_valid(rock) or exposed_minerals.has(rock):
		return
	var approach := view_origin.direction_to(contact)
	var tangent := approach.cross(Vector3.UP if absf(approach.y) < 0.9 else Vector3.RIGHT).normalized()
	var vertical := tangent.cross(approach)
	for offset: Vector3 in [Vector3.ZERO, tangent * 0.25, -tangent * 0.25, vertical * 0.22, -vertical * 0.22]:
		var through := contact + offset
		var end := through + view_origin.direction_to(through) * (2.3 * rock.cell_size)
		var ray := PhysicsRayQueryParameters3D.create(view_origin, end, 4)
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.get("collider") != rock:
			continue
		var point: Vector3 = hit.position
		var face_normal: Vector3 = hit.normal
		if (point - contact).dot(approach) < 0.12 or face_normal.dot(approach) > -0.25:
			continue
		if rock.shape_owner_get_owner(rock.shape_find_owner(hit.shape)) == rock.collider:
			continue
		var anchor := rock._hit_cell(rock.to_local(point - face_normal * 0.045))
		if not rock.solid.has(anchor):
			continue
		var mineral := MineralScene.instantiate() as EmbeddedMineral
		mineral.mineral = next_mineral
		mineral.anchor_cell = anchor
		rock.add_child(mineral)
		var up := Vector3.UP if absf(face_normal.y) < 0.9 else Vector3.RIGHT
		mineral.global_transform = Transform3D(Basis.looking_at(-face_normal, up), point)
		exposed_minerals[rock] = mineral
		cuts_to_mineral = 8
		next_mineral = 5 - mineral.mineral
		return


func _strike_mineral(mineral: EmbeddedMineral, contact: Vector3, power: int) -> void:
	%MineralImpactSound.pitch_scale = randf_range(0.91, 1.08)
	%MineralImpactSound.play()
	%CrystalOreSound.pitch_scale = 0.88 if mineral.mineral == 2 else 1.08
	%CrystalOreSound.play()
	if mineral.strike(power):
		_release_mineral(mineral, contact)


func _release_mineral(mineral: EmbeddedMineral, point: Vector3) -> void:
	exposed_minerals.erase(mineral.get_parent())
	excavation.spawn_ore(point, mineral.global_basis.z, 1, mineral.mineral)
	mineral.retire()


func _warn_collapse(point: Vector3, normal: Vector3) -> void:
	if not _within(point, 12.0):
		return
	_feedback("岩層鬆動！")
	if mining_particles:
		%CollapseDust.global_position = point
		%CollapseDust.direction = (normal * 0.7 + Vector3.DOWN).normalized()
		%CollapseDust.restart()


func _landslide(point: Vector3, _amount: int) -> void:
	if _within(point, 12.0):
		_feedback("岩塊落地碎裂")
	var sound := %CollapseSound as AudioStreamPlayer3D
	if not sound.playing:
		sound.global_position = point
		sound.play()


func _collect_piece(piece: Debris, index: int) -> bool:
	var using_cart := pushing
	if not piece.usable() or not inventory.reserve_collection(using_cart):
		return false
	var pose := piece.global_transform
	var rare := piece.rare
	var mineral := piece.mineral
	excavation.retire(piece)
	_float_ore(pose, using_cart, rare, index, mineral)
	return true


func _float_ore(pose: Transform3D, using_cart: bool, rare: bool, index: int, mineral: int) -> void:
	var piece := PickupOre.instantiate() as Node3D
	if rare:
		(piece.get_node("Ore") as MeshInstance3D).material_overlay = MinedGlint
	add_child(piece)
	piece.global_transform = pose
	var origin := pose.origin
	var destination := cart_socket if using_cart else player.pack_socket
	var flight := piece.create_tween()
	flight.tween_method(func(t: float):
		var goal := destination.global_position
		var apex := Vector3(origin.x, maxf(origin.y + 1.78, goal.y + 0.38), origin.z)
		if t < 0.37:
			piece.global_position = origin.lerp(apex, ease(t / 0.37, 0.56))
		else:
			piece.global_position = apex.lerp(goal, (t - 0.37) / 0.63)
		piece.global_basis = Basis.from_euler(Vector3(t * 4.4, t * 7.1, t * 2.7)) * pose.basis
	, 0.0, 1.0, pickup_flight_time).set_delay(index * 0.065)
	flight.tween_callback(func():
		inventory.finish_collection(using_cart, rare, mineral)
		if not %PickupSound.playing:
			%PickupSound.play()
		if index == 0:
			_feedback("已收取含礦原石" if mineral >= 2 else ("已收取稀有原石" if rare
				else ("原石已裝入推車" if using_cart else "原石已收入背包")))
		_update_inventory()
		piece.queue_free()
	)


func _check_proximity() -> void:
	for rock: RockVolume in get_tree().get_nodes_in_group("quarry_rock"):
		if rock.near(player.global_position, 6.0):
			rock.prepare()
	near_dropped_ore = false
	var batch := 0
	for piece in excavation.loose.duplicate():
		if not piece.usable() or absf(piece.global_position.y - player.global_position.y) > 1.8:
			continue
		var ore_position: Vector3 = piece.global_position
		if _within(ore_position, 3.0):
			near_dropped_ore = true
			if not piece.rare and inventory.has_room(pushing) and _within(ore_position, pickup_radius) and _ore_reachable(ore_position):
				if _collect_piece(piece, batch):
					batch += 1

	var at_box := _within(unload_box.global_position, unload_radius)
	if at_box and not unloading:
		if _unload() == 0 and not in_unload_zone:
			if not inventory.has_storage_room():
				_feedback("倉庫已滿，原石留在身上")
			else:
				_feedback("已到卸貨點")
	in_unload_zone = at_box


func _ore_reachable(ore_position: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(player.eyes.global_position, ore_position, 4)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func _update_route() -> void:
	var title := "岩山採石場"
	var destination := mining_waypoint.global_position
	if not inventory.pack.is_empty() or inventory.reserved_pack > 0 or (pushing and (not inventory.cart.is_empty() or inventory.reserved_cart > 0)):
		title = "工坊卸貨"
		destination = unload_box.global_position
	elif not inventory.storage.is_empty() and _within(workshop_entry.global_position, 16.0):
		title = "小屋破石台"
		destination = workshop_entry.global_position
	var offset := destination - player.global_position
	offset.y = 0
	var distance := offset.length()
	if distance < 2.3:
		route.text = title
		return
	var heading := player.global_basis.inverse() * offset
	var direction := posmod(roundi(atan2(heading.x, -heading.z) / (TAU / 8.0)), ROUTE_ARROWS.size())
	route.text = "%s　%s  %d m" % [ROUTE_ARROWS[direction], title, roundi(distance)]


func _within(point: Vector3, radius: float) -> bool:
	var offset := player.global_position - point
	return Vector2(offset.x, offset.z).length_squared() <= radius * radius


func _unload() -> int:
	var cart_before := inventory.cart.size()
	var cart_present := pushing or cart.global_position.distance_to(unload_box.global_position) < 2.6
	var moved := inventory.unload(cart_present)
	if moved == 0:
		return 0
	unloading = true
	_feedback("已入庫 %d 顆原石" % moved)
	%UnloadSound.play()
	var from_cart := cart_before - inventory.cart.size()
	var hand := player.global_position + Vector3.UP * 1.0 - player.basis.z * 0.55
	stock_pile.set_count(inventory.storage.size(), hand, cart_socket.global_position, from_cart)
	_update_inventory()
	var tilt := create_tween()
	if from_cart > 0:
		tilt.tween_property(cart_body, "rotation:x", -0.38, 0.14)
		tilt.tween_property(cart_body, "rotation:x", 0.0, 0.30)
	else:
		tilt.tween_interval(0.44)
	tilt.tween_callback(func(): unloading = false)
	return moved


func _open_workshop() -> void:
	if workshop.visible:
		return
	_clear_touch()
	player.cancel_swing()
	player.walking = false
	controls.hide()
	workshop_mouse = Input.mouse_mode
	workshop_touch_emulation = Input.emulate_mouse_from_touch
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_workshop()
	workshop.present()
	_enable_workshop_touch.call_deferred()


func _enable_workshop_touch() -> void:
	if workshop.visible:
		Input.emulate_mouse_from_touch = true


func _close_workshop() -> void:
	workshop.hide()
	Input.emulate_mouse_from_touch = workshop_touch_emulation
	Input.mouse_mode = workshop_mouse
	player.walking = not (at_bench or rotate_hint.visible)
	controls.visible = not at_bench


func _exit_tree() -> void:
	if is_node_ready() and workshop.visible:
		Input.emulate_mouse_from_touch = workshop_touch_emulation
		Input.mouse_mode = workshop_mouse


func _refresh_workshop() -> void:
	workshop.refresh(upgrades, bench.coins, player.using_drill, automation.collector_enabled, automation.crusher_enabled)


func _purchase_upgrade(id: StringName) -> void:
	if not workshop.visible or not upgrades.can_purchase(id, bench.coins):
		return
	var item: Dictionary = Upgrades.ITEMS[id]
	if not bench.spend_coins(int(item.cost)):
		return
	upgrades.owned[id] = true
	match id:
		&"steel_hammer": bench.set_hammer_level(2)
		&"diamond_hammer": bench.set_hammer_level(3)
		&"finishing": bench.finishing_level = 1
		&"polishing": bench.finishing_level = 2
		&"steel_pick": player.equip_mining_tool(false)
		&"drill": player.equip_mining_tool(true)
		&"bag": inventory.pack_capacity = UPGRADED_PACK_CAPACITY
		&"bin": inventory.storage_capacity = UPGRADED_STORAGE_CAPACITY
		&"cart_rack": inventory.cart_capacity = 30
		&"ore_yield": bonus_ore = 1
		&"ore_yield_2": bonus_ore = 2
		&"pickup_reach": pickup_radius = 3.0
		&"fast_pickup": pickup_flight_time = 0.36
		&"running_boots": player.run_speed = 8.6
		&"spring_boots": player.jump_speed = 6.45
		&"robot":
			automation.collector.show()
			automation.enable_collector(true)
		&"crusher": automation.unlock_crusher(1)
		&"crusher_steel": automation.unlock_crusher(2)
		&"crusher_diamond": automation.unlock_crusher(3)
	_update_inventory()
	_refresh_workshop()
	%PickupSound.play()


func _equip_mining_tool(drill: bool) -> void:
	if workshop.visible and upgrades.owned.has(&"drill" if drill else &"steel_pick"):
		player.equip_mining_tool(drill)
		_refresh_workshop()


func _toggle_automation(id: StringName) -> void:
	if not workshop.visible or not upgrades.owned.has(id):
		return
	match id:
		&"robot": automation.enable_collector(not automation.collector_enabled)
		&"crusher": automation.enable_crusher(not automation.crusher_enabled)
	_refresh_workshop()


func _pay_automatic_ore(hardness: int, mineral: int) -> void:
	var result := mineral if mineral >= 2 else bench.roll_mineral(hardness)
	bench.credit_coins(int(Workbench.LOOT[result].price))


func _cart_follow() -> void:
	# Turn in place with the player. Stop the visual before solid geometry.
	var from := player.global_position + Vector3.UP * 0.62
	var goal := from - player.basis.z * 1.55
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, goal, 4))
	if not hit.is_empty():
		goal = from.lerp(hit.position, 0.62)
	var down := PhysicsRayQueryParameters3D.create(
		Vector3(goal.x, player.global_position.y + 0.35, goal.z),
		Vector3(goal.x, player.global_position.y - 6.0, goal.z), 4
	)
	var floor_hit := get_world_3d().direct_space_state.intersect_ray(down)
	var floor_height: float = cart.global_position.y if floor_hit.is_empty() else floor_hit.position.y
	cart.global_position = Vector3(goal.x, floor_height, goal.z)
	cart.rotation.y = player.rotation.y


func _park_cart() -> void:
	if not pushing or unloading:
		return
	pushing = false
	cart.collision_layer = 2
	_feedback("已停放推車")
	_update_inventory()


func _on_workshop_entry(body: Node3D) -> void:
	if body == player and not at_bench and not workshop.visible and not rotate_hint.visible:
		if pushing:
			_park_cart()
		_enter_bench()


func _enter_bench() -> void:
	at_bench = true
	player.walking = false
	player.cancel_swing()
	player.pickaxe.hide()
	_clear_touch()
	controls.hide()
	_set_workshop_signs(false)
	leave_button.show()
	bench.set_station_active(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_update_inventory()


func _leave_bench() -> void:
	at_bench = false
	bench.set_station_active(false)
	player.global_position = workshop_exit.global_position
	player.velocity = Vector3.ZERO
	player.eyes.make_current()
	player.pickaxe.show()
	leave_button.hide()
	controls.show()
	_set_workshop_signs(true)
	player.walking = not rotate_hint.visible
	_update_inventory()
	if not mobile:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _set_workshop_signs(shown: bool) -> void:
	for child in unload_box.get_children():
		if child is Label3D:
			child.visible = shown
	upgrade.get_node("Sign").visible = shown


func _take_stored() -> int:
	var id := inventory.take_stored(bench.hit_power) if is_node_ready() else -1
	if is_node_ready():
		bench.waiting_hardness = 0
		if id == -1:
			for remaining: int in inventory.storage:
				var hardness := inventory.stone_hardness(remaining)
				bench.waiting_hardness = hardness if bench.waiting_hardness == 0 else mini(hardness, bench.waiting_hardness)
		else:
			bench.source_hardness = inventory.stone_hardness(id)
			bench.source_mineral = inventory.take_known_mineral(id)
		_update_inventory()
	return id


func _update_stock_label() -> void:
	%Stock.text = "背包 %d／%d    推車 %d／%d    倉庫 %d／%d    %d 幣" % [
		inventory.pack.size(), inventory.pack_capacity, inventory.cart.size(),
		inventory.cart_capacity, inventory.storage.size(), inventory.storage_capacity, bench.displayed_coins]


func _update_inventory() -> void:
	_update_stock_label()
	var groups := ceili(float(inventory.cart.size() * load_groups.get_child_count()) / inventory.cart_capacity)
	for index in load_groups.get_child_count():
		load_groups.get_child(index).visible = index < groups
	stock_pile.set_count(inventory.storage.size())


func _on_specimen_opened(_item: String) -> void:
	stock_pile.scatter_fragments(bench.stone.global_position)
	if inventory.storage.is_empty():
		bench.play_stock_clear()


func _show_context(target: PhysicsBody3D) -> void:
	var verb := ""
	var action := _action_for(target)
	var aiming_at_ore := action == Action.MINE or action == Action.PICK_RARE
	var reticle := "○" if aiming_at_ore else "·"
	if crosshair.text != reticle:
		crosshair.text = reticle
		crosshair.add_theme_color_override("font_color", Color("ffdf9e") if aiming_at_ore else crosshair_color)
	match action:
		Action.MINE:
			if target is EmbeddedMineral:
				verb = "採挖露出的礦片" if mobile else "左鍵　採挖露出的礦片"
			else:
				verb = ("按住鑽掘" if mobile else "按住左鍵　鑽掘") if player.using_drill else ("揮鎬" if mobile else "左鍵　敲擊岩石")
		Action.PICK_RARE: verb = "拾取原石"
		Action.HITCH: verb = "接上推車"
		Action.PARK: verb = "停放推車"
		Action.UPGRADE: verb = "工坊升級"
		Action.COLLECTION: verb = "查看圖鑑架"
	# Keep the current press labeled until release, even if that hit exhausts the rock.
	if action_finger == -1:
		var tool_action := "按住鑽掘" if player.using_drill else "揮鎬"
		action_button.text = tool_action if verb.is_empty() else verb
	%Prompt.visible = status_time > 0.0 or not mobile or verb.is_empty()
	if status_time > 0.0:
		return
	if not verb.is_empty():
		%Prompt.text = verb if action == Action.MINE else "E  %s" % verb
	elif target == unload_box:
		%Prompt.text = "走入卸貨區自動入庫"
	elif near_dropped_ore:
		%Prompt.text = "靠近挖下來的礦塊" if inventory.has_room(pushing) else ("推車已滿" if pushing else "背包已滿")
	else:
		%Prompt.hide()


func _feedback(message: String) -> void:
	%Prompt.show()
	%Prompt.text = message
	status_time = 1.1


func _layout_changed() -> void:
	_clear_touch()
	bench.cancel_held_strike()
	var size := get_viewport().get_visible_rect().size
	rotate_hint.visible = mobile and size.y > size.x
	if rotate_hint.visible and workshop.visible:
		_close_workshop()
	stock_pile.set_mobile(mobile)
	excavation.body_budget = 32 if mobile else 90
	excavation.falling_budget = 4 if mobile else 8
	if OS.has_feature("mobile") and not OS.has_feature("web"):
		var safe := DisplayServer.get_display_safe_area()
		if safe.has_area():
			var to_viewport := get_viewport().get_screen_transform().affine_inverse()
			var top_left := to_viewport * Vector2(safe.position)
			var bottom_right := to_viewport * Vector2(safe.end)
			var layout := controls.get_parent() as Control
			layout.offset_left = maxf(0.0, top_left.x)
			layout.offset_top = maxf(0.0, top_left.y)
			layout.offset_right = minf(0.0, bottom_right.x - size.x)
			layout.offset_bottom = minf(0.0, bottom_right.y - size.y)
	player.walking = not (at_bench or rotate_hint.visible or workshop.visible)
	action_button.visible = mobile
	power_button.show()
	run_button.visible = mobile
	jump_button.visible = mobile
	%Help.text = "左下移動　右側轉向　點擊或按住採礦" if mobile else "WASD 移動　左鍵採礦　右鍵礦震　E 互動　Shift 跑步"
	%Help.visible = true


func _toggle_run() -> void:
	player.touch_running = not player.touch_running
	run_button.text = "走路" if player.touch_running else "跑步"


func _clear_touch() -> void:
	stick_finger = -1
	action_finger = -1
	look_finger = -1
	movement_buttons.clear()
	mouse_swing = false
	drill_boost = 0.0
	player.stop_drill()
	player.touch_running = false
	player.jump_requested = false
	run_button.text = "跑步"
	_end_action()
	%Stick.hide()
	%Knob.position = (%Stick.size - %Knob.size) * 0.5
	player.touch_move = Vector2.ZERO


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		_clear_touch()
