extends RefCounted
## The stories the player can pick and what the player has reached in them (user://progress.cfg).
## Stories come from data/stories.json (the base work) and from story packs, stories/<work>/pack.json
## (IMPLEMENTATION.md「故事包」). Per story: title and credits, the best grade of a cleared chapter,
## the endings seen, the `carry` flags a chapter ended with, which chapter opens next; per work: the
## chapter order and the backgrounds and music met in play for 鑑賞. main.gd owns one; 章節選擇, the
## result card, 製作名單 and 鑑賞 read it.

const StoryRunner = preload("res://scripts/story_runner.gd")
const AssetUsage = preload("res://scripts/asset_usage.gd")

## Each entry: {id, kind ("chapter" or "sample"), path, save, work, work_title} and optional skin,
## cover, credits; the base work's entries first, then each pack's in folder order. `work` is "" for
## the base work.
var stories: Array[Dictionary] = []
var progress_path: String = ""
## Story ids a pack listed that were already taken (those entries are left out).
var rejected: Array[String] = []
## Title and credits by story path, read once from the story file.
var _meta: Dictionary = {}
## 鑑賞 unlocks by kind ("bg", "bgm"), read once: {kind: Array of ids}.
var _unlocked: Dictionary = {}


func _init(stories_path: String, progress_file: String, packs_root: String = "res://stories/") -> void:
	stories = read_registry(stories_path)
	for entry: Dictionary in stories:
		entry["work"] = ""
		entry["work_title"] = ""
	_add_packs(packs_root)
	progress_path = progress_file


## Every stories/<work>/pack.json, in folder order; a story id already taken is left out.
func _add_packs(packs_root: String) -> void:
	if not DirAccess.dir_exists_absolute(packs_root):
		return
	var folders: PackedStringArray = DirAccess.get_directories_at(packs_root)
	var sorted: Array = Array(folders)
	sorted.sort()
	for folder: String in sorted:
		for entry: Dictionary in read_pack(packs_root.path_join(folder)):
			if stories.any(func(other: Dictionary) -> bool: return other["id"] == entry["id"]):
				rejected.append(str(entry["id"]))
				push_error("story pack %s: story id '%s' is already taken; left out" % [folder, entry["id"]])
				continue
			stories.append(entry)


## The entries of the pack in `folder` (pack.json), with paths made res:// and the work's skin,
## cover and credits as each story's defaults. [] when there is no valid pack.json.
static func read_pack(folder: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("pack.json")))
	if not parsed is Dictionary or not str((parsed as Dictionary).get("id", "")).is_valid_identifier():
		return entries
	var pack: Dictionary = parsed as Dictionary
	var work: String = str(pack["id"])
	for raw: Variant in pack.get("stories", []):
		if not raw is Dictionary or not (raw as Dictionary).has_all(["id", "path"]):
			continue
		var entry: Dictionary = (raw as Dictionary).duplicate(true)
		entry["kind"] = str(entry.get("kind", "sample"))
		entry["path"] = _in_folder(folder, str(entry["path"]))
		entry["save"] = "user://pack_%s_%s.save" % [work, entry["id"]]
		entry["work"] = work
		entry["work_title"] = str(pack.get("title", work))
		for key: String in ["skin", "cover", "credits"]:
			if not entry.has(key) and pack.has(key):
				entry[key] = pack[key]
		if entry.has("cover"):
			entry["cover"] = _in_folder(folder, str(entry["cover"]))
		entries.append(entry)
	return entries


static func _in_folder(folder: String, path: String) -> String:
	return path if path.contains("://") else folder.path_join(path)


