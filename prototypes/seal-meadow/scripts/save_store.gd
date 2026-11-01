extends RefCounted
## Game-specific envelope checks and validated recovery. Kit copies remain unchanged.
const AtomicFile = preload("res://addons/proto_kit/atomic_file.gd")
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

static func restore(path: String, version: int, migrations: Dictionary) -> Dictionary:
	var error := "missing"
	for source: String in ["main", "backup"]:
		var loaded := inspect(path if source == "main" else path + ".bak", version)
		if loaded.error == "newer":
			return {"error": "newer", "data": {}, "source": ""}
		if loaded.error != "":
			if loaded.error != "missing":
				error = loaded.error
			continue
		var v: int = loaded.version
		var data: Dictionary = loaded.data
		while v < version:
			if not migrations.has(v):
				return {"error": "migration", "data": {}, "source": ""}
			data = migrations[v].call(data)
			v += 1
		if not Validation.valid(data):
			error = "corrupt"
			continue
		return {"error": "", "data": data, "source": source}
	return {"error": error, "data": {}, "source": ""}
