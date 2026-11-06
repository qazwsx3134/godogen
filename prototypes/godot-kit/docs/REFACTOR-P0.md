# P0：鏡頭、載入與音樂生命週期

2026-11-06。已修改 kit 來源與能力契約；執行測試依使用者指示延期，尚未同步遊戲副本。完整參數與範例見 [能力參考](capabilities/REFERENCE.md)。

| 能力／用途 | 輸入與輸出 | 所有權與清理 |
|---|---|---|
| camera_shake：打擊震屏 | camera、強度與衰減設定；add_trauma(amount, ceiling) 累加，step(delta 秒) 更新鏡頭；reset() 無返回值 | 首次震動擷取原有 offset/rotation，結束、停用或換鏡頭還原；交還控制權或釋放 shake 前呼叫 reset。震動期間獨占這兩欄，不影響 position |
| scene_loader：自訂載入畫面 | request(path) 回傳是否啟動；is_loading() 回傳是否仍持有請求；step(delta 秒) 回傳 PackedScene 或 null；shown 為 0..1 | 忙碌拒絕新請求，不覆蓋進度；包含滿格停留時間。cancel 收取並丟棄結果，可能等待，不是中止引擎工作 |
| music：換軌與淡出入 | play(AudioStream)、stop() 無返回值；volume_db/fade_time 控制混音 | Ogg/MP3/WAV 用自己的循環副本，原始資源不變；track 保留原始身分，同首不重播。其他串流的循環由宿主決定 |

```text
宿主 scene
├─ 鏡頭：add_trauma → step → 結束還原／離場 reset
├─ 載入：request → step → PackedScene → 宿主切換
│                   └─ 離場 cancel（可能等待）
└─ 音樂：原始 stream → 私有循環副本 → voice 淡入淡出
```

## 組合範例

宿主在既有可編輯 scene 上持有三個元件，不由工具庫決定換頁或遊戲規則：

```gdscript
const Shake = preload("res://addons/proto_kit/camera_shake.gd")
const Loader = preload("res://addons/proto_kit/scene_loader.gd")
var shake = Shake.new()
var loader = Loader.new()

func _ready() -> void:
    shake.camera = $Camera2D
    # $Music 是已掛 music.gd 的 scene Node；音檔由遊戲提供。
    $Music.play(load("res://audio/room.ogg"))

func begin_next_room(path: String) -> bool:
    return loader.request(path) # false 且 is_loading() 為 true：保留原請求

func _process(delta: float) -> void:
    shake.step(delta)
    var packed: PackedScene = loader.step(delta)
    $LoadingBar.value = loader.shown * 100.0
    if packed != null:
        shake.reset()
        if get_tree().change_scene_to_packed(packed) != OK:
            loader.fail()

func _exit_tree() -> void:
    shake.reset()
    loader.cancel()
```

## 相容性與範圍

原呼叫簽名保留，新增 reset/is_loading。非零鏡頭基準現在會保留；忙碌 request 現在明確拒絕；音樂不再把共用音效資源改為循環，這三點是刻意修正的行為差異。兩個 step 對負值／非有限 delta 不更新。參數的有效範圍由契約約束，未新增通用設定驗證框架。

Loader 的 path/shown/failed 僅供宿主讀取；fail 僅在收取場景後、宿主使用失敗時呼叫。Music 必須 ready 後使用，若需暫停時持續播放由 scene 設 ALWAYS。這批未改動存檔、全域時鐘、場景路由或任何原型副本；下一批仍是 validated snapshot 的存檔邊界，草案不算已實作。

驗證範圍與待補案例見 [VALIDATION](capabilities/VALIDATION.md)。
