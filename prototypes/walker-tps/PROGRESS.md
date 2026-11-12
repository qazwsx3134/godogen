# walker-tps 進度

## 2026-11-12｜scout AI、步態、勾索拆分、加速與甩尾（部分已由使用者提交於 `3065d559`）

- 專案／分支：walker-tps／master。使用者要求照 [design/code-improvements.md](design/code-improvements.md) 實作，之後追加：移動加速、勾索要注意慣性並做出甩尾的感覺。各項結果與差異見該文件開頭的「實作結果」表。
- **已完成**：
  - scout AI：A1–A8，A9 部分。
  - 步態：G1、G2、G5。
  - 戰鬥：C1、C2、C4、C5、C7，C3 部分。
  - 加速：走路 6、衝刺 9 m/s。
  - 勾索繩索甩尾。
- **未做**：G3、G4、C6。
- **提交狀態**：使用者 02:51 自行提交 `3065d559`，包含到 AI 那一批為止（scout、battlefield、步態、`test_gait_terrain` 的前一版）。之後的勾索拆分、甩尾、加速、圖層常數、測試更新仍未提交。
- **重要檔案**：
  - 程式：`scripts/scout.gd`、`battlefield.gd`、`grapple.gd`（新）、`layers.gd`（新）、`walker_combat.gd`、`walker_gait.gd`、`walker_player.gd`、`combat_hud.gd`、`combat_projectile.gd`、`auto_blades.gd`。
  - 場景：`scenes/battlefield.tscn`（重型數值）、`scout.tscn`（avoidance）、`walker_combat.tscn`（`Combat/Grapple`）、`project.godot`（`[layer_names]`）。
  - 製作工具：`tools/tune_scouts.gd`、`tools/split_grapple.gd`，都用 Godot 存檔，正常執行不會呼叫。
  - 新測試：`tests/test_scout_ai.gd`、`tests/test_gait_terrain.gd`，以及 `test_grapple_inertia.gd` 的甩尾段。
- **驗證（本次實跑，Linux 暫存複本，`godot --headless --fixed-fps 60 --path . --script res://tests/test_<名稱>.gd`）**：
  - 基準（改動前）：audio／auto_blades／battlefield／combat／grapple_inertia PASS；walker、scouts 因 Arena 移位 FAIL。
  - 最後一輪：grapple_inertia、combat、auto_blades、scout_ai、gait_terrain、battlefield、audio 全部 PASS，無 SCRIPT ERROR。
  - 數字：勾索直線拉 `overshoot=8.85 peak=18.00 brake_start=17.60`，與改動前完全相同；`SWING swept=70 deg drift=88 deg slack=-0.00 m release=22.0 m/s`；拖行中按住反方向 `STEER swept free=70 deg, holding the opposite strafe=17 deg`；`SPRINT top=9.00 safety_lifts=1`（原速度也是 1）。
  - 變異檢查：
    - 遲滯拿掉、視角錐拿掉時 `test_scout_ai` 會失敗。
    - 換回原步態程式，`test_gait_terrain` 四條失敗。
    - 換回直線拉的勾索，甩尾那條失敗（掃過 6°）。
  - **Arena 歸零的暫存複本**（工作樹的 `main.tscn` 沒動）：新程式 `test_walker` PASS（斜坡腳滑 0、衝刺 9 m/s 腳滑 0）、`test_scouts` PASS。斜坡那段原本固定按住 330 幀，加速後會走過平台，已改成依 `max_speed` 換算約 22 m。
- **未驗證**：實玩手感（甩尾、加速、scout 難度）、手機、手把、截圖。甩尾目前沒有額外視覺特效。
- **限制／下一步**：
  - `main.tscn` 的 Arena 移位仍待使用者決定；工作樹裡 `test_walker`／`test_scouts` 仍然失敗。
  - 玩家加速後 scout 命中率會下降，要實玩後重調。
  - 甩尾參數在 `Combat/Grapple` 的 Swing 群組。
  - 沒有新增使用者延期事項。未 push。


## 2026-11-11｜首次提交與跨電腦完整性驗證

