# 萬事屋吐槽 ADV · debt-commission：進度與交接

只保留最近 3 次 commit 期間的工作與尚未 commit 的工作（新的在上）；更早的紀錄移到 [MILESTONE.md](MILESTONE.md)。每次 commit、出門／下班／暫停前更新本檔，根目錄 `Progress.md` 只更新一行摘要。接手順序：本檔 → [README](README.md) → [session-state](production/session-state/active.md) → [HANDOFF](docs/HANDOFF.md)。

## 2026-11-14｜試玩回饋：置中、齒輪、按鍵陰影、吐槽字超框（未提交）

- 使用者：方向鈕圖示沒置中、有些按鈕的齒輪擋到字、吐槽選項的 < > 形狀怪（應該用陰影做按壓感）、新八吐槽字有時超出框；其餘驗收 OK。
- **修正**：
  - 齒輪：`gintama_reading_button.gd` 的 `_apply_icon_only` 只在 `icon_only` 開啟時改顯示，不再把其他按鈕（調查「收起／展開」）藏起來的紙框圖（畫有齒輪）打開。
  - 置中：方向鈕與 < > 改用置中的 SVG 箭頭（`assets/ui/gintama_icon_chevron_{left,right,up,down}.svg`），不再用字型字元 `‹›︿﹀`。`tools/make_pan_arrows.gd` 同步。
  - 吐槽字：`comedy_preset.gd` 在爆炸框裡改用橢圓判斷字是否放得下（`OVAL_ROOM` 1.2 倍 TextArea），長句不再壓到尖角；五個漫畫效果的 `Text` 改水平置中。
  - 「聽下去」與相關按鈕（使用者追加）：對話框裡的動作鈕全部改成同一種「按鍵」：低飽和、略透明、無外框，底部一條半透明深色台階（用陰影會從透明的鍵面透出來），按下時台階收掉、鍵面下沉。聽下去／繼續（`InvestigationContinue`）／< > 用淺色 `key_*.tres`；吐槽！（`boke_primary`）與調查話題（新角色 `key_action`）用 `ui_styles.key_style()` 的灰藍按鍵。
  - 和紙按鈕左右內距 18→34（`washi_*.tres` 與 `ui_styles.gd`），字不再貼到圓角（例：「先調查所有位置」）。
- **測試**：`test_ui_styles`（吐槽！是半透明、無外框、有底部台階的按鍵，按下沉下）、`test_landscape_reading`（工具列圖示置中）、`test_orientation`（方向鈕是置中圖示、收起鈕沒有齒輪）、`test_comedy`（字在爆炸框橢圓內且置中）加檢查。結果見下一行。
- **驗證（2026-11-14 實跑，Linux 暫存複本）**：最終樣式完整測試 60/60 PASS（log `/tmp/godot-tests.BqfGx5`）；巡檢 390×844 68 張無超出（最終樣式），844×390 沿用前一版按鍵樣式的巡檢。手機實機未驗證。
- **已知**：鍵面半透明，所以壓在下面的「下一句 ▼」三角形會淡淡透出來（吐槽！右下角）。

## 2026-11-13｜稽核問題全修＋參考圖新功能（未提交，待作者看畫面）

- 使用者：「都修」（`reviews/2026-11-13-uiux-audit.md`），並依 `docs/story-telling-game/ui-ref/` 加：可選方向的捲動 CG、圖示按鈕、轉場後標題動畫、查找線索頁面、已知線索頁面。
- **修正**：
  - P0 設定被目錄蓋住：設定留在 `Game` 底下（點擊順序對），`z_index = 3` 畫在 `PopupLayer`（z 2）之上；toast 與教學遮罩 z +2 才不被設定蓋住。`test_settings` 檢查繪製與點擊順序。
  - P1 字級：`scripts/text_scale.gd`，手機（每 CSS px ≥ 約 2.6 設計像素）小於 44 的字 ×1.25，桌機不變；對話正文 = 字級設定 × 同一倍數；`metadata/fixed_font_size` 可排除。在 `_ui_scale` 之前算（對話框寬度跟字有關）。headless 的 64×64 假視窗與原生 Android／iOS 另外處理。實測直式手機正文 13→16.3 px、最小字 9.4→12 px。
  - P1 cut-in 殘留：選項出現時 `StageEffects.clear_overlays()`。P1 調查：見下方「查找線索」。
  - P2：作答時 HUD 不再重複倒數（目錄蓋住時仍顯示「暫停」）；目錄三列改和紙列，右側只有開面板的列用「›」；卷宗分頁用 tab 樣式（選中與否看得出）、分頁與關閉鈕 133；存檔卡內距加大、空存檔隱藏預覽位；標題「章節選擇」入口 27→36；章節選擇右上三鈕最小寬 133、列表字 30→34；對話紀錄加空狀態、紀錄與存讀檔的「關閉」改 × 方鈕；捲軸 14 px（主題）。行長過長在手機上隨字級放大解決。
