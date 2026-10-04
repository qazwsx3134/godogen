# headless 測試、變異檢查、機器人平衡量測

## 測試迴圈（Godot 遇到 SCRIPT ERROR 仍可能 exit 0，一定要 grep log）

```bash
cd <專案>; godot --headless --path . --editor --quit >/dev/null 2>&1       # 先匯入
for s in rules scenes play persistence; do
  x=""; [ $s = play ] && x="--fixed-fps 60"
  timeout 600 godot --headless --path . $x --script res://tests/test_$s.gd > /tmp/t_$s.log 2>&1
  if grep -qE 'SCRIPT ERROR|Parse Error|Failed to load script|^FAIL' /tmp/t_$s.log || ! grep -q PASSED /tmp/t_$s.log; then echo "FAIL $s"; else echo "PASS $s"; fi
done
```

四組的分工：`rules`＝純邏輯（能力疊加、經驗曲線、規則）；`scenes`＝每個 scene 的節點契約、版面在框內、字型有字形；`play`＝用真的 `main.tscn` 跑流程（機器人、點擊、通關）；`persistence`＝玩過之後 `.tscn`／`.tres` 的雜湊不變，在 scene 裡改的文字會保留（防止程式覆寫編輯器的調整）。

## 時間域陷阱（最容易讓測試連環失敗的一個）

`--fixed-fps 60` 時每個影格固定算 1/60 秒、沒有睡眠，遊戲時間比牆上時間快很多。所以：
- **不要用 `Time.get_ticks_msec()`（牆上時鐘）做會影響玩法的邏輯**（選卡鎖、震動間隔）：機器人的點擊全被吞掉，十幾個不相干的測試一起失敗。改用 `get_tree().create_timer(秒, true, false, true)`（暫停時照跑、忽略 hit stop），或讓時鐘可以注入（`var clock: Callable`）。
- 需要牆上時間的東西（馬達震動）：測試用注入的時鐘，把物理影格換算成毫秒。
- `Tween` 要 `set_ignore_time_scale(true)` 才不被 hit stop 拖慢。
- `--write-movie` 無視 `--resolution`；畫面大小是專案視窗設定。要看別的比例，用 SubViewport 渲染成 PNG。

## 變異檢查（每個新測試都做一次）

1. 備份要弄壞的檔案：`cp f $S/bak/f`。
2. 用 `sed` 弄壞**一個**行為（拿掉規則、改成另一個值）。
3. 跑對應測試：**必須出現 FAIL**。沒有就是測試沒在檢查東西。
4. 還原：`cp $S/bak/f f && cmp f $S/bak/f`，再跑一次要 PASS。

做這個才抓得到「條件寫成永遠成立」（`a or b or c` 全是 true）的假測試。

## 在別人正在改的工作樹上測試

`rsync -a --delete <專案>/ $S/snap/`（排除 `build/`），在複本裡匯入並跑四組。複本通過、真的工作樹卻失敗＝別人改到一半。**刪資料夾不要用 `rm -rf $VAR`**（會被擋）；用新的資料夾名稱。

## CRLF（WSL＋Windows 的工作樹）

- 工作樹的 `.sh` 可能是 CRLF，直接跑會 `bash\r: No such file`。
- `.tres` 的多行字串帶 `\r\n`：`Label` 把 `\r` 當成另一個換行，說明文字多一個空行、擠出卡片框。顯示前 `.replace("\r", "")`。
- 用 Edit 工具改 CRLF 檔案會自動保持 CRLF；用 python 取代時要 `newline=''` 讀寫並判斷原本的換行。

## 機器人平衡量測（`tools/balance_run.gd` ＋ `.sh`）

