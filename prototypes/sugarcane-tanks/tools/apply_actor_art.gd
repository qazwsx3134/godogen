extends SceneTree
## One-off authoring tool for the actor art pass (.claude/tasks/sugarcane-art/actors-brief.md).
## Replaces the Polygon2D placeholders of the hero, the enemies, the projectiles and the pickups with
## the generated pictures in assets/, wires the HUD portraits and coin, and gives every ability its icon.
##
##   godot --headless --path . --script res://tools/apply_actor_art.gd
##
## Each scene is loaded as it is saved right now (so settings someone else saved, such as y-sort or
## z_index, are kept), changed in memory, and written back with PackedScene.pack + ResourceSaver.save.
## It has been applied. From here on the saved .tscn files are the source: edit them in the editor.
## Running it again is refused (hero.tscn already has %Sprite), because a second pass would overwrite
## hand edits.
##
## How an actor is laid out (every picture faces right, its bottom edge is the feet):
##   %Body        flips (scale.x = ±1) to face left or right; holds only %Sprite (and the markers that flip with it)
##   %Sprite      centered, offset = (half width - anchor pixel, -half height), position = (0, foot):
##                the anchor pixel stands on x = 0 and the bottom edge on y = foot, so scale works around the feet
##   Shadow       a small ellipse at (0, foot)
##   HpBar        just above the head
## `foot` is about 0.9 x the collision radius: the feet sit on the bottom edge of the collision circle.
## `scale` stays within 0.75–1.25: the pictures are larger than the collision circles, which do not change.

## Per scene: picture, anchor pixel x, sprite scale, foot y, shadow radii.
const ACTORS: Dictionary = {
	"res://player/hero.tscn": {"tex": "hero", "anchor": 36.0, "scale": 1.0, "foot": 26.0, "shadow": Vector2(30, 10)},
	"res://enemies/rat.tscn": {"tex": "rat", "anchor": 58.0, "scale": 0.85, "foot": 22.0, "shadow": Vector2(38, 10)},
	"res://enemies/tank.tscn": {"tex": "tank", "anchor": 104.0, "scale": 0.75, "foot": 40.0, "shadow": Vector2(66, 17)},
	"res://enemies/boss_tank.tscn": {"tex": "boss_tank", "anchor": 160.0, "scale": 0.75, "foot": 70.0, "shadow": Vector2(104, 26)},
	"res://enemies/plate.tscn": {"tex": "chef", "anchor": 60.0, "scale": 0.9, "foot": 38.0, "shadow": Vector2(46, 13)},
	"res://enemies/chiang_boss.tscn": {"tex": "chiang", "anchor": 134.0, "scale": 0.75, "foot": 50.0, "shadow": Vector2(52, 14)},
}
## Pixel in the picture where the weapon's muzzle / the pan is (hero launcher tip, chef pan).
const HERO_MUZZLE_PX: Vector2 = Vector2(115, 63)
const CHEF_PAN_PX: Vector2 = Vector2(118, 43)
## Chiang's right fist (where the pistol is held) and the pistol's grip pivot and muzzle, in picture pixels.
const CHIANG_FIST_PX: Vector2 = Vector2(201, 153)
const PISTOL_PIVOT_PX: Vector2 = Vector2(16, 10.6)
const PISTOL_MUZZLE_PX: Vector2 = Vector2(71, 10.6)

## Projectiles and pickups: scene -> [picture, parent holding the sprite ("" = the root), sprite offset].
## The bullet's offset puts its brass casing, not its muzzle flame, on the hit centre.
const SPRITES: Dictionary = {
	"res://player/sugarcane.tscn": ["sugarcane_shot", "%Visual", Vector2.ZERO],
	"res://enemies/bullet.tscn": ["bullet", "", Vector2(-11, 0)],
	"res://enemies/pea.tscn": ["pea", "", Vector2.ZERO],
	"res://enemies/corn.tscn": ["corn", "", Vector2.ZERO],
	"res://enemies/carrot.tscn": ["carrot", "", Vector2.ZERO],
	"res://pickups/exp_gem.tscn": ["exp_gem", "%Visual", Vector2.ZERO],
	"res://pickups/heart.tscn": ["heart", "%Visual", Vector2.ZERO],
	"res://pickups/coin.tscn": ["coin", "%Visual", Vector2.ZERO],
}

var _failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var probe: Node = (load("res://player/hero.tscn") as PackedScene).instantiate()
	var done: bool = probe.get_node_or_null("%Sprite") != null
	probe.free()
	if done:
		print("already applied (hero.tscn has %Sprite): nothing to do")
		quit(0)
		return
	for path: String in ACTORS:
		_actor(path, ACTORS[path])
	for path: String in SPRITES:
		_flat_sprite(path, SPRITES[path][0], SPRITES[path][1], SPRITES[path][2])
	_hud()
	_ability_icons()
	print("APPLY FAILED" if _failed else "APPLY OK")
	quit(1 if _failed else 0)