- **新功能**：
  - 標題橫幅 `scenes/ui/title_banner.tscn`（`tools/make_title_banner.gd` 產生一次）：`bg` 的 `title`、調查第一次開始的「開始尋找線索」。不擋點擊、不拖住下一句、略讀不播。
  - 捲動 CG：`bg` 的 `scroll`（down/up/left/right）＋`scroll_seconds`，`stage_motion.gd` `scroll()`／`end_scroll()`；驗證規則已加。功能展示加兩個示範（version 改為 `s-b9224ad13c5d`，舊的功能展示存檔會封存）。
  - 查找線索：`scenes/ui/pan_arrows.tscn`（`tools/make_pan_arrows.gd`）邊緣方向鈕，只顯示還能拖的方向，點一下滑一段；矮螢幕（CSS 高 < 480）一進調查就收成細列，細列帶提示文字；教學第二步收起時改指「展開」。
  - 已知線索：卷宗改成直長卡片一列（`CardStrip`），未取得的是暗色空卡＋羅馬數字；`StoryRunner.case_file()` 加 `material_total`／`profile_total`。
  - 圖示按鈕：`gintama_reading_button.gd` 的 `icon_only`；工具列四鈕只顯示置中 SVG 圖示（隱藏有字位的紙框圖），名稱留在 tooltip。
- **驗證（本次實跑，Linux 暫存複本）**：受影響測試逐組通過（settings、orientation〔新增手機字級、方向鈕〕、landscape_reading〔改驗圖示按鈕〕、phase3_ui、phase4_ui〔卷宗卡片〕、reading_convenience、vn_shell、investigation、search_cast、scene_transition、reading_scenes、ui_styles、skin、reading_feel 等）。完整測試結果見下一行。巡檢 390×844 與 844×390 各 68 張無超出、44 px 以下按鈕 0 個；截圖 `test-results/ui-ref/`、橫幅與捲動逐格截圖驗過。
- **未做／待決定**：直式長圖（往下捲最適合）需要 AI 生圖，依規則等作者決定要直接生成還是給 opt image 提示詞；手機實機、網頁匯出未驗證。
- **完整測試**：`bash ../godot-kit/tools/run_tests.sh <Linux 複本>` 60/60 PASS（2026-11-13 本次最終程式碼實跑，log `/tmp/godot-tests.9CSZoH`）。

## 2026-11-13｜UI／UX 稽核（只有報告與工具，未提交）

- 使用者：「再對不同元件做一次 uiux audit」。報告：[reviews/2026-11-13-uiux-audit.md](reviews/2026-11-13-uiux-audit.md)，證據截圖與量測 log 在 `test-results/uiux-audit/`（gitignore）。
- 工具：`tools/screen_audit.gd` 加 `AUDIT_METRICS=1`（逐畫面印出按鈕／文字的 CSS px 與字級）；設定改成從目錄的「設定」列打開、流程圖從章節選擇打開並正常關閉（原本那兩張截圖拍錯畫面）。
- 主要發現：P0 從目錄開設定時被目錄蓋住（`PopupLayer` z_index 2，設定面板 z 0）；P1 手機字級偏小（正文 13 px、HUD 9.7 px）、橫式手機調查面板蓋滿畫面、直式調查沒有拖曳提示、cut-in 殘留在選項上；P2 共 9 項（倒數重複、目錄停用樣式、卷宗分頁、存檔卡編號等）。
- **沒有修任何問題**，等作者決定順序。驗證：巡檢在 390×844 與 844×390 全程跑完（68 張）；設定與流程圖在兩種尺寸另跑一次（17 張）。

## 2026-11-13｜吐槽按鈕、角色熱區 node、結局卷軸（未提交，待作者看畫面）

