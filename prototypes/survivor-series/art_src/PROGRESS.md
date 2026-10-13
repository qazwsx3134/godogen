# 美術進度（2026-10-14 01:40 更新）

## 還沒確定（等使用者看過再定）
| 項目 | 現在遊戲裡用的 | 要看的東西 |
|---|---|---|
| 地磚 r8（非菱形、橫排長方形鋪磚） | candidate 02（暫用） | `map/preview/r8/candidates-contact.png` 三選一 |
| 9 項回饋（血條、透視、吸經驗、丟臭豆腐、彈簧手、煙、夜市群路障、傷害數字、三種死法） | 全做完 | 試玩確認手感（見下方「2026-10-13 使用者回饋」） |
| 27 個新卡片圖示＋拳頭／雨傘／臭豆腐／機車騎士像素圖 | 全接上 | `icons/all-contact.png`；不滿意的格子只重生那張表 |
| 特效（kit `pixel_vfx`：硬邊爆炸與煙霧 shader、方塊粒子） | 已換 | 遊戲裡看煙霧還像不像破圖；靜態圖 `pixel-style/fx-demo-kit.png`、`vfx-gallery.png` |
| 介面面板配色（`docs/pixel-ui-plan.md` D2） | 夜市版：深靛藍底＋燈籠金框（建議值） | 另一個選擇是 PokéSurvivor 原版藍盒子 |
| 底部格子（同上 D4） | 兩排：武器 6 大格＋被動 6 小格（建議值） | 另一個選擇是只放武器、被動移到暫停畫面 |
| commit | 都還沒 commit | 使用者說最後自己決定何時 commit |

## 還沒做
- 地磚定案後：重新匯出 `map/godot/`（地面重做後一直沒更新）。
- 拳頭揮出時會放大 1.15～1.5 倍，那幾幀不在像素格上（小問題，先不改）。
- 汽車的撞擊半徑沒跟著放大後的圖調整。
- 敵人很多＋路障時的效能沒量過。
- 「炷」字俐方體 11 號沒有，會退回 Noto 字型（三炷香卡片看得出字體不同）。
- 動畫／影片（見下方「暫停中」）。
- 可刪：`heroes/man/master/`（沒用到的洋紅版）。
- 帳務：BytePlus 有兩筆「送出結果不明」，要到後台確認有沒有扣款（見「紀錄」）。
- 刻意維持向量、不打算改：圈圈套中區、機車預警線、陰影。
- 玩法與發佈的待辦在 `TODO.md`（T-115 PokéSurvivor 機制候選、T-204 設定畫面、T-205 對外試玩包）。


## 已定案（選中的圖一律是 `selected.png` 或 `master/`）
| 素材 | 檔案 | 備註 |
|---|---|---|
| 男主角 | `heroes/man/master-green/master.json`（來源 `man/edit-02.png`） | 綠幕 key（紅領帶偏洋紅） |
| 女主角 | `heroes/woman/master-green/master.json`（來源 `woman/edit-01.png`） | 綠幕 key；眼睛仍有虹膜，使用者選定照用 |
| 臭臭胖子 | `enemies/fatty/master/master.json`（來源 candidate-03） | 叼菸保留 |
| 機車 5 方向 | se：`vehicles/motorcycle/master/`（＝`selected-se.png`）；s／e／ne／n：`vehicles/motorcycle/dir-<方向>/selected.png` | s 01、e 02、ne 01、n 01；n／s 車身看起來比 se 小，接入時統一尺寸 |
| 汽車 5 方向 | se：`vehicles/car/master/`（＝`selected-se.png`）；s／e／ne／n：`vehicles/car/dir-<方向>/selected.png` | s 02、e 02（fix-e-02 的 take 2，看得到車頂）、ne 01、n 01 |
| 夜市風格基準 | `background/street_block/selected.png`（candidate-01，斜菱形鋪磚） | 只當風格參考；地圖用拼接素材 |
| 圖示 ×11（掉落物與六把武器） | `icons/<名稱>/selected.png` | 愛的小手 01、便當寶箱 02、金幣 01、鞭炮 01、寶石 02、香 01、天燈 02、珍珠 02、滷肉飯 01、藍白拖 01、吸塵器 edit-01（加粗版） |
| 圖示 ×27（其餘武器、被動、進化、融合） | `icons/<id>/selected.png`（切自 `icons/sheets/`） | 2026-10-14 一次生成；拳頭、雨傘、臭豆腐、機車騎士的遊戲圖也由這批縮出（`assets/pixel/fx/`） |
| 地圖道具 ×8 | `map/props/<id>.png`（遊戲尺寸見 `ASSETS-REPORT-3.md`） | 攤位 ×2、燈籠柱、花台、三角錐、護柱、停放機車、水果箱；攤位比主角偏小，接入時可放大 |
| 像素重畫（2026-10-14） | 各資料夾 `**/pixel/SELECTED.txt` | 男主角 03、女主角 02、流氓 02、胖子 02、機車／汽車 5 方向；上面幾列是重畫前的原圖，當像素圖的參考 |
| 地圖 Godot 匯出 | `map/godot/`（TileSet＋示範場景，Godot 4.7 匯入通過） | 地面重做後要重新匯出 |

