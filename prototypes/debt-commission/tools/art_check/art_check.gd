extends RefCounted
## 投稿檢查: for one work (data/ for the base work, or stories/<作品>/), what its stories use and what
## is still to be drawn, against docs/ART-SPEC.md. Three levels:
##   錯誤  a story the game rejects; an asset whose `path` names a missing or unreadable file
##   待辦  a used background or character with no picture yet (gradient / silhouette), a used face
##         with no picture
##   建議  sizes and shapes below ART-SPEC.md's advice
## plus used assets with a picture but no `license` (IMPLEMENTATION.md「素材授權」) and unused ones.
## Pictures are read from their source files (not the imported textures). Used by
## tools/art_check/run.gd (command line) and the editor menu 作品：投稿檢查 (addons/story_tools).

const StoryRunner = preload("res://scripts/story_runner.gd")
const StoryLibrary = preload("res://scripts/story_library.gd")
const AssetUsage = preload("res://scripts/asset_usage.gd")
const BASE_FOLDER: String = "res://data/"
const BASE_REGISTRY: String = "res://data/stories.json"
## ART-SPEC.md figures.
const BACKGROUND_MIN: Vector2i = Vector2i(1080, 2340)
const INVESTIGATION_RATIO: float = 4.0 / 3.0
const PORTRAIT_MIN_HEIGHT: int = 1600
const ITEM_MIN: int = 512
## A portrait's feet may sit this far (of its height) above the bottom edge; empty margins beyond
## this share of the picture on a side shrink the figure.
const FOOT_GAP: float = 0.02
const MARGIN: float = 0.15


## The works there are: the base work, then each stories/<作品>/ with a pack.json.
static func works(packs_root: String = "res://stories/") -> Array[String]:
	var folders: Array[String] = [BASE_FOLDER]
	if DirAccess.dir_exists_absolute(packs_root):
		for name: String in DirAccess.get_directories_at(packs_root):
			if FileAccess.file_exists(packs_root.path_join(name).path_join("pack.json")):
				folders.append(packs_root.path_join(name) + "/")
	return folders


## The report of one work: {title, folder, stories, errors, todo, suggestions, no_license, unused}.
static func check(folder: String) -> Dictionary:
	folder = folder.trim_suffix("/") + "/"
	var base: bool = folder == BASE_FOLDER
	var entries: Array[Dictionary] = StoryLibrary.read_registry(BASE_REGISTRY) if base \
		else StoryLibrary.read_pack(folder.trim_suffix("/"))
	var title: String = "本作"
	if not base:
		var pack: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder + "pack.json"))
		title = str((pack as Dictionary).get("title", folder)) if pack is Dictionary else folder
	var report: Dictionary = {"title": title, "folder": folder, "stories": [], "errors": [], "todo": [],
		"suggestions": [], "no_license": [], "unused": []}
	var catalog_path: String = StoryRunner.catalog_path_for(folder + "x_story.json")
	var read: Dictionary = StoryRunner.read_catalog(catalog_path)
	if read.has("error"):
		report["errors"].append("素材設定 %s 讀不了：%s" % [catalog_path, read["error"]])
		return report
	var catalog: Dictionary = read["catalog"]
	# Every story's usage, merged: {collection: {id: ["故事:節點", …]}}, characters with their faces.
	var usage: Dictionary = {"backgrounds": {}, "characters": {}, "items": {}, "sounds": {}, "music": {}, "investigation": {}}
	for entry: Dictionary in entries:
		var path: String = str(entry["path"])
		var row: Dictionary = {"id": entry["id"], "path": path, "error": ""}
		report["stories"].append(row)
		var runner: RefCounted = StoryRunner.new()
		if not runner.call("load_story", path):
			row["error"] = str(runner.get("error_message"))
			report["errors"].append("劇本 %s（%s）：%s" % [entry["id"], path, row["error"]])
		var story: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		if not story is Dictionary:
			continue
		var pov: String = str(runner.call("default_pov")) if row["error"].is_empty() else str(catalog.get("default_pov", ""))
		_merge(usage, AssetUsage.used(story, catalog, pov), str(entry["id"]))
	_check_backgrounds(report, catalog, usage, base)
	_check_characters(report, catalog, usage, base, folder)
	_check_items_and_sounds(report, catalog, usage)
	for collection: String in AssetUsage.COLLECTIONS:
		for id: String in (catalog.get(collection, {}) as Dictionary).keys():
			if not (usage[collection] as Dictionary).has(id):
				report["unused"].append("%s/%s" % [collection, id])
	return report


## 錯誤 count of a report (the command line exits 1 when any work has one).
static func error_count(report: Dictionary) -> int:
	return (report["errors"] as Array).size()


