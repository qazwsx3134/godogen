# godot-kit：進度與交接

由根目錄 `Progress.md` 拆出（2026-11-02）。新的放最上面；每次 commit、出門／下班／暫停前更新本檔，根目錄只更新一行摘要。共用模組說明見 [README](README.md)。

## 2026-11-01｜46 種 Three.js 原生移植

- 專案／分支：godot-kit／master，基準 `fad04133`。使用者要求「移植 threejs 的」，前輪其餘 44 份已接續實作，現有全部 **46 份**對應 Godot 原生 scene。未 commit／push／公開部署，其他原型／圖片既有修改及 `tools/vfx/pixle_vfx_forge.md` 保留。
- 已完成：42 種原 JS 幾何／GLSL／自訂頂點屬性移植，原 CPU 動畫保存為 30 Hz AnimationLibrary；另做動態武器拖尾、0.4 秒七段全畫面後製，沿用兩個預警。幾何保存為 `.res`、shader 與可編輯 `.tscn`，42 scene 保存可見預覽時點，runtime reset 從零播放。原生 API 含重播／停止／完成訊號、投射物方向／命中、光束端點與武器綁定。來源 hash／授權／預設參數保留。
- 展示：41 個 2D／87 個 3D（46 原生＋41 Scenario billboard），3D 預設原生效果。來源篩選、Hit／Stop／速度、慢速自動重播時距；拖影與後製的示範宿主使用獨立 scene。編譯 showcase 44 nodes，2D／3D gallery 分別 20／23 nodes，工具以 Godot pack/save 保留子 scene 引用。
- 本輪 L2：`test_three_ports.gd` **17,760 checks PASS**（`/tmp/vfx-three-tests.log`），`test_vfx_library.gd` **3,864 PASS**（`/tmp/vfx-three-regression.log`），`test_vfx.gd` **45 PASS**（`/tmp/vfx-three-base.log`），Web clock **7 PASS**（`/tmp/vfx-three-player.log`）；209 個 shader 強制解析通過（`/tmp/vfx-three-allshaders.log`）。原 JS 再製 42 JSON＋stats byte-identical；原始 hash／JS-Python 語法／ZIP 完整性 PASS。編譯 PCK 180 幀 headless 啟動 PASS（`/tmp/vfx-three-pack.log`）。具體命令與修正前 FAIL 證據範圍見 `docs/vfx/VALIDATION.md`。
- 本輪修正：CW winding／單面剔除、透明排序與不透明 pass、階段性深度／draw count、PackedVector4Array 動畫型別、重製工具 depth variant 冪等性、移除武器後拖尾清理、命中座標包含可編輯 Parts transform。測試不只比較數值，亦檢查 GPU 參數型別與實際 mesh 接觸點。
- 新網站包：`prototypes/godot-kit/build/vfx-showcase.zip`，**15,839,283 bytes**，SHA-256 `5e3c759afc861d565f33631d00da9bd7e13c619a657555aa4cb0f572ec45fe5b`。`python3 prototypes/godot-kit/build/showcase/serve.py` → `http://127.0.0.1:8765/`；本輪沒有運行中的 server。`build/` 已 ignore，可由 `tools/vfx/build_showcase.py` 重建。
- 部分／待驗：GPU 外觀、瀏覽器實際 boot、手機觸控／效能仍未驗。Chromium 沿用前輪 socket EPERM 阻礙，未冒稱本輪重跑；匯入／匯出仍有沙箱 TCP listen 錯誤，沒有腳本／shader／資源錯誤。原 JS 目標 Three 0.187.0，離線製作實際用已校驗 cache **0.185.1**；CPU 軌 30 Hz、固定預設幾何，未實作每個 setOptions 動態重建，也未宣稱逐像素相同。未執行額外 Static Impact recipe、其他遊戲／完整 kit L3。
- 重要檔案：`prototypes/godot-kit/docs/vfx/THREE-PORTS.md`（精度／API／編輯與重製）、`VALIDATION.md`、`SOURCES.md`；`addons/proto_kit/vfx/3d/00gamedevs/`、`library.gd`／來源索引、`tools/vfx/three_port/`、`tests/test_three_ports.gd` 與原 JS 參考 fixture、`showcase/README.md`。
- 下一步：使用者開新版網站做 GPU／瀏覽器／手機驗收，可用 Chromium 環境執行 `showcase/test_browser.cjs`；依具體外觀差異修正，再同步使用者指定專案。工作區本輪與前輪新增 vfx 素材／scene／shader／工具／測試／文件尚未提交，未同步其他遊戲副本，未使用 AI 生圖。