`heroes/man/master/` 是沒用到的洋紅版，可刪。

## 下一步（2026-10-12 16:30 更新：A 已交，B 被使用者暫停未開始）
- 派工單 `BRIEF-assets-3.md` → 報告 `ASSETS-REPORT-4.md`。Codex session 已結束（Mac 上 pane `wT:pH`，可 `codex resume 01a11ad1-0e7b-7262-9fa1-59ce67e608d9`）。
- A 地面驗收（Claude 看圖）：新磚 512 px、低對比、菱形清楚，比舊版好很多；Godot 4.7 匯入 0 錯。待修：
  1. **水平接縫**：`map/preview/ground-repeat-3x3.png` 在 y=512／1024 每列都有灰縫錯位的小缺口（QC Y 比 1.22，逼近上限 1.25；`seamless_verified=false`），遊戲裡每 512 px 會出現一條斷線。
  2. **濕地反光**往燈籠上方飄，看起來像火星／煙，不像地上的倒影；倒影應落在燈籠底座附近的地面。示意圖裡暖光暈也離燈籠太遠（只是擺放問題）。
  3. 斑馬線亮米白、對比偏高（小問題，可在 Godot 調 modulate）。
- 2026-10-12 使用者同意修 A 的 1、2 並開工 B → 派工單 `BRIEF-assets-4.md`（Mac 路徑）→ 報告 `ASSETS-REPORT-5.md`。Codex 在 Herdr pane `wT:pH`（agent 名 `art7b`，gpt-6-luna max、`--approve-for-me`）。
- **2026-10-12 第七輪結果：BLOCKED（使用者出門，依指示停止）**
  - A 已完成：地磚接縫重修（wrap QC x 1.013／y 1.008，原本 y 1.22）、濕地反光改成從燈座往畫面下方延伸的暖紅橘光帶；Godot 4.7（Mac）匯入 0 錯。圖：`map/preview/pavement-comparison-r7.png`、`ground-seam-y512-3x.png`、`wet-reflection-comparison-r7.png`、`ground-layered-hero90.png`。
  - Claude 看圖：反光方向與位置正確；接縫大致消失，但 `ground-seam-y512-3x.png` 縮圖上仍隱約有一兩處小缺口，下次放大確認後再請使用者定案。
  - B（流氓 3 張候選）**未開始**。續做：叫 Codex 只做 `BRIEF-assets-4.md` 的 B 段，報告接著寫進 `ASSETS-REPORT-5.md` 的 B 段。
  - 2026-10-12 晚：接縫 3 倍圖逐段放大看過，三段一致、灰縫連續，至多一處極小角點錯位，遊戲尺寸看不出來 → **使用者定案（2026-10-12）**，地面 A 段結案。B 已派給 WSL 上的 Codex（Herdr pane `wJ:p12`，WSL 路徑）。
  - **B 完成（DONE）**：`enemies/smoker-gangster/candidate-0{1,2,3}.png`、`candidates-contact.png`、`comparison-old-vs-new.png`；QC 0 警告。三張姿勢幾乎一樣（平頂高漸層、黑背心、金鍊、雙臂刺青、叼菸），差異只在細節。使用者選 **01** → `enemies/smoker-gangster/master/`（approve 0 警告），已接入遊戲。