## The registry entries that have an id, a path and a save.
static func read_registry(path: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if parsed is Dictionary:
		for entry: Variant in (parsed as Dictionary).get("stories", []):
			if entry is Dictionary and (entry as Dictionary).has_all(["id", "path", "save"]):
				entries.append(entry as Dictionary)
	return entries


## The registry index of the story at `path`, -1 when it is not listed.
func index_of_path(path: String) -> int:
	for index: int in range(stories.size()):
		if stories[index]["path"] == path:
			return index
	return -1


# ---------------------------------------------------------------- title and credits

func title(entry: Dictionary) -> String:
	return str(_read_meta(entry)["title"])


## A story's `credits`, else its work's ([] when there are none or they are malformed).
func credits(entry: Dictionary) -> Array:
	var own: Array = _read_meta(entry)["credits"]
	if own.is_empty() and entry.get("credits") is Array and StoryRunner.new().validate_credits(entry["credits"]).is_empty():
		return entry["credits"]
	return own


## Credits in one line for a chapter row or the result card: 「劇本 甲｜繪 乙、丙」, the first three roles.
static func credit_line(credit_list: Array) -> String:
	var parts: PackedStringArray = []
	for credit: Dictionary in credit_list.slice(0, 3):
		parts.append("%s %s" % [credit["role"], "、".join(PackedStringArray(credit["names"]))])
	return "｜".join(parts)


## 製作名單: every story with credits, in the registry's order, then the game's own
## ({title, credits} at `game_credits_path`). A story's credits are followed by the makers of the
## pictures and music it uses (their catalog `license`), without repeating a name under a role.
func credit_sections(game_credits_path: String) -> Array[Dictionary]:
	var sections: Array[Dictionary] = []
	for entry: Dictionary in stories:
		var rows: Array = _with_asset_credits(credits(entry), entry)
		if not rows.is_empty():
			sections.append({"title": title(entry), "credits": rows})
	var game: Variant = JSON.parse_string(FileAccess.get_file_as_string(game_credits_path)) \
		if FileAccess.file_exists(game_credits_path) else null
	if game is Dictionary and StoryRunner.new().validate_credits((game as Dictionary).get("credits")).is_empty():
		sections.append({"title": str((game as Dictionary).get("title", "")), "credits": (game as Dictionary)["credits"]})
	return sections


## `own` credits and then, role by role, the asset makers of the story not named there already.
func _with_asset_credits(own: Array, entry: Dictionary) -> Array:
	var path: String = str(entry["path"])
	var story: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	var catalog: Dictionary = StoryRunner.read_catalog(StoryRunner.catalog_path_for(path)).get("catalog", {})
	if not story is Dictionary or catalog.is_empty():
		return own
	var pov: String = str((story as Dictionary).get("default_pov", catalog.get("default_pov", "")))
	var rows: Array = own.duplicate(true)
	for asset_row: Dictionary in AssetUsage.credits(catalog, AssetUsage.used(story, catalog, pov)):
		var named: Array = []
		for row: Dictionary in rows:
			if row["role"] == asset_row["role"]:
				named.append_array(row["names"])
		var names: Array = (asset_row["names"] as Array).filter(func(n: String) -> bool: return not named.has(n))
		if names.is_empty():
			continue
		var existing: Array = rows.filter(func(row: Dictionary) -> bool: return row["role"] == asset_row["role"])
		if existing.is_empty():
			rows.append({"role": asset_row["role"], "names": names})
		else:
			(existing[0]["names"] as Array).append_array(names)
	return rows


## The picture on a story's 章節選擇 card: the registry's `cover` when it names a picture, else the
## first background with a picture the story shows, walking its nodes from `entry`, in that story's
## own catalog. "" for none.
func cover(entry: Dictionary) -> String:
	var catalog: Dictionary = StoryRunner.read_catalog(StoryRunner.catalog_path_for(str(entry["path"]))).get("catalog", {})
	var backgrounds: Dictionary = catalog.get("backgrounds", {}) as Dictionary
	var named: String = str(entry.get("cover", ""))
	if not named.is_empty() and ResourceLoader.exists(named):
		return named
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(entry["path"])))
	if not parsed is Dictionary:
		return ""
	var nodes: Dictionary = (parsed as Dictionary).get("nodes", {}) as Dictionary
	var queue: Array = [str((parsed as Dictionary).get("entry", ""))]
	var visited: Dictionary = {}
	while not queue.is_empty():
		var node_id: String = queue.pop_front()
		if visited.has(node_id) or not nodes.has(node_id):
			continue
		visited[node_id] = true
		var node: Dictionary = nodes[node_id] as Dictionary
		for step: Variant in node.get("steps", []):
			if step is Dictionary and str((step as Dictionary).get("op", "")) == "bg":
				var path: String = str((backgrounds.get(str((step as Dictionary).get("id", "")), {}) as Dictionary).get("path", ""))
				if not path.is_empty() and ResourceLoader.exists(path):
					return path
			_collect_targets(step, nodes, queue)
		_collect_targets(node.get("next", ""), nodes, queue)
	return ""


## Every string inside `value` that names a node, appended to `queue` (links of any op).
static func _collect_targets(value: Variant, nodes: Dictionary, queue: Array) -> void:
	if value is String and nodes.has(value):
		queue.append(value)
	elif value is Dictionary:
		for key: Variant in (value as Dictionary).keys():
			_collect_targets((value as Dictionary)[key], nodes, queue)
	elif value is Array:
		for item: Variant in value:
			_collect_targets(item, nodes, queue)