- 使用者：「吐槽按鈕太醜，做得像一般按鈕」；「調查銀時的嘴角時，看不到哪邊可以設定 node 讓圖上的哪個部分可以被點」；「結束時先畫面全暗、顯示結算卷軸，點了之後才顯示重玩、回標題」。
- **已完成**：
  - 「吐槽！」：`ui_styles.gd` 的 `boke_primary` 改用深藍框（和「開始故事」同一套），`dialogue_box_gintama.tscn` 的 `BokeTsukkomi` 樣式同步；`btn_tsukkomi_*.png` 不再使用（檔案保留）。
  - 角色熱區 node：角色 scene 的 `Art/Spots/<名稱>`（ReferenceRect，只在編輯器畫框），劇本熱區寫 `"spot": "<名稱>"`；`placeholder_sprite.gd` `spot_rect()`、`main_investigation.gd` 依它擺熱區、`story_validator.gd` 確認 scene 有這個 node、不可同時寫 `art_region`。`gintoki.tscn` 加了 `Spots/mouth`（原 art_region 的位置）；功能展示改用 `spot`（version 不變），說明台詞指出 node 在哪。`art_region` 仍支援（第一章夾具還在用）。
  - 結局：`end`（非 Game Over）與 `result` 共用 `chapter_result_gintama.tscn`——`Dim` 全黑淡入 0.6 秒 → 卷軸由中間展開 0.45 秒 → 「點一下繼續」緩慢明滅 → 點一下（任何點擊／觸控／確認鍵）後「下一章／重玩／回標題」淡入。`end` 的卷軸只有文字、結局名稱、製作名單。新增 `Restart` 按鈕與 `TapHint`；根節點 `dim_in`／`unroll`／`buttons_in` 可調；畫面效果「減少」不播動畫但仍等那一下。`end_controls.tscn` 刪除（工作樹刪除，未動 index），`_end_box` 移除，`_restart_button`／`_end_title_button` 指向卷軸的按鈕；按鈕出現時發 QA 狀態；`tools/browser_check.mjs` 在結局畫面先點一下再按按鈕。`test_reading_scenes` 不再檢查 end_controls（原本的既有失敗因此消失）。
- **驗證（本次實跑，Linux 暫存複本）**：新測試 `test_portrait_spots`（驗證規則、熱區＝scene 的框、移動框熱區跟著移）、`test_ending_scroll`（end：漸暗→全暗、按鈕先隱藏且不能按、點一下才出現、重玩重新開始；result：數據與評價、減少動畫時立即出現仍等點擊、回標題）。`run_tests.sh` ending_scroll chapter_flow ep00 reading_scenes ui_styles phase4_rounds_ui phase3_ui phase4_ui showcase story_packs katsura_dog_ears save_slots choices comedy portrait_spots search_cast investigation 全 PASS（`reading_scenes` 現在也過）。巡檢截圖：結局橫式（end）、直式（result）、吐槽按鈕兩種方向，存在 `test-results/ending/`。
- **未驗證**：`browser_check.mjs` 的修改沒在瀏覽器跑過。

## 2026-11-12｜換背景轉場重做：墨暈、故障、筆刷（未提交，待作者看畫面）

- 使用者：「墨水跟 glitch 太簡陋，請優化，讓轉場更專業」。
- **已完成**（`shaders/scene_transition.gdshader` 重寫，`scripts/stage_motion.gd` 秒數與節奏）：
  - shader 用 `hint_screen_texture` 讀殘影底下的新背景，新舊畫面都參與；圖案改用螢幕座標，直式橫式掃得一樣（舊版在直式下筆刷掃不滿）；每次轉場隨機 `seed`。拿掉沒用到的 `aspect` 參數。
  - 墨暈 1.3 秒（原 0.8）：五滴墨依序落下各自暈開（扭曲的不規則邊、毛細暈開、前緣積墨、濃淡灰階），蓋滿後停一拍，再從另一組墨滴退開；新畫面先灰暗濕潤再回色，留一點殘墨。墨滴大小依畫面對角線縮放。
  - 故障 0.75 秒（原 0.5）、等速：以 22 格跳格；不等高橫條錯位、RGB 分離、方塊位移、垂直跳動、掃描線、雜訊條，少量壓色／反色／染色塊；新舊畫面逐塊交換。修掉 `pow(sin(PI))` 得到 NaN 讓最後一格全黑。
  - 筆刷 0.7 秒不變：一道實心墨帶（刷毛濃淡），尾端飛白露出新畫面，前方少量墨點；取代原本像金屬尖刺的漸層邊。
  - 功能展示「畫面・背景轉場」三句說明改寫（只改文字，version 不變）；IMPLEMENTATION.md、README 更新。
- **驗證（本次實跑，Linux 暫存複本）**：xvfb（Compatibility 渲染器，與網頁版同一套）逐進度 0／15／30／45／60／72／85／100% 截圖，直式與橫式，無 shader 錯誤，0% 與舊畫面相同、100% 與新畫面相同；總覽在 `test-results/transitions/`。`run_tests.sh` scene_transition showcase reading_feel game_feel orientation 全 PASS；`check_story.gd` OK。
- **未驗證**：實際播放的動態觀感（截圖只看定格）、網頁匯出版與手機上的效能（墨暈每像素約 15 次 noise）。
- **可以再加**：轉場音效（catalog 目前沒有刷筆／墨滴／雜訊音）。

## 2026-11-12｜直式／橫式可切換＋功能展示補齊進階玩法（未提交，待作者看畫面）