- **2026-10-12 接入遊戲**（使用者選無限捲動）：`street.tscn` 拿掉幾何街區，改 `Map`（地磚無限重複＋每 1024 px 一格、3×3 格跟著鏡頭、每格 7 個道具、座標 hash 當種子）；bounds 跟主角移動；抽菸者換流氓圖。測試全過，實錄畫面確認。道具沒有碰撞、畫在所有角色下面（之後要擋路或前後遮擋再加）。
- 原始規格（已寫進派工單）：
1. **地面重做**（只做地面，道具保留）。問題：地磚只有 128×128、橘色反光條紋鋪滿、對比太高（敵人與煙霧會看不清）、重複一眼可見、斜菱形鋪磚看不出來、斑馬線糊。要求：
   - 無縫地磚 512 px 以上（遊戲尺寸），低對比、中性暖灰褐，斜菱形鋪磚在遊戲尺寸清楚可辨。
   - 反光從地磚拆出來，做成燈籠附近才放的疊加層（暖色光暈、濕地反光各一）。
   - 斑馬線重做成清楚的疊加層。
   - 重新匯出 Godot、出 3×3 與「地面＋道具＋主角」預覽；`--route codex-cli`。
2. **抽菸者改成台灣流氓**：虛構的成年男性，手臂刺青、抽菸，髮型照 `docs/reference/阿志.png`：兩側與後腦剃到見頭皮的高漸層（high skin fade），頭頂留短、剪成平頂的黑髮。**參考圖是真人照片：只借髮型，臉與身分要虛構，不畫成照片裡的人。** 其餘規格同其他敵人（mob、朝右下、50 度俯視、透明、pixel、`--style-ref` 男主角）。3 張候選。

## 玩法待辦（美術告一段落後改程式）
- [x] 2026-10-12 香改成「戳人」：每 1.1 秒朝身邊最近的敵人各刺一下（射程 130×範圍，0.28 秒刺出收回），沒人在範圍內就等。進化「媽祖遶境」維持常駐繞圈。`playable` 測試涵蓋。
- [x] 2026-10-12 機車衝刺改成 S 型：沿鎖定方向前進、左右擺 45 px、一個波長 190 px，每次衝刺換邊；預警線畫同一條 S。`playable` 測試涵蓋。
- [x] 2026-10-12 地圖改無限捲動（見上）。
- [x] 2026-10-13 男女主角、臭臭胖子、機車／汽車 5 方向、圖示全部接入（`tools/build_art_scenes.gd`）；測試全過、實錄＋預覽圖確認。圖示用在掉落物與六把武器的升級卡；進化／融合／被動卡沒有圖示。拳頭揮擊仍是幾何圓點。機車 n／s 看起來比 se 小（素材本身），沒調。

## 2026-10-13 使用者回饋（9 項）— 2026-10-14 全部做完，待使用者試玩確認
使用者回答：透視問題四種都有（前後遮擋錯、地磚像等角視角、大小比例不對、陰影／腳底沒貼地）；路障要擋主角＋敵人＋投射物。