- 專案／分支：walker-tps／master。使用者明確要求 commit，排除不必要檔案，同時確保另一台電腦 pull 後不缺遊戲檔案。本次提交整個既有原型：保存場景、雙機體 GLB／貼圖、綠鏽地圖／材質、勾索慣性／刀片／主砲／AI／回合、處理後音效、proto_kit 副本、測試及製作工具。遊戲實作基準以本次提交為準，最新 hash 由 `git log -1` 查核。
- **收錄策略：** 原型 .gitignore 新增 Python 快取、log、OS 雜檔及 captures／build／dist／exports 排除，沿用 .godot/ 與 raw 音效排除。所有執行素材、Godot .import 設定與 .uid 均保留；原始音效僅供重新轉檔，不是執行依賴。此原型素材沒有 LFS filter，不需額外下載 LFS；沒有忽略所需 GLB、貼圖、Ogg、導航、材質或 scene。共用套件保持同步來源副本，未為清理而刪減套件內容。
- **乾淨副本：** 僅從 Git index 取出 prototypes/walker-tps 至 `/tmp/walker-only-check-zsd4kt50`（`git ls-files -z -- prototypes/walker-tps` → `git checkout-index --stdin -z --prefix=…/`），沒有 .godot、原始音效或 docs/86。README 補首次開啟／匯入步驟；遊戲不需重建場景或 FFmpeg。
- **本次匯入證據：** `env XDG_DATA_HOME=/tmp/walker-check-data XDG_CONFIG_HOME=/tmp/walker-check-config godot --headless --path /tmp/walker-only-check-zsd4kt50/prototypes/walker-tps --editor --quit` → 退出 0，無 ERROR／缺檔。這次從零產生快取，未挪用本機 .godot。
- **本次 L2：** 乾淨副本以 `env XDG_DATA_HOME=/tmp/walker-check-data godot --headless --fixed-fps 60 --path /tmp/walker-only-check-zsd4kt50/prototypes/walker-tps --script res://tests/test_audio.gd` → AUDIO PASSED，退出 0；同指令 test_combat.gd → COMBAT PASSED，退出 0。短命測試場景切換前先 stop／等待 dummy audio driver，避免 boot 播放未釋放。素材驗證 `python3 prototypes/walker-tps/tools/verify_audio.py` → AUDIO_ASSETS PASSED（14、200988 bytes、來源未改）。地圖／慣性／刀片沿用上兩段本日證據，本次未重跑；沒有跑完整 suite。
- **文字檢查：** `git diff --cached --check` 排除同步 addons 與原包 License.txt 後通過；上游套件 shader 的尾端空白及原始授權 CRLF 保留，不直接改同步副本。
- **完成／限制：** 遊戲依賴已納入提交，未 push；其他原型／docs/86 的未提交內容不包含在此提交。手機效能、手把、音效實聽與舊 main.tscn Arena 測試基線仍待處理，沒有新增延期事項。下一步由作者試玩；要讓遠端另一台電腦取得本次 commit，仍需後續 push。

## 2026-11-11｜音效處理、接入與 Git 整理（未 commit）

- 專案／分支：walker-tps／master。使用者要求處理 assets/sound 到可放 Git，並補充 Hove Audio 與 Michel Baradari 的來源；本次處理與接入完成，未 commit／push。
- **素材：** 9 個原始音檔 10,104,955 bytes，保留且 SHA-256 驗證未變更。裁切單發／短步伐、去 DC、RMS 配對受編碼前 -6 dBFS 峰值限制、淡入淡出、mono 44.1 kHz Vorbis q4；14 個輸出共 200,988 bytes，減少 98.01%。manifest 保存裁切、增益、sample peak／RMS 與輸入輸出雜湊。不是 LUFS／true-peak 量測。
- **Git／來源：** sound/.gitignore 排除原始媒體與舊 import，各原始資料夾 .gdignore 避免重複匯入；runtime Ogg、其 import、manifest、CREDITS、原包授權文字與工具可提交，不需 LFS。Hove 自訂 royalty-free 使用說明；Michel Baradari CC BY 3.0；Kenney／SuperPhat／Breviceps CC0；Lee Barkovich 依隨附 info.txt 的 CC BY 3.0，未宣稱逐檔核對原包。CREDITS 記來源、修改與署名。
- **遊戲：** 出擊啟動、間隔至少 6 秒的 AI 通訊、scout 三種輪替機槍聲、命中／擊毀、IK 落腳合併與最多 3 聲部、移動起始機械聲與落地已接入。完整走路段與點射版保留備用；主砲／揮刀保留既有 Synth。Movement／Weapons／Impacts／Voice 混音 bus 加 Master limiter，3D 音效有距離衰減。爆炸獨立於短光效存活，結算只清除實彈，不切最後一台擊毀的尾音。
- **重要檔案：** tools/process_audio.py、verify_audio.py、apply_audio.gd；assets/sound/{README,CREDITS}.md、manifest.json、runtime/；default_bus_layout.tres；walker_player／scout／battlefield／combat_impact／combat_projectile 腳本與相關保存場景。apply_audio 透過 Godot SceneBuilder 保存，正常啟動不重建。混音已有資源時不覆寫。
- **本次 L2：** repo 根執行 `python3 prototypes/walker-tps/tools/verify_audio.py` → AUDIO_ASSETS PASSED（14 mono Vorbis、200988 bytes、原始忽略且未變更），退出 0。`env XDG_DATA_HOME=/tmp/walker-audio-data godot --headless --fixed-fps 60 --path prototypes/walker-tps --script res://tests/test_audio.gd` → AUDIO PASSED，退出 0，最終無殘留警告／錯誤；覆蓋 14 檔匯入與時長、buses／limiter、啟動、通訊節流、步伐節流／落地、爆炸存活與最後擊毀後收尾。
- **本次回歸：** 同指令改 test_combat.gd → COMBAT PASSED、退出 0；test_battlefield.gd → BATTLEFIELD PASSED、退出 0。地圖測試原本直接 quit 留下播放中的資源，補 stop／釋放場景／等待 audio driver 後重跑，最終無資源殘留錯誤。沒有跑完整 suite，沿用此前 main.tscn Arena 位移的已知限制。
- **本次匯入：** `env XDG_DATA_HOME=/tmp/walker-audio-data XDG_CONFIG_HOME=/tmp/walker-audio-config godot --headless --path prototypes/walker-tps --editor --quit` → 退出 0，無腳本／場景／資源匯入錯誤。Git 待收錄清單確認只有處理後 Ogg／import 與文件，原始媒體不在清單。
- **限制／下一步：** 尚未耳機、喇叭或手機實聽，也未驗證手機效能；由作者實玩確認音量與步態節奏。沒有新增延期事項。原始素材不隨 Git，重新處理需自行取得來源，但乾淨 checkout 可直接用 runtime。整個原型仍未追蹤；根 Progress.md 只更新 walker 一行，其他專案既有修改保留。

