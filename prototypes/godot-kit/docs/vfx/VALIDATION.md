# 特效共用模組驗證（2026-11-01）

## Three.js 全目錄原生移植（本輪最終證據）

使用者要求續移植 Three.js；46 份匯出檔現均有 Godot 原生 scene。目錄為 41 個 2D／87 個 3D（46 原生＋41 billboard），3D 展示預設篩選原生效果。以下是本輪重新執行的 L2；下面兩節保留各自前輪的歷史證據。Godot 4.7、master，未 commit／push／公開部署，未同步其他遊戲副本。

Godot 測試使用 `XDG_DATA_HOME=/tmp/godot-vfx-user XDG_CONFIG_HOME=/tmp/godot-vfx-config`，依序執行：

| 驗證 | 命令／證據 | 最終結果 |
|---|---|---|
| 原始 JS 對照與原生 API | `godot --headless --path prototypes/godot-kit --script res://tests/test_three_ports.gd`；`/tmp/vfx-three-tests.log` | **17,760 checks PASS**；42 種原始幾何／自訂屬性／CW winding、原 JS 時點 uniform／變換／透明排序／深度／draw count、停止／重播／獨立材質、投射物實際命中位置與法線、光束端點、動態拖尾／武器釋放、七階段後製 0.4 秒 |
| 素材與展示回歸 | `godot --headless --path prototypes/godot-kit --script res://tests/test_vfx_library.gd`；`/tmp/vfx-three-regression.log` | **3,864 checks PASS**；Scenario／預警既有行為、原生 46／全部 87 來源篩選、切換只留單一效果、慢速自動重播與手動停止 |
| 共用播放器回歸 | `godot --headless --path prototypes/godot-kit --script res://tests/test_vfx.gd`；`/tmp/vfx-three-base.log` | **45 checks PASS** |
| 真正觸發 shader parser | `godot --headless --path prototypes/godot-kit --script res://tools/vfx/three_port/check_shaders.gd -- res://addons/proto_kit/vfx/3d/00gamedevs`；`/tmp/vfx-three-allshaders.log` | **209 shaders PASS**；呼叫 `get_shader_uniform_list()`，避免只設定 Shader.code 而尚未解析的假通過；headless 不驗證 GPU driver 編譯／畫面 |
| Web 動畫時鐘 | `node --test --test-isolation=none prototypes/godot-kit/showcase/test_player.cjs`；`/tmp/vfx-three-player.log` | **7 tests PASS** |
| 原始資料再製一致性 | 用 `extract.mjs` 再輸出至 `/tmp/vfx-three-repro`，比對 `/tmp/vfx-three-extracted`；`/tmp/vfx-three-repro.log` | 42 個效果與 stats JSON 均 byte-identical；參考 fixture 取自原 JS，不從 Godot 輸出產生 |
| 語法／來源／包完整性 | Python AST、Node `--check`、SHA-256／ZIP CRC 與必要成員比對 | PASS；46 原 JS hash 與 native scene、41 組原 PNG／atlas／recipe／README hash、41 PNG、JS／WASM／PCK／兩份 worklet／MIT notice 存在，ZIP 內 PCK 與本機輸出一致 |
| 隔離建置／匯入 | `python3 prototypes/godot-kit/tools/vfx/build_showcase.py`；`/tmp/vfx-three-web-build.log`、`build/showcase-{import,export}.log` | PASS，正式 PCK＋同版官方 release runtime；無 SCRIPT／SHADER／資源錯誤；匯入／匯出仍有沙箱 TCP listen `_sock == -1`／ERR_CANT_CREATE |
| 編譯 PCK 啟動 | `godot --headless --main-pack prototypes/godot-kit/build/showcase/godot/index.pck --fixed-fps 60 --quit-after 180`；`/tmp/vfx-three-pack.log` | PASS，180 幀無 ERROR／SCRIPT ERROR／SHADER ERROR |

新 ZIP：`build/vfx-showcase.zip`，**15,839,283 bytes**，SHA-256 `5e3c759afc861d565f33631d00da9bd7e13c619a657555aa4cb0f572ec45fe5b`。啟動 `python3 prototypes/godot-kit/build/showcase/serve.py` 後開 `http://127.0.0.1:8765/`；目前沒有運行中的 server。

本輪測試實際抓到並修正：透明 renderOrder／不透明 pass 策略、活動階段深度與 draw range、vec4 array 連續插值轉成通用 Array（改離散軌並斷言 GPU 參數型別）、重跑材質工具派生出遞迴 depth shader、已釋放武器的拖尾未停止。錯誤條件在修正前確實 FAIL，修正後才有上表 PASS；沒有以數值攤平比較掩蓋參數型別錯誤。

