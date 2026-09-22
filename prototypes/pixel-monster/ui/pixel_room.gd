extends Control
## Original pixel stage drawn at 144 × 88; the UI scales its viewport by whole numbers.

var pet: Dictionary = {}
var egg: Dictionary = {}
var animation: String = "idle"
var animation_left: float = 0.0
var elapsed: float = 0.0
var battle: bool = false
var enemy_species: String = "moss"
var enemy_turn: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	elapsed += delta
	animation_left = maxf(animation_left - delta, 0.0)
	if animation_left == 0.0:
		animation = "idle"
	queue_redraw()

func play(action: String) -> void:
	animation = action
	animation_left = 2.4 if action in ["hatch", "evolve"] else 1.5

func _r(x: float, y: float, width: float, height: float, color: String) -> void:
	draw_rect(Rect2(roundf(x), roundf(y), width, height), Color(color))

func _draw() -> void:
	if battle:
		_arena()
	else:
		_room()
	if pet.is_empty():
		_draw_egg()
	else:
		var action: String = animation
		if action == "idle":
			if pet.get("behavior", "idle") == "sleeping" or pet.get("conditions", {}).get("hibernating", false):
				action = "sleep"
			elif pet.get("conditions", {}).get("sick", false):
				action = "sick"
			elif pet.get("conditions", {}).get("injured", false):
				action = "injured"
			elif fmod(elapsed, 14.0) > 10.0:
				action = "walk"
		var x: float = 43.0 if battle else 73.0
		var y: float = 62.0
		if action in ["happy", "victory", "hatch", "evolve", "train"]:
			y -= absf(sin(elapsed * 9.0)) * 4.0
		elif action == "walk":
			x += floorf(sin(elapsed * 1.5) * 9.0)
			y -= int(elapsed * 7.0) % 2
		elif action in ["attack", "hit"]:
			x += sin(elapsed * 24.0) * 3.0
		draw_set_transform(Vector2(x, y))
		_creature(str(pet.get("species", "sprout")), action)
		draw_set_transform(Vector2.ZERO)
		if battle:
			draw_set_transform(Vector2(109 + (sin(elapsed * 24.0) * 2.0 if enemy_turn else 0.0), 56), 0.0, Vector2(-1, 1))
			_creature(enemy_species, "attack" if enemy_turn else "idle")
			draw_set_transform(Vector2.ZERO)
		if action == "sleep":
			_z(92, 32 - int(elapsed * 2) % 5)
		elif action in ["happy", "victory", "eat"]:
			_heart(88, 33 - int(elapsed * 3) % 4, "d97f76")
		elif action == "sick":
			_r(84, 31, 3, 6, "9cad77")
			_r(84, 40, 3, 2, "9cad77")
		if action == "eat":
			var bite: int = 3 - int(elapsed * 5.0) % 3
			_r(85, 58, bite * 3, 5, "bc724d")
			_r(84, 56, bite * 3, 2, "e5ad71")
		if action == "train":
			_r(85, 59, 14, 3, "6f7770")
			_r(84, 54, 4, 13, "41534c")
			_r(98, 54, 4, 13, "41534c")
		if action in ["heal", "clean", "hatch", "evolve", "happy", "victory"]:
			_sparkles()
		if action == "evolve" and animation_left > 1.4:
			draw_rect(Rect2(0, 0, 144, 88), Color(0.98, 0.98, 0.83, (sin(elapsed * 18.0) + 1.0) * 0.35))
	if not battle and not pet.is_empty() and not bool(pet.get("lights_on", true)):
		draw_rect(Rect2(0, 0, 144, 88), Color(0.10, 0.18, 0.24, 0.48))
		_r(24, 17, 6, 6, "e8dfb9")
		_r(27, 16, 5, 5, "506e78")

