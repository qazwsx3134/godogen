# godot-kit：Godot 原型共用模組

## 介紹

`prototypes/` 底下的 Godot 原型（debt-commission、pachinko、pixel-monster）各自寫過幾樣相同的東西：佔位音效、不怕當機的存檔、headless 測試的輔助函式。這些已抽出來，在這裡只維護一份，新原型直接拿來用，不必再寫一次。後來又加了從 sugarcane-tanks 抽出來的手感（音效庫、震動、hit stop、震屏、音樂）、搖桿、載入邏輯、scene 產生器，以及字型子集、網頁匯出、測試與錄影的工具（`tools/`）。

這裡不是原型，也不是框架。收錄標準只有一條：**至少兩個原型真的在用**。只有一個專案需要的東西，留在那個專案裡。

| 模組 | 解決什麼 | 使用中 |
|---|---|---|
| [`synth.gd`](addons/proto_kit/synth.gd) | 程序合成佔位音：掃頻、敲擊噪音、音符串。不用下載或授權任何音檔 | pachinko、pixel-monster |
| [`atomic_file.gd`](addons/proto_kit/atomic_file.gd) | 存檔寫到一半當機或關掉分頁，也不會留下半個檔案 | debt-commission、pixel-monster |
| [`test_kit.gd`](addons/proto_kit/test_kit.gd) | headless 測試基底：斷言、等幾幀、等條件成立、模擬點擊與手勢 | debt-commission、pixel-monster |
| [`scene_builder.gd`](addons/proto_kit/scene_builder.gd) | 用 headless 腳本把程式建好的節點樹存成 `.tscn`：設好 owner、存檔後重新載入驗證，不覆蓋既有檔案 | 目前只有 kit 的測試在用；sugarcane-tanks 與 taskbar-hero 各有一份舊版，**沒有回頭改**，原因見下方 scene_builder.gd 一節 |
| [`font_check.gd`](addons/proto_kit/font_check.gd) | 測試輔助：遊戲寫的每個字元，字型都有字形嗎（網頁版沒有系統字型，缺字會變空白方塊）。搭配下方 `tools/subset_font.py` | sugarcane-tanks；其他原型還沒套用字型子集 |
| [`sfx_bank.gd`](addons/proto_kit/sfx_bank.gd) | 依事件名播音效：放一個同名的 `.ogg`／`.wav` 就換掉聲音，沒有檔案用合成的佔位音，再沒有就借另一個事件的聲音，都沒有就靜音、絕不報錯。輪流用幾個 voice、同一事件的最小間隔、長音效截斷淡出且不疊加 | sugarcane-tanks；pachinko、pixel-monster、debt-commission 還在各自直接管 `AudioStreamPlayer`，尚未改用 |
| [`haptics.gd`](addons/proto_kit/haptics.gd) | 手機震動：偵測（Android、iOS、網頁只認觸控裝置）、三級強度、間隔與每秒上限、較大級穿過、較弱不打斷較強、時鐘可注入。網頁版不會每次呼叫都讓瀏覽器 `console.warn` | sugarcane-tanks；pixel-monster 還在直接呼叫 `Input.vibrate_handheld(35)`，尚未改用 |
| [`time_control.gd`](addons/proto_kit/time_control.gd) | hit stop：打擊停頓，有冷卻、可強制、只拉長不縮短；唯一碰 `Engine.time_scale` 的地方 | sugarcane-tanks |
| [`music.gd`](addons/proto_kit/music.gd) | 背景音樂換軌：舊的淡出、新的淡入，同一首不重播，不受暫停與 hit stop 影響 | sugarcane-tanks |
| [`camera_shake.gd`](addons/proto_kit/camera_shake.gd) | trauma 震屏：偏移與轉角跟 trauma 的平方成正比，平滑不抖，可關（無障礙） | sugarcane-tanks |
| [`floating_stick.gd`](addons/proto_kit/floating_stick.gd) | 浮動虛擬搖桿：平時看不見，按下才在手指下出現，輸出螢幕向量 | sugarcane-tanks |
| [`scene_loader.gd`](addons/proto_kit/scene_loader.gd) | 載入畫面的邏輯：執行緒載入、進度不倒退也不跑在時鐘前面、失敗可重試、離開時收掉任務 | sugarcane-tanks |

GDScript、Godot 4.7。只用於 `prototypes/`，不接進 `publish.sh`（見 [ADR 0001](../docs/adr/0001-prototypes-live-in-godogen.md)）。

## 新原型怎麼接

1. 建好 Godot 專案，資料夾要有 `project.godot`。可以用編輯器建，或手寫最小版：

   ```ini
   config_version=5

   [application]
   config/name="my-proto"
   config/features=PackedStringArray("4.7", "GL Compatibility")
   ```

2. 把 kit 複製進去。在 `prototypes/godot-kit/` 執行：

   ```bash
   ./sync.sh my-proto        # 產生 prototypes/my-proto/addons/proto_kit/
   ```

3. 在程式裡 preload 需要的模組。模組都沒有 `class_name`，不會和專案自己的類別撞名：

   ```gdscript
   const Synth = preload("res://addons/proto_kit/synth.gd")
   const AtomicFile = preload("res://addons/proto_kit/atomic_file.gd")
   ```

   測試檔則是繼承：`extends "res://addons/proto_kit/test_kit.gd"`。

4. `addons/proto_kit/` 要和專案其他檔案一起 commit，別人 clone 下來才載入得到。

`addons/proto_kit/` 只是副本，**不要直接改**，下次同步會被覆蓋。要改就改 `godot-kit/`，流程見文末「維護」。

## synth.gd：佔位音效

每個函式都回傳可直接播放的 `AudioStreamWAV`（16-bit 單聲道 22050 Hz）。

| 函式 | 聲音 |
|---|---|
| `Synth.ramp(freq_a, freq_b, dur, vol_a = 0.5, vol_b = 0.5, curve = 1.0)` | 正弦波從 `freq_a` 滑到 `freq_b`，音量從 `vol_a` 變到 `vol_b`。`curve > 1` 讓變化集中在後段。頭尾各有 6 ms 淡入淡出，不會爆音 |
| `Synth.click(dur, vol = 0.4, decay = 24.0)` | 快速衰減的噪音，像撞擊、按鍵。`decay` 越大越短促。固定 seed，每次都是同一個聲音 |
| `Synth.notes(freqs, note_dur, soft = false)` | 依序播放一串音符，每個長 `note_dur` 秒，起音快、尾音漸弱。`soft = false` 偏方波、有晶片音感；`true` 是純正弦 |
| `Synth.to_stream(data)` | 把自己算好的 16-bit PCM 包成 stream |

