extends RefCounted
## Versioned JSON save with a backup and step-by-step migrations. Commits go through atomic_file.gd.
## `const SaveSlots = preload("res://addons/proto_kit/save_slots.gd")`
##
## save(): the current main file, if it reads, becomes `path.bak`; then the new data is committed.
## restore(): main, else backup. Data from a newer build is refused (never silently downgraded).
## migrations: {from_version: Callable(Dictionary) -> Dictionary}, each moves one version up.
## Ints come back as floats (JSON); cast what you read.

const AtomicFile = preload("res://addons/proto_kit/atomic_file.gd")


static func save(path: String, data: Dictionary, version: int) -> Error:
	var current: Variant = _read(path)
	if current is Dictionary:
		var backup_error: Error = AtomicFile.write_bytes(path + ".bak", AtomicFile.read_bytes(path))
		if backup_error != OK:
			return backup_error
	return AtomicFile.write_text(path, JSON.stringify({"version": version, "data": data}))


## Returns {data, source: "main"|"backup"|"", error: ""|"missing"|"corrupt"|"newer"|"migration"}.
static func restore(path: String, version: int, migrations: Dictionary = {}) -> Dictionary:
	var error := "missing"
	for source: String in ["main", "backup"]:
		var file: String = path if source == "main" else path + ".bak"
		if not FileAccess.file_exists(file):
			continue
		var raw: Variant = _read(file)
		if not (raw is Dictionary and raw.get("data") is Dictionary):
			error = "corrupt"
			continue
		var v: int = int(raw.get("version", 0))
		if v > version:
			return {"data": {}, "source": "", "error": "newer"}
		var data: Dictionary = raw.data
		while v < version:
			if not migrations.has(v):
				return {"data": {}, "source": "", "error": "migration"}
			data = migrations[v].call(data)
			v += 1
		return {"data": data, "source": source, "error": ""}
	return {"data": {}, "source": "", "error": error}


static func _read(path: String) -> Variant:
	var bytes: PackedByteArray = AtomicFile.read_bytes(path)
	if bytes.is_empty():
		return null
	var json := JSON.new()  # not JSON.parse_string: a corrupt file is expected here, no error spam
	return json.data if json.parse(bytes.get_string_from_utf8()) == OK else null
