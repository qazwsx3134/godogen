# Kit 第三批實作研究：檢查工具與 VFX（2026-11-06）

承接 [第二批](KIT-RESEARCH-02.md)，讀完剩餘 26 項的實作邊界。25 支全文，VFX Library 為載入結構／全部兩個查詢方法與 metadata 選讀。未重審全部效果資源或原型；不新增 runtime 測試。

## 逐項結果

下列限制亦已回填正式 `catalog/specs.json`，讓 AI 的 list/show 查詢取得相同結論。

| 能力 | 實作限制與組合判斷 |
|---|---|
| [font_check](../addons/proto_kit/font_check.gd) | 來源文字檢查，不是字型渲染驗收。只收 code point>0x7E（排除 BOM），含註解與非玩家文字；不驗 ASCII、字形組合、動態下載文字。預設略過 addons/art_src/tests/tools/build/docs 等及隱藏目錄，不辨識 .gdignore；extensions 大小寫須符合。missing_report 回字元→第一個來源路徑；缺檔／目錄讀取失敗未形成獨立錯誤，空結果不保證掃描成功。傳入 Font 的 fallback 可能影響 has_char 結果；應使用實際隨遊戲交付的字型配置。 |
| [screenshot](../addons/proto_kit/screenshot.gd) | 需要 renderer；headless 或空影像回空字串。save 立即讀目前 Viewport，不自行等待 frame_post_draw；宿主先等待正確畫面。out_dir 取第一個使用者參數；檔名 widthxheight_label.png，重複呼叫同 label 可覆寫。label 沒有檔名清理，不接任意不可信路徑；mkdir/save 失敗只以空字串與 push_error 表達。 |
| [sprite_check](../addons/proto_kit/sprite_check.gd) | 唯讀像素診斷而非視覺品質保證。格子按 atlas 尺寸÷columns/rows，要求正整數 grid；並非完整 schema validator。bbox 用 alpha>0，feet 用 alpha>0.5，只有淡像素視為 empty；腳底容許差2px。動畫格序沿用 Sheet.resolve/cell fallback，鏡像相同格列去重。輸出 level/anim/dir/frame/cell/text，未提供穩定 diagnostic code；error/warn 不代表人物動作自然或材質正確。 |
| [synth](../addons/proto_kit/synth.gd) | 同步生成 22050Hz、16-bit mono PCM，耗時與記憶體隨秒數／音符數線性增加；不要每個 hit 重建。click 使用新 RNG 固定 seed，不耗玩法 RNG。duration/note_dur、頻率、curve 等未驗有限與合理範圍，呼叫端須限制；to_stream 假設 bytes 已是相符 PCM 格式，不檢查長度。回新 AudioStreamWAV，不寫檔、不播放；平台聽感未在本輪驗證。 |
| [test_kit](../addons/proto_kit/test_kit.gd) | 僅 SceneTree 測試 runner，不能掛遊戲 Node。註冊全域 Logger 並在 _finish 移除；收集 SCRIPT ERROR，其他錯誤與啟動前 parse error 需外層 runner 判斷。_until 使用 wall-clock timeout，等待 process_frame；不是整個程序 watchdog。_finish 在零 checks 且無錯時也會 PASS。_tap/_drag 是滑鼠事件，非多點觸控；_press 經 Input。這是工具研究，未新增或執行測試。 |
| [ui.ui_theme](../addons/proto_kit/ui/ui_theme.gd) | 由固定 ui_styles.json 建立新 Theme；tokens 每次讀檔，不驗 JSON schema。unknown style 回 null，缺欄位可能直接報錯。使用 SystemFont 與系統 CJK fallback，不保證 Web 字型存在；應由消費者換成隨包字型。屬無材質圖的 UI 配方，不替代 debt-commission 已驗收和紙 PNG 介面。 |
| [vfx.2d.sheet_effect](../addons/proto_kit/vfx/2d/sheet_effect.gd) | AnimatedSprite2D 保存場景的播放器。ready 時在動畫存在且非空才自動播放；無效動畫不回結構化錯誤。非 loop 完成先 emit finished 再按 free_on_finish queue_free，回池必須預先設 false；loop 由 owner 停止／釋放。使用引擎動畫時鐘，沒有 step(delta) 介面；不能與手動步進 VFX 一律等同處理。 |
| [vfx.3d.sheet_effect](../addons/proto_kit/vfx/3d/sheet_effect.gd) | AnimatedSprite3D 保存場景的播放器；pixel_size 為公尺／像素。ready 可自動播放；非 loop 完成 emit finished 後預設 queue_free，池化須先 free_on_finish=false。loop 不靠完成訊號收尾。時鐘由引擎推進，無統一 manual step；billboard／材質等依保存 scene，不因腳本存在就保證每個場景配置相同。 |
| [vfx.sheet_frames](../addons/proto_kit/vfx/sheet_frames.gd) | 純製作 helper；只切水平單排、等寬 PNG。count 1..4096、fps 有限且正、寬可整除 count，無效回 null。回新的 SpriteFrames，但各 AtlasTexture 借用同一輸入 Texture2D，不複製像素。只建立 default 動畫，不自動存檔、不包含 pivot／多排／trim；來源管理與 ResourceSaver 由外層工具負責。 |
| [vfx.3d.00gamedevs.spell_indicator](../addons/proto_kit/vfx/3d/00gamedevs/spell_indicator.gd) | XZ 地面、扇形朝 +X，旋轉根節點瞄準。auto_step=false 才由宿主 step(seconds)；manual_progress=true 只外部推進 progress，達1後仍需 step 完成0.15秒尾段，stop 是0.12秒取消淡出而非立即隱藏。finished 不區分完成／取消，不可直接當攻擊命中。借用 %Surface 材質，必須 scene-local；circle scene 已靜態確認 local，不宣稱所有副本已驗。 |
| [vfx.3d.pixel_burst](../addons/proto_kit/vfx/3d/pixel_burst.gd) | PixelVfx3D 的保存場景與自動 step adapter；自有遊戲時鐘時先 auto_step=false。繼承 base 的池容量、palette、座標與預熱限制，沒有額外完成事件。此 scene 的 MultiMesh 已靜態確認 resource_local_to_scene=true；仍需消費者場景／GPU 驗證。 |
| [vfx.preview_2d](../addons/proto_kit/vfx/preview_2d.gd) | 開發預覽 scene 專用：依賴 %NativeEffects/%Replay，ready 連 timer 並立即播放固定示例。不是通用 spawn facade，不對外回傳 gameplay 事件，不作遊戲正式自動觸發器。 |
| [vfx.preview_3d](../addons/proto_kit/vfx/preview_3d.gd) | 開發預覽 scene 專用：依賴 %NativeEffects/%Replay，只連 timeout；首次播放依 Timer 配置。固定座標與 palette 用作展示，重複 tick 不代表回合生命週期。 |
| [vfx.3d.00gamedevs.impact_demo](../addons/proto_kit/vfx/3d/00gamedevs/impact_demo.gd) | 僅 demo：ready 對 %Impact.trigger(center UV 0.5,0.5)；不負責正式 subject mask、敵人選取或傷害。需要保存展示場景；不要把它接到遊戲取代 impact_frame。 |
| [vfx.3d.00gamedevs.trail_demo](../addons/proto_kit/vfx/3d/00gamedevs/trail_demo.gd) | 僅 demo：ready 將 %Weapon local base/tip 綁 %Trail，播放 %Swing 的 swing。正式遊戲由宿主綁真實武器與動畫；不要同時使用示例 Swing 控制遊戲 transform。 |
| [pixel_vfx](../addons/proto_kit/pixel_vfx.gd) | Node2D 自動 _process；粒子／shape 以本地 draw 座標，effect() 卻把 at 設成 shader child.global_position；轉換根節點時不可假設一致。pixel>0、life>0、palette至少5色；部分容量拒絕可由 stats 查詢。tones 快取後改 palettes 不會自動失效，回傳容器亦非唯讀。shader children 自行 process，停 parent process 不代表停子特效；clear queue_free shader children，未重設 RNG。draw Callable 只可在繪製期間用 cell。 |
| [pixel_vfx3d](../addons/proto_kit/pixel_vfx3d.gd) | 必須 ready 後使用，%Chunks MultiMesh 及非空 %Rings、max_chunks>=1；palette至少5色，m_per_px/duration/drop seconds需正值。ring 設 global_position 並固定 world y=0.03；chunks 直接用輸入位置作 MultiMesh local transform，碰地y=0.02，非任意世界地形。前兩次 step 為預熱直接 return；clear 不重設 RNG 或重新啟動預熱。容量滿靜默略過，不是效果完整播放保證；共享 MultiMesh 必須由 scene 隔離。 |
| [sprite_inspector](../addons/proto_kit/sprite_inspector.gd) | 唯讀開發場景，需要完整 %unique node 樹。自動發現目前只讀包含 sprite3d_sheet.gd 的 .tres 與 sheets.json，未如檔頭宣稱自動掃 .res；.res 可用 --sheet 指定。第一個 font 未驗 CJK。動畫名用空格切字，帶空格名稱有歧義；空 sheet 清單時方向鍵仍可能讀 null。預覽總是 modulo 循環且每 process 最多走一幀，不可當 one-shot/低FPS runtime 正確性證明。方向按鈕與縮圖仍 runtime 建立，待維護時改 item scene。 |
| [sprite_inspector_atlas](../addons/proto_kit/sprite_inspector_atlas.gd) | Inspector 內部 Control。需要合法正 grid、非零 image_size／控制項尺寸；GUI mouse 點擊轉圖集 cell，僅 emit index，不修正資料。公開 sheet/marks/anim_cells 由父場景持有；更新後需 queue_redraw。純檢視器，不是 atlas editor 或自動切格工具。 |
| [sprite_inspector_frame](../addons/proto_kit/sprite_inspector_frame.gd) | Inspector 內部 Control。傳入合法 Sheet、image_size、cell、zoom與像素診斷；父層以同一 zoom 比較各幀，不能逐幀縮放掩蓋尺寸差異。onion_cell／grid 等直接繪製，不驗完整資料。只 emit clicked；不修改或儲存 sheet，公開資料變更後由宿主 queue_redraw。 |
| [hd2d_demo](../addons/proto_kit/hd2d_demo.gd) | 組合示例／製作參考，build 回未入樹 Node，由呼叫端 add/free。程序建立整個 stage、HUD與佔位圖；不是已保存可直接維護的遊戲畫面。Runner 停用 MarchStrip 自動 process 再手動 step，但 shot camera 仍自行推進，並非所有動畫共享單一 deterministic clock。正式交付須製作並保存 scenes/resources，保留編輯器調整。 |
| [hd2d_gallery](../addons/proto_kit/hd2d_gallery.gd) | SceneTree 截圖工具，依 Hd2dDemo 組合，用固定 dt step 與實際 process_frame 混合。需要 renderer／窗口；Screenshot.save 的空回傳未檢查，quit 不能單獨當產圖成功。輸出資料夾取第一 user arg，會寫 PNG；不應作 runtime 元件。 |
| [sprite3d_gallery](../addons/proto_kit/sprite3d_gallery.gd) | SceneTree 視覺診斷工具，程序建立 placeholder sheet／actors／crowd；等 frame_post_draw 拍四面板。需要 renderer；輸出是首參數檔案，未自行建父資料夾／檢查 save_png 結果，exit0不保證檔案成功。不能用佔位圖驗收正式美術或以程序畫面取代保存遊戲場景。 |
| [vfx_gallery](../addons/proto_kit/vfx_gallery.gd) | SceneTree 像素效果截圖工具；實際按 process delta 到達四個時點後抓圖，非精準離散時間重播。最多3x3格，shader slots最多4個；extra參數須 name=path，目前未防缺等號。save_png 未查錯誤、未建父資料夾；正常退出不保證產圖。正式玩法不能依賴此工具。 |
| [vfx.gallery](../addons/proto_kit/vfx/gallery.gd) | 開發資產瀏覽場景，固定 %節點與 SubViewport，會刪除 holder 現有 child 再實例化。依 DETAILS.duration 排自動重播，非用 finished 判斷；若修改 SpriteFrames 個別 frame duration，估時可能不同。stop/reset/hit 以 duck typing 分流，語義未統一；weapon與impact包專屬demo。不能複製成通用遊戲效果生命週期管理器。 |
| [vfx.library](../addons/proto_kit/vfx/library.gd) | 靜態 PackedScene 目錄，EFFECTS 使用 preload，引用此腳本會建立整份靜態資源依賴；不是按需下載／lazy registry。get_scene 未知ID或dimension回null；ids 只按dimension列現有順序、不排序。DETAILS 的loop/duration是展示 metadata，不保證效果所有生命週期相同。查詢方法與載入結構已讀，未逐筆重審全部metadata／素材／授權。 |