static func to_markdown(report: Dictionary) -> String:
	var lines: PackedStringArray = ["# 投稿檢查：%s" % report["title"], "",
		"資料夾 `%s`，%d 個故事。規格見 docs/ART-SPEC.md。" % [report["folder"], (report["stories"] as Array).size()], "",
		"| 錯誤 | 待辦 | 建議 | 缺授權 |", "|---|---|---|---|",
		"| %d | %d | %d | %d |" % [(report["errors"] as Array).size(), (report["todo"] as Array).size(),
			(report["suggestions"] as Array).size(), (report["no_license"] as Array).size()], ""]
	for section: Array in [["錯誤（要先修，遊戲會出錯或少圖）", "errors"], ["美術待辦（還沒有圖；遊戲先顯示漸層或剪影）", "todo"],
			["建議（照規格會更好）", "suggestions"]]:
		lines.append("## " + section[0])
		lines.append("")
		if (report[section[1]] as Array).is_empty():
			lines.append("（沒有）")
		for item: String in report[section[1]]:
			lines.append("- " + item)
		lines.append("")
	lines.append("## 授權")
	lines.append("")
	if (report["no_license"] as Array).is_empty():
		lines.append("用到的素材都有授權資訊。")
	else:
		lines.append("缺授權資訊：%d 項（catalog 的 `license`：author、source、license、approved；格式見 IMPLEMENTATION.md「素材授權」）：%s"
			% [(report["no_license"] as Array).size(), "、".join(PackedStringArray(report["no_license"]))])
	lines.append("")
	lines.append("## 劇本沒用到的素材")
	lines.append("")
	lines.append("遊戲本身或外觀包也可能用到（例如效果音、標題音樂），刪除前先確認。")
	lines.append("")
	lines.append("、".join(PackedStringArray(report["unused"])) if not (report["unused"] as Array).is_empty() else "（沒有）")
	lines.append("")
	return "\n".join(lines)


static func _merge(usage: Dictionary, used: Dictionary, story_id: String) -> void:
	for id: String in (used["investigation"] as Dictionary).keys():
		usage["investigation"][id] = true
	for collection: String in AssetUsage.COLLECTIONS:
		for id: String in (used[collection] as Dictionary).keys():
			if collection == "characters":
				if not usage[collection].has(id):
					usage[collection][id] = {"nodes": [], "expressions": {}}
				var target: Dictionary = usage[collection][id]
				for node: String in used[collection][id]["nodes"]:
					target["nodes"].append("%s:%s" % [story_id, node])
				for face: String in (used[collection][id]["expressions"] as Dictionary).keys():
					if not target["expressions"].has(face):
						target["expressions"][face] = []
					for node: String in used[collection][id]["expressions"][face]:
						target["expressions"][face].append("%s:%s" % [story_id, node])
			else:
				if not usage[collection].has(id):
					usage[collection][id] = []
				for node: String in used[collection][id]:
					usage[collection][id].append("%s:%s" % [story_id, node])


static func _where(places: Array) -> String:
	var shown: Array = places.slice(0, 3)
	return "、".join(PackedStringArray(shown)) + ("…等 %d 處" % places.size() if places.size() > 3 else "")


