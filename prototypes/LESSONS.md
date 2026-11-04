# 原型開發踩過的坑（統一清單）

所有 `prototypes/` 原型踩過的坑都列在這裡。開工前、或遇到「不合理的失敗」時，先在這份清單裡搜尋關鍵字（例如 `headless`、`匯出`、`亂數`、`Herdr`）。

- 一條一行：**症狀** → 做法。細節在括號裡的來源，來源段落會繼續更新，以來源為準。
- **新的坑寫在這裡**，放進對應主題的最後一行：`- **症狀**（YYYY-MM-DD，原型名）→ 做法`。只屬於某個原型、別處用不到的調校，放進該原型自己的文件，再到最下方「各原型專屬」表登記連結。
- 同一個坑再遇到，在原條目後面加 `(×2)`，不要新增一條。
- 根目錄 `CLAUDE.md` 的「教訓紀錄」是 2026-10-27 以前的舊位置，條目已收進下面。

## 環境與工具鏈（macOS／WSL／Windows）

- **macOS 照抄 WSL 的指令失敗**：`godot` 不在 PATH、沒有 `xvfb-run`、`run_tests.sh` 沒有執行權限 → `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot bash <腳本>`；換機器先確認 Godot 路徑與腳本權限。（[CLAUDE.md](../CLAUDE.md) 2026-10-14、[erwin-run](erwin-run/PROGRESS.md#已知的坑)）
- **macOS 上 `XDG_DATA_HOME` 隔離不了 `user://`**：存檔一律在 `~/Library/Application Support/Godot/app_userdata/<專案>`，曾把作者的真實存檔從 v1 轉成 v2 覆蓋 → 試跑前先 `cp` 存檔到 `~/.claude/backups`，或用遊戲的 `--save=<名稱>` 參數。（[CLAUDE.md](../CLAUDE.md) 2026-10-27）
- **`--headless` 加 `--write-movie` 在 macOS 會 crash**（MoltenVK）→ 擷取畫面要開視窗。（[pachinko](pachinko/TODO.md#環境與工具鏈)）
- **CRLF**：WSL＋Windows 的工作樹裡 `.sh` 可能是 CRLF（`bash\r: No such file`）；`.tres` 多行字串帶 `\r`，`Label` 多出空行 → 用 LF 腳本或 kit 的 `tools/run_tests.sh`；顯示前 `.replace("\r", "")`；`.gitattributes` 放 `* text=auto eol=lf`。（[testing-and-balance](godot-kit/skills/godot-prototype-to-itch/references/testing-and-balance.md#crlfwslwindows-的工作樹)、[GODOT_BEST_PRACTICES](godot-kit/GODOT_BEST_PRACTICES.md) #12）
- **同一個 repo 在 WSL（`/mnt/d/...`）與 Mac（`~/repo/...`）路徑不同** → 舊報告裡的路徑要換算。（[character-sprite-forge](godot-kit/skills/character-sprite-forge/SKILL.md#坑)）
- **Windows 上的 Godot 編輯器用自己的匯出範本資料夾**（`%APPDATA%\Godot\export_templates\4.7.stable`）→ 在 WSL 裝範本對它沒用。（[godot-prototype-to-itch](godot-kit/skills/godot-prototype-to-itch/SKILL.md)）
- **搬資料夾 `Permission denied`，`lsof` 查不到** → 是 Windows 檔案總管開著子資料夾；用 `powershell.exe -Command "(New-Object -ComObject Shell.Application).Windows() | % LocationURL"` 列出開著的視窗，請使用者關，不要替使用者關。（[CLAUDE.md](../CLAUDE.md) 2026-10-04）
- **`rm -rf $VAR` 被 auto mode 擋；`pkill -f '字串'` 殺到自己的 shell（exit 144）** → 用字面路徑或新的資料夾名稱；記下 PID 再 `kill <pid>`。（[CLAUDE.md](../CLAUDE.md) 2026-10-02）
- **GitHub 下載很慢** → 匯出範本用 HTTP Range 只抓 `web_nothreads_release.zip`（kit 的 `tools/web/fetch_web_templates.py`）。（[godot-prototype-to-itch](godot-kit/skills/godot-prototype-to-itch/SKILL.md)）
- **Blender 在 WSL 要用 Windows 版**，路徑先 `wslpath -w` 轉換。（[seal-meadow](seal-meadow/PROGRESS.md#注意事項)）

## Git

- **`.gitignore` 早就寫了 `.godot/`、`build/`，檔案卻一直顯示已修改** → 規則加在提交之後；`git ls-files -ci --exclude-standard` 找出來，`git rm -r --cached` 移出版控。（[CLAUDE.md](../CLAUDE.md) 2026-10-14）
- **推大量圖檔與音檔回 HTTP 400、遠端掛斷**（×2）→ HTTPS 推送的緩衝區預設只有 1 MB，超過就改成分段傳送，被 GitHub 拒絕。2026-11-02 起，這個 repo 已設 `git config http.postBuffer 157286400`（150 MB，只寫在 `.git/config`），直接 `git push` 即可；單次推超過 150 MB 時，再臨時加 `-c http.postBuffer=524288000`。不改全域設定。換一台機器 clone 要重設。（[CLAUDE.md](../CLAUDE.md) 2026-10-14）
- **沙箱內 `.git` 唯讀、Xvfb／Chromium 圖形測試要沙箱外執行** → 是環境限制，不要寫成遊戲壞了，也不要跳過授權。（[dreamling-idle/PROGRESS.md](dreamling-idle/PROGRESS.md)）

## 測試與量測

- **用牆上時鐘（`Time.get_ticks_msec()`）做玩法邏輯，`--fixed-fps 60` 下十幾個測試連環失敗** → 用 `create_timer(秒, true, false, true)`（遊戲時間）或可注入的時鐘；`Tween` 要 `set_ignore_time_scale(true)`。（[testing-and-balance](godot-kit/skills/godot-prototype-to-itch/references/testing-and-balance.md#時間域陷阱最容易讓測試連環失敗的一個)、[CLAUDE.md](../CLAUDE.md) 2026-10-02） (×2：2026-11-04 debt-commission，kit 的 `haptics.gd` 用牆上時鐘算震動間隔，測試用 `create_timer` 等的遊戲時間比牆上快，第二下被當成太近吞掉 → 測試設 `haptics.clock`)
- **Godot 遇到 SCRIPT ERROR 仍可能 exit 0** → 測試一定要 grep log。（[godot-prototype-to-itch](godot-kit/skills/godot-prototype-to-itch/SKILL.md)）
- **headless 探針遇到 parse error 會卡到 timeout**；`var x := node.prop`（`node` 沒型別）會讓整支腳本 parse error → 臨時探針一律加 `timeout 120`，改寫成 `var x: bool = ...`。（[godot-prototype-to-itch](godot-kit/skills/godot-prototype-to-itch/SKILL.md)）
- **兩個 Godot 測試程序同時跑會互刪存檔，假失敗** → debt-commission 的測試共用 `.cache/test-data`；完整測試、瀏覽器檢查、網頁重建一律依序跑；有測試在跑時 `verifier` 只做靜態檢查。（記憶檔 `godot-tests-run-sequentially`，2026-10-02）
- **在別人正在改的工作樹上測試** → `rsync` 一份複本測；複本過、工作樹失敗＝別人改到一半。（[testing-and-balance](godot-kit/skills/godot-prototype-to-itch/references/testing-and-balance.md#在別人正在改的工作樹上測試)）
- **假測試（條件永遠成立）** → 每個新測試做一次變異檢查：弄壞一個行為，必須看到 FAIL，再還原。（[testing-and-balance](godot-kit/skills/godot-prototype-to-itch/references/testing-and-balance.md#變異檢查每個新測試都做一次)）
- **建立 `CPUParticles2D`（連 `.new()` 都算）就會改變全域 `randf()` 序列**，固定種子的平衡基準線整個平移 → 先用幾行 headless 腳本量「建這個節點會不會動到 `randf`」；基準線在加完粒子節點之後才拍；特效用自己的 `rng`。（[CLAUDE.md](../CLAUDE.md) 2026-10-03、[pixel-vfx](godot-kit/skills/pixel-vfx/SKILL.md#坑)）
- **逐位元組比對平衡輸出失敗**：`balance_run.sh` 的 `RUN` 行有牆上時間 → 先 `sed -E 's/ wall=[0-9.]+//'`。（[CLAUDE.md](../CLAUDE.md) 2026-10-03）
- **`Performance.TIME_PROCESS`／`TIME_PHYSICS_PROCESS` 亂跳** → 量幀時間用牆上時間。（[CLAUDE.md](../CLAUDE.md) 2026-10-15）
- **第一輪效能數字是冷啟動不是穩態**（shader 快取、Safari WASM tier-up、手機時脈爬升）→ 分 COLD／STEADY 兩個窗，兩個都要看。（[pachinko](pachinko/TODO.md#量測方法)）
- **`--write-movie` 擷取的 FPS 讀數沒意義，headless 與軟體 WebGL 也量不到真實 FPS** → 比 draw call、物件數、節點數；真實幀率要上手機量。（[pachinko](pachinko/TODO.md#量測方法)、[web-release](godot-kit/skills/godot-prototype-to-itch/references/web-release.md#4-匯出版才會出問題的地方)）
- **`--write-movie` 無視 `--resolution`** → 要看別的比例用 SubViewport 或改視窗 override。（[godot-prototype-to-itch](godot-kit/skills/godot-prototype-to-itch/SKILL.md)）
- **測試送滾輪事件只送 press**，GUI 焦點卡住、之後所有按鈕點不到 → press／release 成對送。（[seichi-pov](seichi-pov/README.md#已知地雷)）
- **在主場景 `_ready()` 換場景的錯誤 headless 測試看不到**（測試用 `root.add_child()`）→ 真的跑一次看 log 的 ERROR。（[testing-and-balance](godot-kit/skills/godot-prototype-to-itch/references/testing-and-balance.md#切場景與載入畫面title--loading--main踩過的坑)）
- **用 python `str.replace` 批次改檔，比對不到也照印 ok** → 改檔腳本一律 `assert old in s`。（[pachinko](pachinko/TODO.md#盤面重設計)）

- **等待動畫自動 `queue_free()` 時，Lambda 直接 capture node 會報「Lambda capture … was freed」，即使 `is_instance_valid` 檢查也來不及** → capture `WeakRef`，用 `get_ref() == null` 等待；同時檢查 log 的引擎 ERROR，不能只看測試 exit code。（[godot-kit VFX 驗證](godot-kit/docs/vfx/VALIDATION.md)，2026-11-01）
- **測試裡按鈕、點擊「沒反應」**（2026-11-02，kagura-dango）→ kit 的 `_press`／`_tap` 是協程，要 `await _press(...)`；沒 await 就檢查，會在點擊送出前斷言。（[kagura-dango tests](kagura-dango/tests/test_flow.gd)）
- **用 Claude in Chrome 量手機寬度：`resize_window` 縮了視窗，頁面 `innerWidth` 卻沒變**（2026-11-04，mortal-city）→ 在同網域頁面內嵌指定寬度的 iframe（360／390／430px），對 iframe 的 `contentDocument` 量 `scrollWidth <= clientWidth`。（[mortal-city](mortal-city/README.md)）
- **React 網頁原型：子元件的 `setTimeout` 一直不觸發**（2026-11-04，mortal-city）→ 遊戲時鐘每秒 tick 讓父元件重新渲染，inline callback 每次都是新函式，放在 effect 依賴裡會一直重設計時器；callback 改放 `useRef`。（[mortal-city](mortal-city/README.md#發現)）

## Scene、UI 與 Godot API

- **外部改 `.tscn` 時使用者的 Godot 編輯器開著同一個專案**，編輯器存檔會蓋回去 → 改前 `ps aux | grep -i godot`；開著就先講，請使用者重新載入。（[CLAUDE.md](../CLAUDE.md) 2026-10-14）
- **scene 產生器重跑蓋掉手動編輯**（erwin-run 的 `build_scenes.gd --overwrite`）→ scene 存好後它才是來源，重跑前先看 `git diff`。（[erwin-run](erwin-run/PROGRESS.md#已知的坑)）
- **headless 產生 scene 時子 scene 的屬性全被當成覆寫、捲軸多出一組** → 子 scene 用 `instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)`；設 `owner` 用 `get_children()` 逐層走，不用 `find_children()`。（[GODOT_BEST_PRACTICES](godot-kit/GODOT_BEST_PRACTICES.md) #3）
- **headless 工具存 `ShaderMaterial`，沒設的 uniform 被存成 `null`** → 全部明確設值，或存完刪掉 `= null` 那幾行。（[testing-and-balance](godot-kit/skills/godot-prototype-to-itch/references/testing-and-balance.md#切場景與載入畫面title--loading--main踩過的坑)、[horde-25d](horde-25d/README.md)）
- **MultiMesh 不能在 headless 下產生**：dummy renderer 丟掉 instance 資料，存出全零矩陣，不報錯 → 產生器偵測 headless 就拒絕執行，存檔後回讀比對。（[seichi-pov](seichi-pov/README.md#已知地雷)）
- **剛加進 Container 的 node 讀到舊位置**（Container 在幀尾才排版）→ 等 `RenderingServer.frame_pre_draw` 或下一幀再讀 `get_global_rect()`。（[GODOT_BEST_PRACTICES](godot-kit/GODOT_BEST_PRACTICES.md) #3）
- **Container 重新排版會重設子節點的 `scale`／`rotation`** → 動畫放在純 `Control` 外層底下的子節點。（[testing-and-balance](godot-kit/skills/godot-prototype-to-itch/references/testing-and-balance.md#切場景與載入畫面title--loading--main踩過的坑)） (×2：2026-11-04 debt-commission，HUD 數字一改字就重排，跳動的 tween 讀到被重設的 1、從 1 補到 1 等於沒跳 → `tween_property(...).from(放大值)`；測試要在同一幀讀)
- **`MOUSE_FILTER_PASS` 的 Control 蓋在按鈕上仍會吃掉點擊**；`ScrollContainer` 裡的 `RichTextLabel` 預設 STOP 會吃掉滾輪與拖曳 → 後者設 `PASS`。（同上）
- **在主場景 `_ready()` 裡 `change_scene_to_*` 會留下舊場景** → `call_deferred`；`load_threaded_*` 只在狀態是 LOADED 時才換場景。（同上）
- **`CanvasLayer` 裡的 `Control` 與 `_draw()` 量到不同座標空間**，桌機正常、手機選單被切掉 → 不要混用兩套座標。（[pachinko](pachinko/TODO.md#環境與工具鏈)）
- **debt-commission：名字顏色被蓋掉** → `_apply_ui_style_recursive` 會依 `ui_style_role` 重設 Label 字色，個別顏色要在它之後設。（[PLAN-LOG-AVATAR-TUTORIAL](debt-commission/docs/PLAN-LOG-AVATAR-TUTORIAL.md)）
- **演出在 `_ready` 就自己開演，蓋掉整個盤面** → 狀態機才是時間的權威，演出等狀態機叫它。（[pachinko](pachinko/TODO.md#演出)）
- **連續升級面板出現在手指剛點過的位置，誤選** → 加 0.35 秒選卡鎖（遊戲時間 timer）。（[godot-prototype-to-itch](godot-kit/skills/godot-prototype-to-itch/SKILL.md)）
- **滑鼠移到卡片或按鈕上，內容整個看不見**（2026-10-28，hero-horde-idle）→ 從 taskbar-hero 複製來的介面有兩種：蓋在卡片上的透明按鈕（`InspectButton`／`SelectButton`）hover、pressed 樣式是不透明色塊，把圖示整個蓋掉；有覆寫深色 `font_color` 的按鈕沒覆寫 hover／pressed／focus 字色，hover 時退回主題的白字。蓋在內容上的按鈕狀態樣式用半透明（alpha ≤ 0.2）或只畫框；覆寫 `font_color` 時連同 `font_hover_color`、`font_pressed_color`、`font_hover_pressed_color`、`font_focus_color` 一起設。用 `push_input` 送滑鼠移動與點擊再截圖驗證（座標要乘 `root.get_final_transform()`）。其他從 taskbar-hero 複製介面的原型大概也有。（[hero-horde-idle](hero-horde-idle/docs/PROGRESS.md)）
- **推王裡所有英雄都變成一攤橫條（看起來像史萊姆）**（2026-10-28，hero-horde-idle）→ 圖集從 6 列擴成 18 列（加形態），材質 `materials/heroes.tres` 的 `frames` 還是 `(9, 6)`，每格塞進 3 列圖而被壓扁。改圖集後由 `Sprite3DSheet.apply(material)` 依 json 設定格數（`army.gd setup`），並加測試比對材質與 json；只看資料（形態、cell 編號）都對，要放大截圖才看得出。（[hero-horde-idle](hero-horde-idle/docs/PROGRESS.md)）

- **傳送淡出 await 中死亡，復活後仍被舊傳送搬走；只換角色座標也會留下舊區域 bounds**（2026-10-30，seal-meadow）→ 死亡使生命週期編號失效，等待結束先核對再傳送；復活事件同步地圖、相機、跟隨與 checkpoint，測村莊存檔重開及淡出中死亡。（[修正規格](seal-meadow/design/quick-specs/world-lifecycle-2026-10-30.md)）
- **Sprite2D 與 Sprite3D 的 offset.y 方向相反**（2026-11-01，godot-kit VFX）→ 從 recipe pivot 匯入時，2D 用 `(0.5-pivot.y)*h`，3D 用 `(pivot.y-0.5)*h`；用 `generate_triangle_mesh()` 驗證實際底邊位置。（[VFX 來源接入](godot-kit/docs/vfx/SOURCES.md)）
- **Three.js GLSL 的逗號多 uniform 宣告與區域變數遮蔽 uniform 直接移到 Godot 會編譯失敗**（2026-11-01，godot-kit VFX）→ uniform 逐一宣告，shader uniform 名與區域變數分開；headless 匯入後檢查 SHADER ERROR，不能只看 exit code。（[VFX 驗證](godot-kit/docs/vfx/VALIDATION.md)）
- **AnimationPlayer 連續插值 PackedVector4Array shader uniform 時會產生通用 Array**（2026-11-01，godot-kit VFX）→ vec4 array 保存為離散軌；對照數值之外，斷言實際 shader 參數的 Variant 型別。只攤平陣列比數值會漏掉 GPU 接口錯誤。（[Three.js 移植](godot-kit/docs/vfx/THREE-PORTS.md)）
- **Three.js 原幾何直接交給 Godot，單面材質的正反面相反**（2026-11-01，godot-kit VFX）→ 每個三角形連同所有頂點屬性換序 CCW→CW，保留來源 FrontSide／DoubleSide 策略；製作工具標記已換序，重跑不可二次反轉。shader 檢查須呼叫 `get_shader_uniform_list()` 觸發延遲解析，僅設定 code 不足。（[Three.js 移植](godot-kit/docs/vfx/THREE-PORTS.md)）
- **已 free 的 Godot Object 與 null 比較會讓解除綁定分支漏判**（2026-11-01，godot-kit VFX）→ 以獨立 `_was_bound` 記錄綁定狀態，再用 `is_instance_valid()` 判斷宿主；測試真實 free 後的收尾，避免武器拖尾永久活動。（[VFX 驗證](godot-kit/docs/vfx/VALIDATION.md)）
- **立繪動作接台詞／漫畫時看不到，可能是根本還沒登場，或同幀已被下一層蓋住** → 從真實劇本順序測角色可見性、Art 位移與 alpha；先入場再排反應，非對話後續指令等動作完成。準備站位要保存到開口時的動畫；畫外音旗標需在編輯器明示。（debt-commission `tests/test_portrait_reaction.gd`、`tests/test_portrait_controls.gd`，2026-11-02）
- **用 headless 腳本 `instantiate()`＋`pack()` 重存既有 scene，只為加一顆按鈕，結果子 scene instance 上的覆寫屬性全掉了**（2026-11-04，debt-commission `chapter_select.tscn` 的預覽卡片丟了 `size_flags`、邊距與文字）→ 既有 scene 只加一個節點時，存檔前先 `diff` 新舊 `.tscn`；有非預期的刪除就只把新節點那段插進原檔，或在編輯器裡加。
- **把大 GDScript 拆成幾個控制器檔，parse 全過、執行時才 `Method not found`**（2026-11-04，debt-commission G6）→ 字串呼叫（`call_deferred("_name")`、`call("_x")`、`has_method`）不經過 parser；拆分後 grep 被搬走的函式名稱出現在字串裡的地方，改成 `obj.method.call_deferred()`。拆分前後跑完整測試逐組比對。

## 匯出與網頁版

- **匯出版 `FileAccess.file_exists("res://x.ogg")` 是 false** → 一律 `ResourceLoader.exists` 再 `load`。（[CLAUDE.md](../CLAUDE.md) 2026-10-02、[web-release](godot-kit/skills/godot-prototype-to-itch/references/web-release.md#4-匯出版才會出問題的地方)）
- **手機用區網 `http://192.168.x.x` 開，遊戲不啟動**（缺 Secure Context，跟 COOP/COEP 無關）→ 上傳 itch.io Draft 頁、`adb reverse` 後開 localhost，或區網 HTTPS。（[web-release](godot-kit/skills/godot-prototype-to-itch/references/web-release.md#6-用真的瀏覽器驗證匯出版)、[pachinko](pachinko/TODO.md#環境與工具鏈)）
- **匯出只說 "configuration errors"** → preset 開了 `vram_texture_compression/for_mobile=true` 卻沒啟用 ETC2/ASTC；用不到就關掉。（[pachinko](pachinko/TODO.md#環境與工具鏈)）
- **手機 WebGL 上角色全不見**：圖集被壓成桌面專用的 VRAM 格式 → 圖集用 `compress/mode = Lossless`。（[sprite-actors-3d](godot-kit/skills/sprite-actors-3d/SKILL.md#網頁版compatibility的陷阱)）
- **改成只匯出 scene 與相依資源後，用名字在執行時找的檔案默默消失** → 匯出模式維持「Export all resources」。（[godot-prototype-to-itch](godot-kit/skills/godot-prototype-to-itch/SKILL.md)）
- **以為網頁版大的是引擎** → 先把 pck 按副檔名拆開量：字型與大背景才是大頭（21.6 → 6.8 MB），`.wasm` 改不了。先量再縮。（[CLAUDE.md](../CLAUDE.md) 2026-10-03、[web-release](godot-kit/skills/godot-prototype-to-itch/references/web-release.md#3-大小哪裡佔空間怎麼縮)）
- **Godot Web 拿不到系統字型，整套 CJK 好幾 MB** → 用子集化字型；遊戲新增中文字就重跑 `subset_font.py`，並跑「每個字都有字形」的測試。（[erwin-run](erwin-run/PROGRESS.md#已知的坑)、[pachinko](pachinko/TODO.md#環境與工具鏈)）
- **網頁存檔 console 出現 `Failed to save IDB file system`**（原子寫入的 `.tmp` 改名競態）→ 套 kit 的 `tools/web/patch_idbfs.py`。（[web-release](godot-kit/skills/godot-prototype-to-itch/references/web-release.md#4-匯出版才會出問題的地方)）
- **Compatibility renderer 用 Filmic 加高環境光整片過曝** → seichi-pov 改用 AgX、環境光 0.45。（[seichi-pov](seichi-pov/README.md#已知地雷)）
- **@icons 外掛 import 3,854 個 SVG**、Godot Animated Image v1.2.0 在 Linux／Web 載入失敗 → 各套件的安裝與匯出注意事項見 kit README。（[godot-kit README](godot-kit/README.md#各套件注意事項)）
- **同步 kit 後網頁版 pck 多出約 14 MB**（2026-11-02，kagura-dango）→ 沒用到特效庫的專案在 Web preset 的 `exclude_filter` 加 `addons/proto_kit/vfx/*`（16.1 → 5.1 MB）。（[kagura-dango PROGRESS](kagura-dango/PROGRESS.md)）
- **`build/web` 裡多出 `index.png.import` 之類的檔案，跟著上傳**（2026-11-03，kagura-dango）→ 匯出資料夾在專案裡，Godot 會把它當素材匯入；放一個空的 `build/.gdignore`。
- **本機才有的參考檔（截圖、歌曲副本）被打包進 pck**（2026-11-03，kagura-dango）→ `all_resources` 會包所有匯入過的檔案，gitignore 不影響匯出；上傳前看一次 `exclude_filter`，再在 pck 裡 `grep -ac` 資料夾名確認。
- **在 itch 上用網址參數（`?qa=1`）開除錯模式沒反應**（2026-11-03，kagura-dango）→ 遊戲在 iframe 裡，頁面網址的參數傳不進去；手機測試版的開關做成畫面上可點的按鈕或設定項。

## 效能

- **draw call 很高，以為是貼圖散在多張** → 每個 Polygon2D／Line2D／`draw_circle` 都單獨一次 draw call；大量重複物件改成共用貼圖的 Sprite2D、同類放同一 z 層（670 → 280）。先一層層 `visible=false` 量。（[CLAUDE.md](../CLAUDE.md) 2026-10-15）
- **shader 特效一個節點一個材質**，大量用會變慢 → 每秒幾十次的命中特效用形狀，限制 `max_shader_effects`。（[pixel-vfx](godot-kit/skills/pixel-vfx/SKILL.md#坑)）

## 美術、素材與 AI 生圖

- **AI 生圖前要先問使用者**：直接生成，或只給 prompt；派工單要寫明使用者選了哪個。程序化 Blender 建模不用問。（[AGENTS.md](../AGENTS.md)、[seal-meadow](seal-meadow/PROGRESS.md#注意事項)）
- **素材更新後截圖或測試還是舊圖** → 先 `godot --headless --path . --editor --quit` 重新匯入。（[erwin-run](erwin-run/PROGRESS.md#已知的坑)）
- **生成的插畫被 UI 文字帶蓋住重點** → 生圖前量畫面安全區寫進 prompt，生完在遊戲裡截圖看。（[godot-prototype-to-itch](godot-kit/skills/godot-prototype-to-itch/SKILL.md)）
- **放在兩層 `Parallax2D` 之間的遠景物件整個被擋住，沒人發現** → 在遊戲裡截圖確認看得到。（同上）
- **重複的 `Parallax2D` 要捲走，不要淡出** → 做法見 erwin-run 的 `_ruins_leave()`。（同上）
- **小 sprite 用有損壓縮，alpha 邊緣出現色邊** → 只有大背景用 Lossy（0.9），小 sprite 維持無損。（[art-pipeline](godot-kit/skills/godot-prototype-to-itch/references/art-pipeline.md#匯入設定import-檔要-commit)）
- **3D 渲染轉 sprite，站著時角色比影子高**（腳底線取所有幀的最低像素）→ 動作不要甩到腳底以下。（[seal-meadow 3d-to-sprite](seal-meadow/design/pipeline/3d-to-sprite.md#已知問題)）
- **3D 世界裡的像素角色移動會抖** → 不要對世界座標做像素對齊；角色 sampler 用 nearest、不生 mipmap，地面貼圖反而要 mipmap。（[sprite-actors-3d](godot-kit/skills/sprite-actors-3d/SKILL.md#網頁版compatibility的陷阱)）
- **像素特效的 Bayer 抖動在像素角色旁像破圖** → 用離散輪廓；煙與氣體直接半透明填色。（[pixel-vfx](godot-kit/skills/pixel-vfx/SKILL.md#坑)）
- **Codex 生出來的原畫可能朝左下並被水平鏡像**、`route_media.py resolve` 不驗 key 和餘額、單筆生成可能卡 3 小時 → 細節與做法見 character-sprite-forge。（[character-sprite-forge](godot-kit/skills/character-sprite-forge/SKILL.md#坑)）

## 音效與手機震動

- **桌面 Chromium 也有 `navigator.vibrate`** → 偵測再加 `navigator.maxTouchPoints > 0` 或 `(pointer: coarse)`，用真瀏覽器驗證；iPhone Safari 沒有這個 API。（[CLAUDE.md](../CLAUDE.md) 2026-10-03、[web-release](godot-kit/skills/godot-prototype-to-itch/references/web-release.md#5-手機震動網頁)）
- **WAV 匯入成 QOA，原始檔仍在專案裡** → 要縮專案就轉 Ogg。（[art-pipeline](godot-kit/skills/godot-prototype-to-itch/references/art-pipeline.md#匯入設定import-檔要-commit)）
- **網頁版（Sample 播放）譜面與音樂差 1～2 拍，headless Chrome 量卻「同步」**（2026-11-03，kagura-dango，修正 11-02 的結論）→ 瀏覽器回報的 `get_playback_position()` 比實際聽到的晚約 1 秒，不能當節奏時鐘；每首歌第一次 `play()` 會卡住主執行緒 0.8～0.9 秒。網頁版改用「`play()` 返回之後」才起算的牆上時鐘減 `get_output_latency()`，手機實聽三關都對上。headless 瀏覽器沒有聲音輸出，只能檢查內部一致，同步一定要用真機耳朵驗；手機測試版用畫面上的時鐘讀數＋可點的時鐘來源切換做 A/B（itch 在 iframe 裡，網址參數傳不進遊戲）。做法已收進 `godot-kit/addons/proto_kit/song_clock.gd`。（[kagura-dango PROGRESS](kagura-dango/PROGRESS.md)）
- **修好時鐘後，玩家的延遲校準值還是錯的（1～2 秒）**（2026-11-03，kagura-dango）→ 校準存在 user://（瀏覽器 IndexedDB），會跨版本留著；讀取時把超出合理範圍（±400 ms）的值歸零，校準結果也夾在範圍內。改了時鐘就假設舊校準全部作廢。

## 存檔與劇本

- **Dialogic 存的是 timeline 的 `event_index`**，劇本重新轉檔後舊存檔從錯的事件繼續、不報錯 → debt-commission 保留 StoryRunner。存檔位置要用穩定的 id，不要用序號。（[DIALOGIC-EVALUATION](debt-commission/docs/DIALOGIC-EVALUATION.md)）

- **只在啟動檢查存檔版本，開啟後的新檔仍會被自動保存覆寫**（2026-10-31，seal-meadow）→ 寫入前核對現有主檔／備份及待寫快照；恢復備份前比對啟動選定的 bytes，避免把外部新檔換回舊資料；版本不先 int 強轉。這是檢查，不是跨程序檔案鎖。（[存檔保護](seal-meadow/docs/save-protection.md)）

## 多 agent 協作（Herdr、Codex、子 agent）

- **用 `herdr agent wait` 與 agent 狀態判斷子 agent 做完了**，狀態會閃成 idle、wait 提早回來 → 派工單指定報告檔，以報告檔出現為完成訊號。（[CLAUDE.md](../CLAUDE.md) 2026-10-02）
- **使用者已開好 Codex pane 時另開新的，新的卡在 CLI 自動更新** → 先 `herdr agent list` 找現成的 pane 並確認空閒；派工單路徑寫絕對路徑；用 pane ID 當目標。跨 agent 合作時 Codex 不用 Luna max。（記憶檔 `codex-collab-model`，2026-10-16／10-20）
- **Codex 在 Herdr 裡啟動，`-c` 參數跳警告框擋住它** → 按 Esc 關掉。（[erwin-run](erwin-run/PROGRESS.md#已知的坑)）
- **Codex 幾乎每個指令都要人工核准，使用者不在時整批停住** → 長批次前請使用者用 `/approvals` 放寬，或把產出寫在 Codex 的工作區最後一次搬。（[character-sprite-forge](godot-kit/skills/character-sprite-forge/SKILL.md#坑)）
- **不要假設上一個 agent 開的伺服器還活著** → 先確認再用。（[dreamling-idle/PROGRESS.md](dreamling-idle/PROGRESS.md)）
- **派工單的壞味道**：把使用者之後會改的東西寫死在 agent 記憶裡、「故意弄壞一次」講得不具體、審查規則到第二階段才講 → 見 agent-workflow。（[agent-workflow](godot-kit/skills/godot-prototype-to-itch/references/agent-workflow.md#教訓派工單的壞味道)）

## 各原型專屬

只屬於單一遊戲的調校與設計教訓，留在原型自己的文件：

| 原型 | 位置 | 內容 |
|---|---|---|
| pachinko | [TODO.md「踩過的坑」](pachinko/TODO.md#踩過的坑) | 盤面物理（打出軌道位置、入賞率的旋鈕是誘導釘開口）、球數經濟的順序 bug、演出時序 |
| seichi-pov | [README「已知地雷」](seichi-pov/README.md#已知地雷) | MultiMesh、滾輪事件、曝光 |
| erwin-run | [PROGRESS「已知的坑」](erwin-run/PROGRESS.md#已知的坑) | Codex 啟動、重新匯入、scene 產生器、字型子集 |
| seal-meadow | [PROGRESS「注意事項」](seal-meadow/PROGRESS.md#注意事項)、[3d-to-sprite「已知問題」](seal-meadow/design/pipeline/3d-to-sprite.md#已知問題) | 改 scene 的方式、測試的固定前提、3D 轉 sprite 流程 |
| horde-25d | [README](horde-25d/README.md) | 低角度廣角鏡頭的遮擋對策、材質存檔 |
| debt-commission | [DIALOGIC-EVALUATION](debt-commission/docs/DIALOGIC-EVALUATION.md)、[PLAN-LOG-AVATAR-TUTORIAL](debt-commission/docs/PLAN-LOG-AVATAR-TUTORIAL.md) | 劇本系統選型、`ui_style_role` 覆寫 |
| sugarcane-tanks（已搬出 repo） | skill [godot-prototype-to-itch](godot-kit/skills/godot-prototype-to-itch/SKILL.md) | 測試與平衡量測、打擊感、網頁匯出整套做法 |