```gdscript
var player := AudioStreamPlayer.new()
add_child(player)
player.stream = Synth.ramp(180.0, 340.0, 1.2, 0.1, 0.4, 1.4)  # 上升的期待音
player.play()

player.stream = Synth.notes([523.25, 659.25, 783.99], 0.1)     # 升三音的成功音效

var bgm := Synth.notes([261.63, 329.63, 392.0, 329.63], 0.8, true)  # 循環背景音
bgm.loop_mode = AudioStreamWAV.LOOP_FORWARD
bgm.loop_end = bgm.data.size() / 2   # 16-bit 單聲道：一個 sample 佔 2 bytes
```

Web 匯出用 Sample 播放模式，執行期調 player 的 pitch 或音量幾乎沒作用。要有滑音、漸強，就用 `ramp` 把變化烘進聲音本身。

## atomic_file.gd：安全存檔

寫入流程：先寫 `路徑.tmp`，flush 後讀回比對，確認無誤才改名覆蓋正式檔。任何一步失敗，正式檔都維持原樣。

| 函式 | 說明 |
|---|---|
| `AtomicFile.write_text(path, text) -> Error` | 寫文字，例如 JSON |
| `AtomicFile.write_var(path, value) -> Error` | 寫 Godot Variant。格式與 `FileAccess.store_var(value, false)` 完全相同，用 `FileAccess.get_var()` 讀回 |
| `AtomicFile.write_bytes(path, bytes) -> Error` | 寫原始位元組，前兩個函式都經過這裡 |
| `AtomicFile.read_bytes(path) -> PackedByteArray` | 讀檔；檔案不存在或讀不到時回傳空陣列 |

- 回傳 `OK` 才算成功。資料夾不存在時會自動建立。
- 路徑直接傳 `user://...`，不要先 `globalize_path`。Web 版要走 `user://` 才會存進瀏覽器的 IndexedDB，換成絕對路徑就不會永久保存。
- 寫入途中會出現 `.tmp`。平台不允許直接覆蓋時，會短暫出現 `.old`，commit 完就刪掉。清理存檔的程式要把這兩個副檔名一起算進去。

kit 只負責「寫進去」這一步。要不要留 `.bak`、讀檔前怎麼驗證、主檔壞了怎麼還原，要看各遊戲的存檔格式，所以留在各專案。常見寫法是先把「確認可讀的舊主檔」備份成 `.bak`，再寫新檔：

```gdscript
const SAVE_PATH := "user://save.json"

static func save(state: Dictionary) -> Error:
	var current := _load(SAVE_PATH)
	if not current.is_empty():   # 只備份讀得懂的舊檔，壞檔不會蓋掉好的 .bak
		var backup_error := AtomicFile.write_text(SAVE_PATH + ".bak", JSON.stringify(current))
		if backup_error != OK:
			return backup_error
	return AtomicFile.write_text(SAVE_PATH, JSON.stringify(state))

static func load_state() -> Dictionary:
	var state := _load(SAVE_PATH)
	return state if not state.is_empty() else _load(SAVE_PATH + ".bak")

static func _load(path: String) -> Dictionary:
	var text := AtomicFile.read_bytes(path).get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else null
	return parsed if parsed is Dictionary else {}
```

實際例子：pixel-monster 的 `domain/save_service.gd`（JSON，含 schema 驗證）、debt-commission 的 `scripts/save_slots.gd`（`write_var`，18 個手動存檔欄位）。

## test_kit.gd：headless 測試

測試檔繼承它，就能直接用下面這些成員：

| 成員 | 說明 |
|---|---|
| `_expect(condition, label)` | 斷言。失敗時記下 `label` 並印出 `FAIL: label` |
| `_finish(suite)` | 印出 `SUITE PASSED` 或 `SUITE FAILED: n`，並以 0／1 結束。每個測試檔最後都要呼叫 |
| `failures`、`checks` | 失敗清單與斷言次數 |
| `await _frames(count = 1)` | 等幾幀，讓 UI 版面和動畫跑完 |
| `await _until(condition, label, timeout = 5.0)` | 等到 `condition.call()` 為 true。逾時記一筆 `timed out: label` 後繼續，不會卡死 |
| `await _tap(at)` | 在 viewport 座標點一下 |
| `await _drag(from, to, hold)` | 按下、分六步移到 `to`、停 `hold` 秒、放開。涵蓋長按、滑動、拖曳 |
| `_mouse(at, pressed)`、`_move(at)` | 單一滑鼠事件，自己組手勢時用 |
| `await _press(button)` | 像玩家一樣點按鈕：先捲進可見範圍，再依序送 hover、按下、放開。按鈕 disabled 時記為失敗 |

`_tap` 和 `_drag` 直接把事件推進 root viewport，適合點畫面上任意位置、測手勢。`_press` 經過 `Input`，會觸發 hover、focus 和 ScrollContainer 的處理，適合點選單按鈕。

**純邏輯測試**：不需要場景樹，全部在 `_init` 裡跑完。

```gdscript
extends "res://addons/proto_kit/test_kit.gd"

const Rules = preload("res://domain/rules.gd")

func _init() -> void:
	_expect(Rules.damage(10, 2) == 8, "armor reduces damage")
	_expect(Rules.damage(1, 5) == 0, "damage never goes negative")
	_finish("RULES TESTS")
```

**UI 測試**：要等場景樹準備好，所以從 `_init` 延後呼叫 `_run`。

```gdscript
extends "res://addons/proto_kit/test_kit.gd"

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(480, 900)   # headless 視窗預設只有 64x64，按鈕會落在視窗外
	var main: Control = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _frames(3)
	await _press(main.find_child("StartButton", true, false))
	await _until(func() -> bool: return main.started, "game starts")
	_expect(main.score == 0, "new game starts at zero")
	_finish("MAIN UI TESTS")
```

需要在失敗訊息加上下文（例如目前在哪個劇情節點）時，可以在子類別覆寫 `_expect`，簽名要保持一致。debt-commission 的 `tests/test_vn_shell.gd` 就是這樣做。

執行：

```bash
godot --headless --path . --editor --quit            # 第一次或 clone 後先 import，建立 class 快取
godot --headless --path . --script res://tests/test_rules.gd
```

Godot 遇到 SCRIPT ERROR 時仍可能以 0 結束，測試會顯示成通過。CI 或腳本要同時檢查 log：

```bash
log=$(mktemp)
godot --headless --path . --script res://tests/test_rules.gd >"$log" 2>&1; rc=$?
grep -E 'SCRIPT ERROR|Parse Error|Failed to load script' "$log" && rc=1
exit $rc
```