**驗收邊界**：原 JS 標示 Three 0.187.0，本輪離線製作／數值對照實際使用經校驗 cache 的 **0.185.1**；CPU 改寫通道保存為 30 Hz，GPU 方程即時計算。固定使用者預設幾何，未涵蓋每個 JS setOptions 的動態重建。詳細 API、座標、transmission 改寫與精度見 [THREE-PORTS](THREE-PORTS.md)。這些 headless 證據不能宣稱逐像素相同。Chromium 前輪啟動因 socket EPERM 受阻（`/tmp/vfx-browser-smoke.log`），本輪未重跑；**Web boot／GPU 外觀／手機觸控與效能仍待驗收**。未跑完整 kit／其他遊戲 L3，未執行額外 Static Impact recipe。

## 前輪：本機素材接入與網頁展示

使用者已提供 `vfx-example/`，並要求測試與可預覽 Godot 特效／sprite 的展示頁。Godot 4.7、master；本輪未 commit／push／發布。以下結果取代早期製作失敗紀錄；下面原共用模組證據保留為前輪歷史。

| 層級／驗證 | 命令／證據 | 最終結果 |
|---|---|---|
| L2 素材／原生移植／展示場景 | `godot --headless --path prototypes/godot-kit --script res://tests/test_vfx_library.gd`；隔離 XDG；`/tmp/vfx-library-tests-final.log` | **3,815 assertions PASS**，無 ERROR／SCRIPT ERROR／SHADER ERROR；41 組 2D／3D SpriteFrames、實際播放從第 0 幀、實際 3D mesh 的 pivot 邊界、兩個預警生命週期／獨立材質、84 個 gallery 選項切換保持單一實例 |
| L2 受影響播放器回歸 | `godot --headless --path prototypes/godot-kit --script res://tests/test_vfx.gd`；`/tmp/vfx-base-final.log` | **45 checks PASS**，無 ERROR；上一輪基本行為已重跑，並非沿用舊證據 |
| 變異檢查 | 暫時反轉 volcanic-pillar 3D scene offset.y；同一 library suite | `/tmp/vfx-library-mutation.log` 實際 mesh 底邊與 offset 斷言 FAIL；finally 還原原檔後重跑得到上述 3,815 PASS |
| Web 動畫時鐘 | `node --test --test-isolation=none prototypes/godot-kit/showcase/test_player.cjs`；`/tmp/vfx-player-tests-final.log` | **7 tests PASS**：一次性／循環／暫停／seek／速度／非法 delta／末幀完整停留時間 |
| Web JS 語法 | `node --check prototypes/godot-kit/showcase/app.js` 與 `test_browser.cjs` | PASS |
| 原檔完整性／靜態展示包 | 比對 41 組 PNG／atlas／recipe／README SHA-256、HTML asset 引用與 data.js／atlas 清單、46 份 Three.js 狀態 | PASS；41 組資料與資產存在；僅兩份 Three.js 標為已移植 |
| Scene 保存 | `build_library.gd`、`build_gallery.gd`、`build_showcase_scene.gd` 使用 Godot pack/save/reload | 82 個 Scenario 場景、兩個原生預警、兩個 gallery、32-node showcase；驗證 node 數與實際子 scene 引用 |
| 最終匯入 | `godot --headless --path prototypes/godot-kit --editor --quit`；`/tmp/vfx-final-import.log` | 無 SCRIPT／SHADER／資源錯誤；仍有沙箱 TCP listen `_sock == -1`／ERR_CANT_CREATE，不能宣稱無錯匯入 |
| 可攜網站建置 | `python3 prototypes/godot-kit/tools/vfx/build_showcase.py`；`/tmp/vfx-web-build.log`，kit `build/showcase-{import,export}.log` | 成功。正式 export-pack PCK 搭配同版官方 release JS／WASM／兩份 audio worklet；單執行緒、不需 npm／雲端 API |
| 編譯 PCK 冒煙 | `godot --headless --main-pack prototypes/godot-kit/build/showcase/godot/index.pck --fixed-fps 60 --quit-after 150`；`/tmp/vfx-export-pack-smoke.log` | PASS，150 幀無錯，驗證編譯資源中的 showcase 實際啟動 |
| 實際瀏覽器 | Playwright 啟動 Chromium；`/tmp/vfx-browser-smoke.log` | **未完成**：Chromium 在 crashpad socket `setsockopt: Operation not permitted` 結束，未取得頁面或截圖，沒有瀏覽器 PASS 證據 |

網站產物：`build/showcase/`；ZIP `build/vfx-showcase.zip` **11,435,626 bytes**，SHA-256 `3b3c4516d30290589a83add59c2958d4e31844b0a861ddc9ab96cefd86b80c12`。可用 `python3 prototypes/godot-kit/build/showcase/serve.py` 後開 `http://127.0.0.1:8765/`。本輪沒有啟動成功的常駐 Web server，也沒有發布到外部網址。

