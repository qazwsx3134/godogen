extends RefCounted
## 設定: the player's device preferences, kept apart from the progress save (user://settings.json, godot-kit
## atomic_file). sfx is the sound volume 0..1 (every sound is an effect for now: it sets the Master bus); haptics
## turns the phone buzz on or off. quality picks the 3D render scale (QUALITY_SCALE: the battlefield draws at that
## share of the screen's resolution; the UI stays sharp), fps caps the frame rate (30 saves battery). The base layout
## stays 720 wide: with canvas_items stretch every screen draws its UI at its own resolution.

const AtomicFile = preload("res://addons/proto_kit/atomic_file.gd")

const PATH := "user://settings.json"

var sfx: float = 0.8
var haptics: bool = true
## 0 省電, 1 標準 (the default: on a 3x phone screen 0.8 of the native resolution looks the same and draws a third
## fewer pixels), 2 高 (full native resolution: about 3 million pixels on an iPhone 15).
var quality: int = 1
var fps: int = 60

const QUALITY_NAMES := ["省電", "標準", "高"]
const QUALITY_SCALE := [0.6, 0.8, 1.0]
const FPS_CHOICES := [30, 60]


## The Master bus volume for `sfx` (0 = silent).
func sfx_db() -> float:
	return linear_to_db(sfx) if sfx > 0.001 else -80.0


func apply() -> void:
	var master: int = AudioServer.get_bus_index(&"Master")
	AudioServer.set_bus_volume_db(master, sfx_db())
	AudioServer.set_bus_mute(master, sfx <= 0.001)
	Engine.max_fps = fps
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.root.scaling_3d_scale = QUALITY_SCALE[quality]


func to_dict() -> Dictionary:
	return {"sfx": sfx, "haptics": haptics, "quality": quality, "fps": fps}


func save(path: String = PATH) -> Error:
	return AtomicFile.write_text(path, JSON.stringify(to_dict()))


static func load_from(path: String = PATH) -> RefCounted:
	var s := new()
	var bytes: PackedByteArray = AtomicFile.read_bytes(path)
	if bytes.is_empty():
		return s
	var data: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if data is Dictionary:
		s.sfx = clampf(float(data.get("sfx", s.sfx)), 0.0, 1.0)
		s.haptics = bool(data.get("haptics", s.haptics))
		s.quality = clampi(int(data.get("quality", s.quality)), 0, QUALITY_SCALE.size() - 1)
		s.fps = int(data.get("fps", s.fps)) if FPS_CHOICES.has(int(data.get("fps", s.fps))) else 60
	return s
