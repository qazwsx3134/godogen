extends Node
## The only UI-facing coordinator. Domain mutations and their receipts are saved together.

signal changed
signal feedback(message: String, animation: String)
signal milestone(kind: String, message: String)

const Model = preload("res://domain/pet_model.gd")
const Care = preload("res://domain/care_service.gd")
const Clock = preload("res://domain/time_service.gd")
const Evolution = preload("res://domain/evolution_service.gd")
const Steps = preload("res://domain/step_service.gd")
const Hatch = preload("res://domain/hatch_service.gd")
const Saves = preload("res://domain/save_service.gd")
const Battles = preload("res://domain/battle_service.gd")
const Mock = preload("res://domain/mock_step_provider.gd")
const Provider = preload("res://domain/step_provider.gd")

var state: Dictionary = {}
var save_path: String = ""
var debug_enabled: bool = OS.is_debug_build()
var provider: RefCounted
var last_save_ok: bool = true

func _ready() -> void:
	if "--release-simulation" in OS.get_cmdline_user_args():
		debug_enabled = false
	if save_path.is_empty():
		save_path = "user://diary-dev.json" if debug_enabled else "user://diary.json"
	provider = Mock.new() if debug_enabled else Provider.new()
	state = Saves.load_state(save_path)
	if state.is_empty():
		state = Model.create_state(int(Time.get_unix_time_from_system()))
		state.settings.timezone_offset_minutes = int(Time.get_time_zone_from_system().bias)
		Hatch.start_egg(state, now())
	settle(false)
	var timer := Timer.new()
	timer.wait_time = 5.0
	timer.timeout.connect(settle)
	add_child(timer)
	timer.start()
	get_tree().auto_accept_quit = false

func now() -> int:
	var offset: int = int(state.get("settings", {}).get("debug_time_offset", 0)) if debug_enabled else 0
	return maxi(int(Time.get_unix_time_from_system()) + offset, int(state.get("last_tick", 0)))

func settle(announce: bool = true) -> void:
	if state.is_empty():
		return
	var before: Dictionary = state.duplicate(true)
	var result: Dictionary = Clock.advance(state, now())
	var hatched: Dictionary = Hatch.check(state, now())
	var evolutions: Array = Evolution.check(state, now())
	if not _commit(before):
		return
	if announce:
		if bool(hatched.get("hatched", false)):
			milestone.emit("hatch", str(hatched.get("message", "新的小夥伴誕生了！")))
		for event in evolutions:
			milestone.emit("evolve", str(event))
		if bool(result.get("protected", false)):
			feedback.emit("牠正在保護性休眠，輕輕喚醒就能繼續陪伴。", "sleep")
	changed.emit()

func _commit(before: Dictionary) -> bool:
	state.saved_at = now()
	var error: Error = Saves.save(state, save_path)
	last_save_ok = error == OK
	if not last_save_ok:
		state = before
		feedback.emit("存檔失敗，本次操作尚未生效。請確認可用空間。", "idle")
	return last_save_ok

func save() -> void:
	if not state.is_empty():
		last_save_ok = Saves.save(state, save_path) == OK

func act(action: String) -> Dictionary:
	settle(false)
	var before: Dictionary = state.duplicate(true)
	var result: Dictionary = Care.perform(state, action, now())
	if bool(result.get("ok", false)) and not _commit(before):
		return {"ok": false, "message": "存檔失敗"}
	feedback.emit(str(result.get("message", "")), str(result.get("animation", "idle")))
	changed.emit()
	return result

func train(kind: String, quality: int) -> Dictionary:
	settle(false)
	var before: Dictionary = state.duplicate(true)
	var result: Dictionary = Care.train(state, kind, quality, now())
	if bool(result.get("ok", false)) and not _commit(before):
		return {"ok": false, "message": "存檔失敗"}
	feedback.emit(str(result.get("message", "")), "train")
	settle()
	return result

func sync_steps() -> Dictionary:
	var before: Dictionary = state.duplicate(true)
	var result: Dictionary = Steps.synchronize(state, provider, now())
	state["step_sync"] = result.duplicate(true)
	state.step_sync["last_sync"] = now()
	var hatch: Dictionary = Hatch.check(state, now())
	if not _commit(before):
		return {"ok": false, "message": "存檔失敗"}
	feedback.emit(str(result.get("message", "同步完成")), "happy")
	if bool(hatch.get("hatched", false)):
		milestone.emit("hatch", str(hatch.get("message", "芽芽破殼了！")))
	changed.emit()
	return result

func add_mock_steps(count: int) -> void:
	if not debug_enabled:
		return
	var before: Dictionary = state.duplicate(true)
	provider.add_steps(state, count, now())
	if not _commit(before):
		return
	sync_steps()

func mock_mode(mode: String) -> void:
	if not debug_enabled:
		return
	provider.set_mode(state, mode, now())
	sync_steps()

func time_hatch() -> void:
	var before: Dictionary = state.duplicate(true)
	var result: Dictionary = Hatch.use_time_mode(state, now())
	if _commit(before):
		feedback.emit(str(result.get("message", "改用時間孵化")), "idle")
	settle()

func fast_forward(seconds: int) -> void:
	if not debug_enabled:
		return
	state.settings.debug_time_offset = int(state.settings.get("debug_time_offset", 0)) + seconds
	settle()

func begin_battle(npc_id: String, stance: String) -> Dictionary:
	settle(false)
	var before: Dictionary = state.duplicate(true)
	var result: Dictionary = Battles.begin(state, npc_id, stance, now())
	if bool(result.get("ok", false)) and not _commit(before):
		return {"ok": false, "message": "存檔失敗"}
	if not bool(result.get("ok", false)):
		feedback.emit(str(result.get("message", "現在無法對戰")), "idle")
	changed.emit()
	return result

func finish_battle() -> Dictionary:
	var before: Dictionary = state.duplicate(true)
	var result: Dictionary = Battles.finish(state, now())
	if bool(result.get("ok", false)) and not _commit(before):
		return {"ok": false, "message": "存檔失敗"}
	var won: bool = str(result.get("outcome", "")) == "win"
	feedback.emit(str(result.get("message", "戰鬥已記錄")), "victory" if won else "defeat")
	settle()
	return result

func archive() -> void:
	var before: Dictionary = state.duplicate(true)
	var result: Dictionary = Evolution.archive(state, now())
	if bool(result.get("ok", false)):
		Hatch.start_egg(state, now())
		if not _commit(before):
			return
	feedback.emit(str(result.get("message", "已保存成長日記")), "happy")
	changed.emit()

func setting(key: String, value: Variant) -> void:
	var before: Dictionary = state.duplicate(true)
	state.settings[key] = value
	_commit(before)
	changed.emit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()
	if what == NOTIFICATION_APPLICATION_RESUMED and not state.is_empty():
		settle()
		sync_steps()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()
