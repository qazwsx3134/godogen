extends RefCounted
## Seal adapter: v1+ envelope inspection, game payload validation, and kit snapshot IO.
const AtomicFile = preload("res://addons/proto_kit/atomic_file.gd")
const SaveSlots = preload("res://addons/proto_kit/save_slots.gd")
const Validation = preload("res://scripts/save_validation.gd")

static func inspect(path: String, version: int) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"error": "missing"}
	var json := JSON.new()
	if json.parse(AtomicFile.read_bytes(path).get_string_from_utf8()) != OK or not json.data is Dictionary:
		return {"error": "corrupt"}
	var raw: Dictionary = json.data
	var v: Variant = raw.get("version")
	if not (v is int or v is float) or not is_finite(float(v)):
		return {"error": "corrupt"}
	if float(v) > version:
		return {"error": "newer"}
	if float(v) < 1.0 or floorf(float(v)) != float(v) or not raw.get("data") is Dictionary:
		return {"error": "corrupt"}
	return {"error": "", "version": int(v), "data": raw.data}

## Keep the game's historical corrupt error for invalid payloads.
## Seal migrations start at v1; v0 has no migration and cannot be loaded.
static func restore(path: String, version: int, migrations: Dictionary) -> Dictionary:
	var restored: Dictionary = SaveSlots.restore(path, version, migrations, Validation.valid)
	if restored.error == "invalid":
		restored.error = "corrupt"
	return restored


static func save(path: String, snapshot: Dictionary, version: int, migrations: Dictionary) -> Error:
	return SaveSlots.save(path, snapshot, version, Validation.valid, migrations)
