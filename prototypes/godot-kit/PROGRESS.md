# godot-kit：進度與交接

由根目錄 `Progress.md` 拆出（2026-11-02）。新的放最上面；每次 commit、出門／下班／暫停前更新本檔，根目錄只更新一行摘要。共用模組說明見 [README](README.md)。

## 2026-11-06｜首款消費者 seal-meadow 接入（未提交）

- godot-kit／master；seal 的 SaveStore 改為 validator/migrations adapter，Main 保存經 adapter，遊戲仍擁有恢復 bytes 與停止寫入狀態；v4 遷移改固定 UID，符合純回呼要求。
- 僅同步 seal 的 save_slots.gd；atomic_file 已一致，其他副本未同步。這是來源接入，不是執行驗收；具體差異見 seal docs/save-protection.md。
- 靜態檢查：cmp、capabilities.py build/check PASS 70、git diff --check；測試延期，未碰真實存檔、scene 或匯出，未 commit/push。
- 下一步：完成其他候選小批重構；恢復測試時先驗 SaveSlots 與 seal adapter。revision／跨程序鎖等草案仍未實作。

## 2026-11-06｜SaveSlots 驗證與備份保護（未提交）

- godot-kit／master；完成既有 save/restore 的可選純 validator、逐版 migration 返回檢查、JSON round-trip 候選驗證、主／備份雙方 future 保護；有效主檔才以原始 bytes 輪替備份。沒有新增平行存檔框架。
- 舊三參數呼叫保留；缺失／字串版本不再寬鬆轉型，migration 失敗可回退備份。未提供 codec／revision／跨程序鎖或跨檔原子交易，明定單寫入者。
- 重要文件：docs/SAVE-SLOTS.md、save_slots.gd、specs 與生成能力參考；草案標註已實作子集。MCP 搜尋仍 Transport closed，按先前清單讀 kit／seal 來源。
- 驗證：capabilities.py build 成功、check PASS 70、git diff --check 通過；測試依使用者指示延期，未執行 Godot／讀寫真實存檔；待補 L2 在 VALIDATION.md。
- 未完成／下一步：選一款遊戲 adapter 遷移並確認版本政策；研究草案其餘功能不算已完成。未同步副本、未 commit/push；保留其他 session 工作及先前未提交修改。

## 2026-11-06｜P0 鏡頭／載入／音樂生命週期重構（未提交）

- 專案／分支：godot-kit／master；使用者指示繼續，優先重構、測試延期。
- 已完成：camera_shake 擷取並還原原有 offset/rotation，新增 reset，停用／換鏡頭清理；scene_loader 忙碌拒絕重入且保留進度，新增 is_loading；music 對支援的 AudioStream 私有副本設定循環，原始 track 身分保留。
- 契約：兩個 step 明訂有限非負秒數；loader cancel 是可能等待的收取／丟棄，不是即時取消。camera 仍要求單一寫入者，宿主釋放前 reset。用途／參數／輸出／範例與限制已回填 specs 並再生目錄；詳見 docs/REFACTOR-P0.md。
- 驗證：靜態／目錄層，capabilities.py build 成功；capabilities.py check 顯示 PASS 70；git diff --check 通過。未執行 Godot 或 L2 測試，不沿用先前 PASS；待驗證案例在 docs/capabilities/VALIDATION.md。
- 未完成：validated snapshot 與其餘 P0/P1 候選尚未實作；各遊戲副本未同步，不能宣稱遊戲整合驗收。
- 下一步：先收斂 save_slots 的驗證／備份選擇與未來版本保護，保持遊戲 payload 規則由 adapter 提供。
- 工作區：本批三支來源、specs／生成目錄、README／研究追蹤／驗證與進度文件；保留先前未提交 kit 工作、.codegraph 與其他 session 修改。未 commit／push。

## 2026-11-06｜第三批 26 項與 9 CLI 實作研究（未提交）

