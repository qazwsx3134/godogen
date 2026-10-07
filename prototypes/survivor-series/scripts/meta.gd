extends Node
## Between-run progress: coins, shop levels, records and unlocked achievements, saved as JSON.
const AtomicFile = preload("res://addons/proto_kit/atomic_file.gd")
@export var catalogue: Resource
@export var save_path: String = "user://survivor_meta.json"
var coins: int = 0
var shop_levels: Dictionary = {}
var unlocked: Array = []
var records: Dictionary = {}
## Last chosen hero id.
var hero: String = "man"
## Fusion ids discovered across runs (the codex).
var fusions: Array = []

func _ready() -> void:
	load_save()

func _defaults() -> void:
	coins = 0
	shop_levels = {}
	unlocked = []
	hero = "man"
	fusions = []
	records = {"best_time": 0.0, "best_kills": 0, "total_kills": 0, "best_level": 0, "wins": 0, "runs": 0}

func load_save() -> void:
	_defaults()
	var text: String = AtomicFile.read_bytes(save_path).get_string_from_utf8()
	var parser := JSON.new()
	if text == "" or parser.parse(text) != OK or not parser.data is Dictionary:
		return
	var data: Dictionary = parser.data
	coins = int(data.get("coins", 0))
	hero = str(data.get("hero", "man"))
	if data.get("fusions") is Array:
		fusions = data.fusions
	if data.get("shop") is Dictionary:
		shop_levels = data.shop
	if data.get("unlocked") is Array:
		unlocked = data.unlocked
	if data.get("records") is Dictionary:
		for key: String in records:
			records[key] = data.records.get(key, records[key])

func save() -> Error:
	return AtomicFile.write_text(save_path, JSON.stringify({"coins": coins, "hero": hero, "fusions": fusions, "shop": shop_levels, "unlocked": unlocked, "records": records}))

func level_of(id: StringName) -> int:
	return int(shop_levels.get(String(id), 0))

func item(id: StringName) -> Resource:
	for entry: Resource in catalogue.shop:
		if entry.id == id:
			return entry
	return null

func price(id: StringName) -> int:
	var entry: Resource = item(id)
	return -1 if entry == null or level_of(id) >= entry.max_level else entry.cost(level_of(id))

func buy(id: StringName) -> bool:
	var cost: int = price(id)
	if cost < 0 or coins < cost:
		return false
	coins -= cost
	shop_levels[String(id)] = level_of(id) + 1
	save()
	return true

## Permanent stat bonuses for Street's run build.
func bonuses() -> Dictionary:
	var total: Dictionary = {}
	for entry: Resource in catalogue.shop:
		total[entry.stat] = float(total.get(entry.stat, 0.0)) + entry.per_level * level_of(entry.id)
	return total

func is_unlocked(id: StringName) -> bool:
	return unlocked.has(String(id))

## Records one finished run, banks its coins and returns the achievements it unlocked.
func record_run(time: float, kills: int, level: int, won: bool, earned: int) -> Array[Resource]:
	coins += earned
	records.runs = int(records.runs) + 1
	records.best_time = maxf(float(records.best_time), time)
	records.best_kills = maxi(int(records.best_kills), kills)
	records.best_level = maxi(int(records.best_level), level)
	records.total_kills = int(records.total_kills) + kills
	if won:
		records.wins = int(records.wins) + 1
	var fresh: Array[Resource] = []
	for entry: Resource in catalogue.achievements:
		if not is_unlocked(entry.id) and float(records.get(entry.stat, 0)) >= entry.threshold:
			unlocked.append(String(entry.id))
			fresh.append(entry)
	save()
	return fresh