待驗：實際瀏覽器 Godot Web boot／GPU 外觀、手機觸控與頁面視覺；可在允許 Chromium 的環境以 `showcase/test_browser.cjs` 接續。未跑完整 kit suite 或其他遊戲 L3。其餘 44 份 Three.js 尚未移植；沒有把它們列為可用效果。沒有複製／再散布 Scenario renderer，也沒有執行使用者額外的 Static Impact recipe。

本輪修正：上游 res://貼圖引用、Sprite2D／Sprite3D offset.y 方向相反、根 scene 保存時不能要求不存在的子 instance、Godot shader 多變數 uniform 宣告／同名遮蔽、runtime 從 editor 預覽 frame 跳過起頭。已針對相應行為補測試。export-release 在隔離資料夾缺 debug template 的驗證路徑失敗，最終改用 export-pack＋原版 release runtime，未將 release 檔冒充 debug template。

## 前輪：共用基礎模組

分支 master；Godot `4.7.stable.official.5b4e0cb0f`。本次為 L2（新共用模組與既有 native 特效、同步流程交互），未改既有遊戲副本。所有 Godot 指令使用 `XDG_DATA_HOME=/tmp/godot-vfx-user XDG_CONFIG_HOME=/tmp/godot-vfx-config` 隔離使用者資料。

| 驗證 | 指令／證據 | 結果 |
|---|---|---|
| scene 製作 | `godot --headless --path prototypes/godot-kit --script res://tools/vfx/build_scenes.gd`；`/tmp/vfx-build.log` | 6 份 scene，node 數分別為 1、1、1、15、7、20；Godot 存檔後重載與子 scene 引用核對通過 |
| 匯入 | `godot --headless --path prototypes/godot-kit --editor --quit`；`/tmp/vfx-import.log` | 無腳本解析／資源載入錯誤；仍有沙箱禁止 TCP listen 的 `_sock == -1`／ERR_CANT_CREATE，不能宣稱全無錯誤 |
| 模組＋preview 冒煙 | `godot --headless --path prototypes/godot-kit --script res://tests/test_vfx.gd`；`/tmp/vfx-tests.log` | **45 checks，VFX TESTS PASSED**，最後一次無 ERROR／SCRIPT ERROR／Parse Error |
| 變異檢查 | 暫時將 atlas region 的 x 加 1，再跑同一 suite；`/tmp/vfx-mutation.log` | 正確看到 frame rectangle FAIL，exit 非 0；還原後上列 suite 全過 |
| 真實 PNG 轉換 | `/tmp/vfx-integration` 隔離專案，24×8 PNG 三色、3 幀、15fps once；執行 `res://tools/vfx/import_strip.gd` | `/tmp/vfx-cli.log` 成功產生 `.tres` 與來源 JSON |
| CLI 重載／負向案例 | 隔離專案 `res://check.gd` 重載、比對綠色幀實際像素與 SHA-256；重跑同輸出；5 幀切 24px | `/tmp/vfx-cli-checks.log`：重載通過；已存在輸出 exit 1 且 hash 不變；非法切格 exit 1 且不產生輸出 |
| 同步新專案 | `bash prototypes/godot-kit/sync.sh /tmp/vfx-consumer` | `/tmp/vfx-sync.log` 同步成功；只同步暫存消費者 |
| 獨立消費者預覽 | 在 `/tmp/vfx-consumer` 匯入後，`godot --headless --path /tmp/vfx-consumer --fixed-fps 60 --quit-after 130 res://addons/proto_kit/vfx/preview_2d.tscn`，再依序執行 preview_3d | `/tmp/vfx-consumer-2d.log`、`/tmp/vfx-consumer-3d.log` 無錯；匯入同樣有沙箱 TCP 錯誤（`/tmp/vfx-consumer-import.log`） |

測試涵蓋一次性／循環／手動播放、finished signal、保留實例選項、MultiMesh 實例獨立、原生碎片與 ring 生命週期。編輯保留測試先修改 preview 子節點位置，pack／save／reload，再執行並確認位置不變與來源 scene hash 不變。

尚未驗證：兩站實際素材、來源 ZIP 內的 SpriteFrames／atlas 格式、授權與 Three.js 移植、真實 GPU shader 外觀、手機／Web、真人編輯器驗收。headless 不提供畫面品質證據。未跑完整 kit suite 或其他原型測試；本輪未聲稱沿用它們的結果。

本輪早期測試曾出現捕捉已釋放 node 的 Lambda 引擎錯誤；已改 WeakRef 並重跑乾淨。早期匯入曾有 editor settings 寫入權限錯誤，後續加上 XDG_CONFIG_HOME 隔離，不再出現。僅上表最後證據作為交付依據。`/tmp` 是本機暫存證據，可能隨環境清除；重現入口是已提交範圍內的腳本與測試（本次工作尚未 commit）。
