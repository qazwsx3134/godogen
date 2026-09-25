# godot-kit：Godot 原型共用模組

## 介紹

`prototypes/` 底下的 Godot 原型（debt-commission、pachinko、pixel-monster）各自寫過幾樣相同的東西：佔位音效、不怕當機的存檔、headless 測試的輔助函式。這些已抽出來，在這裡只維護一份，新原型直接拿來用，不必再寫一次。

這裡不是原型，也不是框架。收錄標準只有一條：**至少兩個原型真的在用**。只有一個專案需要的東西，留在那個專案裡。

| 模組 | 解決什麼 | 使用中 |
|---|---|---|
| [`synth.gd`](addons/proto_kit/synth.gd) | 程序合成佔位音：掃頻、敲擊噪音、音符串。不用下載或授權任何音檔 | pachinko、pixel-monster |
| [`atomic_file.gd`](addons/proto_kit/atomic_file.gd) | 存檔寫到一半當機或關掉分頁，也不會留下半個檔案 | debt-commission、pixel-monster |
| [`test_kit.gd`](addons/proto_kit/test_kit.gd) | headless 測試基底：斷言、等幾幀、等條件成立、模擬點擊與手勢 | debt-commission、pixel-monster |

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

## 維護

```bash
./sync.sh                 # 更新所有已有 addons/proto_kit 的原型
./sync.sh <原型資料夾名>   # 讓新原型加入
./sync.sh --check         # 有副本和這裡不同就 exit 1
```

修改 kit 的流程：

1. 只改 `godot-kit/addons/proto_kit/`。
2. 跑 kit 自己的測試：`godot --headless --path . --script res://tests/test_proto_kit.gd`
3. `./sync.sh`，再跑每個使用中原型的測試。

- **新增模組**：同樣的程式在第二個原型也出現時再抽進來，並在 `tests/test_proto_kit.gd` 補測試。
- **為什麼用複製**：這個 repo 在 Windows／WSL 上 checkout 時，git 會把 symlink 變成純文字檔；Godot 匯出也需要實體檔案，所以用複製而不用 symlink。