## 2026-11-11｜勾索慣性剎車＋自動刀片（未 commit）

- 專案／分支：walker-tps／master。使用者要求勾索讓戰甲越過錨點後剎車，途中追加近戰自動刀片；兩項均完成。
- **慣性：** 拉動以 45 m/s² 加速至 18 m/s，距錨點 4 m 提前鬆索，越過錨點投影 2 m 開始以 24 m/s² 剎車。拉動／滑行／剎車期間略過一般行走減速，保留實際碰撞結果與重力；G 提早進入剎車，飛釘期 G 取消；越界、失焦、死亡、回合結束仍硬清動量。牆面／敵人身體不會被穿過。輕敵拖曳規則保留。
- **自動刀片：** 前方約 140°／3.6 m／高差 ≤1.8 m；0.12 秒前搖後重新檢查範圍與遮擋，每個有效目標一次 30 傷害，攻擊間隔 0.9 秒。會自動銜接拉近的輕敵、更新擊毀計數；結算停用。視覺用 7° 機身扭動＋雙側弧形刀光，音效與命中特效使用現有合成模組。原刀片與 Hull 合併，沒有新增獨立刀片骨架。
- **來源：** scripts/walker_combat.gd、walker_player.gd、auto_blades.gd、combat_hud.gd；新增保存場景 scenes/auto_blades.tscn（5 nodes）、walker_combat.tscn 引用後 14 nodes，皆經 Godot SceneBuilder pack／引用／節點數驗證。tools/add_auto_blades.gd 為製作工具；既有 build_combat_slice.gd 更新為保留 AutoBlades 引用。執行遊戲不生成場景。
- **本次 L2 證據（專案根目錄）：** `env XDG_DATA_HOME=/tmp/walker-combat-data godot --headless --fixed-fps 60 --path . --script res://tests/test_grapple_inertia.gd` → GRAPPLE_INERTIA PASSED，退出碼 0；錨點 z=18、停止 z=26.85，越位 8.85 m、峰值 18 m/s、剎車開始速度 17.60 m/s。涵蓋漸進加速、滑行／越位／停止、G 提早剎車、安全取消及牆面碰撞。最終一次有 3 個 ObjectDB 退出洩漏警告。
- **本次近戰：** 同指令改用 `res://tests/test_auto_blades.gd` → AUTO_BLADES PASSED，退出碼 0，最終有 4 個 ObjectDB 退出洩漏警告；涵蓋每次一次傷害／攻擊間隔、連續擊毀、勾索拉近自動接刀、牆面／背後／高差／前搖移出不命中、結算停止。
- **本次回歸：** 同指令改用 `res://tests/test_combat.gd` → COMBAT PASSED，退出碼 0、無腳本錯誤；test_battlefield.gd → BATTLEFIELD PASSED、退出碼 0，退出有 5 個 ObjectDB 洩漏警告，未定位。未跑完整 suite，也未重跑原 Arena 位移尚待處理的 test_walker／test_scouts。
- **匯入與畫面：** `env XDG_DATA_HOME=/tmp/walker-combat-data XDG_CONFIG_HOME=/tmp/walker-combat-config godot --headless --path . --editor --quit` → 退出碼 0、無匯入錯誤。xvfb 執行 tools/capture_dash_blades.gd，輸出 `/tmp/walker-dash-blades-shots/` 5 張；已檢視越錨、剎車與自動刀光，無 shader／執行錯誤。標示 ANCHOR 的 Label3D 只存在截圖工具，未加入正式場景。llvmpipe 有 V-Sync 警告，不代表手機效能；音效與手感待真人驗收。
- **已修製作問題：** AutoBlades 的 @onready model 曾寫在所依賴的 body 之前，造成初始化空值；已依依賴順序修正並重跑近戰、戰鬥、慣性測試。
- **限制／未完成：** 未做手動大幅迴旋或獨立刀片骨架；慣性不模擬繩索擺盪。手機／手把手感與效能未驗；若停止距離過長，可調 overshoot_distance／brake_deceleration，不能把頭段 2 m 越位當成完整停止距離。模型、材質與其他 session 原始修改保留。
- **下一步：** 作者實玩拉近／越位剎車與自動刀片的連段，調整剎車與近戰節奏。沒有使用者指定延期事項。README／TODO／design/combat-slice.md 與根 Progress.md 已同步；未 commit／push。