## scene_builder.gd：用腳本存 scene

**給以後的產生器腳本用；已套用過的一次性腳本不要回頭改。** sugarcane-tanks 與 taskbar-hero 的 `tools/build_scenes.gd` 各有一份同樣的 owner／計數／驗證函式（sugarcane-tanks 叫 `_save`、`_own`、`_count`…；taskbar-hero 叫 `_save_scene`、`_assign_scene_owners`、`_count_nodes`），這個模組是兩份的聯集，收成 `static func`。那些腳本已經套用過，產出的 scene 之後又被改過（sugarcane-tanks 的檔頭就寫了不要 `--force`），改成呼叫這個模組只有風險，所以目前沒有原型採用，只有 kit 的測試在用。

為什麼要用腳本存：`PackedScene.pack()` 寫出的檔和編輯器存的一樣，編輯器打開就能直接調整（見 AGENTS.md「Godot 開發」）。但 `pack()` 只存 `owner` 是根節點的節點，其餘的**不報錯就丟掉**，所以 `save_scene` 先設好 owner，存完再重新載入驗證。

| 函式 | 說明 |
|---|---|
| `SceneBuilder.save_scene(root, path, options = {}) -> Dictionary` | 設 owner、`pack`、存檔，再以 `CACHE_MODE_IGNORE` 重新載入，比對前後節點數與子 scene 引用。資料夾不存在會先建。**一定會釋放 `root`**，呼叫後不要再用 |
| `SceneBuilder.add(parent, child, node_name = "") -> Node` | `add_child` 並回傳 `child`。名稱可讀（同名加數字），不會存出 `@Label@2` |
| `SceneBuilder.instance(path) -> Node` | 實例化子 scene。`pack()` 因此存成乾淨的引用，只留你改過的屬性；一般的 `instantiate()` 會把子 scene 根節點的非預設屬性（位置、顏色…）複製成覆寫 |
| `SceneBuilder.unique(node) -> Node` | 標記成 `%唯一名稱`，回傳同一個節點，所以能包在 `add()` 裡 |
| `SceneBuilder.own_nodes(root)`、`SceneBuilder.count_nodes(node) -> int` | `save_scene` 內部的兩步。想在存檔前自己檢查節點樹時才直接呼叫 |

`save_scene` 回傳 `{"ok": bool, "skipped": bool, "nodes": int, "refs": Array[String], "error": String}`：

- `nodes`：建了幾個節點，含子 scene 實例裡面的；跳過時是 0。`refs`：存下來的 scene 引用到的子 scene 路徑，不重複。
- `options["expected_refs"]`：必須出現在存下來的 scene 裡的子 scene 路徑，缺一個就失敗。
- `options["overwrite"] = true`：覆蓋既有檔案。預設**檔案已存在就跳過**（`ok` 與 `skipped` 都是 true，不動檔案），免得重跑把編輯器裡的手動調整蓋掉。
- 失敗時 `ok = false`、`error` 寫原因，並 `push_error`。檔案如果是這次呼叫新建的就刪掉，下次重跑才不會跳過一個壞 scene；用 `overwrite` 蓋掉的舊檔已經換掉、不會還原，覆蓋前先看 `git diff`。

Owner 規則：自己建的節點都設 `owner = root`；**子 scene 的實例只有根節點設 owner**，裡面的節點屬於那個子 scene，設了會被多存一份。所以把節點加在實例底下會被 `pack()` 丟掉，`save_scene` 會以「節點數對不上」失敗。`unique()` 同理只對自己加的節點有效：標在實例裡面的節點會被**默默忽略**（`ok` 仍是 true，父 scene 取不到 `%名稱`）。

一支迷你產生器（`godot --headless --path . --script res://tools/build_menu.gd`）：

```gdscript
extends SceneTree
const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")

func _initialize() -> void:
	_build.call_deferred()

func _build() -> void:
	var menu := Control.new()
	menu.name = "Menu"
	SceneBuilder.add(menu, SceneBuilder.unique(Label.new()), "Title")   # 存檔後用 %Title 取得
	SceneBuilder.add(menu, SceneBuilder.instance("res://ui/panel.tscn"), "Panel")
	var result := SceneBuilder.save_scene(menu, "res://ui/menu.tscn", {"expected_refs": ["res://ui/panel.tscn"]})
	quit(0 if result.ok else 1)
```

套用過之後，在腳本檔頭註明重跑會被拒絕，例如 `## Applied 2026-10-03. Re-running is rejected: the scenes exist and were edited by hand; do not overwrite.`

腳本在 `quit()` 之前出 SCRIPT ERROR，headless 程序不會結束，跑的時候加 `timeout`。

## sfx_bank.gd：依事件名播音效

遊戲只說「發生了什麼」（`sfx.play(&"hit")`），聲音從哪來由這個模組決定。來源是 sugarcane-tanks 的 `game/sfx.gd`，邏輯原封不動搬來；遊戲專屬的三張表（合成的佔位音、借用表、長音效表）由遊戲的子類別填，sugarcane-tanks 的 `game/sfx.gd` 現在只剩這三張表。沒有 `class_name`，用繼承的：`extends "res://addons/proto_kit/sfx_bank.gd"`。

| 成員 | 說明 |
|---|---|
| `play(sound, min_gap = 0.035)` | 播一個事件，用 `voices` 個 `AudioStreamPlayer` 輪流播。**一定發 `played`**：沒有聲音、被 `min_gap` 擋掉、沒有 voice 都一樣。`min_gap`（秒）內同一個事件的第二次呼叫被丟掉；`0.0` 表示不擋 |
| `signal played(sound)` | 每次 `play()` 都發。測試與機器人用它計數 |
| `stream_for(sound) -> AudioStream` | 這個事件現在會播的串流，沒有聲音是 `null` |
| `source_of(sound) -> String` | 聲音從哪來：檔案路徑、`"synth"`、`"<事件> (borrowed)"`（借的是哪個事件），沒有聲音是 `""` |
| `refresh()` | 忘掉查過的結果。查找結果會被記住，之後新放進去或刪掉的檔案要呼叫它才看得到（或重新執行遊戲）；改了 `sound_dir`、`_streams`、`fallback` 之後也要 |
| `sound_dir`（`res://assets/sfx`）、`voices`（10）、`volume_db`（-6） | 匯出欄位，在 `_ready` 之前定好 |
| `_streams: Dictionary` | 事件名 → 合成的佔位音，用 `Synth` 做 |
| `fallback: Dictionary[StringName, StringName]` | 事件名 → 它沒有自己的聲音時借用的另一個事件。不能繞圈（a 借 b、b 借 a） |
| `long_sounds: Dictionary` | `{事件: {"seconds": 秒, "gain_db": dB}}`，見下方「長音效」 |