- 專案／分支：debt-commission／master。使用者要求：寫故事或 build 前能選直式或橫式，元件與 node 兩種都支援，並用一篇 demo 展示所有功能。
- **已完成**：
  - 故事設定 `orientation`（劇本 JSON 根層，`"portrait"`／預設橫式）；`data/stories.json` 一列也可寫 `orientation`＋`title`。新增 `showcase_portrait`「功能展示（直式）」，與橫式共用同一份劇本、各自存檔。不影響 `version`。
  - `main.gd` `_apply_orientation()`：載入／切換故事時換 `content_scale_size`（1920×1080 ↔ 1080×1920），桌機視窗跟著轉，Android／iOS 呼叫 `screen_set_orientation`。`_story_choice_index()` 先比 path＋save（同劇本兩列）。`_ui_scale()` 直式以 390 CSS px 為基準，並以對話框最小寬封頂（原本窄螢幕 ×1.15 會讓 972 寬的框撐出 1080 畫面）。冷啟動（網頁 `?sample=showcase_portrait`、桌機記住直式故事）時 UI 還沒建，不排版，靠 `node_added` 套 metadata。桌機視窗轉直時縮到螢幕放得下（實測 1080p 螢幕 577×1026）。
  - `scripts/orientation_layout.gd`：node 的 `metadata/portrait_layout` 是直式屬性，直式時套用、橫式還原；`node_added` 讓執行時才實例化的 scene 也套到。已寫入 metadata（`tools/add_portrait_layouts.gd`，Godot 存檔）：`stage.tscn` 三個站位、標題 `CardArea`、`round_hud.tscn` 根、`tsukkomi_impact(_right).tscn` 的 `CutInPanel`／`Burst`。其他面板靠 Container／比例 anchor 兩邊共用。重存時 Godot 去掉了與子 scene 預設值相同的覆寫（已逐項確認相同）。
  - 功能展示加「進階：話題、證言、連擊與導演」一段（目錄第 4 項，共 44 個節點、3 個結局，`check_story.gd --write` 後 version `s-448840e52b56`；舊的 showcase 存檔會被封存）：調查的 keep_cast／角色熱區／對話／移動、證言回合（listen、whiff、消音條、牌子）、連擊回合（combo_timers、bonus、break、super、QTE）、導演選擇、章節結算 result（導演選第三張「收工」）。
  - 故事編輯器「故事」區加「畫面方向」下拉。
  - `tools/screen_audit.gd`：真實外殼把故事從頭玩到尾，每個新畫面存一張圖，回報超出畫面的標題按鈕／HUD／工具列。
  - 順手修：D1 搬常數後，編輯器 `loadProject()` 與 `test_core.mjs` 還在從 `story_runner.gd` 讀 `VALID_OPS` 等清單（測試報 null、編輯器退回內建清單），改讀 `story_validator.gd`。
- **驗證（本次實跑，Linux 暫存複本 `rsync`，Godot 4.7）**：
  - `run_tests.sh` 22 組：build_packs chapter_flow choices comedy ep00 flowchart game_feel orientation phase4_rounds_ui phase4_ui portrait_reaction save_slots search_cast settings showcase skin stage_scene story_packs ui_styles landscape_reading phase3_ui investigation，全 PASS。`reading_scenes` 仍是改動前就有的 `end_controls.tscn` 失敗，沒有修。
  - 新測試 `test_orientation`：直式畫布 1080×1920、標題按鈕／HUD／對話框在畫面內、三站位分開、切回橫式還原 scene 的值、故事自己的 `orientation` 也生效、非法值被拒、直式冷啟動、直式調查拖到邊後空瓶在畫面內且點得到。`test_showcase` 加進階與結算兩條路線（runner 層）。最後一次 main.gd 修改後重跑 12 組（orientation showcase landscape_reading phase3_ui chapter_flow story_packs save_slots flowchart choices phase4_rounds_ui comedy settings）全 PASS。
  - `tools/story_editor`：`test_core.mjs` ALL PASSED（50 項）、`test_node_types`／`test_step_insert`／`test_portrait_controls` 通過。
  - `screen_audit.gd`：直式 540×960 與 320×568 各 66 張、橫式 960×540 66 張，無超出畫面；另跑直式結算卡、Game Over（五次冷場）、開著第一次教學各一輪，畫面正常。總覽圖在 `test-results/orientation/`（gitignore）。橫式畫面與改動前一致。
  - **未驗證**：完整測試（L3，待作者手動驗收後跑）、Web 匯出版、Android／iOS 原生轉向、真人手機試玩；編輯器裡的新下拉只有語法檢查與 test_core，沒在瀏覽器點過。
- **已知限制**：直式背景沿用 16:9 圖 cover 裁切（調查可左右拖）；直式三人同台時伊莉莎白的牌子會壓到右邊的人；`.dialogue`（Parley）來源還不能設方向；編輯器的舞台預覽仍是橫式。
- **下一步**：作者看 `test-results/orientation/` 總覽圖或 `?sample=showcase_portrait` 試玩直式，調整 `stage.tscn` 站位與其他 metadata；驗收後跑完整測試再提交。
- **工作區**：以上全部未提交；`art_src/` 的大量 PNG 修改不是本次工作，保持原狀。