func _room() -> void:
	_r(0, 0, 144, 88, "e4d8b4")
	_r(0, 0, 144, 3, "c7c199")
	for x in range(0, 144, 8):
		_r(x, 4, 1, 49, "ded0aa")
	_r(0, 52, 144, 4, "b5a77e")
	_r(0, 56, 144, 32, "d2b88f")
	for y in [64, 75, 86]:
		_r(0, y, 144, 1, "c2a47d")
		for x in range(0, 144, 24):
			_r(x + (12 if y == 75 else 0), y - 10, 1, 10, "c6ac84")
	# Window, hills and a tiny drifting cloud.
	_r(17, 11, 36, 31, "a79770")
	_r(19, 12, 32, 27, "faf0cf")
	_r(21, 14, 28, 23, "a8ccbd")
	_r(24, 18, 6, 6, "f9e6a4")
	_r(21, 31, 28, 6, "83aa8d")
	_r(28, 27, 13, 10, "91b295")
	_r(33, 25, 5, 5, "91b295")
	var cloud: int = 34 + int(sin(elapsed * 0.12) * 3.0)
	_r(cloud, 19, 9, 2, "ecedcd")
	_r(cloud + 2, 17, 4, 2, "ecedcd")
	_r(34, 14, 2, 23, "f7eccb")
	_r(21, 27, 28, 2, "f7eccb")
	_r(16, 40, 38, 3, "f3e6bf")
	# Wall keepsakes.
	_r(66, 14, 14, 18, "b49c76")
	_r(68, 16, 10, 14, "f4e8c9")
	_heart(70, 20, "c48d70")
	_r(102, 31, 29, 4, "a9926a")
	_r(106, 21, 5, 10, "91ab9a")
	_r(112, 19, 4, 12, "d3a17e")
	_r(117, 22, 4, 9, "f2deb0")
	_r(124, 24, 6, 7, "a87558")
	_r(125, 18, 2, 7, "63896a")
	_r(121, 18, 5, 3, "7b9b71")
	_r(126, 15, 5, 4, "7b9b71")
	# Quilt and potted fern.
	_r(112, 52, 23, 14, "987a59")
	_r(111, 52, 26, 9, "9cafa0")
	_r(114, 50, 10, 4, "f3e7c7")
	_r(113, 54, 22, 6, "adc2a2")
	_r(119, 54, 2, 6, "91ae97")
	_r(130, 54, 2, 6, "91ae97")
	_r(14, 56, 11, 11, "b87d5b")
	_r(12, 54, 15, 4, "ce9570")
	_r(18, 40, 3, 15, "638664")
	_r(11, 42, 9, 5, "84a070")
	_r(20, 37, 9, 5, "709466")
	_r(8, 39, 6, 3, "84a070")
	_r(24, 34, 4, 3, "709466")
	# Woven rug.
	_r(45, 69, 53, 10, "b89571")
	_r(42, 71, 59, 6, "b89571")
	_r(47, 70, 49, 8, "d9cf9d")
	_r(45, 72, 53, 4, "d9cf9d")
	_r(51, 73, 40, 2, "bcba8b")
	for index in mini(pet.get("poop", []).size(), 5):
		var px: int = 36 + index * 18
		_r(px, 72, 7, 3, "80684e")
		_r(px + 1, 69, 5, 3, "927555")
		_r(px + 3, 67, 2, 2, "a58660")

func _arena() -> void:
	_r(0, 0, 144, 88, "b5c9b2")
	_r(0, 51, 144, 37, "d8cfa7")
	for x in range(0, 144, 12):
		_r(x, 39, 8, 12, "94ad92")
		_r(x + 3, 34, 3, 8, "94ad92")
	_r(20, 68, 45, 7, "a8b38c")
	_r(88, 62, 42, 7, "a8b38c")
	_r(70, 53, 1, 31, "efe3bd")
	for y in [4, 12, 20]:
		_r(0, y, 144, 1, "afc4ac")

func _draw_egg() -> void:
	var progress: float = clampf(float(egg.get("credited_steps", 0)) / maxf(float(egg.get("target_steps", 500)), 1.0), 0.0, 1.0)
	var wobble: float = roundf(sin(elapsed * (2.0 + progress * 4.0)) * (2.0 if progress >= 0.25 else 0.0))
	_r(62, 68, 22, 4, "ad9c77")
	draw_set_transform(Vector2(73 + wobble, 60 - int(sin(elapsed * 2.0) > 0.8)))
	_r(-6, -20, 12, 3, "637154")
	_r(-9, -17, 18, 4, "637154")
	_r(-11, -13, 22, 18, "637154")
	_r(-8, 5, 16, 3, "637154")
	_r(-6, -17, 12, 3, "fff2ce")
	_r(-8, -13, 16, 17, "fff2ce")
	_r(-5, 4, 10, 2, "e8dba9")
	_r(-8, -1, 3, 5, "e2d8a4")
	_r(-3, -12, 5, 5, "a1b779")
	_r(3, -2, 5, 5, "a1b779")
	_r(-7, -4, 3, 3, "bcc98c")
	_r(-4, -15, 3, 2, "fffaf0")
	if progress >= 0.5:
		_r(-1, -5, 2, 3, "68744f")
		_r(-3, -2, 3, 2, "68744f")
		_r(-2, 0, 2, 3, "68744f")
	if progress >= 0.75:
		_r(0, 2, 5, 1, "68744f")
		_r(5, 1, 2, 1, "68744f")
	draw_set_transform(Vector2.ZERO)
	if progress >= 0.75:
		_sparkles()