```gdscript
extends "res://addons/proto_kit/sfx_bank.gd"      # game/sfx.gd，掛在主 scene 的一個 Node 上

const Synth = preload("res://addons/proto_kit/synth.gd")

func _ready() -> void:
	_streams = {
		&"hit": Synth.click(0.05, 0.3, 40.0),
		&"boom": Synth.click(0.35, 0.5, 9.0),
	}
	fallback = {&"enemy_die": &"boom"}                             # 沒有自己的聲音，就用 boom 的
	long_sounds = {&"rev": {"seconds": 0.7, "gain_db": -6.0}}      # 5 秒的檔案只播 0.7 秒，小聲一點
	super()                                                        # 建 voice：表要在這之前填好

# 之後在任何地方：
#   sfx.play(&"hit")
#   sfx.play(&"enemy_die", 0.0)                                    # 不要最小間隔
#   sfx.played.connect(func(sound: StringName) -> void: heard.append(sound))
```

**找聲音的順序**（查過就記住）：

1. `sound_dir` 裡的 `<事件>.ogg`，沒有就 `<事件>.wav`。**檔名就是事件名，放一個同名檔案就換掉聲音，不用改程式。** 編輯器還沒匯入的檔案也讀得到（直接從硬碟讀）。
2. `_streams` 裡同名的佔位音。
3. `fallback` 指向的那個事件的聲音（它的檔案或佔位音）。
4. 都沒有：靜音。`stream_for` 回 `null`、`source_of` 回 `""`、`play()` 不報錯。借用的對象也沒有聲音時一樣靜音。

**長音效**：檔案比事件長很多時（5 秒的引擎聲配不到 1 秒的預警），`long_sounds` 讓它播 `seconds` 秒後淡出 0.12 秒（`CLIP_FADE`）再停；音量加上 `gain_db`；同一個事件還在響時不會再疊一個（不同事件可以同時響）。voice 被別的聲音接手時，它的淡出作廢，音量也回到 `volume_db`。

**`min_gap` 用牆上時鐘**（`Time.get_ticks_msec()`）：耳朵聽到的是真實時間，節流音效也該如此。**玩法邏輯不要抄這個寫法**：`--fixed-fps` 的測試裡，遊戲時間比牆上時間快很多，用牆上時鐘做的鎖或冷卻會把機器人的點擊全吞掉（sugarcane-tanks 的選卡鎖踩過）。玩法的計時用遊戲時間，例如 `create_timer(秒, true, false, true)`。

**測試**：`tests/test_proto_kit.gd` 的 `_test_sfx_bank` 在 `user://` 底下寫幾個靜音檔當 `sound_dir`（`.ogg` 是內嵌的 2.7 KB 固定檔，GDScript 存不出 ogg），逐條驗：檔案優先於佔位音、`.ogg` 優先於 `.wav`、借用與靜音、`refresh()`、voice 輪流、`min_gap`、長音效的截斷／音量／不疊加／接手後作廢。每一條都各弄壞過一次確認測試會失敗（記在 `.claude/tasks/sugarcane-art/kit-sfx-report.md`）。

實際例子：sugarcane-tanks 的 `game/sfx.gd`（13 個合成音、6 筆借用、2 個長音效）。

## haptics.gd：手機震動

手機馬達的規則收成一個 `RefCounted`：三級強度、節流、玩家開關與強度縮放、時鐘可注入。來源是 sugarcane-tanks 的 `game/juice.gd`，規則原封不動搬來；`juice.gd` 現在每次 `haptic()` 時把自己的設定寫進一個 `Haptics`，再呼叫它的 `buzz()`。

| 成員 | 說明 |
|---|---|
| `buzz(tier)` | 依規則（見下）震一下。`tier` 是 `durations_ms`、`amplitudes` 的索引，0 最輕。桌面沒有馬達，但規則放行時一樣發 `vibrated`，測試可以用它計數 |
| `signal vibrated(duration_ms, amplitude)` | 規則放行了一下。**不管這台裝置有沒有馬達都會發** |
| `supported() -> bool` | 這台裝置能不能震，問一次、記起來。Android、iOS：能。網頁：要是觸控裝置，而且瀏覽器有 `navigator.vibrate`。桌面：不能。拿來隱藏設定裡的震動開關 |
| `enabled`（true）、`scale`（1.0） | 玩家的開關；縮放每一下的長度（不縮放強度），0 = 完全不震 |
| `min_gap_ms`（70）、`max_per_second`（6） | 兩下之間至少隔多久；任何一秒內最多幾下 |
| `durations_ms`（`[14, 38, 90]`）、`amplitudes`（`[0.35, 0.65, 1.0]`） | 每一級的長度（ms）與強度（0..1，只有 Android 用強度）。短於約 10 ms 多數手機沒感覺，長於約 150 ms 是嗡聲不是打擊感。`amplitudes` 是 `PackedFloat64Array`：Float32 會把 0.35 讀回 0.3499999940395355，`vibrated` 就不再等於你設的值 |
| `clock: Callable` | 規則用的毫秒。空 = 牆上時鐘（`Time.get_ticks_msec()`，馬達本來就跑在真實時間）。測試與機器人要設一個跟著遊戲時間走的：`--fixed-fps` 時牆上時間比遊戲快很多，規則會把幾乎每一下都丟掉。**設定時會忘掉之前的震動** |
| `now_ms() -> int` | 規則現在用的時間（`clock` 或牆上時鐘） |

```gdscript
const Haptics = preload("res://addons/proto_kit/haptics.gd")

var haptics := Haptics.new()

func _ready() -> void:
	haptics.enabled = saved.haptics                  # 玩家的開關
	switch_row.visible = haptics.supported()         # 沒有馬達的裝置不顯示開關

func on_enemy_died() -> void:
	haptics.buzz(0)                                  # 小事：輕輕一下

func on_boss_died() -> void:
	haptics.buzz(2)                                  # 大事：重重一下
```

**規則**（都在 `buzz()` 裡）：

1. `enabled` 關，或 `scale` 為 0：什麼都不做。
2. 兩下之間至少 `min_gap_ms`，任何一秒內最多 `max_per_second` 下，所以一群怪同時死掉時手機不會一直嗡。
3. 較弱的一下不會打斷還沒結束的較強的一下（手機上新的一下會取代正在震的那一下）。

**比上一下更大級的，不受第 2 條限制**：被爆擊打死的 Boss 是先 small（爆擊）再 large（死亡），在同一幀，large 不能被吃掉。