func _read_meta(entry: Dictionary) -> Dictionary:
	var path: String = str(entry["path"])
	if not _meta.has(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		var story: Dictionary = parsed as Dictionary if parsed is Dictionary else {}
		var credit_list: Variant = story.get("credits", [])
		_meta[path] = {"title": str(story.get("title", entry["id"])),
			"credits": credit_list if StoryRunner.new().validate_credits(credit_list).is_empty() else []}
	return _meta[path]


# ---------------------------------------------------------------- progress

## The best grade of a cleared story, "" when not cleared.
func cleared_grade(story_id: String) -> String:
	var config: ConfigFile = ConfigFile.new()
	return str(config.get_value("cleared", story_id, "")) if config.load(progress_path) == OK else ""


## Keeps `grade` when it beats the story's best.
func record_clear(story_id: String, grade: String) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(progress_path)
	var best: String = str(config.get_value("cleared", story_id, ""))
	var grades: Array = StoryRunner.GRADES
	if best.is_empty() or grades.find(grade) < grades.find(best):
		config.set_value("cleared", story_id, grade)
		config.save(progress_path)


## An `end`/`result` reached: `ending` ("" for none) joins the story's seen endings, and a
## non-empty `carried` replaces the flags it hands to the next chapter.
func record_ending(story_id: String, ending: String, carried: Dictionary) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(progress_path)
	var seen: Array = config.get_value("endings", story_id, [])
	if not ending.is_empty() and not seen.has(ending):
		config.set_value("endings", story_id, seen + [ending])
	if not carried.is_empty():
		config.set_value("carry", story_id, carried)
	if not carried.is_empty() or not ending.is_empty():
		config.save(progress_path)


## The `carry` values the chapter before stories[index] ended with; {} for samples, the first
## chapter, or when that chapter has not reached an end. Replaying a chapter never reads its own.
func previous_carry(index: int) -> Dictionary:
	var earlier: int = _chapter_before(index)
	if earlier < 0:
		return {}
	var config: ConfigFile = ConfigFile.new()
	config.load(progress_path)
	return config.get_value("carry", str(stories[earlier]["id"]), {}) as Dictionary


## "結局 1/3" for a story with `ending`s, "" without (its JSON is read for the total).
func ending_note(entry: Dictionary) -> String:
	var story: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(entry.get("path", ""))))
	if not story is Dictionary:
		return ""
	var endings: Array[Dictionary] = StoryRunner.endings_of(story)
	if endings.is_empty():
		return ""
	var seen: Array = _seen_endings(str(entry["id"]))
	return "結局 %d/%d" % [endings.filter(func(e: Dictionary) -> bool: return seen.has(e["id"])).size(), endings.size()]


## 結局收集: every `ending` of each chapter (samples excluded) with whether it was reached:
## [{chapter (the title before its first ・), title, seen}].
func chapter_endings() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for entry: Dictionary in stories:
		if str(entry.get("kind", "")) != "chapter":
			continue
		var story: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(entry["path"])))
		if not story is Dictionary:
			continue
		var seen: Array = _seen_endings(str(entry["id"]))
		var chapter: String = title(entry).get_slice("・", 0)
		if not str(entry["work"]).is_empty():
			chapter = "%s・%s" % [entry["work_title"], chapter]
		for ending: Dictionary in StoryRunner.endings_of(story):
			rows.append({"chapter": chapter, "title": str(ending["title"]), "seen": seen.has(ending["id"])})
	return rows


## The chapter after stories[index], {} when that is not a chapter or is the last.
func next_chapter(index: int) -> Dictionary:
	if index < 0 or str(stories[index].get("kind", "")) != "chapter":
		return {}
	for later: int in range(index + 1, stories.size()):
		if str(stories[later].get("kind", "")) == "chapter" and stories[later]["work"] == stories[index]["work"]:
			return stories[later]
	return {}


## A chapter opens once the chapter before it is cleared; samples are always open.
func unlocked(index: int) -> bool:
	if str(stories[index].get("kind", "")) != "chapter":
		return true
	var earlier: int = _chapter_before(index)
	return earlier < 0 or not cleared_grade(str(stories[earlier]["id"])).is_empty()


## The index of the chapter before stories[index] (a chapter), -1 when there is none.
func _chapter_before(index: int) -> int:
	if index < 0 or str(stories[index].get("kind", "")) != "chapter":
		return -1
	for earlier: int in range(index - 1, -1, -1):
		if str(stories[earlier].get("kind", "")) == "chapter" and stories[earlier]["work"] == stories[index]["work"]:
			return earlier
	return -1


func _seen_endings(story_id: String) -> Array:
	var config: ConfigFile = ConfigFile.new()
	config.load(progress_path)
	return config.get_value("endings", story_id, [])


# ---------------------------------------------------------------- 鑑賞

## The progress.cfg key of a work's 鑑賞 unlocks: "bg"/"bgm" for the base work, "<work>/bg" for a pack.
static func gallery_key(work: String, kind: String) -> String:
	return kind if work.is_empty() else "%s/%s" % [work, kind]


## Marks a background ("bg") or music ("bgm") id as met in play; written once per id. `kind` may be
## a work's key (gallery_key).
func unlock(kind: String, id: String) -> void:
	if id.is_empty() or unlocked_ids(kind).has(id):
		return
	(_unlocked[kind] as Array).append(id)
	var config: ConfigFile = ConfigFile.new()
	config.load(progress_path)
	config.set_value("gallery", kind, _unlocked[kind])
	config.save(progress_path)


## The ids of `kind` met in play, in the order they were first met.
func unlocked_ids(kind: String) -> Array:
	if not _unlocked.has(kind):
		var config: ConfigFile = ConfigFile.new()
		config.load(progress_path)
		_unlocked[kind] = (config.get_value("gallery", kind, []) as Array).duplicate()
	return _unlocked[kind]