## 2026-11-01｜VFX 素材接入與網頁試映室

- 專案／分支：godot-kit／master，基準 `fad04133`。使用者提供 `vfx-example/`，另要求測試與 Godot／sprite 網頁展示。本輪未 commit／push／公開部署；保留其他原型與圖片既有變更，以及使用者新增的 `tools/vfx/pixle_vfx_forge.md`。
- 已完成：41 組 Scenario 匯出 PNG／atlas／recipe／README／SpriteFrames 接入，原 PNG bytes 保持；修正貼圖路徑、保留原動畫名／fps／loop，依 pivot 保存 82 個可編輯 2D／3D scene。46 份 Three.js 已盤點原碼 hash／preset／options，圓形／扇形預警兩份保留原方程與生命週期移植到原生 Godot。`vfx/library.gd` 只列可用的 41 個 2D／43 個 3D scene；兩個 gallery 與 32-node showcase 可 F6。
- 網頁已完成本機建置：`prototypes/godot-kit/showcase/` 原始碼；Sprite 搜尋／播放／逐幀／速度／倍率／透明格線／錨點與 PNG／recipe 下載；另按需載入真實 Godot Web，選 2D／3D、效果並重播。建置隔離 project，沿用同版官方 release JS／WASM／audio worklet 與正式 PCK，不改 kit project.godot。啟動：`python3 prototypes/godot-kit/build/showcase/serve.py`，再開 `http://127.0.0.1:8765/`；本輪沒有運行中的 server。
- 本輪 L2：`test_vfx_library.gd` **3,815 assertions PASS**（`/tmp/vfx-library-tests-final.log`），`test_vfx.gd` **45 checks PASS**（`/tmp/vfx-base-final.log`）；pivot 反向變異確實 FAIL，還原重跑 PASS。Web 動畫時鐘 Node **7 tests PASS**（`/tmp/vfx-player-tests-final.log`），JS 語法、原檔 hash／HTML assets／來源狀態靜態檢查 PASS。最終編譯 PCK 150 幀 headless 冒煙 PASS（`/tmp/vfx-export-pack-smoke.log`）。匯入／匯出仍有沙箱 TCP listen 錯誤；最終無 SCRIPT／SHADER／資源錯誤。未跑其他遊戲／完整 kit L3。
- 網站 ZIP：`prototypes/godot-kit/build/vfx-showcase.zip`，11,435,626 bytes，SHA-256 `3b3c4516d30290589a83add59c2958d4e31844b0a861ddc9ab96cefd86b80c12`。build/ 已 ignore，可由 `tools/vfx/build_showcase.py` 重建；不是公開 URL。
- 部分／未完成：其餘 **44 份 Three.js 尚未移植**；使用者額外 Static Impact recipe 未渲染。Chromium 啟動被 sandbox socket EPERM 擋住，沒有瀏覽器／GPU 外觀／手機驗收證據；不能宣稱 Web boot 已驗收。`showcase/test_browser.cjs` 已備妥，待可用瀏覽器環境接續。
- 重要文件：`prototypes/godot-kit/showcase/README.md`、`docs/vfx/SOURCES.md`、`docs/vfx/VALIDATION.md`、`addons/proto_kit/vfx/README.md`／`sources.json`／`three_sources.json`。來源再散布說明保留於各 Scenario README 與 00GameDevs MIT notice；Scenario renderer 未打包。
- 下一步：使用者開啟網站驗收；可用 Chromium 的環境執行 browser suite、實際 shader 外觀與手機觸控；續移植 Three.js 餘項。工作區本輪新增素材／scene／gallery／網站／測試／工具／文件，修改 kit README／.gitignore／播放器與進度，未同步既有遊戲副本、未新增 AI 生圖。

## 2026-11-01｜Godot 共用特效庫