## 應先修的邊界

```text
輸入資料驗證 → 明確座標／時鐘 → 元件生命週期 → 實際消費者接入
  grid/palette    local/world     finish/free      一款一款遷移
```

1. PixelVfx 2D／3D 優先統一公開座標，再由邊界轉 local；避免搬到有 transform 的 parent 後錯位。自動與手動時鐘也要涵蓋子特效。
2. VFX 的完成、取消、停止動畫、淡出與 queue_free 各有語義，先寫各 adapter 的行為，不能只靠 has_method("stop")。
3. SpriteCheck 先驗 grid／frame schema 再掃像素；Inspector 僅作閱覽，不當作 runtime 播放一致性的證據。
4. Gallery 寫檔應回傳／檢查 IO 結果；成功退出與真的取得截圖分開。
5. FontCheck／UiTheme 的字型來源要對齊實際匯出檔；來源字元涵蓋不等於排版／shaping／fallback 驗證。

這些是靜態發現，未改程式、未重現失效。現有演算法可保留，先補資料與所有權邊界；不要為展示腳本增設萬用遊戲 Manager。

## 覆蓋與工具狀態

kit 70 項現在為 62 項實作研究（含明列選讀）與 8 項前階段。它們包含 demo／內部畫面／測試工具，不等於 70 項獨立 runtime 功能。[覆蓋表](RESEARCH-COVERAGE.md) 保留每項深度，16 原型未覆蓋的部分也仍保留。9 項 CLI 的完整實作研究不由此數字代表。