**為什麼網頁版要查觸控**：桌面 Chromium 也有 `navigator.vibrate` 這個函式（用 `tools/web/web_probe.mjs` 以桌面視窗量過，`typeof navigator.vibrate` 是 `'function'`），只查函式會讓桌面以為自己能震；iPhone Safari 則完全沒有它。所以探測字串 `Haptics.WEB_HAPTICS_PROBE` 還要求 `navigator.maxTouchPoints > 0` 或 `(pointer: coarse)`。要先查而不是直接呼叫，是因為 Godot 的網頁端對每一次不可能成功的 `Input.vibrate_handheld` 都會讓瀏覽器 `console.warn`（pixel-monster 的 `Input.vibrate_handheld(35)` 就是這樣）。`web_probe.mjs` 直接讀這個常數的字串，在桌面與手機各算一次，確認「桌面不震、手機震」；它依序找 `--haptics-source`、`<專案>/addons/proto_kit/haptics.gd`、`<專案>/game/juice.gd`，所以探測字串要維持單行的 `const WEB_HAPTICS_PROBE: String = "..."`。

**沒有在真機上驗證過**：平台行為照 Godot 與瀏覽器的文件寫，測試與機器人都用 `vibrated` 計數。每條規則、`vibrated` 的長度與強度、`clock` 清狀態、`supported()` 只問一次、探測字串在 `tests/test_proto_kit.gd` 的 `_test_haptics` 都有斷言，且各弄壞過一次確認測試會失敗（記在 `.claude/tasks/sugarcane-art/kit-haptics-report.md`）。

## time_control.gd：hit stop

唯一碰 `Engine.time_scale` 的地方。選單暫停用 `tree.paused`，兩者不互搶。放在遊戲 scene 的一個 Node 上（`process_mode` 設 Always）：

```gdscript
time_control.hit_stop(0.06)          # 一般打擊
time_control.hit_stop(0.2, true)     # Boss 死亡：略過冷卻，只會拉長進行中的停頓、不會縮短
time_control.reset()                 # 重新開始或離開場景
```

停頓有冷卻（`hit_stop_cooldown`，預設 0.25 秒）：一整間房的擊殺不會每一格都卡住遊戲。停頓的長度用牆上時鐘（玩家感覺到的就是這個），所以不要拿它做玩法計時；`clock` 可以注入，測試用。離開場景樹一定把速度還原成 1。

## music.gd：淡入淡出的背景音樂

```gdscript
music.play(room_theme)     # 不同的一首：舊的淡出、這首淡入，並自動設成循環
music.play(room_theme)     # 同一首：什麼都不做（一間房走到下一間，音樂不重來）
music.stop()               # 淡出成靜音
```

用場景裡的 `AudioStreamPlayer` 子節點（兩個就夠：一個淡出、一個淡入），不夠的自己補。節點的 `process_mode` 設 Always（暫停時也照常），淡入淡出不受 `Engine.time_scale` 影響，所以 hit stop 不會把它拉長。要有具名曲目（房間曲、Boss 曲）就繼承它再加 export：`extends "res://addons/proto_kit/music.gd"`，sugarcane-tanks 的 `game/music.gd` 就只有那兩行 export。

## camera_shake.gd：trauma 震屏

`RefCounted`，由擁有相機的節點每幀呼叫 `step(delta)`：

```gdscript
var shake := CameraShake.new()
shake.camera = $Camera2D
func _process(delta: float) -> void: shake.step(delta)
shake.add_trauma(0.25)            # 小打擊
shake.add_trauma(0.85)            # Boss 死亡
shake.add_trauma(0.25, 0.35)      # 這種事件最多把 trauma 推到 0.35：連續暴擊會悶悶地震，不會變成大震
```

只動 `Camera2D.offset` 與 `rotation`，不碰身體或相機位置，瞄準與碰撞不受影響。動作是兩個頻率不相干的正弦波，不是每幀亂數（那會嗡嗡抖）；trauma 歸零的那一格把相機放回正中。`shake_scale = 0` 就完全不震（無障礙選項）。轉角要 `Camera2D.ignore_rotation` 關掉才看得到。

## floating_stick.gd：浮動搖桿

放在一個鋪滿觸控區的 `Control` 上，底下要有兩個唯一名稱的子節點 `%Base`（圓形底座）與 `%Knob`（搖桿頭，在底座裡）。外觀（大小、StyleBox、透明度）都在遊戲自己的 scene 裡。讀滑鼠事件，所以觸控（Godot 預設把觸控轉成滑鼠）、桌面滑鼠與 `test_kit` 的 `_drag` 都能用：

```gdscript
var direction: Vector2 = stick.vector      # 螢幕向量：x 右、y 下，長度 0..1，死區內是 0
var forward := Vector2(stick.vector.x, -stick.vector.y)   # 3D 要「y 向前」就自己翻
stick.release()                            # 遊戲在手指底下被暫停時，結束這次觸控
```

平時 `%Base` 隱藏，按下才在手指下出現，放開就消失。目前只有浮動模式；seichi-pov 的固定搖桿讀的是觸控事件、輸出 y 向前，要換成這支得先加固定模式，它有未提交的修改，沒動。

## scene_loader.gd：載入畫面的邏輯

載入畫面的外觀（進度條、百分比、提示、錯誤與重試鈕）是遊戲自己的 scene；這支只管「讀取」：

```gdscript
var loader := SceneLoader.new()
loader.request("res://main.tscn")                      # 檔案不存在或請求被拒：回 false，loader.failed
func _process(delta: float) -> void:
    var packed: PackedScene = loader.step(delta)       # 讀完、且進度條滿了一小段時間才給，否則 null
    bar.value = loader.shown * 100.0
    if loader.failed: ...顯示錯誤，重試鈕呼叫 loader.request(path)
    elif packed != null and get_tree().change_scene_to_packed(packed) != OK: loader.fail()
func _exit_tree() -> void: loader.cancel()             # 沒人領的載入任務要收掉，否則會洩漏
```

`shown` 只往前走、不會跑在真正的讀取進度前面、也不會跑在時鐘前面（`min_show_time`，所以畫面不會一閃而過；沒有執行緒的網頁版一次讀完，進度條仍用這段時間填滿），每秒最多走 `fill_speed`，滿了再停 `hold_at_full` 秒才交出場景。只有狀態是 LOADED 才放行：進度值可能比狀態早一點到 1.0。**沒有執行緒的網頁版在呼叫 `request()` 的那一刻就讀完了**，所以要先讓畫面畫出來（等兩幀）再呼叫。測試裡讓載入失敗的做法：隨機位元組、副檔名 `.scn`（引擎只印 `Unrecognized binary resource file`）；文字 scene 寫壞會印 `Parse Error`，會被 kit 的 log 檢查當成失敗。

