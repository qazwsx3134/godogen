extends "res://addons/proto_kit/test_kit.gd"
## Acceptance contract from the five-act brief, exercised through the game reader.
const Sprite3DSheet = preload("res://addons/proto_kit/sprite3d_sheet.gd")
# Standing meters, tier, directions, required actions. Keep independent of generator.
const EXPECTED := {
	"luffy": [1.8, 1, 8, "idle walk punch gear2_walk fall down getup ride hit"],
	"ace": [1.85, 1, 8, "idle walk attack hit down"],
	"jinbe": [3.0, 1, 8, "idle walk attack hit"],
	"ivankov": [3.1, 1, 8, "idle walk attack hit"],
	"marine": [1.75, 1, 8, "walk hit attack down"],
	"marine_rifle": [1.75, 1, 8, "walk attack hit down"],
	"vice_admiral": [2.3, 1, 8, "walk hit attack down"],
	"pacifista": [6.9, 1, 8, "walk attack hit"],
	"wb_pirate_a": [1.9, 1, 8, "idle attack hit"],
	"wb_pirate_b": [2.1, 1, 8, "idle attack hit"],
	"smoker": [2.1, 2, 8, "idle walk attack smoke hit"],
	"garp": [2.9, 2, 8, "idle walk block hit knocked"],
	"akainu": [3.05, 2, 8, "idle walk attack"],
	"crocodile": [2.5, 2, 8, "idle walk attack"],
	"whitebeard": [6.7, 3, 1, "idle quake slash"],
	"aokiji": [3.0, 3, 1, "idle attack"],
	"kizaru": [3.0, 3, 1, "idle attack"],
	"hancock": [1.9, 3, 1, "idle kick"],
	"marco": [2.0, 3, 1, "idle phoenix"],
	"coby": [1.7, 3, 1, "idle hit knocked"],
	"sengoku_buddha": [9.0, 3, 1, "idle strike"],
	"executioner": [2.0, 3, 1, "idle raise down"],
	"ace_chained": [1.85, 3, 1, "kneel struggle"],
	"giant": [18.0, 3, 1, "walk"],
}
const PORTRAITS := "luffy_shout luffy_resolve luffy_hurt ace garp whitebeard smoker hancock jinbe ivankov crocodile marco kizaru aokiji akainu sengoku coby"
const LOOPING := ["idle", "walk", "gear2_walk", "ride", "smoke", "kneel", "struggle", "phoenix"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var tags := ["033", "025", "020"]
	var densities := [0.033, 0.025, 0.02]
	for i: int in tags.size():
		var base: String = "res://assets/sprites/density_%s" % tags[i]
		var index: Variant = JSON.parse_string(FileAccess.get_file_as_string(base + "/index.json"))
		_expect(index is Dictionary and index.get("characters") is Dictionary, "valid density index")
		if not index is Dictionary or not index.get("characters") is Dictionary:
			continue
		_expect(index.characters.size() == EXPECTED.size(), "all 24 actors, no extras")
		for character: String in EXPECTED:
			_expect(index.characters.has(character), character + " in index")
			if not index.characters.has(character):
				continue
			var entry: Dictionary = index.characters[character]
			var contract: Array = EXPECTED[character]
			_expect(is_equal_approx(float(entry.height_m), float(contract[0])), "standing world height")
			_expect(int(entry.tier) == int(contract[1]), "actor tier")
			var path: String = base.path_join(String(entry.sheet))
			_expect(FileAccess.file_exists(path), "sheet exists")
			var sheet = Sprite3DSheet.from_json(path, character)
			_expect(sheet != null, path + ": " + character)
			if sheet == null:
				continue
			_expect(sheet.atlas != null, "atlas texture imported")
			if sheet.atlas == null:
				continue
			_expect(sheet.atlas.get_width() <= 2048 and sheet.atlas.get_height() <= 2048, "mobile atlas size limit")
			_expect(sheet.atlas.get_width() == sheet.columns * sheet.cell_px and sheet.atlas.get_height() == sheet.rows * sheet.cell_px, "atlas grid dimensions")
			_expect(is_equal_approx(sheet.meters_per_px, densities[i]), "density")
			_expect(sheet.directions == int(contract[2]), "required directions")
			_expect(sheet.mirror == (character not in ["ace_chained", "sengoku_buddha", "giant"]), "mirror policy")
			var required: PackedStringArray = String(contract[3]).split(" ")
			_expect(sheet.anims.size() == required.size(), "exact animation set")
			var image: Image = sheet.atlas.get_image()
			var reference: Dictionary = sheet.anims.values()[0]
			var ref_cell: int = int(reference.cell)
			var ref_image: Image = image.get_region(Rect2i((ref_cell % sheet.columns) * sheet.cell_px, (ref_cell / sheet.columns) * sheet.cell_px, sheet.cell_px, sheet.cell_px))
			var height_px: int = roundi(float(contract[0]) / densities[i])
			if character == "ace_chained":
				height_px = roundi(height_px * 0.5)
			_expect(absi(ref_image.get_used_rect().size.y - height_px) <= 2, "native reference / kneeling pose height")
			for action: String in required:
				_expect(sheet.anims.has(action), character + ": " + action)
				if not sheet.anims.has(action):
					continue
				var anim: Dictionary = sheet.anims[action]
				_expect(int(anim.n) > 0 and anim.d.size() == int(anim.n), "frame durations complete")
				_expect(bool(anim.loop) == (action in LOOPING), "loop / one-shot")
				for duration: int in anim.d:
					_expect(duration > 0, "positive ticks")
				for direction: int in sheet.logical_count():
					var row: int = [0, 1, 2, 3, 4, 3, 2, 1][direction] if sheet.directions == 8 else 0
					var flip: int = -1 if (sheet.directions == 8 and direction > 4) or (sheet.directions == 1 and sheet.mirror and direction == 1) else 1
					var angle: float = direction * 45.0 if sheet.directions == 8 else 90.0 + direction * 180.0
					_expect(sheet.direction(angle) == direction, "direction selection")
					var tick: int = 0
					for frame: int in int(anim.n):
						var actual: Vector2i = sheet.cell(StringName(action), direction, tick)
						_expect(actual == Vector2i(int(anim.cell) + row * sheet.columns + frame, flip), "row / frame / mirror")
						_expect(actual.x >= 0 and actual.x < sheet.columns * sheet.rows, "cell fits atlas")
						tick += int(anim.d[frame])
					var after: Vector2i = sheet.cell(StringName(action), direction, tick)
					var final_frame: int = 0 if anim.loop else int(anim.n) - 1
					_expect(after.x == int(anim.cell) + row * sheet.columns + final_frame, "wrap / hold final pose")
		# Existing runtime IDs remain readable at their original entry point.
		for legacy: String in ["luffy", "marine", "vice_admiral"]:
			_expect(Sprite3DSheet.from_json(base + "/sheets.json", legacy) != null, "legacy sheet compatibility")
	var hashes: Dictionary = {}
	for identifier: String in PORTRAITS.split(" "):
		var texture := load("res://assets/portraits/%s.png" % identifier) as Texture2D
		var image: Image = texture.get_image() if texture != null else null
		_expect(image != null and image.get_size() == Vector2i(96, 96), "96px portrait: " + identifier)
		if image == null:
			continue
		_expect(image.get_used_rect().has_area() and image.detect_alpha() == Image.ALPHA_BIT, "transparent binary-alpha bust")
		hashes[identifier] = image.get_data().hex_encode().sha256_text()
	_expect(hashes.luffy_shout != hashes.luffy_resolve and hashes.luffy_shout != hashes.luffy_hurt and hashes.luffy_resolve != hashes.luffy_hurt, "three distinct Luffy expressions")
	print("Sprite asset checks: ", checks)
	_finish("SPRITES TESTS")
