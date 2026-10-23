extends SceneTree
## Writes Parley's stores at their default paths so writers pick speakers from a list:
##   godot --headless --path . --script res://tools/story_build/make_parley_stores.gd
## Characters come from every work's catalog (tools/story_build/parley_stores.gd); rerun after
## adding characters, or use the editor menu 專案 → 工具 → Parley：更新角色清單.

const ParleyStores = preload("res://tools/story_build/parley_stores.gd")


func _init() -> void:
	var result: Dictionary = ParleyStores.update()
	print("PARLEY STORES: %s (%d characters, added %s)" % ["written" if result["ok"] else "FAILED", result["count"], result["added"]])
	quit(0 if result["ok"] else 1)