## 2026-11-12｜程式結構改善 D1–D7（未提交）

- 專案／分支：debt-commission／master。使用者要求「照著分析文件，先把 debt-commission 做完再做 walker-tps」。依據 [docs/CODE-IMPROVEMENTS.md](docs/CODE-IMPROVEMENTS.md)；實作時與原方案不同的地方，以該文件開頭的「實作結果」表為準。
- **基準（改動前）**：在 Linux 暫存複本跑完整 `run_tests.sh`，`XDG_DATA_HOME` 指到暫存區（不碰真實存檔）。結果 56/57 PASS；`reading_scenes` 原本就失敗：`authored res://scenes/ui/end_controls.tscn has its expected nodes before packing`，應是 11-11 介面素材接入後 scene 與測試期待不一致。本次沒有修它，也不算本次退化。
- **已完成**：
  - D4：48 處字串呼叫改成具型別。
  - D5：`enum Screen` 加 `_screen_mode` 字串轉接屬性，新增 `_hide_story_parts()`。
  - D6：69 個跨檔函式去底線；回合倒數與 QA 計時搬進 `main_round.gd`／`main_qa.gd` 的 `process()`。
  - D1：新增 `scripts/story_validator.gd`，runner 從 2875 行降到約 1730 行。
  - D2：四個大分支各自成為函式，`_validate_step` 從約 350 行降到約 180 行。
  - D7：`tools/bot_players.gd` 加 `slow`／`hesitant` 策略與 `--think`／`--assist`。
- **延後**：D3 op 登記表。原方案自己的條件「新增 op 前」沒有成立。
- **連帶修改**：`tests/test_character_height.gd`、`tools/story_editor/check_catalog.gd` 原本直接呼叫被搬走的私有驗證函式，改用 `StoryValidator`。`tools/story_build/dm_source.gd` 改從 validator 讀常數。`tests/test_phase4_ui.gd` 一處改名。`tools/story_editor/story_core.js` 一行註解。
- **驗證（本次實跑，Linux 暫存複本，Godot 4.7）**：
  - 每一步跑完整 `bash ../godot-kit/tools/run_tests.sh <複本>`：D4 56/57；D5 第一步＋D1 55/57，`character_height` 因上述私有呼叫失敗，修正後恢復；D6＋D5 第二步＋D2 56/57；最後一輪見下一點。
  - 每輪除 `reading_scenes` 外全過，log 裡沒有 `unknown screen mode`。ERROR／WARNING 的種類與基準相同，只有結束時資源洩漏的次數會浮動。
  - 機器人：`godot --headless --path . --script res://tools/bot_players.gd -- --runs 300`，原始碼與 D1、D2 之後的輸出逐字相同（只差 MCP 路徑那行）；D7 之後原有五行仍逐字相同。
  - 新策略 300 局：`slow`（5 秒）全 A、每局冷場 1；`--think 6 --assist` 全 S；`hesitant` S 6／A 23／B 98／C 128、放棄 45。
  - 沒有測試涵蓋的工具：所有引用 runner 的 `tools/*.gd` 都跑過 `--check-only` 解析（故意放錯確認抓得到）；`check_catalog.gd` 好壞兩份 catalog 各實跑一次，結果分別是 OK 與正確拒絕。
- **最後一輪完整測試（全部改動，含 D6 狀態搬移）**：56/57，只有 `reading_scenes` 失敗（與基準相同），304 秒；沒有 `unknown screen mode`；ERROR／WARNING 種類與基準相同，另多一條「`story_validator.gd` 缺 `.uid`」，已從匯入後的複本補回 `scripts/story_validator.gd.uid`。
- **未驗證**：Web 匯出、瀏覽器檢查（`browser_check.mjs`）、手機。D5 改了畫面狀態的型別，`window.__debtQA` 對外字串不變，但沒有用瀏覽器實跑。
- **工作區**：上述檔案與本檔未提交，未 push；其他 session 的修改未觸碰。

## 2026-11-11｜選定介面素材接入（未提交，待作者看畫面）

- **出門交接**：本輪停在 21 張選圖接入完成。獨立驗收 PASS（21/21 雜湊一致、未發現可重現缺陷），原報告在 `/private/tmp/debt-ui-verification/INDEPENDENT-REVIEW.md`。下一台先讀本段，再在 Godot 查看新版畫面；尚未做視覺／手機驗收或 Web 重匯。沙箱 `.git` 唯讀，無法代為 commit，未 push。提交範圍為本次 debt-commission 素材、介面、測試與交接文件及根目錄 Progress.md；工作區另有其他 session 的制度／skills 修改，請勿混入。`.claude/tasks/debt-ui-assets/REPORT.md` 被 gitignore，主要交接資訊已記在本檔。