- 專案／分支：godot-kit／master；使用者連續指示繼續，延續研究與契約整理。未改 runtime／scene，未同步副本，未 commit／push。
- 已完成：26 項剩餘 kit 腳本的實作研究（25 全文；vfx.library 為載入結構與兩個查詢方法，metadata 選讀）；9 CLI 主入口全文研究（sync 沿用前階段）。用途／時間／座標／失敗與所有權限制回填 specs.json/tools.json，CLI 新增機器可讀 effects 欄位並再生目錄。
- 重要結果：PixelVfx 形狀與 shader、PixelVfx3D ring 與 chunks 的座標不同；VFX finished/free/cancel 契約不同；Inspector 預覽不等於 runtime one-shot 行為；CLI 非零退出可能已寫產物。詳見 `docs/KIT-RESEARCH-03.md`。
- 覆蓋：62 項實作研究（含明列選讀）＋8 項前階段；kit 已無僅清單盤點項目。這不代表 16 原型的全部實作、423 個資源或所有 CLI helpers 都已審完；原型缺口保留於覆蓋表。
- 工具：codebase-memory MCP 首次及重試均 Transport closed，按既有清單 fallback 讀來源；CodeGraph CLI 仍可查詢，沒有重裝或更改設定。
- 驗證：文件／目錄層；`python3 prototypes/godot-kit/tools/capabilities.py build` 成功、`python3 prototypes/godot-kit/tools/capabilities.py check` PASS 70；本地文件連結與 git diff --check。未執行 CLI self-tests、匯出、錄影、Godot 或新重構測試，測試延期維持。
- 下一步：回到 P0/P1 小批重構，優先 save_slots 的 validated snapshot 與 camera／loader 所有權；修正式契約時保留相容性，再按一款遊戲一個 adapter 遷移。來源深讀有紀錄，不需重做整份清單。
- 工作區：保留先前 kit 改動與 .codegraph 本地索引；其他 session 的 mortal-city／cyberpunk 文件變更未觸碰。

## 2026-11-06｜第二批 kit 深讀與 CodeGraph MCP（未提交）

- 專案／分支：godot-kit／master；使用者授權繼續並可安裝 CodeGraph MCP／skill。
- 已完成：全文研究 gacha、card_draft、pet_care、march_strip、hd2d_look、hd2d_stage、sprite3d_actor、pixel_card3d、camera_shot、nine_slice；限制回填 catalog/specs.json 並再生能力目錄與 REFERENCE。詳見 `docs/KIT-RESEARCH-02.md`。
- 覆蓋：累計 36 項實作研究（含選讀）、8 項前階段、26 項仍清單盤點；未宣稱全庫或全部原型完整研究／驗收。
- 工具：CodeGraph v0.9.9 CLI 已可用；目前索引無 .gd。local installer 不支援 Codex，取得沙箱外寫入授權後，global installer 成功加入 ~/.codex/config.toml；需重啟 session 載入 MCP。本輪實際以 CLI 找到 capabilities.py 的 api；GDScript 用既有 codebase-memory MCP。
- 驗證：文件層；`python3 prototypes/godot-kit/tools/capabilities.py build` 成功生成 70 項，check 為生成一致性檢查。遊戲測試維持延期，無新的 runtime PASS；沒有改 runtime 或同步副本。
- 下一步：補讀剩餘 inspection／authoring／VFX／gallery，並依既有 P0/P1 順序重構。codegraph MCP 待新 session 實際連線；不用重複安裝。本機 .codegraph 索引與其他 session 的 mortal-city 修改保留，未 commit／push。

## 2026-11-06｜跨 kit 與 16 原型的實作研究（未提交）

- 專案／分支：godot-kit／master；承接使用者「好，研究／繼續」。本段只新增研究文件與入口，沒有再改 runtime、同步副本、commit 或 push。
- 已完成：跨存檔、時鐘、交易／領獎、戰鬥、觸控／安全區、鏡頭／載入、敘事編譯、VFX／Sprite、音訊／平台與工具的關鍵路徑比較。每個結論附來源、抽取邊界與優先順序。
- 重要產物：`docs/REUSE-RESEARCH.md`、`docs/RESEARCH-COVERAGE.md`、`docs/REUSE-CONTRACT-DRAFTS.md`；README 與 REUSE-AUDIT 已連結，修正 star-tide 釣魚「僅單一需求」的過度簡化。
- 結論：先回收 seal／taskbar 的存檔驗證與備份保護；處理 camera／loader／audio 的所有權，再抽 touch scene 與 glow batch；inventory 共用交易邊界，story compiler 先在 debt 拆 seam。完整戰鬥、離線收益、釣魚與遊戲規則不硬合併。
- 已知靜態風險：camera_shake 關閉震動可留下偏移、scene_loader 覆寫 in-flight request、music 修改共用 stream loop、save_slots 缺 payload validator。尚未重現或修正；不要當成本輪執行測試結果。
- 部分／未完成：70 項 kit 逐項標示深度；26 項本次實作研究（含選讀）、8 項前階段、36 項仍為清單盤點。16 原型均有來源比較，但未逐行審完 666 支，也未審完 StoryRunner／battle 或全部工具／場景。外移 repo、完整歷史與素材授權重審未涵蓋。草案 API 全部標示未實作，不登記為可用能力。
- 驗證：規劃／文件層，不執行測試；只檢查新增文件本地連結與 diff 格式。使用者延期 weighted_choice 重構後測試仍延期；此前 PASS 只適用下段列明範圍。
- 下一步：依 P0/P1 順序做小批重構，先修正正式契約再遷移指定消費者；恢復測試時先驗 weighted_choice 與四個已改消費者。進一步來源深讀按覆蓋表補齊，不能宣稱完整研究已窮盡。
- 工作區：保留先前 kit 未提交程式／目錄／scene／測試與 LESSONS；另有 mortal-city session 的未提交修改，未觸碰。