本輪 codebase-memory MCP 在首次查詢與重試均回 Transport closed，改用既有清單的來源檔；未重新安裝或擅自修改 MCP 設定。VFX pixel_burst.tscn 的 MultiMesh 與 spell-indicator-circle.tscn 的材質已靜態查得 resource_local_to_scene=true；不是全部 scene 的隔離驗收。

驗證層級：文件／目錄。執行既有 capabilities build/check 與 diff 格式檢查；沒有新增或執行延期的 Godot／遊戲測試。後續回到既有 P0/P1：先修存檔與鏡頭／載入所有權，再遷移觸控、光效與交易邊界。

## 9 項 CLI 主入口補查

已讀 9 個列入目錄的 CLI 主入口全文（sync 沿用前階段已讀來源）。未執行它們的 self-test、匯出、錄影或同步；build_web 的 fetch／patch／PCK helpers 未在此輪逐檔重審。完整限制與機器可讀 effects.writes/may_use_network/failure_effects 已回填 tools.json。

| 工具 | 實際副作用／失敗語義 |
|---|---|
| [tool.sprite_atlas](../tools/sprite_atlas.py) | 需要 Pillow；讀 manifest 相對圖片路徑，固定角色 scale，trim 與 canvas 對齊政策不同。直接先寫 atlas.png 再寫 sheets.json，會覆寫且不是雙檔原子提交；IO 中斷可留下不同版本。AtlasError exit1，JSON/IO/型別錯誤未統一格式。格數／尺寸有上限，但完整 schema（正 cell/columns、非空動畫、正 ticks、合法 align）未全面驗證。 |
| [tool.subset_font](../tools/subset_font.py) | 需要 fonttools；--check 不寫檔，缺字 exit1。正常模式即使發現缺字仍會寫子集，再 exit1，非零不代表沒有產物。--skip-dir 取代預設列表，不是追加；掃描忽略讀檔／UTF-8 失敗且不驗 project 存在，空掃描不等於成功。輸出覆寫；source/out 只用 abspath 比較，不解析符號連結。保留 name records 不等於工具自動審查授權；動態文字需另補集合。 |
| [tool.build_web](../tools/web/build_web.sh) | 會下載模板、匯入專案、寫 build/.gdignore、覆寫 build/web 與 ZIP，非部署。主腳本只取引擎 major.minor 給 fetch helper；helper 的版本匹配需另審。export pipeline 以 || true 消化錯誤，後續以 index.html 存在繼續，不能保證所有匯出錯誤都讓 CLI 失敗；只移除舊 index.html，其他 stale build 檔可能進 ZIP。zip_name 必須是受控檔名，現行未驗路徑／空白檔名。使用專用輸出目錄，失敗可能留下部分產物。 |
| [tool.run_tests](../tools/run_tests.sh) | 需 timeout；先匯入後跑 suites，會執行任意遊戲測試及其 user:// 寫入，應用隔離測試存檔。suite exit0、無指定錯誤字樣且含 PASSED 才過；PASSED 子字串並非 assertion 數驗證。import 只驗 process exit／timeout，未同樣掃 import log。TEST_TIMEOUT 每次 import／suite 各計，非總時間。參數 name/fps 應受控；本輪未執行此工具。 |
| [tool.capture](../tools/capture.sh) | 需 renderer，可能開窗口並執行遊戲。會先刪 output 下 f*.png/f.wav，ffmpeg -y 覆寫 video.mp4；僅用專用錄影資料夾。固定30fps與 Compatibility renderer；畫面尺寸依遊戲 viewport，非必為 --resolution 值。ffmpeg 可選；缺少 ffmpeg 時不會更新既有 video.mp4，不能把舊影片當本次結果。WAV 參數經未引用命令展開，帶空白 output 路徑有風險。 |
| [tool.audit_copies](../tools/audit_copies.py) | 唯讀 SHA-256 來源比較，無語義或採用判定。relative project 基於 prototypes，absolute 可指外部；缺 copy 以 argparse exit2，--check 有差異 exit1，無 --check 即使 drift 仍exit0。沒有忽略規則，會包含輸出／隱藏檔；符號連結檔案可能讀到外部內容。對照結果不授權同步。 |
| [tool.sync](../sync.sh) | 修改模式使用整包 rsync -a --delete，刪除目標 kit 多餘檔；不合併修改、不做備份、不檢查相容性。沒有指定 target 會更新所有已有副本，故 AI 應明列單一目標。--check 唯讀呼叫 audit_copies；需先確認目標 project.godot。相對名稱基於 prototypes，支援 absolute；不應直接改目的副本。 |
| [tool.vfx_import_strip](../tools/vfx/import_strip.gd) | 需 Godot 與已匯入 PNG，僅水平等寬 strip；七個參數完整，source/license_note 只需非空，不代表授權已核實。拒絕既有 .tres 或 .source.json；先存 resource 再寫來源。來源檔開啟失敗會嘗試刪新 resource，但沒有查 store_string/close 寫入錯誤或 rollback 結果；不是 crash-safe 雙檔交易。res:// 前綴檢查不是完整路徑沙箱。 |
| [tool.capabilities](../tools/capabilities.py) | 只有 build 寫生成檔；check 比較 capabilities/resources/REFERENCE，不比較 inventory.json 新鮮度，也不執行 schema.json 完整驗證。list/show/plan 重新讀取目前來源，非直接信任舊 catalog。api 是 regex 擷取，不涵蓋繼承／內部類全部 API，註解也會進靜態引用。plan 不解析 Python import、shader include 或動態載入，非安裝 manifest。build 多檔逐寫，非原子。 |

最需要更正的假設是「非零退出就沒有產物」：subset_font 缺字仍寫字型；atlas 與 VFX importer 都分兩次寫；Web 匯出 pipeline 會消化 process failure。未來工具介面應分開 status、written_files、diagnostics 與 rollback 狀態。這些結論為原始碼證據，不是失敗注入測試。
