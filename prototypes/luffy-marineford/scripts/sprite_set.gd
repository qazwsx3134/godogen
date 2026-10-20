extends RefCounted
## The placeholder cast at one pixel density (tools/make_placeholder_sprites.py -> assets/sprites/density_<id>/):
## Luffy, the common Marine and the vice admiral, plus the rest of the Marineford cast listed in index.json (one sheets
## JSON per atlas). Spike QA `density=033|025|020` picks the set; world heights stay fixed, only pixels per meter change.

const Sprite3DSheet = preload("res://addons/proto_kit/sprite3d_sheet.gd")
const DENSITIES := ["033", "025", "020"]
const DEFAULT := "025"

## World heights (m) of the first three characters; the others come from index.json.
const HEIGHTS := {"luffy": 1.8, "marine": 1.75, "vice_admiral": 2.3}

## The density every sheet() call reads (main sets it from QA at start).
static var current: String = DEFAULT
static var _cache: Dictionary = {}
static var _index: Dictionary = {}
static var _index_density: String = ""

var density: String
var luffy: Resource
var marine: Resource
var vice_admiral: Resource


static func load_set(id: String) -> RefCounted:
	if not DENSITIES.has(id):
		push_warning("unknown density '%s', using %s" % [id, DEFAULT])
		id = DEFAULT
	current = id
	var set: RefCounted = new()
	set.density = id
	set.luffy = sheet("luffy")
	set.marine = sheet("marine")
	set.vice_admiral = sheet("vice_admiral")
	return set


static func _dir() -> String:
	return "res://assets/sprites/density_%s/" % current


static func _load_index() -> void:
	if _index_density == current:
		return
	_index_density = current
	_index = {}
	var path: String = _dir() + "index.json"
	if FileAccess.file_exists(path) or ResourceLoader.exists(path):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary:
			_index = data.get("characters", {})


## The sheet of character `id` at the current density (cached), or null when the cast has no such character.
static func sheet(id: String) -> Resource:
	var key: String = current + "/" + id
	if _cache.has(key):
		return _cache[key]
	_load_index()
	var file: String = String(_index[id].get("sheet", "sheets.json")) if _index.has(id) else "sheets.json"
	var path: String = _dir() + file
	var result: Resource = null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if data is Dictionary and (data.get("characters", {}) as Dictionary).has(id):
		result = Sprite3DSheet.from_json(path, id)
	_cache[key] = result
	return result


## World height (m) of character `id`.
static func height(id: String) -> float:
	_load_index()
	if _index.has(id):
		return float(_index[id].get("height_m", 1.8))
	return float(HEIGHTS.get(id, 1.8))


## Every character id the current density's index lists (the first three when there is no index yet).
static func ids() -> PackedStringArray:
	_load_index()
	return PackedStringArray(_index.keys()) if not _index.is_empty() else PackedStringArray(HEIGHTS.keys())