# --- actors ------------------------------------------------------------------

func _actor(path: String, c: Dictionary) -> void:
	var root: Node2D = _edit(path) as Node2D
	var tex: Texture2D = _texture(c["tex"])
	var size: Vector2 = tex.get_size()
	var scale: float = c["scale"]
	var foot: float = c["foot"]
	var anchor: float = c["anchor"]
	var body: Node2D = root.get_node("Body") as Node2D
	_clear(body)
	for old: String in ["LegLeft", "LegRight"]:   # the chef's old legs hung off the root
		if root.has_node(old):
			_clear_one(root, old)
	body.position = Vector2.ZERO
	body.rotation = 0.0   # the old tank bodies started turned a quarter circle
	body.scale = Vector2.ONE
	_add(body, _sprite(tex, anchor, scale, foot), "Sprite")

	var shadow: Polygon2D = root.get_node("Shadow") as Polygon2D
	shadow.position = Vector2(0.0, foot)
	shadow.polygon = _ellipse(c["shadow"].x, c["shadow"].y)
	shadow.color = Color(0, 0, 0, 0.34)

	# Health bar just above the head (the hero also has the number above it).
	var head_top: float = foot - scale * size.y
	var bar: ProgressBar = root.get_node("%HpBar") as ProgressBar
	var bar_height: float = bar.offset_bottom - bar.offset_top
	bar.offset_bottom = head_top - 6.0
	bar.offset_top = bar.offset_bottom - bar_height
	if root.has_node("%HpLabel"):
		var label: Label = root.get_node("%HpLabel") as Label
		var label_height: float = label.offset_bottom - label.offset_top
		var centre: float = bar.offset_top - 9.5
		label.offset_top = centre - label_height * 0.5
		label.offset_bottom = centre + label_height * 0.5

	var at := func(pixel: Vector2) -> Vector2:   # a picture pixel -> position in %Body's space
		return Vector2(scale * (pixel.x - anchor), foot + scale * (pixel.y - size.y))
	match path:
		"res://player/hero.tscn":
			# The launcher's muzzle is where the canes start; under %Body so it flips with the hero.
			_reparent(root, "Hand", body, at.call(HERO_MUZZLE_PX))
		"res://enemies/plate.tscn":
			root.set("display_name", "廚師")
			_reparent(root, "Muzzle", body, at.call(CHEF_PAN_PX))
		"res://enemies/chiang_boss.tscn":
			root.set("portrait", _texture("portrait_chiang"))
			_pistol(root, at.call(CHIANG_FIST_PX))
		"res://enemies/boss_tank.tscn":
			root.set("portrait", _texture("portrait_boss_tank"))
	_save(root, path, _required(path))

## The pistol swings around its grip, with the barrel on the arm's x axis: aimed left it is mirrored
## around the barrel (scale.y = -1) and stays right side up.
func _pistol(root: Node, hand: Vector2) -> void:
	var arm: Node2D = root.get_node("%GunArm") as Node2D
	for child: Node in arm.get_children():
		if child.name != &"Muzzle":
			arm.remove_child(child)
			child.free()
	arm.position = hand
	arm.rotation = 0.0
	var tex: Texture2D = _texture("pistol")
	var pistol := Sprite2D.new()
	pistol.texture = tex
	pistol.offset = tex.get_size() * 0.5 - PISTOL_PIVOT_PX
	arm.add_child(pistol)
	arm.move_child(pistol, 0)
	pistol.name = "Pistol"
	(arm.get_node("%Muzzle") as Node2D).position = PISTOL_MUZZLE_PX - PISTOL_PIVOT_PX

func _required(path: String) -> Array:
	match path:
		"res://player/hero.tscn":
			return ["Body", "Sprite", "Hand", "HpBar", "HpLabel"]
		"res://enemies/plate.tscn":
			return ["Body", "Sprite", "Muzzle", "HpBar", "ContactArea"]
		"res://enemies/chiang_boss.tscn":
			return ["Body", "Sprite", "GunArm", "Muzzle", "HpBar", "ContactArea"]
	return ["Body", "Sprite", "HpBar", "ContactArea"]

# --- projectiles and pickups -------------------------------------------------

func _flat_sprite(path: String, tex_name: String, parent_name: String, offset: Vector2) -> void:
	var root: Node = _edit(path)
	var parent: Node = root if parent_name.is_empty() else root.get_node(parent_name)
	for child: Node in parent.get_children():
		if child is Polygon2D:
			parent.remove_child(child)
			child.free()
	var sprite := Sprite2D.new()
	sprite.texture = _texture(tex_name)
	sprite.offset = offset
	_add(parent, _unique(sprite), "Sprite")
	parent.move_child(sprite, 0)
	_save(root, path, ["Sprite"])