## The picture at `path`, or an error message.
static func _picture(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return "檔案不存在"
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty():
		return "讀不了（格式不支援或檔案壞了）"
	return image


static func _license(report: Dictionary, collection: String, id: String, info: Dictionary) -> void:
	var license: Variant = info.get("license")
	if not str(info.get("path", "")).is_empty() and not (license is Dictionary and not AssetUsage.authors(license).is_empty()):
		report["no_license"].append("%s/%s" % [collection, id])


static func _check_backgrounds(report: Dictionary, catalog: Dictionary, usage: Dictionary, base: bool) -> void:
	for id: String in (usage["backgrounds"] as Dictionary).keys():
		var info: Dictionary = catalog["backgrounds"][id]
		var name: String = "背景 %s（%s）" % [info.get("label", id), id]
		var path: String = str(info.get("path", ""))
		var investigation: bool = (usage["investigation"] as Dictionary).has(id)
		if path.is_empty() and str(info.get("top", "")) == str(info.get("bottom", "")):
			continue  # one flat colour (a black screen): meant to have no picture
		if path.is_empty():
			report["todo"].append("%s：還沒有圖，目前是漸層。PNG／JPG，高 ≥ %d、寬 ≥ %d%s；放 %s，catalog 寫 `path`。用在 %s"
				% [name, BACKGROUND_MIN.y, BACKGROUND_MIN.x, "，調查用要畫寬（4:3 以上，例如 3120×2340）" if investigation else "",
				"assets/image/" if base else "art/", _where(usage["backgrounds"][id])])
			continue
		_license(report, "backgrounds", id, info)
		var picture: Variant = _picture(path)
		if picture is String:
			report["errors"].append("%s：`%s` %s" % [name, path, picture])
			continue
		var size: Vector2i = (picture as Image).get_size()
		if size.x < BACKGROUND_MIN.x or size.y < BACKGROUND_MIN.y:
			report["suggestions"].append("%s 是 %d×%d，建議高 ≥ %d、寬 ≥ %d（長手機上放大約 %.1f 倍）"
				% [name, size.x, size.y, BACKGROUND_MIN.y, BACKGROUND_MIN.x, float(BACKGROUND_MIN.y) / size.y])
		if investigation and float(size.x) / size.y < INVESTIGATION_RATIO:
			report["suggestions"].append("%s 用在調查，寬高比 %.2f，建議 4:3 以上，玩家才能左右拖曳" % [name, float(size.x) / size.y])


static func _check_characters(report: Dictionary, catalog: Dictionary, usage: Dictionary, base: bool, folder: String) -> void:
	for id: String in (usage["characters"] as Dictionary).keys():
		var info: Dictionary = catalog["characters"][id]
		var name: String = "立繪 %s（%s）" % [info.get("name", id), id]
		var used: Dictionary = usage["characters"][id]
		var path: String = str(info.get("path", ""))
		var faces: Array = (used["expressions"] as Dictionary).keys()
		faces.sort()
		if path.is_empty():
			report["todo"].append("%s：還沒有圖，目前是剪影。透明底 PNG，高 ≥ %d，腳底貼齊底邊、左右置中；表情 %s。用在 %s"
				% [name, PORTRAIT_MIN_HEIGHT, "、".join(PackedStringArray(faces)), _where(used["nodes"])])
			continue
		_license(report, "characters", id, info)
		var picture: Variant = _picture(path)
		if picture is String:
			report["errors"].append("%s：`%s` %s" % [name, path, picture])
			continue
		var image: Image = picture
		_portrait_shape(report, name, image)
		var pictures: Dictionary = info.get("expressions", {}) if info.get("expressions") is Dictionary else {}
		for face: String in faces:
			if face == "neutral":
				continue
			if not pictures.has(face) or str(pictures[face]).is_empty():
				report["todo"].append("%s 的表情 %s：還沒有圖，先顯示定稿。和定稿同畫布 %d×%d、同腳底線；放 %s%s_%s.png，catalog `expressions` 登記。用在 %s"
					% [name, face, image.get_width(), image.get_height(), "assets/image/expressions/" if base else "art/",
					id, face, _where(used["expressions"][face])])
				continue
			var face_picture: Variant = _picture(str(pictures[face]))
			if face_picture is String:
				report["errors"].append("%s 的表情 %s：`%s` %s" % [name, face, pictures[face], face_picture])
			elif (face_picture as Image).get_width() < image.get_width() or (face_picture as Image).get_height() < image.get_height():
				# A bigger pose may widen the canvas sideways and upward (ART-SPEC.md); smaller cannot keep the feet and centre.
				report["suggestions"].append("%s 的表情 %s 畫布 %s 比定稿 %s 小；要和定稿同畫布（姿勢較大時往左右與上方加大），換表情時人才不會跳動"
					% [name, face, _size_text(face_picture), _size_text(image)])


static func _portrait_shape(report: Dictionary, name: String, image: Image) -> void:
	if image.detect_alpha() == Image.ALPHA_NONE:
		report["suggestions"].append("%s 沒有透明底（要透明底 PNG，去背乾淨）" % name)
		return
	if image.get_height() < PORTRAIT_MIN_HEIGHT:
		report["suggestions"].append("%s 高 %d，建議 ≥ %d" % [name, image.get_height(), PORTRAIT_MIN_HEIGHT])
	var used: Rect2i = image.get_used_rect()
	var size: Vector2i = image.get_size()
	if used.size.x <= 0:
		return
	var foot_gap: int = size.y - used.end.y
	if foot_gap > size.y * FOOT_GAP:
		report["suggestions"].append("%s 腳底離底邊還有 %d px，請貼齊（站位以圖的底邊對齊）" % [name, foot_gap])
	var margins: Array = [used.position.x, size.x - used.end.x, used.position.y]
	if margins[0] > size.x * MARGIN or margins[1] > size.x * MARGIN or margins[2] > size.y * MARGIN:
		report["suggestions"].append("%s 四周透明留白偏多（左 %d、右 %d、上 %d px），空白會一起縮放讓人變小"
			% [name, margins[0], margins[1], margins[2]])


static func _check_items_and_sounds(report: Dictionary, catalog: Dictionary, usage: Dictionary) -> void:
	for id: String in (usage["items"] as Dictionary).keys():
		var info: Dictionary = catalog["items"][id]
		var path: String = str(info.get("path", ""))
		if path.is_empty():
			continue  # 線索圖可以不給：顯示名稱第一個字的色塊
		_license(report, "items", id, info)
		var picture: Variant = _picture(path)
		if picture is String:
			report["errors"].append("線索圖 %s（%s）：`%s` %s" % [info.get("name", id), id, path, picture])
			continue
		var size: Vector2i = (picture as Image).get_size()
		if size.x != size.y or size.x < ITEM_MIN:
			report["suggestions"].append("線索圖 %s（%s）是 %d×%d，建議正方形、≥ %d" % [info.get("name", id), id, size.x, size.y, ITEM_MIN])
	for collection: String in ["sounds", "music"]:
		for id: String in (usage[collection] as Dictionary).keys():
			var info: Dictionary = catalog[collection][id]
			var path: String = str(info.get("path", ""))
			if path.is_empty():
				continue
			_license(report, collection, id, info)
			if not FileAccess.file_exists(path):
				report["errors"].append("%s %s：`%s` 檔案不存在" % ["音效" if collection == "sounds" else "音樂", id, path])


static func _size_text(image: Image) -> String:
	return "%d×%d" % [image.get_width(), image.get_height()]