- 用真的 `main.tscn`、`--autoplay --seed=N`，`god`（不會死，量等級曲線）與 `real`（會死，量壓力與勝率）兩種模式，一章約 4 秒；同 seed 結果**逐字相同**。
- 輸出每間房：結算等級、拿到的經驗、升級次數、戰鬥秒數、損血、死亡、金幣、清房後收集秒數、殘留掉落物。
- **當純重構的回歸測試**：改動前後的輸出必須逐字相同；有差異就要解釋或回退。
- 調整流程：先寫「第 N 間結算等級」的目標表 → 用經驗曲線與擊殺經驗對上（`exp_to_next(L) = 4 + 2L`、老鼠 3 點，通關約 Lv19）→ 再用每間房的 `hp_scale` 調壓力（Boss 房檔案裡可能沒有這一行，要新增）。
- 判讀注意：機器人閃子彈與紅線比真人準，所以「機器人幾乎不被打到」的房間不要為了數字硬加難度；拿來比的是改前改後，不是絕對勝率。120 局勝率誤差約 ±4.5 個百分點，480 局約 ±2.3。
- Boss 叫出來的小怪不要給經驗（否則等級會隨戰鬥長短飄、也能刷）。

- **加任何 `CPUParticles2D` 都會讓基準線平移**：節點一建立（`.new()` 就算）就消耗全域亂數（headless 腳本實測：`seed(1)` 後第一個 `randf()` 從 0.4218 變 0.1591），遊戲裡用全域 `randf()` 的敵人繞路、掉落位置跟著變，每個 seed 的結果都不同——即使特效完全沒播。要「改前改後逐字相同」的 gate，先確認這次改動沒加粒子節點；加了就在加完之後重拍基準線，並用統計（通關率、等級曲線）確認沒壞。
- 比對 `balance_run.sh` 的原始行時，`RUN` 行有 `wall=`（牆上時間），每次不同；比對前要 `sed -E 's/ wall=[0-9.]+//'`，否則基準線自己跟自己都對不上。
- 二分「是哪個改動讓輸出變了」：從基準線的副本出發，一次只加一項（擠壓、拿掉舊特效、加空節點、只加新節點不播放），每項跑 2 個 seed 就夠。

## 工具備註：寫 Ogg

沒有 ffmpeg／oggenc 時：`curl -O https://bootstrap.pypa.io/pip/pip.pyz`，`python3 pip.pyz install --target <dir> soundfile numpy`，`PYTHONPATH=<dir>`。`soundfile` 一次寫整首（260 萬格）會 segfault，要 `SoundFile.blocks(blocksize=44100)` 分段寫。轉完比對：幀數相同、RMS 相近、相關性約 0.99。

## 切場景與載入畫面（title → loading → main）踩過的坑

- **在主場景的 `_ready()` 裡 `change_scene_to_*`**（例如開發參數要略過標題）會印「Parent node is busy adding/removing children」，舊場景留在樹上（看不見，結束時還會洩漏）。要 `call_deferred`。**headless 測試看不到這個**（測試用 `root.add_child()`，`current_scene` 在 `_ready` 裡是 null），只有真的跑一次、看 log 的 ERROR 才會發現。
- `ResourceLoader.load_threaded_*`：進度會先讀到 1.0、狀態還是 IN_PROGRESS，**只在狀態是 LOADED 時才換場景**。沒人 `load_threaded_get` 的工作結束時會漏一個物件。FAILED 的工作要先 `get` 才能重試，否則重試還是 FAILED。先用 `ResourceLoader.exists` 檢查，檔案不存在時引擎不會印 ERROR。壞掉的 scene（語法錯誤）會讓 log 出現 `Parse Error`，被測試迴圈的 grep 當失敗，所以那條路徑只能手動測。
- `--fixed-fps 60` 下遊戲時間比牆上時間快約 100 倍：等執行緒的東西在遊戲時間裡看起來很慢。要測「最短顯示時間」這類時鐘規則，先 `var kept := load(path)` 把目標場景放進快取，讓請求立刻完成。
- **滑鼠**：`MOUSE_FILTER_PASS` 的 Control 蓋在按鈕上仍會吃掉點擊（事件只往祖先冒泡，不會傳給後面的兄弟），所以覆蓋面板沒有 STOP 的暗幕也擋得住輸入；驗證「擋不擋」要把面板所有 Control 設成 IGNORE 再看測試會不會失敗。**Container 重新排版會重設子節點的 `scale`／`rotation`**：動畫放在純 `Control` 外層底下的子節點，不要放在 VBox 的直接子節點。`ScrollContainer` 裡的 `RichTextLabel` 要 `mouse_filter = PASS`（預設 STOP 會吃掉滾輪與觸控拖曳）。
- 存 `ShaderMaterial` 的 headless 工具會把沒設的 uniform 存成 `null`：全部明確設值。