## tools/：字型子集與網頁匯出

開發時在命令列跑的工具，**不會**同步進原型，直接從 kit 執行（路徑相對於 `prototypes/` 的上一層，即 repo 根目錄）。每支都有 `--self-test`（不連網、不需要 Godot），改了要重跑；自我測試都做過「弄壞一處、確認會失敗」。

| 工具 | 做什麼 | 用法 |
|---|---|---|
| `tools/subset_font.py` | 把 CJK 字型縮成遊戲用得到的字：掃專案的 `.gd` `.tscn` `.tres` `.json` 等文字檔，再加 Big5 常用 5,401 字與符號。可變字重字型烤成指定字重；原檔絕不覆寫；同樣輸入得到同樣的位元組。需要 `pip install fonttools` | `python3 prototypes/godot-kit/tools/subset_font.py --project prototypes/<原型> --source <完整字型> --out prototypes/<原型>/ui/fonts/X.ttf --weight 700`；`--check` 只報告字型缺哪些字；`--minimal` 只留遊戲寫的字 |
| `addons/proto_kit/font_check.gd`（會同步進原型） | 測試裡掃遊戲寫的每個字元，字型缺字形就失敗 | `FontCheck.missing_characters(load("res://ui/fonts/X.ttf"))` |
| `tools/web/build_web.sh` | 一行指令出網頁版：匯入 → 匯出 `Web` preset → 補 IDBFS 補丁 → 印 pck 組成 → 打包 zip；範本第一次用時自動抓 | `prototypes/godot-kit/tools/web/build_web.sh <原型> [--zip-name 名稱]`；原型要有 `export_presets.cfg` 裡名為 `Web` 的 preset（輸出 `build/web/index.html`，匯出模式 `all_resources`），可以抄 sugarcane-tanks 的 |
| `tools/web/fetch_web_templates.py` | 只抓需要的那一個網頁匯出範本：官方 `.tpz` 有 1.28 GB，用 HTTP Range 只讀約 13 MB；每個檔案驗 CRC-32；官方鏡像失敗就換 GitHub | `python3 prototypes/godot-kit/tools/web/fetch_web_templates.py [--version 4.7] [--debug] [--check]` |
| `tools/web/patch_idbfs.py` | 修 Emscripten IDBFS 的「同步時檔案已消失」（`AtomicFile` 的暫存檔改名會碰到）；比對字串找不到就失敗，不默默略過 | `python3 prototypes/godot-kit/tools/web/patch_idbfs.py build/web/index.js` |
| `tools/web/pck_size.py` | 把 `.pck` 依種類拆開，看網頁下載量由什麼組成 | `python3 prototypes/godot-kit/tools/web/pck_size.py build/web/index.pck` |
| `tools/web/web_probe.mjs` | 用 headless Chromium 以桌面與手機各開一次匯出版：console 錯誤、失敗的請求、canvas 大小、震動偵測、截圖 | `node prototypes/godot-kit/tools/web/web_probe.mjs --playwright <playwright-core 的路徑> --project prototypes/<原型> --url http://127.0.0.1:8765/index.html --tap 0.5,0.76`；網頁版必須從 localhost 或 HTTPS 開，區網 http 引擎不會啟動 |
| `tools/run_tests.sh` | 跑專案的 headless 測試並嚴格檢查 log：Godot 遇到 `SCRIPT ERROR` 仍會 exit 0，所以 log 有 `SCRIPT ERROR`／`Parse Error`／`Failed to load script`、有 `FAIL` 開頭的行、或沒有 `PASSED`，都算失敗 | `prototypes/godot-kit/tools/run_tests.sh <原型> [套件[:fps] ...]`；不給套件就跑全部 `tests/test_*.gd`；`play:60` 是這套用 `--fixed-fps 60` 跑 |
| `tools/capture.sh` | 錄影：開視窗、固定 30 fps 寫出 PNG 影格，有 ffmpeg 就轉成 mp4（需要顯示器；`--write-movie` 的畫面大小永遠是專案的視窗大小） | `prototypes/godot-kit/tools/capture.sh <原型> <輸出資料夾> [影格數] [-- 遊戲參數]` |

`tools/*.sh` 必須維持 LF 行尾（CRLF 會變成 `bash\r: No such file`；Windows 上的 git 若轉成 CRLF，在 repo 的 `.gitattributes` 加 `*.sh text eol=lf`）。完整流程與踩過的坑見 skill `godot-prototype-to-itch`。已採用：sugarcane-tanks（它的 `tools/build_web.sh` 與 `tools/subset_font.py` 是包這些工具的薄殼，`web_probe.mjs` 與 `pck_size.py` 的本地副本已刪）。

## Godot 官方 Best practices

[GODOT_BEST_PRACTICES.md](GODOT_BEST_PRACTICES.md) 整理官方文件 Best practices 章節的 12 頁：每頁一句重點、哪個已安裝的 `godot-*` skill 涵蓋（附行號），以及 skill 沒寫到的缺口守則（Node 替代品、專案資料夾結構、版控等）。規劃場景結構、autoload、資料容器之前先看一眼。

## 第三方套件目錄

需要時先查這裡，不要自己重寫。每個套件都固定在一個 commit，並在 Godot 4.7 實測過。「已裝」的套件在該原型裡有可以參照的做法；其餘只列在目錄，等哪個原型用得上再裝，避免每個專案都背著用不到的檔案。

