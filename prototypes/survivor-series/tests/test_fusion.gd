extends "res://addons/proto_kit/test_kit.gd"
## Second weapon batch and hidden fusions: recipes, slots, hidden card, umbrella shield, zones, discovery save.
const META_PATH = "user://test_fusion_meta.json"
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(META_PATH))
	var game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	game.get_node("Services/Meta").save_path = META_PATH
	root.add_child(game)
	game.set_physics_process(false)
	await _frames(2)
	var street = game.street
	game.start_run()
	var build = street.build
	# --- recipe rules ---
	build.weapons.clear()
	build.levels.clear()
	for id: StringName in [&"punch", &"wave"]:
		build.weapons.append(id)
		build.levels[id] = 3
	_expect(not build.offers().any(func(i: Resource) -> bool: return i.id == &"duo"), "no fusion card while the parts are below the recipe level")
	build.levels[&"punch"] = 4
	build.levels[&"wave"] = 4
	build.picked_ids.append(&"x")
	build.pending_choices = 1
	var duo: Resource = build.definition(&"duo")
	_expect(build.offers().has(duo), "both parts at the recipe level offer the fusion")
	_expect(build.pick(&"duo") and build.weapons == [&"duo"] and build.count(&"punch") == 0 and build.count(&"wave") == 0, "fusing replaces both parts with one weapon and frees a slot")
	build.pending_choices = 1
	_expect(not build.offers().any(func(i: Resource) -> bool: return i.id == &"punch" or i.id == &"wave"), "fused parts are not offered again as new weapons")
	# --- hidden card ---
	var card: Button = (load("res://scenes/upgrade_card.tscn") as PackedScene).instantiate()
	root.add_child(card)
	build.discovered.clear()
	card.setup(duo, build)
	_expect(card.get_node("%Title").text == "？？？" and card.get_node("%Tag").text.contains("隱藏"), "an undiscovered fusion hides its name")
	build.discovered[&"duo"] = true
	card.setup(duo, build)
	_expect(card.get_node("%Title").text == "雙人合擊", "a discovered fusion shows its name")
	card.queue_free()
	# --- discovery is saved ---
	build.pending_choices = 0
	game.state = game.State.UPGRADE
	game.upgrade_generation = 1
	build.weapons.clear()
	build.levels.clear()
	for id: StringName in [&"punch", &"wave"]:
		build.weapons.append(id)
		build.levels[id] = 4
	build.pending_choices = 1
	game.current_offers = build.offers()
	_expect(game.choose_upgrade(&"duo", 1), "choosing the fusion card works")
	game.meta.load_save()
	_expect(game.meta.fusions.has("duo"), "a discovered fusion is saved to the codex")
	# --- duo fires four-way ---
	street.clear()
	street.spawn_left = 1000.0
	street.phase_index = 0
	street.arsenal.reset()
	street.arsenal.cooldowns.clear()
	street.arsenal.fire(build.weapon_stats(&"duo"))
	_expect(street.projectiles.get_child_count() == 4, "duo fires four waves around the hero")
	# --- umbrella shield ---
	street.clear()
	street.arsenal.reset()
	build.weapons.clear()
	build.levels.clear()
	build.weapons.append(&"umbrella")
	build.levels[&"umbrella"] = 1
	_expect(not street.player.umbrella.visible, "umbrella is hidden until charged")
	street.arsenal.fire(build.weapon_stats(&"umbrella"))
	_expect(street.arsenal.shield == 1 and street.player.umbrella.visible, "firing the umbrella charges one hit")
	street.player.reset()
	street.arsenal.shield = 1
	street.arsenal.step(0.016)  # a full umbrella still starts its cooldown
	var hp_before: float = street.player.hp
	var foe: Node2D = street.spawn_enemy(1, street.player.position + Vector2(30.0, 0.0))
	street.grid.rebuild(street.enemies.get_children())
	street._hurt(20.0, "test")
	_expect(street.player.hp == hp_before and street.arsenal.shield == 0, "a charged umbrella eats the hit")
	street._hurt(20.0, "test")
	_expect(street.player.hp == hp_before, "the umbrella grants a short invulnerability after absorbing")
	street.arsenal.step(0.016)
	_expect(street.arsenal.shield == 0, "an absorbed charge waits a full cooldown to come back")
	street.player.hurt_cooldown = 0.0
	street._hurt(20.0, "test")
	_expect(street.player.hp < hp_before, "with no charge the hit lands")
	# --- zones slow and pull ---
	street.clear()
	street.player.reset()
	street.spawn_left = 1000.0
	street.phase_index = 0
	var anchor_foe: Node2D = street.spawn_enemy(0, street.player.position + Vector2(200.0, 0.0))
	var near: Node2D = street.spawn_enemy(0, street.player.position + Vector2(200.0, 50.0))
	street.grid.rebuild(street.enemies.get_children())
	build.weapons.clear()
	build.levels.clear()
	build.weapons.append(&"ring")
	build.levels[&"ring"] = 1
	var start_gap: float = 0.0
	street.arsenal.fire(build.weapon_stats(&"ring"))
	var ring: Node2D = street.projectiles.get_child(0)
	if near.position.distance_to(ring.position) < 1.0:
		near = anchor_foe
	start_gap = near.position.distance_to(ring.position)
	for i: int in 20:
		street.step(1.0 / 30.0, Vector2.ZERO, 0.0)
	_expect(near.position.distance_to(ring.position) < start_gap - 20.0 or near.dead, "a ring drags an enemy toward its centre")
	_expect(near.slow_left > 0.0 or near.dead, "a ring slows the enemy inside")
	# --- rider and tofu spawn ---
	street.clear()
	street.arsenal.reset()
	build.weapons.clear()
	build.levels.clear()
	for id: StringName in [&"rider", &"tofu"]:
		build.weapons.append(id)
		build.levels[id] = 1
	street.spawn_enemy(0, street.player.position + Vector2(120.0, 0.0))
	street.grid.rebuild(street.enemies.get_children())
	street.arsenal.fire(build.weapon_stats(&"rider"))
	street.arsenal.fire(build.weapon_stats(&"tofu"))
	_expect(street.projectiles.get_child_count() == 2, "rider and tofu each spawn a projectile")
	game.queue_free()
	await _frames(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(META_PATH))
	_finish("SURVIVOR FUSION")