- 專案／分支：debt-commission／master，接手基準 `6333a892`。作者將 21 張選圖放進 `art_src/ui/gen-20261110/pick/`；沿用先前直接生圖的同意，將選定的標題 A 修成「糖事屋」與「糖」印章，App 圖示 A、開機圖 B 也為「糖」字版。原圖、修訂輸出與提示詞保留在原素材目錄。
- 完成：21 張圖複製到 `assets/ui/selected/`（對照及雜湊見 `SOURCE.md`）；深藍／和紙按鈕、分頁與吐槽三態接入 scene 與 `ui_styles.gd`，保留閱讀列專用圖；標題圖、評價印章、未解鎖封條、結局卷軸及碎眼鏡接入現有 scene。`project.godot` 指定開機圖與圖示，Web 匯出排除 `art_src/`。場景由 Godot pack／save，核對節點數與子場景實例；可調整節點見 README。
- 驗證：Godot `--headless --editor --recovery-mode --quit` 匯入 exit 0，無場景／腳本解析錯誤；沙箱仍拒絕系統憑證與編輯器設定寫入，退出有資源清理訊息。為避免碰真實存檔，在 `/private/tmp/debt-ui-verification/project` 複本把 `user://` 轉到副本的 `res://.test-user/`，停用 MCP autoload／編輯器外掛，逐一執行 `Godot --headless --path <副本> --script res://tests/test_<名稱>.gd`：`ui_styles`、`gallery`、`skin`、`settings`、`chapter_flow`、`phase4_rounds_ui` 均 PASS；後續版面／結局調整後重跑 `ui_styles`、`gallery`、`chapter_flow` PASS。`gallery` 的壞檔測試預期會輸出 ConfigFile parse error；`skin` 退出有資源清理訊息。
- 另外在副本驗證 UI 間距存檔後執行仍保留、執行時狀態不寫回 scene；1920×1080 headless 版面座標檢查涵蓋標題、結算、Game Over、鑑賞、結局及吐槽。42 張候選的四角 alpha 與外緣綠邊重掃通過；App 圖示 48 px 預覽可辨，筆畫較細。完整測試、Web 匯出與手機未重跑。
- 限制／下一步：沙箱啟動 Godot 視窗 exit 134，無法擷取新版實際畫面；請作者在編輯器及遊戲中看標題、按鈕、結算等版面。作者選定的吐槽按下 A 中央有模糊紋，停用 B 仍偏紅，實際手感與辨識待確認。原有 `pick/` 移動及本次素材、scene、腳本和文件均未提交；未 push。

## 2026-11-10｜介面素材盤點、展示頁、第一批介面候選圖（候選圖與 TODO 已在 `b944de53`，等作者挑圖）