## 2026-11-06｜Godot 能力庫盤點與組合式重構（未提交）

- 專案／分支：godot-kit／master；本輪基準查得 `860e6fb7`（最新以 git log -1 為準）。未 commit／push；開始工作區乾淨，未同步或改寫其他遊戲的 kit 副本。
- 已完成盤點：16 個頂層 Godot 原型；自有 GDScript 公開 API、kit 靜態引用／副本差異、23 組逐位元組重複來源；另列場景、Resource 與 shader uniforms。二進位美術只計數，不宣稱授權與外觀審查；外移 repo、完整 git 歷史與 art_src 巢狀專案未涵蓋。
- 已完成工具庫：70 支腳本能力與 9 項 CLI 的用途、情境、輸入輸出、參數、範例、限制與來源採用證據；`catalog/specs.json`／`tools.json` 為人工語義來源，`tools/capabilities.py` 提供 list/show/plan/build/check/inventory，生成 JSON 契約、REFERENCE、資源清單與盤點。plan 僅靜態依賴參考，不是選擇性安裝器。附 `catalog/schema.json`。
- 已完成重構：`fixed_step.gd` 抽取 skybound 與 dreamling 的時間累積政策（retain/drop）；`damage_numbers_3d.gd`＋兩個保存 scene 抽取三款存活遊戲相同數字池，支援世界座標、專屬 RNG、容量／顏色／生命週期調校；`weighted_choice.gd` 抽取有序浮點權重核心，rarity/chest_shop/run_timeline/refine_ladder 四個既有模組已改用。gacha 的整數抽取與 card_draft 的 <= 邊界保留。
- 使用者最新優先序：**主要先著重重構，測試可以先緩**。停止新增／擴大測試；weighted_choice 及四個消費模組重構後尚未重跑，不能沿用此前 PASS 宣稱本輪最終程式驗收。
- 此前 L2 證據：Python 工具 5 tests OK；Godot composition 37 checks PASS、既有 survivor 109 checks PASS；scene headless 匯入 exit 0；隔離變異 return 0 使 composition 4 FAIL（exit 1）。完整命令、log 與有效範圍在 `docs/capabilities/VALIDATION.md`。後段只再生目錄與審查 diff，沒有新的測試證據。
- 相容性／限制：新數字池用世界座標與獨立 RNG；fixed_step drop 保留小數餘額；weighted_choice 對非法／零權重明確拒絕且不消耗 RNG，四個上層有對應失敗結果。這些不是無條件零行為差異；遷移舊遊戲需逐款確認。GPU／手機／Web／效能及完整 L3 未驗。
- 重要入口：`README.md`、`docs/COMPOSITION.md`、`docs/REUSE-AUDIT.md`、`docs/capabilities/REFERENCE.md`、`catalog/`、新增三個原語、`tests/test_capability_composition.gd`。製作工具不得二次 free SceneBuilder 已接手釋放的 root，已修正並記錄教訓。
- 未提交狀態：本輪 kit 原始碼／scene／工具／測試／目錄／文件，加根 Progress 與 LESSONS；Godot 匯入產生的不相關 UID 已清理，保留本輪新增檔案的 UID。
- 後續：依使用者指定繼續消除重複與拆分候選耦合；glow_pool 需 shader/material/scene 一起抽、inventory 需注入 item catalog、story_build 需分離 graph IR 與 ADV 指令。恢復驗證時先 weighted_choice／四個消費者 L1/L2，再挑指定遊戲遷移，不批次同步。

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