## 2026-11-11｜雙勾索、主砲、scout 戰鬥 AI 與單局（未 commit）

- 專案／分支：walker-tps／master。使用者授權整批實作，途中中斷後兩次指示繼續；既有地圖／材質與其他 session 修改保留。
- **已完成：** 前方兩個發射點與可見雙索釘／圓索、45 m 射程；兩索命中同一輕敵時拖近敵人，地形／重敵則以 18 m/s 拉玩家；取消、冷卻、抵達、遮擋、目標死亡／失效、失焦、越界、回合結束皆斷索。索線以旋轉後局部 Y 軸伸長，保持粗細，避免全域縮放拉成扁片。
- **已完成：** 砲塔 ±30° 及俯仰限制、超限時瞄準／開火帶動車身、鏡頭準星與砲口準星；掃掠砲彈每發 40 傷害、1.2 秒裝填、砲口光／後座與音效。發射前檢查砲座到砲口，防止槍管穿牆後從牆後射出；索釘也檢查發射點前的遮擋。
- **已完成：** 兩台輕型 scout（80 HP／質量 3）、一台重型（120 HP／質量 12），玩家 100 HP／質量 8；受擊閃白／玩家紅閃、擊毀爆炸與倒伏、計數。AI 使用製作時烘焙的 2,025 個導航多邊形，巡邏→目視追擊→朝向確認／0.8 秒預警→開火，失去視線後搜索最後位置；被拉時中斷自主行動。原 main.tscn 的 12 台保留展示遊蕩模式。
- **已完成：** 任務說明→DEPLOY／Enter→300 秒殲滅 3 台→勝利／玩家毀損失敗／超時→RETRY／R 重載場景。結算清除彈體、停止交戰；重載清除 HP、擊毀、勾索與 AI 狀態。FIRE 可拖曳瞄準、HOOK、AIM 切換觸控鍵與鍵鼠／手把動作映射已接入。
- **來源與場景：** design/combat-slice.md；scripts/walker_combat.gd、combat_projectile.gd、combat_impact.gd、combat_hud.gd、scout.gd、battlefield.gd；scenes/walker_combat.tscn、combat_projectile.tscn、combat_impact.tscn、combat_hud.tscn，以及 walker／scout／battlefield 的組合；materials/battlefield_navigation.tres。所有新 UI／重複物件透過 Godot PackedScene 保存，未執行時可編輯。
- **製作工具：** tools/build_combat_slice.gd 預設偵測已保存 CombatHUD 後停止；正常匯入／執行不建場景、不烘焙。明確重跑 --overwrite 前須保留人工調整。SceneBuilder 核對 owner／instance 與節點數；後續 UI 受擊 overlay 亦經 Godot 保存。
- **本次 L2 證據：** `env XDG_DATA_HOME=/tmp/walker-combat-data godot --headless --fixed-fps 60 --path prototypes/walker-tps --script res://tests/test_combat.gd` → COMBAT PASSED、退出碼 0，最終無腳本錯誤或洩漏警告。涵蓋真實高速砲彈、裝填、近牆砲口保護、輕敵拖近且玩家不衝刺／重敵與地形拉玩家、天空落空／取消／冷卻、雙索粗細、AI 導航追擊／視線遮擋／實際射擊傷害／牆擋砲彈、勝敗超時、真正 change_scene 重試恢復。
- **本次地圖回歸：** 同 headless 指令改用 `res://tests/test_battlefield.gd` → BATTLEFIELD PASSED、退出碼 0；退出仍有 3 個 ObjectDB 洩漏警告，未定位。測試更新為先出擊再驗通行／越界。原 test_walker／test_scouts 的 Arena 位移基線未修，也未把新測試通過寫成舊基線修復。
- **本次匯入：** `env XDG_DATA_HOME=/tmp/walker-combat-data XDG_CONFIG_HOME=/tmp/walker-combat-config godot --headless --path prototypes/walker-tps --editor --quit`，檢查新腳本／保存場景與導航資源，最終退出碼 0、無腳本或資源匯入錯誤。沒有跑完整 suite，L3 待作者手動驗收後再擴大。
- **本次畫面：** `env XDG_DATA_HOME=/tmp/walker-combat-data xvfb-run -a godot --path prototypes/walker-tps --resolution 1280x720 --fixed-fps 60 --script res://tools/capture_combat.gd -- /tmp/walker-combat-shots` → 退出碼 0，7 張圖；檢視任務說明、瞄準、雙索、側面、拉近與結算，確認索線問題已修。llvmpipe 的 V-Sync 警告及 FPS 不代表手機表現，音效尚未實聽。
- **已知限制／未完成：** 本版是 HP 戰鬥，沒有穿深／部位損傷、近戰迴旋或多人；scout 沿用 walk／idle，開火與死亡以效果／倒伏表達，沒有專用骨架動畫；屍體不再參與碰撞。Esc 只釋放滑鼠，未做暫停。手機 Safe Area、手感、手把實機與效能待驗；原測試場 main.tscn 的 Arena 位移保持原狀。
- **下一步：** 作者實玩一局，驗勾索速度／落點、瞄準與回合節奏；再依回饋調整數值及手機按鈕。舊的「先到一段落」已由本次實作指示恢復；沒有新增使用者指定延期事項。
- **工作區：** 專案整個目錄仍未追蹤，README／TODO／PROGRESS 與根 Progress.md 已同步；原 docs/86、其他原型與 LESSONS 既有修改保留。本次沒有 commit／push。截圖為 /tmp 暫存。

