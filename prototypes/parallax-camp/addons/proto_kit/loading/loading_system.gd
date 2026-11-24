extends CanvasLayer
## 全域載入畫面（autoload）。CanvasLayer＋ProgressBar 的外觀在 loading_system.tscn，可在編輯器改。
## 執行緒載入與進度邏輯用 ../scene_loader.gd；這裡只管淡入淡出、更新進度條、換場景。
##   專案設定 → Autoload：名稱 LoadingSystem，路徑 res://addons/proto_kit/loading/loading_system.tscn
##   LoadingSystem.go("uid://b1x2y3...")      # 建議用 UID：檔案搬家或改名後仍找得到
##   LoadingSystem.go("res://scenes/level_2.tscn")
## 需要的子節點：%Root（Control，整個畫面，淡入淡出的對象）、%Bar（ProgressBar）、%Percent（Label，可省）、%Error（Label，可省）

signal loaded(path: String)
signal failed(path: String)

const SceneLoader = preload("res://addons/proto_kit/scene_loader.gd")

@export var fade_seconds := 0.25

var _loader := SceneLoader.new()
var _busy := false
@onready var _root: Control = %Root
@onready var _bar: ProgressBar = %Bar


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.modulate.a = 0.0
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


## uid:// 或 res:// 都可以。回傳 false：正在載入中，或找不到這個場景（目前畫面不動）。
func go(path: String) -> bool:
	if _busy:
		return false
	var resolved := resolve(path)
	if resolved.is_empty():
		push_error("loading_system: no scene at " + path)
		failed.emit(path)
		return false
	_busy = true
	_bar.value = 0.0
	_set_text(^"%Error", "")
	_root.mouse_filter = Control.MOUSE_FILTER_STOP  # 載入中擋住點擊
	await _fade(1.0)
	if not _loader.request(resolved):
		_end_failed(resolved)
		return false
	set_process(true)
	return true


## 把 uid:// 換成 res:// 路徑；不存在時回傳空字串。
static func resolve(path: String) -> String:
	if path.begins_with("uid://"):
		var id := ResourceUID.text_to_id(path)
		if id == ResourceUID.INVALID_ID or not ResourceUID.has_id(id):
			return ""
		path = ResourceUID.get_id_path(id)
	return path if ResourceLoader.exists(path) else ""


func is_busy() -> bool:
	return _busy


func _process(delta: float) -> void:
	var packed := _loader.step(delta)
	_bar.value = _loader.shown * _bar.max_value
	_set_text(^"%Percent", "%d%%" % roundi(_loader.shown * 100.0))
	if _loader.failed:
		set_process(false)
		_end_failed(_loader.path)
	elif packed != null:
		set_process(false)
		get_tree().paused = false
		if get_tree().change_scene_to_packed(packed) != OK:
			_end_failed(_loader.path)
			return
		loaded.emit(_loader.path)
		await _fade(0.0)
		_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_busy = false


func _end_failed(path: String) -> void:
	_set_text(^"%Error", "Failed to load")
	failed.emit(path)
	await get_tree().create_timer(1.0, true).timeout
	await _fade(0.0)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func _fade(to: float) -> void:
	var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(_root, "modulate:a", to, fade_seconds)
	await t.finished


func _set_text(n: NodePath, s: String) -> void:
	var l := get_node_or_null(n) as Label
	if l != null:
		l.text = s


func _exit_tree() -> void:
	_loader.cancel()
