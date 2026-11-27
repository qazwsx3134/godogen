extends Node3D

signal specimen_opened(item: String)
signal sample_collected(index: int)
signal coins_changed(total: int)
signal wallet_displayed_changed(total: int)

const SOFT_DURABILITY := 5
# ponytail: inline loot table; moves to data/loot .tres in M3.
# find is the index shared by Finds and IconModels.
const LOOT: Array[Dictionary] = [
	{"name": "碎石", "price": 2, "weight": 55.0, "find": 3, "rare": false},
	{"name": "石英", "price": 8, "weight": 25.0, "find": 0, "rare": false},
	{"name": "方解石", "price": 15, "weight": 14.0, "find": 1, "rare": false},
	{"name": "紫水晶", "price": 60, "weight": 6.0, "find": 2, "rare": true},
]
const GLOW := Color("ffe9a8")
const DULL := Color("6f675c")
const REPEAT_DELAY := 0.18
const REPEAT_INTERVAL := 0.13
const HELD_PRODUCT_DELAY := 0.55
const MOUSE_POINTER := -2
## Strike timing, measured from the previous strike (game seconds). The ring closes onto the stone at PERFECT_FROM.
const PERFECT_FROM := 0.34
const PERFECT_TO := 0.55
const STEADY_BONUS := 0.05
const PERFECT_BONUS := 0.15
const LUCKY_BONUS := 0.12
## Applied when the stone opens with at least FLAWLESS_PERFECTS perfect strikes.
const FLAWLESS_BONUS := 1.25
const FLAWLESS_PERFECTS := 2
const GOLD := Color("ffd75a")
const STEADY := Color("f3ead8")

## Shortest gap between two counted hits (game seconds). Lower = faster tapping.
@export var min_hit_interval := 0.09
## Chance that a rubble stone still glows through the last crack (keeps the clue honest-but-uncertain).
@export var rubble_glow_chance := 0.3
@export var indoor := false
@export var raw_shells: Array[ArrayMesh] = []
@export var raw_hulls: Array[ConvexPolygonShape3D] = []

@onready var stone: StaticBody3D = %Stone
@onready var shell := $Stone/Shell as MeshInstance3D
@onready var hit_shape := $Stone/HitShape as CollisionShape3D
@onready var original_shell := shell.mesh
@onready var original_material := shell.material_override
@onready var original_hull := hit_shape.shape
@onready var hammer: Node3D = %Hammer
@onready var hammer_home := hammer.transform
@onready var strike_face: Marker3D = %StrikeFace
@onready var stone_home := stone.transform
@onready var start_scale := stone.scale
@onready var camera: Camera3D = %Camera
@onready var hint: Label = %Hint
@onready var count: Label = %Count
@onready var coins_label: Label = %Coins
@onready var impact_emitters := %ImpactEmitters.get_children()
@onready var estimate_label: Label = %Estimate
@onready var icon_viewport: SubViewport = %IconViewport
@onready var price: Label3D = %Price
@onready var price_color := price.modulate
@onready var ring: MeshInstance3D = %TimingRing
@onready var ring_material := ring.mesh.surface_get_material(0) as StandardMaterial3D

var take_raw_stone: Callable
var source_id := -1
var source_mineral := -1
var source_hardness := 1
var waiting_hardness := 0
var at_station := true

var hits := 0
var hit_power := 1
var durability := SOFT_DURABILITY
var finishing_level := 0
var lucky_chance := 0.12
var held_pointer := -1
var held_position := Vector2.ZERO
var repeat_in := 0.0
var reveal_until := 0.0
var clear_animation: Tween
var opened := 0
var coins := 0
var loot_index := 0
var revealing := false
var new_sample := false
var clearing := false
var loading_stone := false
var displayed_coins := 0
## Quality multiplier of the stone on the bench; set by how it is struck, applied to the price on reveal.
var quality := 1.0
var shown_quality := 1.0
var perfects := 0
var flawless := false
var payout := 0
var clock := 0.0
var last_strike_at := -1.0
var ring_animation: Tween
var impact_index := 0
var wallet_animation: Tween
var estimate_animation: Tween
var product_animation: Tween
var collection_animation: Tween
var achievement_animation: Tween
var last_impact := Vector3.ZERO
var discoveries: Dictionary[String, bool] = {}
var achievements: Dictionary[String, bool] = {}
var cooldown := 0.0
var animation: Tween
var shake: Tween
var price_animation: Tween
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	if indoor:
		$Meadow.hide()
		$Foothills.hide()
	if take_raw_stone.is_valid():
		$Handcart.hide()
		coins_label.hide()
	%MineralIcon.texture = icon_viewport.get_texture()
	# The torus lies flat on Y; turn it to face the bench camera.
	ring.basis = Basis(Quaternion(Vector3.UP, (camera.position - ring.position).normalized()))
	_next_stone()