## 2026-11-10｜材質重複感改善（未 commit）

- 專案／分支：walker-tps／master。使用者澄清要改善貼圖的規律重複，並授權執行。
- 已完成：只修改 `shaders/spatial_env_weathered.gdshader` 與 `spatial_env_ground.gdshader`。道具用固定的每物件偏移／方向、兩種尺寸混合、大片污損／殘漆與沿世界 Y 的流痕；苔色與草土交界改平滑隨機遮罩，道路增加局部泥土覆蓋和不規則邊緣。沿用圖集、材質資源和模型，不改道具排列、scene 或碰撞。
- 本次驗證為材質視覺層：`env XDG_DATA_HOME=/tmp/walker-terrain-data xvfb-run -a godot --path prototypes/walker-tps --resolution 1280x720 --fixed-fps 60 --script /tmp/capture-walker-materials.gd` → 退出碼 0，產生 5 張截圖，無 shader 編譯錯誤；檢視出生點與斷牆／殘骸同框近景，確認規律格狀重複減弱，流痕和污損顯示。V-Sync 警告來自 llvmpipe，非手機證據。
- 證據：`/tmp/walker-material-shots/1280x720_spawn.png`、`1280x720_Wall0.png` 等；這些是本機暫存截圖。本次沒有重跑移動／地圖測試，因只改 shader；不將上次結果寫成本次驗證。
- 限制：地表及道具各 6 次貼圖讀取（上一版分別 4／3），手機效能未量測；仍使用原圖集，局部仍能辨認相同裂紋形狀。需作者確認視覺效果。
- 並行工作：讀到另一 session 新增 scout／機砲與 main.tscn 編輯器移位紀錄，原文保留，本次不處理該測試場問題。根 Progress.md 僅在 walker-tps 原行補上材質進度，保留另一 session 的警示和待辦。
- 下一步：作者確認去重複效果，視需要降低流痕強度或調整表面尺寸；手機上量測後再決定材質成本。沒有使用者指定延期事項。相關 README 已同步，所有本次變更未 commit／push。

## 2026-11-10｜衝刺／跳躍、scout 敵機入場、機砲細化；暫停點（未 commit）