- 專案／分支：debt-commission／master。使用者要求：檢視介面（不含故事）缺什麼素材、做功能展示頁；接著用 Herdr 開 Codex（GPT-6 Luna max）產生圖片，並把需要的音效列進 TODO。使用者 17:52 自行提交 `b944de53`（TODO 音效清單＋42 張候選圖與提示詞）。現在暫停，**作者回家挑圖**。
- **盤點與展示頁**：寫臨時巡覽腳本，開視窗跑 Godot 4.7（1280×720），自動走完整段功能展示：四段、調查、5 次冷場到 Game Over、重試後完美吐槽、結局；標題覆蓋頁、目錄、存讀檔、覆寫確認、案件檔、QTE、結算則直接呼叫開啟。挑 28 張截圖做成展示頁：每個畫面標出正式圖／純色樣式／程式繪製／合成音／缺，附規格；另有音效表、「故事側但介面會顯示」（8 個線索沒圖）與「上架前要換」（萃取 UI 圖、原聲帶 BGM 授權未明）。頁面：<https://claude.ai/artifact/5PWktqSHkHipZ7YKbFxQpa>（私人）；本機檔在 `build/ui_assets_page/`（gitignore，未提交）。巡覽腳本放在 job 暫存資料夾，會被清掉；要重拍得另存成 `tools/shots_ui_tour.gd`。
- **主要缺口**：(1) 通用按鈕只有閱讀列 LOG／AUTO／SKIP／MENU 有圖，其他十幾個畫面的按鈕是 `ui_styles.gd` 的 StyleBoxFlat 平塗；現有 `gintama_extracted_menu.png` 只有 195×62、齒輪烤在圖上，不能當通用 9-slice。(2) 19 個 catalog 音效全是 `stage_effects.gd` 合成，`tsukkomi_weak` 沒登記 catalog，介面點擊／開關面板／翻頁完全沒聲音。(3) 標題是文字、`project.godot` 沒設 `boot_splash`（Web 開啟會先顯示 Godot 預設圖）。(4) 結算評價是文字「【C】」。(5) 結局只有兩顆按鈕、鑑賞未解鎖格是深藍方塊。
- **TODO**：新增「音效待辦（2026-11-10 盤點）」勾選列表 33 項，分優先、玩法系統、超必殺、介面音（要新增 `ui_click` 等 5 個 id 並接程式）、劇情、系統 BGM、選用。
- **候選圖**：派工單 `.claude/tasks/debt-ui-assets/BRIEF.md`，Herdr pane `wT:pZ`（名稱 `uiart`，Codex `gpt-6-luna`、`model_reasoning_effort=max`、workspace-write）。報告 `.claude/tasks/debt-ui-assets/REPORT.md`（`STATUS: DONE`）。產出在 `art_src/ui/gen-20261110/`：11 項拆成 21 個檔名 × A／B＝42 張、`raw/` 52 張、`PROMPTS.md`、`contact_sheet.png`、8 張 `ninepatch_check_*.png`（按鈕邊距 48 px，分頁標籤下邊 8 px）。項目：深藍／和紙按鈕各三態、分頁標籤兩態、「吐槽！」按鈕三態、標題題字、開機畫面、App 圖示、S／A／B／C 印章、結局卷軸卡、鑑賞封條卡、Game Over 碎眼鏡。Codex 開工時週額度剩 16%。
- **驗證（本次實跑）**：自己用 PIL 重掃 42 張：尺寸全符合；透明圖四角 alpha 皆 0、開機畫面不透明；沒有綠色去背殘邊。看過總覽圖與深藍按鈕的 9-slice 拉伸圖，四角與銀框不變形。截圖前備份 `~/Library/Application Support/debt-commission` 到 `~/.claude/backups/2026-11-10-debt-commission-userdata`；跑完 `diff -rq` 只多了 `ui_tour*` 暫存檔，已刪除，真實存檔沒動。沒跑遊戲測試（沒改程式）。
- **已知問題**：`btn_tsukkomi_pressed_A` 中央有模糊污點；`btn_tsukkomi_disabled_A／B` 仍是紅色，不像停用，要重做；深藍按鈕比遊戲現在的深藍更暗，接上後要並排確認。功能展示「立牌」那句畫面上沒出現牌子，原因未查。巡覽沒拍到消音條、伊莉莎白的牌子、連擊、吐槽之力全滿氣焰、調查的對話／移動話題、「聽下去」（在 `phase4_rounds` 夾具）；沒在手機實機看。
- **建議選擇（作者決定）**：深藍按鈕 B、和紙按鈕 A、分頁 A、「吐槽！」一般 B／按下 B（停用重做）、標題 B、開機畫面 A、App 圖示 B、印章 A 組、結局卡 B、未解鎖卡 A、碎眼鏡 B。
- **下一步**：作者挑好 → 把選中的圖放進 `assets/ui/` 並登記授權；`ui_styles.gd` 的按鈕改成 StyleBoxTexture（邊距 48）；標題、結算印章、結局卡、鑑賞未解鎖卡、Game Over 換新圖；`project.godot` 設 `boot_splash` 與 icon；重拍截圖對照；改 `.tscn` 後 headless 匯入檢查，再跑受影響測試（L2）。「吐槽！」停用態可派給還開著的 `uiart` pane 重做。音效照 TODO 清單另外準備。
- 未提交：本檔、`MILESTONE.md`（11-08 以前的段落原文移過去）、根目錄 `Progress.md`。

## 2026-11-09｜依評審建議改善 #1、#3、#5、#6、#7（`18e03b97`）