| # | 回饋 | 預定做法 |
|---|---|---|
| 1 | 血條放英雄上方，扣血要有減少動畫 | `player.tscn` HpBar 移到頭上（約 y −96）；加一條 HpTrail 墊底，主條立刻扣，墊底條延遲 0.25 秒再 tween 下來 |
| 2 | 透視怪 | (a) 主角、敵人、道具放進同一個 y-sort 層（Props 搬出 Map 的 z −10；燈籠光暈／倒影 z_index −9 留在地上）；(b) 地磚重生成非菱形：50° 斜俯視、橫向排列的長方形鋪磚（往上被壓扁），派 Codex（`--route codex-cli`，流程同 `BRIEF-assets-3.md` A 段，3 張候選）；(c) 比例：攤位約 ×1.8、汽車約 ×1.6、機車約 ×1.15、停放機車對齊機車敵人，玩法半徑先不動；(d) 陰影橢圓依各圖寬度調大、貼腳底 |
| 3 | 吸經驗範圍大一點 | `street.tscn` `magnet_radius` 70 → 約 110 |
| 4 | 臭豆腐要用丟的，有投擲動畫 | 從主角拋物線丟到目標點（有高度偏移、旋轉），落地才變成減速扣血區 |
| 5 | 愛的小手像彈簧手 | 手臂往左右彈出、超過再縮回（TRANS_ELASTIC／BACK），判定沿伸出的手臂 |
| 6 | 流氓的煙霧很怪 | `smoke.tscn` 改成幾團半透明柔邊煙（徑向漸層貼圖），慢慢擴散飄散 |
| 7 | 地圖物件太分散；夜市要群聚；要當路障擋路、擋投射物 | 改成每格放一組「夜市群」場景（例：一排攤位＋兩端燈籠＋水果箱、L 形轉角、三角錐＋護柱＋停放機車的路障），可在編輯器調；每個道具場景加 footprint（StaticBody2D 長方形）：主角靠 move_and_slide 被擋，敵人逐幀推出 footprint 並沿邊滑開，飛行投射物撞到就消失（天燈這種從天上砸的不擋） |
| 8 | 顯示傷害數字 | 敵人記 `last_damage`，street 在 impact 時生飄字（上飄淡出，上限約 40 個） |
| 9 | 死亡依溢出傷害分三種 | overkill = 傷害 − 剩餘血量：小（< 0.25×最大血）原地倒下淡出；中（< 1×）往後滑一段再倒；大 → 現在的旋轉彈飛 |

結果（2026-10-14）：九項都做了，場景由 `tools/build_feedback_scenes.gd` 產生；五組測試全過（含新加的死亡三種、傷害數字、路障推出／擋投射物、彈簧手、臭豆腐落地、血條墊底條檢查）；網頁版重建、瀏覽器檢查全過；實錄與預覽圖看過 y-sort、路障群、煙霧、彈簧手、臭豆腐。地磚三張新候選（`map/preview/r8/candidates-contact.png`），遊戲暫用 02，**待使用者選**。夜市群有三種（`scenes/clusters/`：一排攤位、兩排夾走道、三角錐路障），每格 1024 px 80% 機率放一組。中途修了一個洩漏：群聚場景把道具內部 node 也存進去，每次開局多出一批孤兒 node。
另外：上一輪的瀏覽器檢查改寫（`tools/browser_check.mjs`、`game.gd` 的 `?duration=`、TODO／README）還沒 commit。

## 美術待辦
- 2026-10-14 已補齊：拳頭圖、全部 27 個卡片圖示（武器、被動、進化、融合），以及雨傘、飛行中的臭豆腐、機車騎士的像素圖。來源是 `icons/sheets/gen-{a,b,c}/generated.png`（Codex 3×3 綠幕圖示表，提示詞 `prompt-{a,b,c}.txt`，格子對應 `layout.json`），切好的原圖在 `icons/<id>/selected.png`，總覽 `icons/all-contact.png`。哪一格不滿意就只重生那張表、重跑 `tools/slice_icon_sheet.py`。
- 剩下的向量圖形是刻意留的：圈圈套中區、機車預警線、陰影（PokéSurvivor 的光環與預警也是平滑圖形）。

## 暫停中
- 動畫／影片：等靜態圖都定案再做（`heroes/MANUAL-VIDEO.md`、`heroes/man/set/` 保留可續用）。

## 紀錄
- 派工單與報告：第四輪 `BRIEF-assets.md` → `ASSETS-REPORT-1.md`、`-2.md`（圖示總覽 `icons/all-contact.png`）；第五輪 `BRIEF-assets-2.md` → `ASSETS-REPORT-3.md`。
- 第五輪汽車 e 方向第一次重做卡了 3 小時（codex exec 無回應），停掉後重跑一次成功；之後派工單可要求每筆生成設時限。
- 生圖一律 `--route codex-cli`：config 裡的 API key（Gemini、OpenAI 無效；xAI 沒額度；BytePlus、fal 無效）會讓預設路由失敗。BytePlus 有兩筆「送出結果不明」（clientRequestId `6f5394908dc249518ad1f0a9d1aae991` 等），可到後台確認有無扣款。
- Codex 在 Herdr pane `wT:pE`；多數指令要人工核准（建議在 Codex 用 `/approvals` 放寬）。
- 流程說明：skill `character-sprite-forge`（`prototypes/godot-kit/skills/character-sprite-forge/`）。