- **專案／分支：** walker-tps／master。和另一個 session（綠鏽戰線地形、材質、評審，見下面三段）同時在這個專案工作；那三段原文保留沒動。
- **已完成：**
  - **衝刺（Shift／RB／觸控 BOOST）：** 6.5 m/s。速度越快步伐越密（`step_time_run` 0.17 s），車身壓低 0.3 m，鏡頭 FOV 放寬 10°。
  - **跳躍（Space／A／觸控 JUMP）：** 先蹲再彈起，最高 2.56 m；空中會收腳。落地時四腳重新踩地、車身下沉回彈、揚塵、鏡頭重震、落地聲。
  - **觸控按鈕：** JUMP／BOOST 用 `TouchScreenButton`，由 `tools/add_action_buttons.gd` 以 open_scene＋put 加進 `hud.tscn`；右下角按鈕區不算進轉鏡頭的範圍。
  - **scout 敵機：** 模型在 `docs/86/enemy/scout/`，複製到 `assets/scout/`。
    - 規格：1 個蒙皮 mesh、17 根骨頭、1,304 tris、1 種材質，貼圖是 1K albedo＋512 ORM，沒有自發光。
    - 動畫：`walk` 0.8 秒、`idle` 2 秒，都是循環。
    - 機砲照參考圖細化：六角斷面機匣、背鰭、溝線、削角護罩、砲口環、漸細砲管。
  - **scout 進場景：** 新增 `scenes/scout.tscn` 和 `scripts/scout.gd`（暫時的遊蕩 AI，每台自己的 RNG，走路動畫速度 = 移動速度 ÷ 1.6）；`tools/add_scouts.gd` 在 `main.tscn` 加了 Enemies（12 台）。
  - **待辦整理：** 新增 `TODO.md`，合併使用者的待辦（主砲瞄準、射擊、近戰左右迴旋、scout AI）和評審的 R1～R8；README 的待辦改成連到這份。
- **相關但在專案外：**
  - `docs/86/walker/`：v1、v2 兩版 walker 模型與建模腳本。
  - `docs/86/enemy/scout/`：scout 的建模、渲染腳本與 README。
  - `docs/86/blender_kit.py`：共用的 Blender 工具，修了凸包刪點的重複錯誤，加了可選的自發光。
  - `prototypes/LESSONS.md`：這幾段工作新增 5 條。
- **⚠ 阻礙（使用者處理）：** `scenes/main.tscn` 的 Arena 位置變成 `(2.00, −2.01, 0.16)`，地面往下沉 2 m。
  - 檔案時間是 22:53，Windows 上的 Godot 編輯器從 01:12 一直開著；我和地形 session 的腳本都不會移動 Arena，應該是在編輯器裡不小心拖到後存檔。
  - 編輯器開著，所以沒有從外部改回去。修法和影響見 TODO.md「先處理」。
- **本次驗證（23:3x 重跑）：**
  - `godot --headless --fixed-fps 60 --path . --script res://tests/test_battlefield.gd` → `BATTLEFIELD PASSED`。
  - `test_walker.gd` → **失敗**：「walker stands on the ground」「planted feet on the ground (y=−1.192)」，都是上面的 Arena 移位造成的。
  - `test_scouts.gd` → **失敗**：scout 的 y 是 −2.01，原因相同。
- **Arena 移位前的最後一次證據（22:3x～22:5x，本 session）：**
  - `test_walker.gd` → `WALKER PASSED`：衝刺 6.50 m/s、著地腳誤差小於 1 mm；跳高 2.56 m；坡道 390 幀裡 15 幀兩組腳同時在空中。
  - `test_scouts.gd` → `SCOUTS PASSED`。
  - `xvfb-run -a godot --path . --resolution 1280x720 --script res://tools/perf_scouts.gd`，量 draw call 和三角面：
    - 0 台：70 次，45k tris。
    - 12 台：96 次，79k tris。
    - 48 台：167 次，172k tris。
    - 48 台、scout 不投影：118 次，108k tris。
    - 每台 1 次 draw call，開投影再多 1 次。
  - 截圖：xvfb 下拍了衝刺、跳躍最高點、落地、scout 近景，畫面正常。FPS 是 llvmpipe 軟體繪圖的數字，不代表手機。
- **未驗證：** 手機實機的幀率與觸控手感、手把、大量 scout 時的實機效能。
- **已知限制：** scout 只有走路和待機兩段動畫；AI 是暫時的遊蕩；12 台 scout 只在 `main.tscn`，battlefield 裡沒有。
- **下一步：**
  1. 修 Arena 移位，重跑兩套測試。
  2. 決定 PvE 或 PvP、原生或網頁。
  3. 手機實測。
  4. 主砲瞄準＋射擊（TODO.md 的順序）。
- **使用者延期事項：** 2026-11-10 使用者說「先到一段落」，下一步待指示。
- **工作區：** `prototypes/walker-tps/` 整個目錄還沒被 Git 追蹤；`docs/86/`、`prototypes/LESSONS.md` 的修改也都沒 commit。沒有 commit／push。

## 2026-11-10｜粗模搭配共用貼圖材質（未 commit）