| 套件 | 用途 | 版本（固定 commit） | 狀態 |
|---|---|---|---|
| [Parley](https://github.com/bisterix-studio/parley) | 節點流程圖式的分支對話編輯器，存成 JSON 格式的 `.ds` | `42f78c7` | 已裝：debt-commission（只當編輯器） |
| [Dialogue Manager](https://github.com/nathanhoad/godot_dialogue_manager) | 文字語法的分支對話編輯器與 runtime，需 Godot 4.6+ | v4.1.0 `a719088` | 已裝：debt-commission（只當編輯器） |
| [Puzzle Dependencies](https://github.com/nathanhoad/godot_puzzle_dependencies) | 解謎依賴圖：規劃哪個線索解開哪個謎題，可匯出 Graphviz | v3.0.1 `875a62f` | 已裝：debt-commission（只當編輯器） |
| [RichText3D](https://github.com/mszylkowski/rich-text-3d-godot) | 在 3D 空間顯示 BBCode 富文字（`MeshInstance3D`） | v0.1.3，commit `ac618d0` | 目錄；目前原型都是 2D |
| [@icons](https://github.com/Voxybuns/at-icons) | 600 多種自訂節點的編輯器圖示 | v1.5.0 release | 目錄 |
| [Godot Animated Image](https://github.com/513195902/godot_animated_image) | 播放 GIF、APNG、Animated WebP（GDExtension） | v1.2.0 `9a8cbed` | **暫不使用**：v1.2.0 的 Linux 與 Web 原生檔壞了 |

所有套件都是 MIT 授權。

### 裝進原型的共同步驟

1. 下載固定版本，**只複製 `addons/<套件>/`**，保留裡面的 LICENSE。
2. 在 `project.godot` 的 `[editor_plugins]` `enabled=` 清單加上 `res://addons/<套件>/plugin.cfg`。**不要從 Project Settings 介面啟用或開關**：Parley 與 Dialogue Manager 從介面啟用時會加 runtime autoload。
3. 只當編輯器用的套件，要加進 Web preset 的 `exclude_filter`，例如 `addons/<套件>/*`。前提是專案沒有任何 autoload 指向它。debt-commission 的 `tools/build_web.sh` 有做這個檢查，可以照抄。
4. 跑 `godot --headless --path . --editor --quit`，確認 log 沒有 `SCRIPT ERROR|Parse Error`，再跑專案自己的測試。

### 各套件注意事項

- **Parley、Dialogue Manager、Puzzle Dependencies**：debt-commission 的 README「劇本與解謎編輯工具」一節有完整說明。
  - Parley 與 DM 都是劇本的編寫格式。debt-commission 的 `tools/story_build/` 能把兩者都建置成同一份劇本 JSON（含可達性檢查與自動存檔版本），新原型要做分支劇本時可以整個資料夾帶走，只需改 adapter 輸出的指令。
  - Puzzle Dependencies 把圖表存在 `project.godot`；面板裡的更新按鈕會覆寫固定的版本，不要按。
- **RichText3D**：沒有 release，下載 [`ac618d0` 的 zip](https://github.com/mszylkowski/rich-text-3d-godot/archive/ac618d0b3989fd9797f1ac653c2a899b2fcd0d45.zip) 後只取 `addons/rich_text_3d/`。實測在 4.7 可載入並建立實例。只用於 3D 場景。
- **@icons**
  - **安裝來源**：要用 [release zip](https://github.com/Voxybuns/at-icons/releases/download/v1.5.0/at-icons_v1.5.0.zip)。repo 的 zip 含網頁版 picker 的原始檔，不能直接用。
  - **import 成本**：共 3,854 個 SVG，第一次 import 會產生約 15,000 個快取檔，`.godot` 增加約 63 MB，本機約 7 秒。
  - **用法**：在腳本寫 `@icon("res://addons/at-icons/node/<名稱>.svg")`。
  - **匯出**：Web 匯出可以排除 `addons/at-icons/*`。實測排除後，用了 `@icon` 的腳本在匯出版照常執行，SVG 也不會打包進去。
  - 換編輯器主題或縮放後要重新 import 圖示（上游 bug）。
- **Godot Animated Image**：目前不要裝。
  - v1.2.0 的 Linux `.so` 與 Web `.wasm` 缺少進入點 `godot_animated_image_init`，實測載入失敗。錯誤訊息只提到 Windows DLL，推測作者只測了 Windows。
  - 就算上游修好，Web 版還要在匯出設定開啟 Extension Support，並改用 dlink 匯出模板。repo 目前快取的模板只有 `web_nothreads`，所以不能在既有原型的 Web preset 直接打開這個選項。
  - 需要動畫時，改用 asset-gen 的抽幀流程，搭配 `SpriteFrames`／`AnimatedSprite2D`。

## 下一批值得抽出來的

收錄標準仍是「至少兩個原型真的在用」。下面的東西**已經有兩個以上的原型各寫了一份**（證據是 2026-10-03 對各原型程式碼的搜尋），只是還沒抽進 kit。排序依「重複度 × 抽出的工作量 × 省下的東西」。抽之前照「維護」的流程：只改 `godot-kit/`、補 kit 的測試、`sync.sh`、再跑每個使用中原型的測試。

| 優先 | 模組 | 現在各寫了一份的地方 | 抽出來要做的事 | 能省什麼 |
|---|---|---|---|---|
| 1 | **字型子集工具** `subset_font.py`<br>**已抽出（2026-10-03），sugarcane-tanks 已採用** | sugarcane-tanks `tools/subset_font.py`；pixel-monster 與 seichi-pov 各帶一份 11.9 MB 的 `NotoSansTC.ttf`（逐位元組相同）；taskbar-hero 帶 17 MB＋16.5 MB 的 CJK OTF | 加 `--project` 參數；掃描字元的範圍（略過哪些資料夾）做成參數；OTF 不需要 `instancer` 那一步 | 每個網頁匯出少 9–30 MB；測試「遊戲寫的每個字都有字形」一併帶走 |
| 2 | **網頁匯出工具組**<br>**已抽出（2026-10-03），sugarcane-tanks 已採用**；`web_probe.mjs` 多了 `--project`，IDBFS 補丁收進 `build_web.sh` | debt-commission `tools/fetch_web_templates.py`、`tools/build_web.sh`；sugarcane-tanks `tools/build_web.sh`、`pck_size.py`、`web_probe.mjs`；pachinko `tools/serve.sh`＋`Caddyfile` | 範本版本、預設名稱、輸出 zip 名稱做成參數；`build_web.sh` 的 IDBFS 補丁（debt-commission）收進來，用 `AtomicFile` 存檔的原型都需要 | 新原型一行指令出可上傳的網頁版，並能在真瀏覽器裡驗證 |
| 3 | **場景產生器的共用函式** `scene_builder.gd`（以 `PackedScene.pack()` 存檔、驗 owner 與節點數、文字層級的小補丁）<br>**已抽出（2026-10-03），尚未有原型採用** | 用 `PackedScene.pack()` 存 scene 的腳本數：sugarcane-tanks 8、taskbar-hero 3、debt-commission 3、seichi-pov 2；sugarcane-tanks 的文件早就記著 taskbar-hero 有自己的一份同樣的函式 | 已把 `_save`、`_own`、`_count`、`_instance`、`_unique` 收成 `static func`（見上方 scene_builder.gd 一節）；文字層級的小補丁還沒收。之後新寫的一次性腳本直接 `preload` 它，已套用過的舊腳本不回頭改 | 每個一次性腳本少一百行重複；遵守 AGENTS.md「用 headless 存 scene」更容易 |
| 4 | **手機震動** `haptics.gd`<br>**已抽出（2026-10-03），sugarcane-tanks 已採用** | pixel-monster `ui/main.gd:449`（直接 `Input.vibrate_handheld(35)`）；sugarcane-tanks `game/juice.gd`（偵測、三級、節流、時鐘可注入、測試） | 已獨立成一個 `RefCounted`（見上方 haptics.gd 一節）；`juice.gd` 每次 `haptic()` 把自己的設定寫進它再呼叫 `buzz()`，`Tier` 列舉與各事件的對應留在 juice | pixel-monster 不再每次呼叫都讓瀏覽器 `console.warn`，也有桌面誤判的修正 |
| 5 | **音效播放** `sfx_bank.gd`（檔案優先、合成後備、同時一個、長音效截斷）<br>**已抽出（2026-10-03），sugarcane-tanks 已採用** | 各自直接管 `AudioStreamPlayer`：pachinko `scripts/presentation.gd`、pixel-monster `ui/sound.gd`、debt-commission `main.gd`／`scripts/stage_effects.gd`、sugarcane-tanks `game/sfx.gd`（只有這一份有檔案優先、同時一個、長音效截斷） | 合成音表、借用表、長音效表改成由專案的子類別在 `_ready` 填，不寫死在模組裡（見上方 sfx_bank.gd 一節） | 使用者丟 `事件名.ogg` 就換聲音的流程，每個原型都能用 |
| 6 | **虛擬搖桿** `floating_stick.gd`<br>**已抽出（2026-10-04）**：sugarcane-tanks 的浮動搖桿，輸出螢幕向量；seichi-pov 的固定搖桿還沒換 | seichi-pov `ui/move_stick.gd`（輸出 x 右、y 前進，給 3D）；sugarcane-tanks `ui/joystick.gd`（浮動，2D，靠觸控轉滑鼠事件） | 需要先統一輸出（螢幕向量），3D 專案自己轉；固定與浮動做成模式 | 兩個原型的搖桿行為一致、測試共用 |
| 7 | **素材處理**（洋紅去背、切格、縮到遊戲尺寸）<br>**沒有抽**：`process_art.gd` 的背景清單、檔名與有損匯入是這款遊戲專屬，另一套是 Python 加外部腳本；等第二個 Godot 原型要做同樣的事再決定 | sugarcane-tanks `tools/process_art.gd`（零依賴，Godot 內跑）；anime-card-roguelite `scripts/prepare-visuals.py`，它交給 `~/.codex/skills/generate2dsprite/scripts/generate2dsprite.py`（1,838 行，有錨點、縮放設定檔、QC） | **先選一套**。建議 `process_art.gd` 當零依賴預設，並借 `generate2dsprite` 的品質檢查（邊緣是否被切到、錨點）；尺寸表改成每個專案的 manifest，不寫死在腳本 | 新原型用同一套約定與工具 |

**抽出來之後還沒做的（要各原型的擁有者處理）**：debt-commission 的 `tools/fetch_web_templates.py`、`tools/build_web.sh` 改成呼叫 kit 的版本；pixel-monster、seichi-pov、taskbar-hero 套字型子集（各省 9–30 MB）並加 `FontCheck` 測試；pachinko 的 `tools/serve.sh` 對照 `web_probe.mjs` 的「網頁版必須從 localhost 或 HTTPS 開」；pixel-monster `ui/main.gd:449` 的 `Input.vibrate_handheld(35)` 改用 `haptics.gd`（要有偵測，網頁版才不會每次呼叫都讓瀏覽器 `console.warn`）；pachinko `scripts/presentation.gd`、pixel-monster `ui/sound.gd`、debt-commission `main.gd`／`scripts/stage_effects.gd` 的音效管理改用 `sfx_bank.gd`（各寫一個繼承它的小腳本、填自己的合成音表，就有檔案優先、同時一個、長音效截斷）。這些原型目前都有未提交的修改，`./sync.sh --check` 對它們全部報 drift（debt-commission、pachinko、pixel-monster、seichi-pov、taskbar-hero），所以這一輪只對 sugarcane-tanks 跑了 `sync.sh`；別一次 `./sync.sh` 全部同步，會把新模組混進別人未完成的變更。

**目前只有一個原型用，也還沒抽出來**：`juice.gd` 的三級回饋對照表（哪個事件算哪一級是這款遊戲的調校）、升級選卡面板與選卡鎖、`hero_stats.gd` 的能力疊加、敵人基底（依賴 `game.show_damage` 等介面）、載入畫面與製作名單面板的**畫面本身**（只有 `scene_loader.gd` 的邏輯抽出來了）、射線步進投射物（核心只有 8 行 `intersect_ray`，其餘是這款遊戲的碰撞規則）、`balance_run`（決定性的機器人平衡量測，依賴這款遊戲的 `main.gd`）。等第二個原型需要時再抽。

沿用 sugarcane-tanks 做完整條流程的經驗見 skill `godot-prototype-to-itch`（原始檔在 `skills/godot-prototype-to-itch/`，用 symlink 掛進 `~/.claude/skills/`，跟 `cf-stack` 一樣）。角色原畫到動畫 sprite（Claude 挑圖、Codex 生圖、沒有影片 API 時手動生影片）見 skill `character-sprite-forge`（`skills/character-sprite-forge/`，同樣用 symlink）。

## 維護

```bash
./sync.sh                 # 更新所有已有 addons/proto_kit 的原型
./sync.sh <原型資料夾名>   # 讓新原型加入
./sync.sh --check         # 有副本和這裡不同就 exit 1
./sync.sh /絕對路徑/遊戲    # repo 外面的遊戲（也可以加 --check）；不帶參數的 ./sync.sh 只更新 prototypes/ 底下的
```

sugarcane-tanks 已經在 2026-10-04 搬出 repo，現在是 `/mnt/d/repo/godot/sugarcane-tanks`：它的 `addons/proto_kit/` 是副本，用 `./sync.sh /mnt/d/repo/godot/sugarcane-tanks` 更新，它的 `tools/*.sh` 靠 `GODOT_KIT` 或「隔壁有 `godogen/prototypes/godot-kit`」找到這裡。

修改 kit 的流程：

1. 只改 `godot-kit/addons/proto_kit/`。
2. 跑 kit 自己的測試：`godot --headless --path . --script res://tests/test_proto_kit.gd`
3. `./sync.sh`，再跑每個使用中原型的測試。

- **新增模組**：同樣的程式在第二個原型也出現時再抽進來，並在 `tests/test_proto_kit.gd` 補測試。
- **為什麼用複製**：這個 repo 在 Windows／WSL 上 checkout 時，git 會把 symlink 變成純文字檔；Godot 匯出也需要實體檔案，所以用複製而不用 symlink。
