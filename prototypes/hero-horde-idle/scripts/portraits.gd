extends RefCounted
## The 養成 screens' art (packed by tools/pack_stage_art.py): each class's ready stance and its head-and-shoulders
## square (assets/heroes/portraits; every hero of a class shares the class's art), the 招牌技 icons and the class
## pennants (assets/ui). An icon that has not been made yet falls back to the class's face.
##
## BATTLE_SPRITES picks what a hero looks like on cards (the roster, the march squad): true = the same pixel
## character as in the push and the march (the ready cell of assets/heroes/heroes.png, in that hero's own tint, with
## a dark one-texel outline: shaders/ui_sprite.gdshader); false = the face crop of the class's large portrait. The
## hero page always shows the large portrait: the 48 px battle sprite blown up to page size turns to blocks.

const DIR := "res://assets/heroes/portraits/"
const FILES := ["shield", "sword", "spear", "bow", "mage", "healer"]
## Each class's title on the hero page (PushSim.CLASS_NAMES are the one-character tab names).
const TITLES := ["盾衛", "劍士", "槍兵", "弓手", "法師", "補師"]
const UI_DIR := "res://assets/ui/"
const Army = preload("res://scripts/army.gd")
const BATTLE_SPRITES := true
const HEROES := "res://assets/heroes/heroes.png"
const CELL := 48
const READY_CELL := 4
## The sprite's outline in the UI: the same dark line for every rarity (the rarity shows as the card's small tag).
const OUTLINE := "res://materials/ui_sprite_dark.tres"
## PushSim.Sig order.
const SIG_FILES := ["wall", "cleave", "gale", "pierce", "arrow", "meteor", "dawn"]
const RARITY_COLORS := [Color("b9b4a8"), Color("86b8d8"), Color("bc98dc"), Color("e2b866")]

static var _faces: Dictionary = {}
static var _face_cache: Dictionary = {}
static var _sprite_cache: Dictionary = {}


## heroes.png rows per 形態 (domain/heroes.gd): the six class rows of humans, then monsters, then dreamlings.
const FORM_PREFIX := ["", "monster_", "dream_"]


static func row_of(form: int, c: int) -> int:
	return maxi(form, 0) * FILES.size() + c


## A hero's ready stance by form and class (see sprite_row).
static func hero_sprite(form: int, c: int) -> AtlasTexture:
	return sprite_row(row_of(form, c))


## A hero's large portrait: the class's for humans, the form's placeholder for the others.
static func hero_full(form: int, c: int) -> Texture2D:
	if form <= 0:
		return full(c)
	return load(DIR + FORM_PREFIX[form] + FILES[c] + ".png")


static func sprite(c: int) -> AtlasTexture:
	return sprite_row(c)


## The ready stance of heroes.png row `row` as drawn in the push, cropped to the figure plus one texel for the outline.
static func sprite_row(c: int) -> AtlasTexture:
	if _sprite_cache.has(c):
		return _sprite_cache[c]
	var sheet: Texture2D = load(HEROES)
	var cell := Rect2i(READY_CELL * CELL, c * CELL, CELL, CELL)
	var image: Image = sheet.get_image()
	if image.is_compressed():
		image.decompress()
	var used: Rect2i = image.get_region(cell).get_used_rect().grow(1).intersection(Rect2i(0, 0, CELL, CELL))
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(cell.position + used.position, used.size)
	_sprite_cache[c] = atlas
	return atlas


## What a hero looks like on a card (see BATTLE_SPRITES); hero(), tint() and material() go on the same TextureRect.
static func card(c: int) -> Texture2D:
	return sprite(c) if BATTLE_SPRITES else face(c)


## The hero's own tint, half as strong as in the push (the push's warm light lifts it there; on a dark card the full
## tint muddies the art). White for the portraits, which are not tinted.
static func tint(i: int, c: int) -> Color:
	return Army.tint(i, c).lerp(Color.WHITE, 0.5) if BATTLE_SPRITES else Color.WHITE


static func material(_rarity: int) -> Material:
	return load(OUTLINE) if BATTLE_SPRITES else null


static func full(c: int) -> Texture2D:
	return load(DIR + FILES[c] + ".png")


static func face(c: int) -> AtlasTexture:
	if _face_cache.has(c):
		return _face_cache[c]
	if _faces.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + "portraits.json"))
		_faces = data.get("face", {}) if data is Dictionary else {}
	var atlas := AtlasTexture.new()
	atlas.atlas = full(c)
	var f: Array = _faces.get(FILES[c], [0, 0, 64, 64])
	atlas.region = Rect2(f[0], f[1], f[2], f[3])
	_face_cache[c] = atlas
	return atlas


static func sig_icon(sig: int, c: int) -> Texture2D:
	var path: String = UI_DIR + "sig/" + SIG_FILES[sig] + ".png"
	return load(path) if ResourceLoader.exists(path) else face(c)


static func class_icon(c: int) -> Texture2D:
	var path: String = UI_DIR + "class/" + FILES[c] + ".png"
	return load(path) if ResourceLoader.exists(path) else face(c)