- 專案／分支：walker-tps／master；使用者已授權執行地表、殘牆與殘骸材質改善。
- 已完成：原創程序圖集三張 1024 × 512 PNG（albedo／normal／ORM），8 種表面；地表混合泥土／碎柏油／草地，道具使用混凝土、鏽鐵、焦黑鋼與朝上表面的苔色。先看出生點與道具近景，再套用全圖。
- 實作：2 個 Compatibility spatial shader、4 個共用外部 .tres；透過 Godot SceneBuilder 保存三個既有場景，保留 instance 引用及節點數（地圖 414 nodes），沒有重建幾何或更改碰撞。原模型面數未增加，草仍為不透明幾何。
- 重要檔案：assets/environment/battlefield_*.png、materials/*.tres、shaders/spatial_env_*.gdshader、tools/make_environment_atlas.py、tools/apply_battlefield_materials.gd。Python 只用標準庫、固定 seed，沒有生成 AI 圖片或引入外部素材。工具正常執行不會自動呼叫。
- 可編輯性：scene 實際引用外部材質 .tres，可調 tile_meters／road_half_width／moss_amount／atlas_cell；套用工具使用 take_over_path 保持共享，不把材質複製進各 scene。重跑套用工具前需保留人工材質調整。
- 本次驗證：`env XDG_DATA_HOME=/tmp/walker-terrain-data godot --headless --fixed-fps 60 --path prototypes/walker-tps --script res://tests/test_battlefield.gd` → BATTLEFIELD PASSED、退出碼 0；退出有 6 個 ObjectDB 洩漏警告，未定位。移動本體未改，沿用上次 WALKER PASSED 證據，沒有重跑該組或完整測試。
- 本次匯入：`env XDG_DATA_HOME=/tmp/walker-terrain-data XDG_CONFIG_HOME=/tmp/walker-terrain-config godot --headless --path prototypes/walker-tps --editor --quit` → 最終退出碼 0，無匯入錯誤。
- 本次渲染：xvfb 執行 `/tmp/capture-walker-materials.gd`，產生 5 張截圖到 `/tmp/walker-material-shots/`；檢視出生點、殘骸與斷牆近景，無 shader 編譯錯誤。修正 fract＋隱式 mip 造成的圖集格線，以 textureGrad 與格內邊界處理；已記 LESSONS。llvmpipe 有 V-Sync 警告，非手機效能證據。
- 限制／未完成：貼圖有可見重複、幾何仍為初版方塊輪廓及三角草；沒有 AI、戰鬥、導航或新任務。新增材質運算與貼圖，沒有宣稱 FPS 提升；手機幀率、VRAM、熱降頻與真人畫面驗收待做。
- 下一步：作者按 F5 看材質與戰後感，依回饋調色、比例或製作局部高品質素材；實機測量後才調整草、陰影與材質預算。沒有使用者指定延期事項。
- 工作區：原型仍未追蹤，新增素材／工具與場景改動未 commit；其他原型修改保留；根 Progress.md 只更新本專案一行，沒有 commit／push。

## 2026-11-10｜綠鏽戰線地形初版（未 commit）

- 專案／分支：walker-tps／master。使用者已授權「做地形」，接續首圖提案製作，未擴充戰鬥。
- 已完成：240 × 220 m 起伏地表與碰撞、中央凹路、西側高地、東側廠房通道、斷橋與煙囪、14 組殘牆、10 台裝甲殘骸、30 區草叢，以及車殼積土位置的草。以程序幾何製作，沒有使用 AI 生圖。
- 入口：project.godot 預設 battlefield.tscn；原 main.tscn／arena.tscn 保留作移動測試。地圖／殘牆／殘骸各有可編輯保存場景；SceneBuilder 檢查 owner、子場景引用與 pack 前後節點數，地圖 414 nodes、battlefield 459 nodes。正常執行不重建場景。
- 行為：battlefield.gd 僅處理離開有效範圍或掉落時返回 PlayerSpawn，清速度並重置落腳。原移動測試場的舊外牆問題仍保留在該測試場；新地圖有恢復保護。
- L2 驗證（本次）：`godot --headless --fixed-fps 60 --path prototypes/walker-tps --script res://tests/test_battlefield.gd`，驗證出生點、中央前進、三路落地與前進、越界／跌落恢復、草網格保存與殘骸植被；加強測試曾發現東路正對殘牆，已將標記移到 x=85 的廠房外側通道並重跑 → BATTLEFIELD PASSED、退出碼 0；有 6 個 ObjectDB 退出洩漏警告。
- 本次移動回歸：同指令改用 `res://tests/test_walker.gd` → WALKER PASSED，退出碼 0，衝刺 6.50 m/s、跳高 2.56 m；有 4 個 ObjectDB 退出洩漏警告。沒有跑完整測試。
- 匯入：`env XDG_DATA_HOME=/tmp/walker-terrain-data XDG_CONFIG_HOME=/tmp/walker-terrain-config godot --headless --path prototypes/walker-tps --editor --quit`。沙箱內第一次有 socket／設定目錄限制，已申請權限並使用 /tmp 設定目錄重跑，最終退出碼 0、無錯誤。
- 畫面：xvfb + 現有 Screenshot helper，`/tmp/capture-walker-terrain.gd` 產生出生點、全景、廢墟三張圖到 `/tmp/walker-terrain-shots/`。已檢查修正後的草叢和殘骸植被可見；llvmpipe 軟體繪圖，有 V-Sync 警告，不代表手機 FPS。
- 已處理的製作問題：headless MultiMesh 實例資料保存後消失，改用 SurfaceTool 合併靜態草叢網格，加入重新載入 vertex 數檢查；已記 LESSONS。
- 未完成／限制：這是可探索的地形初版，正式貼圖、碎裂細節、灌木／藤蔓、環境音、導航、AI、射擊和任務尚未製作；沒有真人／手機驗收。草沒有碰撞。全圖地表為保存網格，改整體起伏需編輯網格或審查後重跑工具。
- 下一步：作者試走並確認地圖尺度／氣氛，再依回饋調整掩體、材質和地形；實機量測後調草密度。沒有使用者指定延期事項；對戰形式仍未指定。
- 工作區：原型仍是未追蹤目錄，其他原型修改保留；本次沒有 commit／push。根 Progress.md 僅更新 walker-tps 一行。

## 2026-11-10｜審閱與首張地圖提案（未 commit）

- 專案／分支：`prototypes/walker-tps`，`master`。repo HEAD 為 `18e03b97`，但本專案整個目錄尚未被 Git 追蹤，不能把它視為此原型的實作提交。
- 使用者需求：審閱補成 War Thunder 類型遊戲還缺什麼；首圖是世界大戰結束一段時間後、雜草覆蓋殘骸的破敗地形。
- **已完成：** 實作／文件盤點、現有移動測試重跑、渲染截圖檢視、越界掉落短重現；寫入 [評審報告](reviews/2026-11-10-game-critic.md) 與 [首圖提案](design/map-01-green-rust.md)，README 加入入口。
- **現有實作：** 四足 IK、移動／衝刺／跳躍、第三人稱鏡頭、鍵鼠／手把／雙指輸入程式、移動測試場。實機手機與手把未驗收。
- **部分完成／未完成：** 戰鬥、敵人 AI、裝甲／部位損傷、勝敗／重試、首圖場景、匯出與多人尚未實作；本次只做審閱與文件，沒有修改遊戲執行邏輯或場景。
- **待確認：** 已詢問第一版優先 PvE、直接 PvP、或 PvE 預留多人；目前提案暫以 PvE 排序。使用者沒有指定延期事項；報告中的分期均是建議。
- **驗證（本次新證據）：** Godot `4.7.stable.official.5b4e0cb0f`。L2 範圍：`env XDG_DATA_HOME=/tmp/walker-tps-review-20261110-data godot --headless --fixed-fps 60 --path . --script res://tests/test_walker.gd` → `WALKER PASSED`，退出碼 0；有 4 個 ObjectDB 退出洩漏警告。測得衝刺 6.50 m/s、跳高 2.56 m，坡道雙組同時抬腳 15/390 幀。
- **截圖：** `env XDG_DATA_HOME=/tmp/walker-tps-review-20261110-data xvfb-run -a godot --path . --resolution 1280x720 --fixed-fps 60 --script res://tools/capture.gd -- /tmp/walker-tps-review-20261110/shots` → 7 張；檢視站立、橫移、跳躍與落地標籤四張。llvmpipe，不代表手機效能；有 V-Sync 不支援警告。
- **新增發現：** 同樣的 headless 指令改用 `--script /tmp/walker-tps-review-20261110/probe_boundary.gd`，能跳過東側 2 m 外牆，最後位置約 `(122.39, -202.51, 0)`，無救援／重生；退出碼 0 表示成功重現，非修復通過。重現方式記在報告，不依賴暫存腳本才能理解。腳本退出有 2 個 ObjectDB 洩漏警告。
- **已知限制：** 外觀寬約 4.16 m、碰撞寬 2.2 m；足底水平且探地未分承重表面；砲塔 ±30° 限制與原地轉身規則待設計。退出洩漏警告未定位。
- **未驗證：** 真人遊戲樂趣、手機輸入／幀率／熱降頻、手把、音效、匯出版、多敵人／植被負載與連線。沒有重跑舊 README 的編輯器修改保留測試，也沒有跑完整 suite。
- **下一步建議：** 定對戰模式與目標平台 → 修越界與定瞄準規則 → 主砲／受擊靶機 → 1 對 1 與部位損傷 → 首圖灰盒與單局流程 → 實機驗證 → 戰後植被美術。
- **工作區：** 本專案原有檔案與本次新增文件均未 commit；其他原型、模型素材和 LESSONS 原有變更保留，LESSONS 本次只更新 walker-tps 專屬表的越界問題登記。文件相對連結檢查通過，文件編寫前後 15 個執行來源檔 SHA-256 相同。本次沒有 commit／push。截圖與重現工具位於 `/tmp`，是本機暫存證據。