func _creature(species: String, action: String) -> void:
	var outline: String = "415947"
	var body: String = "94bf78"
	var light: String = "c4da91"
	var shadow: String = "6b9b65"
	if species == "ember":
		outline = "754d40"
		body = "d79361"
		light = "f2c786"
		shadow = "b97550"
	elif species == "moss":
		outline = "425853"
		body = "89aaa0"
		light = "b9c9a6"
		shadow = "63847d"
	elif species == "breeze":
		outline = "405d64"
		body = "86bac0"
		light = "bddbd0"
		shadow = "64949f"
	if action == "evolve" and animation_left > 1.4:
		body = outline
		light = outline
		shadow = outline
	var grown: bool = species != "sprout"
	var half: int = 11 if grown else 9
	var top: int = -22 if grown else -17
	if action in ["sleep", "defeat"]:
		top += 7
	# Silhouettes distinguish the three branches.
	if species in ["sprout", "bloom"]:
		_r(-2, top - 6, 3, 8, outline)
		_r(-7, top - 8, 6, 4, shadow)
		_r(1, top - 10, 7, 5, shadow)
		_r(2, top - 9, 4, 2, light)
		if grown:
			_r(-15, -23, 6, 13, outline)
			_r(9, -23, 6, 13, outline)
			_r(-13, -21, 3, 9, body)
			_r(10, -21, 3, 9, body)
	elif species == "ember":
		_r(-14, -26, 7, 12, outline)
		_r(7, -26, 7, 12, outline)
		_r(-12, -24, 4, 8, light)
		_r(8, -24, 4, 8, light)
		_r(-18, -8, 8, 11, outline)
		_r(10, -8, 8, 11, outline)
		_r(-16, -6, 5, 7, shadow)
		_r(11, -6, 5, 7, shadow)
	elif species == "breeze":
		_r(-13, -32, 5, 19, outline)
		_r(8, -34, 5, 21, outline)
		_r(-11, -30, 2, 14, light)
		_r(9, -32, 2, 16, light)
		_r(10, -3, 13, 6, outline)
		_r(20, -8, 7, 8, outline)
		_r(12, -2, 10, 3, light)
		_r(21, -6, 4, 6, body)
	elif species == "moss":
		_r(-16, -19, 28, 22, outline)
		_r(-14, -17, 24, 18, shadow)
		_r(-10, -20, 15, 3, outline)
		_r(-10, -18, 15, 7, body)
		_r(-8, -17, 2, 15, light)
		_r(-14, -8, 23, 2, light)
		_r(-6, -25, 3, 6, outline)
		_r(-10, -26, 6, 3, "95b378")
	_r(-half + 3, top, half * 2 - 6, 3, outline)
	_r(-half, top + 3, half * 2, 22 if grown else 17, outline)
	_r(-half - 2, top + 7, half * 2 + 4, 12, outline)
	_r(-half + 3, top + 3, half * 2 - 6, 2, light)
	_r(-half + 1, top + 5, half * 2 - 2, 17 if grown else 12, body)
	_r(-half - 1, top + 8, half * 2 + 2, 8, body)
	_r(-6, -6, 12, 7, light)
	_r(-half + 2, 2, 6, 4, outline)
	_r(half - 8, 2, 6, 4, outline)
	_r(-half + 3, 2, 4, 2, shadow)
	_r(half - 7, 2, 4, 2, shadow)
	var eye_y: int = top + 9
	var blinking: bool = fmod(elapsed, 4.4) > 4.16
	if action in ["sleep", "happy", "victory", "defeat"] or blinking:
		_r(-6, eye_y + 2, 4, 1, outline)
		_r(3, eye_y + 2, 4, 1, outline)
		if action in ["happy", "victory"]:
			_r(-5, eye_y + 1, 2, 1, outline)
			_r(4, eye_y + 1, 2, 1, outline)
	else:
		_r(-5, eye_y, 3, 4, outline)
		_r(4, eye_y, 3, 4, outline)
		_r(-5, eye_y, 1, 1, "eff0cd")
		_r(4, eye_y, 1, 1, "eff0cd")
	_r(-1, eye_y + 5, 3, 1, outline)
	if action == "eat":
		_r(-1, eye_y + 5, 3, 3 if int(elapsed * 6) % 2 == 0 else 1, outline)
	_r(-8, eye_y + 5, 3, 2, "d4a484")
	_r(7, eye_y + 5, 3, 2, "d4a484")
	if action in ["injured", "heal"]:
		_r(-half, -3, 7, 4, "f1e3c7")
		_r(-half + 3, -4, 2, 6, "e4c9a6")
	if action == "sick":
		_r(7, top + 4, 2, 5, "8fc3c3")

func _heart(x: int, y: int, color: String) -> void:
	_r(x, y, 2, 2, color)
	_r(x + 4, y, 2, 2, color)
	_r(x, y + 2, 6, 2, color)
	_r(x + 1, y + 4, 4, 1, color)
	_r(x + 2, y + 5, 2, 1, color)

func _z(x: int, y: int) -> void:
	_r(x, y, 5, 1, "f8edc9")
	_r(x + 3, y + 1, 1, 1, "f8edc9")
	_r(x + 2, y + 2, 1, 1, "f8edc9")
	_r(x + 1, y + 3, 1, 1, "f8edc9")
	_r(x, y + 4, 5, 1, "f8edc9")

func _sparkles() -> void:
	for index in 8:
		var x: int = 40 + (index * 29) % 61
		var y: int = 22 + (index * 17 - int(elapsed * 12)) % 44
		if y < 14:
			y += 40
		_r(x, y, 1, 5, "fff1c1")
		_r(x - 2, y + 2, 5, 1, "fff1c1")