- 專案／分支：godot-kit／master，基準 HEAD 以 `git log -1` 查核（本次啟動 context 為 `fad04133`）。使用者要求下載 00GameDevs 與 Scenario Pixel VFX Forge，做成可跨專案使用的 Godot 2D／3D 模組。本輪未 commit／push，原有其他專案及圖片修改保留。
- 已完成：`addons/proto_kit/vfx/` 的 2D／3D SpriteFrames 播放場景、既有 native 2D／立體碎片／地面環場景、兩個可編輯預覽、原創程序圓環校準圖集。新增 `tools/vfx/import_strip.gd`（單排 PNG 轉 SpriteFrames、來源與 SHA-256 紀錄、拒絕覆寫），沿用 `sync.sh` 跨專案複製；僅同步 `/tmp/vfx-consumer`，未更新其他遊戲副本。
- 部分完成／阻礙：兩站下載均為 **0 份**，Three.js 移植尚未開始。shell DNS／firecrawl 連線受限；遠端網頁工具只能讀 Scenario 官方頁，無法下載 ZIP；00GameDevs 無法開啟。Scenario 官方頁可確認 PNG／Game-ready ZIP（含 SpriteFrames）匯出，但實際檔案、授權均未驗證。內建 demo 與 native 程式不是網站素材。已詢問是否有本機匯出檔路徑，尚無回覆；未使用 AI 生圖。
- 本輪 L2：`godot --headless --path prototypes/godot-kit --script res://tests/test_vfx.gd` **45 checks PASS**（`/tmp/vfx-tests.log`）；切格座標變異確實 FAIL，還原重跑 PASS。真實 PNG CLI 匯入／重載、SHA-256、拒絕覆寫／非法切格 PASS；隔離消費者的 2D／3D scene 各 130 幀冒煙無錯。scene 由 Godot pack／save 並重載驗證 node 數／instance 引用。詳見 `docs/vfx/VALIDATION.md`。
- 匯入仍有沙箱 TCP listen ERR_CANT_CREATE；後續測試與 preview 無 SCRIPT ERROR／Parse Error。未驗視覺、Web／手機與外部素材，未跑完整 kit／其他遊戲 suite，不宣稱 L3。編輯位置存檔／重載後保留、執行不回寫來源已有測試。
- 重要檔案：`prototypes/godot-kit/addons/proto_kit/vfx/README.md`、`sources.json`、`docs/vfx/SOURCES.md`、`docs/vfx/VALIDATION.md`、`tests/test_vfx.gd`；根 kit README 已登記尚未採用。共用新增屬使用者明確授權例外。
- 下一步：取得兩站實際 ZIP／JS／貼圖及授權證據的本機路徑或可下載環境；Scenario 優先接上游 SpriteFrames；00GameDevs 依實際匯出碼逐項移植。更新來源目錄後做對應 L2 與 GPU／人工外觀驗收，再同步使用者指定專案。工作區本輪新增 kit vfx／工具／測試／文件、修改 kit README／本檔／LESSONS；不夾帶其他既有變更。

## 2026-11-01｜統一本機預覽入口

- repo 根目錄 `preview/` 同時串 debt 故事編輯器與 kit 特效試映室；完整紀錄見 [debt-commission PROGRESS](../debt-commission/PROGRESS.md) 2026-11-01 段，操作見 `preview/README.md`。

## 跨專案審查改善（2026-10-29～30）

| 專案 | 已完成的程式／文件工作 | 仍待外部驗收／延期 |
|---|---|---|
| godot-kit | 成熟度／採用與同步文件、唯讀 hash 盤點、sync --check、CLI 回歸 | 各原型副本不同步，既有差異維持可查 |

- 已完成（kit 部分）：kit 成熟度／採用資訊與同步規範。重要入口 `docs/VERSION-SYNC.md`。未同步 kit 副本。
- 續作完成：kit 唯讀逐檔盤點工具 `tools/audit_copies.py` 與 SHA-256 快照；三專案共同檔案差異已分類於 `godot-kit/docs/VERSION-SYNC.md`，未同步。四類暫存 fixture 驗證 PASS。
- 2026-10-30 kit：sync.sh --check 已整合唯讀差異分類；保留 exit code、外部含空白路徑，audit 新增 --check／JSON 組合。L2 五項隔離 CLI 測試與 bash -n PASS；實際三專案盤點 exit 1（既有差異），數量不變（`/tmp/kit-sync-check-20261030.log`）。副本未同步，Godot 測試未重跑。
