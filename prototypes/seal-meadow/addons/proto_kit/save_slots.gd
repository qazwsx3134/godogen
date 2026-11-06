extends RefCounted
## Versioned JSON snapshots. One writer per path; callbacks must be pure and must not write files.
## validator(Dictionary) -> bool checks the CURRENT schema after migration / JSON serialization.
## migrations: {from_version: Callable(Dictionary) -> Dictionary}, one version per step.
## restore never writes. Either file from a newer version blocks restore AND save.
## No cross-process lock or two-file transaction. AtomicFile commits each file separately.

const AtomicFile = preload("res://addons/proto_kit/atomic_file.gd")


## Existing three-argument calls remain valid. Invalid snapshots never rotate backups.
## ERR_UNAVAILABLE: newer on disk; ERR_INVALID_DATA: candidate rejected; other errors: file IO.
## Only a valid main becomes .bak, preserving its original bytes. Otherwise retain the existing backup.
static func save(path: String, data: Dictionary, version: int, validator: Callable = Callable(), migrations: Dictionary = {}) -> Error:
	if path.is_empty() or version < 0:
		return ERR_INVALID_PARAMETER
	# Validate exactly the JSON representation that will be committed, not the caller's live objects.
	var text: String = JSON.stringify({"version": version, "data": data})
	var encoded := JSON.new()
	if encoded.parse(text) != OK or not encoded.data is Dictionary:
		return ERR_INVALID_DATA
	var candidate: Dictionary = _prepare(encoded.data, version, {}, validator)
	if candidate.error != "":
		return ERR_INVALID_DATA
	var main: Dictionary = _inspect(path, version)
	var backup: Dictionary = _inspect(path + ".bak", version)
	if main.error == "newer" or backup.error == "newer":
		return ERR_UNAVAILABLE
	if main.error == "" and _prepare(main.raw, version, migrations, validator).error == "":
		var backup_error: Error = AtomicFile.write_bytes(path + ".bak", main.bytes)
		if backup_error != OK:
			return backup_error
	return AtomicFile.write_text(path, text)


## Returns {data, source: "main"|"backup"|"", error: ""|"missing"|"corrupt"|"newer"|"migration"|"invalid"}.
## Invalid payload / migration may fall back to backup; newer in EITHER file always blocks.
## data is detached from disk; no repair or automatic write occurs when selecting backup.
static func restore(path: String, version: int, migrations: Dictionary = {}, validator: Callable = Callable()) -> Dictionary:
	if path.is_empty() or version < 0:
		return _result("invalid")
	var entries: Array[Dictionary] = [_inspect(path, version), _inspect(path + ".bak", version)]
	for entry: Dictionary in entries:
		if entry.error == "newer":
			return _result("newer")
	var error := "missing"
	for index: int in range(entries.size()):
		var entry: Dictionary = entries[index]
		if entry.error != "":
			if error == "missing":
				error = entry.error
			continue
		var prepared: Dictionary = _prepare(entry.raw, version, migrations, validator)
		if prepared.error == "":
			return {"data": prepared.data, "source": "main" if index == 0 else "backup", "error": ""}
		if error == "missing" or error == "corrupt":
			error = prepared.error
	return _result(error)


static func _result(error: String) -> Dictionary:
	return {"data": {}, "source": "", "error": error}


## Checks numeric versions before conversion, including future envelopes with malformed payloads.
static func _inspect(path: String, version: int) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"error": "missing"}
	var bytes: PackedByteArray = AtomicFile.read_bytes(path)
	var json := JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK or not json.data is Dictionary:
		return {"error": "corrupt"}
	var raw: Dictionary = json.data
	var v: Variant = raw.get("version")
	if not (v is int or v is float) or not is_finite(float(v)):
		return {"error": "corrupt"}
	if float(v) > version:
		return {"error": "newer"}
	if float(v) < 0.0 or floorf(float(v)) != float(v) or not raw.get("data") is Dictionary:
		return {"error": "corrupt"}
	return {"error": "", "raw": raw, "bytes": bytes}


static func _prepare(raw: Dictionary, version: int, migrations: Dictionary, validator: Callable) -> Dictionary:
	var data: Dictionary = raw.data.duplicate(true)
	var v: int = int(raw.version)
	while v < version:
		var migration: Variant = migrations.get(v)
		if not migration is Callable or not migration.is_valid():
			return _result("migration")
		var next: Variant = migration.call(data)
		if not next is Dictionary:
			return _result("migration")
		data = next.duplicate(true)
		v += 1
	if not validator.is_null():
		if not validator.is_valid():
			return _result("invalid")
		var accepted: Variant = validator.call(data.duplicate(true))
		if not accepted is bool or not accepted:
			return _result("invalid")
	return {"data": data, "error": ""}
