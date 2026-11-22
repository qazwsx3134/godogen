# Conductor 音畫同步

需要讓場景動畫、燈光或關卡事件跟著音樂拍點走時，從 Godot Kit 選用 Conductor。它以音訊播放位置及 Godot 回報的輸出延遲計算拍數。BPM、拍號和起拍校正由歌曲資料提供。

## 安裝

在 `prototypes/godot-kit/` 執行。

```bash
./sync.sh --conductor <原型名稱>
./sync.sh --check --conductor <原型名稱>
```

目標專案會得到 `res://addons/conductor/`，圖示的 `.import` 由目標專案產生。在 Godot 的 Project Settings → Plugins 啟用 **Conductor**，並在 Globals → Autoload 確認有 `Conductor`。插件本身會註冊這個 Autoload。若啟用後清單仍未出現，可重啟插件，或將 `res://addons/conductor/condcutor.gd` 登記為 `Conductor`。若專案已有同名 Autoload，先查現有歌曲時鐘與訊號接法，避免同一首曲子由兩個節點同時播放。

## 接到畫面

把歌曲節奏資料留在場景或 Resource，從主場景開始播放。訊號接線先於播放，拍點事件可以交給 `AnimationPlayer`、粒子或燈光。

```gdscript
@export var track: AudioStream

func _ready() -> void:
	Conductor.beat.connect(_on_beat)
	Conductor.set_song(track, 120.0, 4, 0.0)
	Conductor.play_song_from_beat(0.0)

func _on_beat(_beat_index: int) -> void:
	%AnimationPlayer.play(&"pulse")
```

- `beat(index)` 適合單拍脈衝，`measure(index)` 適合大段落或小節切換。
- `update(delta, beat_position, measure_position)` 可驅動連續效果。`delta` 是拍數變化，單位為拍。
- `ConductedTimer` 以拍數設定等待長度。用 `ConductedAnimationPlayer` 時，動畫時間軸 1 秒對應 1 拍。時間軸被頻繁 seek，方法軌需要自行避免重複觸發。
- 遇到進度跳轉、同一首重播或曲子原地循環時，要先驗證拍點。此版本以最後發出的拍數防重複，直接倒回較早的拍可能在追上原拍數之前都收不到事件。網頁和手機的實際聲畫延遲依播放環境驗收。

## 上游來源

來源固定在 [官方 GitHub commit 6250a1b](https://github.com/skibbl-dev/GodotConductor/tree/6250a1b1d80377e31aed0fca984f8ba54b905b2f/addons/conductor)。Asset Library 的下載指向 `main`，該快照內的插件版本為 **0.1.4**。套件檔案與 [MIT 授權](../third_party/conductor/LICENSE) 保留原樣。[Godot Asset Library](https://godotengine.org/asset-library/asset/4246)
