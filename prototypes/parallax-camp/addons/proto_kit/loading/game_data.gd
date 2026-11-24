extends Node
## 關卡進度存檔（autoload，名稱 GameData）。寫檔用 ../atomic_file.gd，當機也不會留下半個檔。
##   GameData.complete_level(2, 1500)      # 過關：記最佳分數、解鎖下一關、立刻存檔
##   GameData.is_unlocked(3) / GameData.best(2)
##   GameData.current_level = 2           # 想記「上次玩到哪」時自己設，save() 一起存

const AtomicFile = preload("res://addons/proto_kit/atomic_file.gd")
const VERSION := 1

@export var save_path := "user://game_data.save"

var unlocked := 1          ## 已解鎖的最高關卡（第 1 關一開始就開）
var current_level := 1
var best_scores := {}      ## 關卡編號 → 最佳分數


func _ready() -> void:
	load_data()


func complete_level(level: int, score := 0) -> void:
	best_scores[level] = maxi(best(level), score)
	unlocked = maxi(unlocked, level + 1)
	save()


func is_unlocked(level: int) -> bool:
	return level <= unlocked


func best(level: int) -> int:
	return best_scores.get(level, 0)


func save() -> Error:
	return AtomicFile.write_var(save_path, {
		"version": VERSION, "unlocked": unlocked, "current_level": current_level, "best_scores": best_scores})


## 沒有存檔或檔案壞掉時回到初始值，回傳 false。
func load_data() -> bool:
	unlocked = 1
	current_level = 1
	best_scores = {}
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return false
	var d = f.get_var()
	if not d is Dictionary or d.get("version") != VERSION:
		return false
	unlocked = int(d.get("unlocked", 1))
	current_level = int(d.get("current_level", 1))
	best_scores = d.get("best_scores", {})
	return true