func set_station_active(active: bool) -> void:
	at_station = active
	$HUD.visible = active
	if not active:
		cancel_held_strike()
		%StockClear.hide()
		return
	camera.make_current()
	if not stone.visible and not revealing and not clearing and not loading_stone:
		_next_stone()

func _process(delta: float) -> void:
	clock += delta
	cooldown -= delta
	if held_pointer == -1 or not at_station:
		return
	if revealing:
		if clock >= reveal_until:
			_take_product()
		return
	repeat_in -= delta
	if repeat_in <= 0.0 and _try_strike(held_position, true):
		repeat_in = REPEAT_INTERVAL


func _input(event: InputEvent) -> void:
	if held_pointer == -1:
		return
	if event is InputEventScreenTouch and event.index == held_pointer and (not event.pressed or event.canceled):
		cancel_held_strike()
	elif event is InputEventMouseButton and held_pointer == MOUSE_POINTER and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		cancel_held_strike()


func _unhandled_input(event: InputEvent) -> void:
	if not at_station:
		return
	if event is InputEventScreenDrag:
		if event.index == held_pointer:
			held_position = event.position
		return
	if event is InputEventMouseMotion:
		if held_pointer == MOUSE_POINTER:
			held_position = event.position
		return
	if event is InputEventScreenTouch and event.pressed and not event.canceled:
		_pointer(event.index, event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_pointer(MOUSE_POINTER, event.position)


func _pointer(pointer: int, point: Vector2) -> void:
	if held_pointer != -1 or clearing or loading_stone:
		return
	if revealing:
		_take_product()
		get_viewport().set_input_as_handled()
		return
	held_pointer = pointer
	held_position = point
	repeat_in = REPEAT_DELAY
	if _try_strike(point):
		get_viewport().set_input_as_handled()


func cancel_held_strike() -> void:
	held_pointer = -1


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel_held_strike()


func _try_strike(point: Vector2, forgiving := false) -> bool:
	if not stone.visible or loading_stone or hits >= durability or cooldown > 0.0:
		return false
	var origin := camera.project_ray_origin(point)
	var ray := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(point) * 12.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.get("collider") == stone:
		_strike(hit.position, hit.normal)
		return true
	if forgiving and point.distance_to(camera.unproject_position(stone.global_position)) < 72.0:
		var center := camera.unproject_position(stone.global_position)
		return _try_strike(center)
	return false


func play_stock_clear() -> void:
	_unlock("清完整批")
	if clear_animation:
		clear_animation.kill()
	var label: Label = %StockClear
	label.show()
	label.modulate.a = 1.0
	label.pivot_offset = label.size * 0.5
	%ClearSound.play()
	clear_animation = create_tween().set_ignore_time_scale()
	clear_animation.tween_property(label, "scale", Vector2.ONE, 0.3).from(Vector2.ONE * 0.75).set_trans(Tween.TRANS_BACK)
	clear_animation.tween_interval(0.94)
	clear_animation.tween_property(label, "modulate:a", 0.0, 0.45)
	clear_animation.tween_callback(label.hide)

func _strike(contact: Vector3, normal: Vector3) -> void:
	cooldown = min_hit_interval
	var grade := _grade(clock - last_strike_at if last_strike_at >= 0.0 else -1.0)
	last_strike_at = clock
	hits = mini(hits + hit_power, durability)
	var final := hits == durability
	if animation:
		animation.kill()
	stone.scale = start_scale

	# The striking face, rather than the handle pivot, lands at the ray intersection.
	var axis := (global_basis.inverse() * normal).normalized()
	var handle := Vector3(-0.61, 0.79, 0.0).slide(axis).normalized()
	if handle.length_squared() < 0.1:
		handle = Vector3.FORWARD.slide(axis).normalized()
	var impact_basis := Basis(axis, handle, axis.cross(handle)).orthonormalized()
	var impact_pose := Transform3D(impact_basis, to_local(contact) - impact_basis * strike_face.position)
	animation = create_tween()
	animation.tween_property(hammer, "transform", impact_pose, 0.048).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	animation.tween_callback(_impact.bind(contact, normal, final, grade))
	var squash := Vector3(1.08, 0.88, 1.08) if final else Vector3(1.04, 0.95, 1.04)
	animation.tween_property(stone, "scale", start_scale * squash, 0.037)
	if final:
		animation.tween_interval(0.032)
		animation.tween_callback(_reveal)
	animation.tween_property(hammer, "transform", hammer_home, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	animation.parallel().tween_property(stone, "scale", start_scale, 0.13)


func _grade(since: float) -> String:
	if since >= PERFECT_FROM and since <= PERFECT_TO:
		return "perfect"
	return "lucky" if rng.randf() < lucky_chance else "steady"


func _impact(contact: Vector3, normal: Vector3, final: bool, grade := "steady") -> void:
	last_impact = contact
	var stage := mini(3, ceili(float(hits) / durability * 3.0))
	for index in 3:
		stone.get_node("Crack%d" % (index + 1)).visible = index < stage
	if not final:
		var remaining := ceili(float(durability - hits) / hit_power)
		hint.text = "硬度 %d　%d／%d　再敲 %d 下" % [source_hardness, hits, durability, remaining]
	var emitter := impact_emitters[impact_index % impact_emitters.size()] as CPUParticles3D
	impact_index += 1
	emitter.global_position = contact + normal * 0.02
	emitter.direction = (normal + Vector3.UP * 0.55).normalized()
	emitter.restart()
	emitter.emitting = true
	var increase := STEADY_BONUS + finishing_level * 0.02
	var label := "+%.2f　×%.2f"
	var tint := Color("d9efbb")
	match grade:
		"perfect":
			increase += PERFECT_BONUS - STEADY_BONUS
			perfects += 1
			label = "完美　+%.2f　×%.2f"
			tint = GOLD
		"lucky":
			increase += LUCKY_BONUS
			label = "亮面！ +%.2f　×%.2f"
			tint = Color("c7b3ff")
	quality += increase
	match grade:
		"lucky": %Tap.pitch_scale = 1.20
		"perfect": %Tap.pitch_scale = rng.randf_range(1.26, 1.34)
		_: %Tap.pitch_scale = rng.randf_range(0.92, 1.12)
	if final:
		%Tap.pitch_scale *= 0.75
	%Tap.play()
	_shake(0.055 if final else 0.014)
	# Only the multiplier shows while striking: the price would give away what is inside.
	_show_price(label % [increase, quality], tint, contact + Vector3.UP * 0.16, 70 if grade != "steady" else 58)
	if estimate_animation:
		estimate_animation.kill()
	estimate_animation = create_tween().set_ignore_time_scale()
	estimate_animation.tween_method(_draw_estimate, shown_quality, quality, 0.17).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if not final:
		_start_ring()


## The ring closes onto the stone by PERFECT_FROM, glows gold through the perfect window, then fades.
func _start_ring() -> void:
	if ring_animation:
		ring_animation.kill()
	ring.show()
	ring.scale = Vector3.ONE * 1.8
	ring_material.albedo_color = Color(STEADY, 0.45)
	var elapsed := clock - last_strike_at
	ring_animation = create_tween()
	ring_animation.tween_property(ring, "scale", Vector3.ONE, maxf(0.01, PERFECT_FROM - elapsed))
	ring_animation.tween_callback(func(): ring_material.albedo_color = Color(GOLD, 0.95))
	ring_animation.tween_property(ring, "scale", Vector3.ONE * 0.94, PERFECT_TO - PERFECT_FROM)
	ring_animation.tween_callback(ring.hide)


func _draw_estimate(value: float) -> void:
	shown_quality = value
	estimate_label.text = "品相　×%.2f" % value


func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	_change_wallet(-amount)
	return true


func credit_coins(amount: int) -> void:
	_change_wallet(amount)


func _change_wallet(delta: int) -> void:
	coins += delta
	coins_changed.emit(coins)
	if wallet_animation:
		wallet_animation.kill()
	wallet_animation = create_tween().set_ignore_time_scale()
	wallet_animation.tween_method(_draw_wallet, float(displayed_coins), float(coins), 0.46).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _draw_wallet(value: float) -> void:
	var rounded := roundi(value)
	if displayed_coins == rounded:
		return
	displayed_coins = rounded
	coins_label.text = "金幣　%d" % displayed_coins
	wallet_displayed_changed.emit(displayed_coins)


func _reveal() -> void:
	source_id = -1
	var loot: Dictionary = LOOT[loot_index]
	if ring_animation:
		ring_animation.kill()
	ring.hide()
	flawless = perfects >= FLAWLESS_PERFECTS
	if flawless:
		quality *= FLAWLESS_BONUS
	payout = maxi(1, roundi(snappedf(loot.price * quality, 0.000001)))
	_draw_estimate(quality)
	stone.hide()
	opened += 1
	revealing = true
	reveal_until = clock + HELD_PRODUCT_DELAY
	count.text = "已開石　%d" % opened
	%Burst.global_position = last_impact
	%Burst.restart()
	%Burst.emitting = true

	var display := %Finds.get_child(loot.find) as Node3D
	display.show()
	product_animation = create_tween()
	product_animation.tween_property(display, "position:y", 0.30, 0.30).from(0.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if loot.rare:
		product_animation.parallel().tween_property(display, "rotation:y", TAU, 0.94).from(0.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_shake(0.075)
	if loot_index > 0:
		%Chime.play()
	var verdict := "完美無瑕！" if flawless else ""
	hint.text = "%s%s　／　點一下或按住收走" % [verdict, loot.name]
	# The price appears only now, as base × quality.
	_show_price("%d × %.2f = %d 幣" % [loot.price, quality, payout],
		GOLD if flawless else price_color, last_impact + Vector3.UP * 0.3, 80 if flawless else 64, 1.6)
	if flawless:
		_unlock("完美無瑕")
	new_sample = _record_discovery(loot)
	if opened == 1:
		_unlock("第一次開石")
	elif opened == 10:
		_unlock("開石十顆")
	specimen_opened.emit(loot.name)


func _take_product() -> void:
	clearing = true
	revealing = false
	var loot: Dictionary = LOOT[loot_index]
	var display := %Finds.get_child(loot.find) as Node3D
	if product_animation:
		product_animation.kill()
	var origin := display.global_position
	var destination: Vector3 = %ProductTray.global_position
	product_animation = create_tween()
	product_animation.tween_method(func(t: float):
		display.global_position = origin.lerp(destination, t) + Vector3.UP * (0.38 * 4.0 * t * (1.0 - t))
		display.scale = Vector3.ONE.lerp(Vector3.ONE * 0.45, t)
	, 0.0, 1.0, 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	product_animation.tween_callback(func():
		if new_sample:
			sample_collected.emit(loot.find)
			new_sample = false
		_change_wallet(payout)
		%CashSound.play()
		_show_price("+%d 幣" % payout, price_color, destination + Vector3.UP * 0.16, 71)
		clearing = false
		_next_stone(true)
	)


func _record_discovery(loot: Dictionary) -> bool:
	if discoveries.has(loot.name):
		return false
	discoveries[loot.name] = true
	for model in %IconModels.get_children():
		model.visible = model.get_index() == loot.find
	icon_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	%MineralName.text = loot.name
	collection_animation = _notify(%CollectionToast, collection_animation)
	return true


func _unlock(title: String) -> void:
	if achievements.has(title):
		return
	achievements[title] = true
	%AchievementName.text = title
	achievement_animation = _notify(%AchievementToast, achievement_animation)


func _notify(panel: Control, previous: Tween) -> Tween:
	if previous:
		previous.kill()
	panel.show()
	panel.pivot_offset = Vector2(panel.size.x, 0.0)
	panel.modulate.a = 1.0
	var toast := create_tween()
	toast.tween_property(panel, "scale", Vector2.ONE, 0.20).from(Vector2.ONE * 0.87).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	toast.tween_interval(3.0)
	toast.tween_property(panel, "modulate:a", 0.0, 0.29)
	toast.tween_callback(panel.hide)
	return toast


func _show_price(text: String, color: Color, from: Vector3, font_size: int, hold := 0.27) -> void:
	if price_animation:
		price_animation.kill()
	price.text = text
	price.font_size = font_size
	price.global_position = from
	price.modulate = color
	price.show()
	price_animation = create_tween()
	price_animation.tween_property(price, "global_position:y", from.y + 0.38, 0.53).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	price_animation.parallel().tween_property(price, "modulate:a", 0.0, 0.26).set_delay(hold)
	price_animation.tween_callback(price.hide)


func _shake(amount: float) -> void:
	if shake:
		shake.kill()
	shake = create_tween().set_ignore_time_scale()
	for i in 4:
		shake.tween_property(camera, "h_offset", rng.randf_range(-amount, amount), 0.025)
		shake.parallel().tween_property(camera, "v_offset", rng.randf_range(-amount, amount), 0.025)
		amount *= 0.6
	shake.tween_property(camera, "h_offset", 0.0, 0.03)
	shake.parallel().tween_property(camera, "v_offset", 0.0, 0.03)

func _next_stone(animate_entry := false) -> void:
	if not animate_entry:
		price.hide()
	if estimate_animation:
		estimate_animation.kill()
	quality = 1.0 + finishing_level * 0.10
	perfects = 0
	flawless = false
	last_strike_at = -1.0
	if ring_animation:
		ring_animation.kill()
	ring.hide()
	_draw_estimate(quality)
	stone.transform = stone_home
	for display in %Finds.get_children():
		display.hide()
		display.position = Vector3.ZERO
		display.rotation = Vector3.ZERO
		display.scale = Vector3.ONE
	for index in 3:
		stone.get_node("Crack%d" % (index + 1)).hide()
	hits = 0
	revealing = false
	if take_raw_stone.is_valid():
		source_id = take_raw_stone.call() if at_station else -1
		if source_id == -1:
			stone.hide()
			estimate_label.hide()
			hint.text = "料斗剩下硬度 %d 的原石，請到工坊升級槌子" % waiting_hardness if waiting_hardness > 0 else "工作台缺料，先到卸貨箱補貨"
			return
	_set_raw_shell()
	durability = SOFT_DURABILITY + (source_hardness - 1) * 2
	if source_mineral >= 2:
		loot_index = source_mineral
	elif opened == 0:
		loot_index = 1
	else:
		loot_index = roll_mineral(source_hardness, not take_raw_stone.is_valid())
	var glows := loot_index > 0 or rng.randf() < rubble_glow_chance
	var seam := stone.get_node("Crack3/Seam") as MeshInstance3D
	(seam.material_override as StandardMaterial3D).albedo_color = GLOW if glows else DULL
	stone.show()
	estimate_label.show()
	hint.text = "硬度 %d　%d／%d　連點或按住原石" % [source_hardness, hits, durability]
	if animate_entry:
		loading_stone = true
		stone.position = %StoneEntry.position
		stone.rotation.z = 1.45
		var entry := create_tween().set_parallel()
		entry.tween_property(stone, "position", stone_home.origin, 0.19).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		entry.tween_property(stone, "rotation:z", 0.0, 0.19)
		entry.chain().tween_callback(func(): loading_stone = false)


func _set_raw_shell() -> void:
	var id := source_id if take_raw_stone.is_valid() else opened
	var variant := posmod(id, raw_shells.size() + 1) - 1
	if source_hardness == 2 and not raw_shells.is_empty():
		variant = raw_shells.size() - 1
	var has_variant := variant >= 0 and variant < raw_hulls.size() and raw_shells[variant] != null and raw_hulls[variant] != null
	shell.mesh = raw_shells[variant] if has_variant else original_shell
	shell.material_override = null if has_variant else original_material
	hit_shape.set_deferred("shape", raw_hulls[variant] if has_variant else original_hull)
	# Keep the authored strike pose, with a small variation in how the stone rests.
	shell.rotation.y = deg_to_rad(float(posmod(id * 17, 25) - 12))
	hit_shape.rotation.y = shell.rotation.y


func roll_mineral(hardness: int, demo := false) -> int:
	if hardness == 3:
		return 3
	var weights := PackedFloat32Array()
	for loot in LOOT:
		weights.append(loot.weight)
	if not demo:
		weights[3] = 0
		if hardness == 2:
			weights = PackedFloat32Array([10.0, 25.0, 65.0, 0.0])
	return rng.rand_weighted(weights)


func set_hammer_level(level: int) -> void:
	hit_power = level
	var head := $Hammer/Head as MeshInstance3D
	var face := $Hammer/Face as MeshInstance3D
	for part in [head, face]:
		var upgraded := part.material_override.duplicate() as StandardMaterial3D
		upgraded.albedo_color = Color("8ca7bc") if level == 2 else Color("9de1da")
		upgraded.metallic = 0.56
		part.material_override = upgraded
	head.scale = Vector3(1, 1.15, 1.12) if level == 2 else Vector3(1, 0.88, 1.20)
	face.scale = Vector3(1, 1.15, 1.12) if level == 2 else Vector3(1, 0.85, 0.90)
