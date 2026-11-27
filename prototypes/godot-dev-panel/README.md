# Godot Dev Panel

Godot 4 原型共用的 F1 開發面板。用可收合的分類註冊數字欄位、開關、操作按鈕與唯讀資訊。建議每個原型從第一個可玩場景就接入，並讓各遊戲決定可以改哪些參數。

在 repo 根目錄同步到目標遊戲。

```sh
bash prototypes/godot-dev-panel/sync.sh one-more-rock
bash prototypes/godot-dev-panel/sync.sh --check one-more-rock
```

在遊戲根場景組裝面板。此段適用於 Godot 編輯器和透過編輯器執行檔啟動的原型。要給開發者測試匯出版，在 Export Preset 加自訂 feature `developer` 並用 debug 匯出。正式匯出會關閉面板，即使保留同名 feature。

```gdscript
const DevPanel = preload("res://addons/godot_dev_panel/dev_panel.gd")

func _ready() -> void:
	if not DevPanel.available():
		return
	var scene := load("res://addons/godot_dev_panel/dev_panel.tscn") as PackedScene
	var panel := scene.instantiate() as DevPanel
	add_child(panel)
	panel.bind_number("Hero", "移動速度", player, &"speed", 1, 20, 0.1)
	panel.bind_number("Camera", "視野角度", camera, &"fov", 45, 105, 1)
	panel.add_readout("Debug View", "存活敵人", func(): return enemies.size())
```

F1 開啟時暫停場景並釋放滑鼠。F1、Esc 或關閉按鈕會還原暫停狀態和滑鼠模式。第一人稱與觸控遊戲可接 `opened` 清除按住輸入。數字和開關寫入當前執行中的物件，場景重載後讀回場景預設值。FPS 上限、遊戲速率和主音量是引擎層設定，在同一次執行中維持。欄位會在下次開啟時重新讀值。音效試聽可用 `preview_sound(audio_player)`，暫停時也能播。

| 分類 | 內容 |
|---|---|
| Run、Engine & Display | 內建重載場景、時間倍率、FPS 上限與讀數。桌面版另有全螢幕和垂直同步 |
| Army、Enemies、Stress Tests | 遊戲註冊編成、敵人數量或生成壓力測試等參數與命令 |
| Hero、Camera、Rewards、Health Bars、Terrain | 遊戲註冊角色、視角、獎勵、血條和地形參數 |
| Debug View | 內建繪製呼叫和活躍 3D 物理體讀數，遊戲可追加自己的監測 |
| Music、Audio、Sound Test | Audio 內建主音量和靜音。遊戲可註冊音樂切換、分軌音量和音效試聽 |

每個分類有註冊項目才顯示。可使用 `bind_number`、`bind_toggle` 綁現有屬性，也可用 `add_number`、`add_toggle` 傳 getter／setter 走遊戲的驗證邏輯。`add_action` 接命令，`add_readout` 接唯讀回呼。

`dev_panel.tscn` 可直接調整面板、主題與捲動區，`section.tscn` 和 `row.tscn` 可調整分類與欄位版面。修改共用來源後重新同步，遊戲內的註冊放在各遊戲腳本。第一個接入範例見 [One More Rock](../one-more-rock/README.md)。