- 專案／分支：debt-commission／master（HEAD `996c51d5`）。使用者要求「根據昨天 commit 的 PROGRESS 跟 TODO 改善」。只做不需要作者決定、不需要真人或實機的項目。測試前把真實存檔資料夾 `~/Library/Application Support/debt-commission` 備份到 `~/.claude/backups/2026-11-09-debt-commission-userdata`。
- **#5 perfect 有價值**：`StoryRunner.grade_for` 多兩個參數（perfect、caught）：剩 5 副眼鏡也要抓到的槽點至少 60%（`S_PERFECT_RATIO`）是 PERFECT 才給 S，否則 A；Game Over 降級照舊疊加。`test_chapter1` 的 weak 路線改期望 A，`test_chapter_flow` 加 5 組評價樣本。README 結算說明同步。
- **#3 機器人玩家**：`tools/bot_players.gd`（只用 StoryRunner，不進出貨；`tools/*` 已在匯出排除）。五種策略：idle、random（不重複選錯）、repeat（會重複選錯）、weak（全選普通吐槽）、know（知道答案）。第一章夾具各 1000 局（約 50 秒）：idle 1000 局卡在第一回合（證言回合不按就不前進）；random 放棄 895（3 次 Game Over 後）、B 11、C 94，每局冷場 13.71；repeat 放棄 935、B 4、C 61，冷場 15.01；weak 1000 局 A；know 1000 局 S。隨便選幾乎都撐不完，主因是沒槽點的句子按吐槽也扣眼鏡——難度要不要放寬給作者看。
- **#6 回饋空格**：(a) 調查點到空處 toast「這裡沒什麼特別的」，連續 3 次改成「提示：還有 N 個地方沒查過」（`main_investigation.gd`）；(b) 普通吐槽有自己的音效 `tsukkomi_weak`（合成佔位）＋短震動；(c) 冷場 toast 帶原因：時間到／這個選項不對／這句沒有槽點／時機沒抓到（runner 的回合結果多回傳 `action`，`main_round.gd` 的 `MISS_CAUSE`）；(d) `data/tutorials.json` 新增「reading」教學（長按隱藏介面、往上滑看紀錄），第一次不快轉讀到台詞時出現，快轉時不打斷。新增斷言在 `test_phase4_ui`、`test_phase4_rounds_ui`、`test_game_feel`、`test_tutorial`。
- **#7 過時文件**：桂短篇 README 與草稿的 QTE 參數改成現在的三選一；README 範例 `?story=chapter1` → `katsura_dog_ears`；README「驗證」的 30 條 XDG 指令換成 `run_tests.sh`（含 macOS 的 GODOT_BIN、依序跑）、bot 指令與 L1／L2 對照；`docs/story-telling-game/ROADMAP.md`、`design/game-brief.md` 的 9:16 直式改 16:9 橫向；`ROADMAP-COMMERCIAL.md` C4；`TODO.md` 的 `?sample=transitions`；`docs/VERIFICATION.md` 標過時。
- **#1 玩法假設**：README 新增「要驗證的玩法假設（草稿，待作者確認）」：假設、機器人與真人的通過條件、結論待填；`project.yaml` 的 `stage` 改 Pre-Production（Studio 的階段名稱沒有 Prototype）。
- 驗證（本次實跑）：先跑受影響的幾組（chapter_flow、chapter1、game_feel、phase4_rounds_ui、phase3_ui、phase4_ui、tutorial）全過；完整 `GODOT_BIN=… bash ../godot-kit/tools/run_tests.sh .` 57/57 PASS（macOS，Godot 4.7）。跑完發現 `test_save_transfer` 動到真實資料夾裡桂短篇存檔的備份（`.bak` 改名成 `.before_import`，存檔內容與備份相同）：已從備份還原 `.bak`，兩個 `.before_import` 移到備份資料夾的 `_moved_after_tests/`；這是既有測試的問題，沒修，記進 `prototypes/LESSONS.md`。匯入時 Parley 外掛往 `project.godot` 加了兩個 `.ds` 翻譯檔，非本次改動，已還原。
- 延後：#2 把第一章放回正式內容（與 11-08「只留 dog ear」的指示衝突，待使用者決定）、#4 真人試玩、#8 選錯的思考成本、#9 重匯 Web、#10 實機 QTE、#11 桂短篇收尾、#12 效能預算。
- 未提交：上述程式、測試、`tools/bot_players.gd`（含 `.gd.uid`）、`data/tutorials.json`、文件、本檔與 `TODO.md`；連同上一段的 `reviews/`。

## 2026-11-09｜game-critic 評審（只有文件，`996c51d5`）

- 做了什麼：用新 skill `game-critic`（`prototypes/godot-kit/skills/game-critic/`）評審本原型，Herdr Sonnet 子 agent 執行，報告 [reviews/2026-11-09-game-critic.md](reviews/2026-11-09-game-critic.md)（385 行）。
- 總評：引擎與工具鏈紮實，但玩家玩不到完整的「調查→吐槽」loop。分數：心流 4、隨機 6、Loop 3、回饋 6、八角 5、前期驗證 4、設計文件 5、QA 6。
- 最大的三個問題：(1) 正式內容只有功能展示和 5 句台詞的桂短篇，第一章只在 `tests/fixtures/`；(2) 全選 weak 也拿 S（`tests/test_chapter1.gd:93`），高手和亂點差別小；(3) 沒有任何真人試玩紀錄，`project.yaml` 卻標 `stage: Production`。
- 測試（子 agent 本次實跑）：`project.yaml` 的 `commands.test`，57/57 headless 通過。
- 待辦：12 條建議已列進 `TODO.md` 最上方「評審建議」。
- 驗證：子 agent 在 Linux 暫存複本或暫存資料夾跑測試，沒有寫入工作樹；主 session 抽查報告引用的 `file:line` 與原始碼一致，並確認 `git status` 只多了 `reviews/`。
- 未提交：`reviews/`（報告與 `.done` 完成標記）、本檔、`TODO.md`。建議都還沒動手改，等使用者決定先做哪幾條。