# --- HUD and abilities -------------------------------------------------------

func _hud() -> void:
	var root: Node = _edit("res://ui/hud.tscn")
	(root.get_node("%HeroPortrait") as TextureRect).texture = _texture("portrait_hero")
	(root.get_node("%BottomPortrait") as TextureRect).texture = _texture("portrait_hero")
	(root.get_node("%CoinIcon") as TextureRect).texture = _texture("coin")
	_save(root, "res://ui/hud.tscn", ["HeroPortrait", "BottomPortrait", "CoinIcon", "AbilityChips", "BossPanel"])

func _ability_icons() -> void:
	for id: String in ["front", "multishot", "diagonal", "side", "rear", "pierce", "ricochet", "wall_bounce",
			"attack_boost", "attack_speed", "crit", "fire", "freeze", "hp_boost", "heal"]:
		var path: String = "res://data/abilities/%s.tres" % id
		var def: Resource = load(path)
		def.set("icon", _texture("icon_" + id))
		if ResourceSaver.save(def, path) != OK:
			_fail("cannot save " + path)
	print("abilities: 15 icons")

# --- helpers -----------------------------------------------------------------

func _fail(message: String) -> void:
	push_error(message)
	_failed = true

func _texture(name: String) -> Texture2D:
	var tex: Texture2D = load("res://assets/%s.png" % name) as Texture2D
	if tex == null:
		_fail("missing assets/%s.png" % name)
		tex = PlaceholderTexture2D.new()
	return tex

func _edit(path: String) -> Node:
	return (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)

func _sprite(tex: Texture2D, anchor: float, scale: float, foot: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = tex
	var size: Vector2 = tex.get_size()
	sprite.offset = Vector2(size.x * 0.5 - anchor, -size.y * 0.5)
	sprite.position = Vector2(0.0, foot)
	sprite.scale = Vector2(scale, scale)
	return _unique(sprite) as Sprite2D

func _ellipse(rx: float, ry: float, sides: int = 24) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i: int in sides:
		var angle: float = TAU * i / sides
		points.append(Vector2(cos(angle) * rx, sin(angle) * ry))
	return points

func _clear(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.free()

func _clear_one(parent: Node, child_name: String) -> void:
	var child: Node = parent.get_node(child_name)
	parent.remove_child(child)
	child.free()

## Moves a unique-named marker under a new parent. Its unique name is dropped first and set again
## when the scene is saved, because the name belongs to the owner's table.
func _reparent(root: Node, marker_name: String, new_parent: Node, local: Vector2) -> void:
	var marker: Node2D = root.get_node("%" + marker_name) as Node2D
	marker.unique_name_in_owner = false
	marker.get_parent().remove_child(marker)
	marker.owner = null
	new_parent.add_child(marker)
	marker.position = local
	_unique(marker)

func _unique(node: Node) -> Node:
	node.set_meta(&"_unique", true)
	return node

func _add(parent: Node, child: Node, node_name: String = "") -> Node:
	if not node_name.is_empty():
		child.name = node_name
	parent.add_child(child)
	return child

# --- saving ------------------------------------------------------------------

func _save(root: Node, path: String, required: Array) -> void:
	_own(root, root)
	var expected: int = _count(root)
	var packed := PackedScene.new()
	var error: Error = packed.pack(root)
	if error == OK:
		error = ResourceSaver.save(packed, path)
	root.free()
	if error != OK:
		_fail("cannot save %s: %s" % [path, error_string(error)])
		return
	var reloaded: PackedScene = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var check: Node = reloaded.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	var actual: int = _count(check)
	if actual != expected:
		_fail("%s: %d nodes before pack, %d after reload" % [path, expected, actual])
	for node_name: String in required:
		if check.get_node_or_null("%" + node_name) == null:
			_fail("%s: missing %%%s after reload" % [path, node_name])
	var sprite: Node = check.get_node_or_null("%Sprite")
	if sprite != null and (sprite as Sprite2D).texture == null:
		_fail("%s: %%Sprite has no texture after reload" % path)
	print("saved: %s (%d nodes)" % [path, actual])
	check.free()

## Owner on every authored node (a node without one is silently dropped by pack()); sub-scene
## instances get an owner on their root only. The owner is set before the unique-name flag.
func _own(node: Node, owner: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner
		if child.has_meta(&"_unique"):
			child.remove_meta(&"_unique")
			child.unique_name_in_owner = true
		if child.scene_file_path.is_empty():
			_own(child, owner)

func _count(node: Node) -> int:
	var total: int = 1
	for child: Node in node.get_children():
		total += _count(child)
	return total
