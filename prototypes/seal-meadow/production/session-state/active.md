# 蓬蓬草原 session checkpoint

## 2026-10-30｜復工：審查改善與 S34 單機乘坐

使用者最新授權「繼續直到做完」及「做完之後看 seal 也繼續進度」，已解除前次暫停。分支 `master`；本輪程式／場景／文件未 commit／push，保留其他原型修改。多人 M4 仍延後。

- 已完成本輪 S34 乘坐薄切片：寵物第 2 階解鎖、移速 ×1.25、重複切換不累加，攻防加成不重複。選怪／有效技能／受傷／死亡／切區／背景／讀檔會下坐，失敗技能保留狀態。乘坐取消釣魚而不扣餌；暫態不寫檔，schema 仍 v6。
- 沿用同一個 Pet 與史萊姆占位素材；Actor 高度／比例下坐還原。`ui/hud.tscn` 的 PetPanel 改固定 Head + Scroll/Box，乘坐／進化／餵食動作具手機觸控尺寸，場景仍可在編輯器維護。
- L2 `companions m3 review_interactions` 全 PASS（`/tmp/godot-tests.KN9GPi`），含實際按鈕、位移、戰鬥／生命週期、讀檔重開、兩尺寸大字／捲動／44px、編輯器文字／間距保留。匯入仍有沙箱 TCP 監聽錯誤，未見 SCRIPT ERROR／Parse Error。M2 未重跑，沿用 `/tmp/godot-tests.8mkgik`；L3 全套依規範等人工驗收。
- `tools/build_mobile_web.sh` 已再次重建手機候選：`build/seal-meadow-mobile-web.zip` SHA-256 `6c1cc1117d8bc50dea798f576057665fd1ab97d53557a896ca3c8c2dc42b7b8d`；15,112,870 bytes。ZIP／PCK 靜態、IDBFS 與編譯 PCK 的乘坐／背景／出售視窗冒煙 PASS（`/tmp/seal-s34-pack.log`）；來源 hash 與上包區別見 `production/qa/mobile-candidate-2026-10-30.json`。
- 文件入口：`design/gdd/battle-pets-guarders.md`、`docs/architecture/systems/battle-pets-guarders.md`、`production/qa/systems/battle-pets-guarders.md`；README、roadmap、planning dossier／index 同步。S34 只是乘坐分支，AC-S34-03 戰鬥 AI 仍未實作。
- 未完成／延期：iPhone 視覺、觸控、速度感、背景／強制關閉恢復、FPS／20～30 分鐘發熱及真人平衡。沙箱禁止 socket，這次新包 Web／IndexedDB 未驗；10-29 Chromium 證據屬於舊包。未上傳，不自動同步其他 kit 副本，bot 不跑 25 分鐘。
- 下一步：先用此手機候選驗收乘坐重疊、寵物面板與出售確認；依真人回饋調整單機內容／數值。多人與戰鬥寵 AI 不隨本切片自動展開。

## 2026-10-29｜單機階段與獨立審查完成，暫停

- 使用者返家要求繼續，之後指定做到一階段停下並開另一個 Sol medium 審查；單機優先，多人 M4 延後。`master` 基準／最新提交 `180149a9`；本輪修改未 commit／push。
- `REVIEW.md` 8～10 已實作：背包精煉分頁、技能命中後選存活怪自動攻擊、傳送門選取外環；新增可編輯 `ui/refine_row.tscn`。過量背包存檔保護及寵物經驗損失訊息已修。
- S17、S18、S19、S33、S35 GDD／TDD／QA 和 `production/qa/m3-economy.md` 已補；S35 衣櫥預覽／取消、資格與保存已做，存檔升 v6。D09、D10 保持暫定，M3 仍缺真人／真機驗收。
- 最新 L2 `wardrobe`、`m0`、`m3`、`m3_hardening`、`collection`、`content`、`review_interactions` 通過（`/tmp/godot-tests.wtxsbV/`），11 個隔離變異均被抓到，headless 場景匯入無錯。最新完整 suite 依專案規範等使用者手動驗收後再跑。
- 手機測試包 `build/seal-meadow-mobile-web.zip` SHA-256 `a8150f3138aa02062f7abbd855ea6d87a7de0fba8cb16a7d4bacefb73efb91c4`；Chromium 12 項含 v4／v5→v6、精煉與衣櫥預覽／重開通過、0 錯誤（`/tmp/seal-web-wardrobe-20261029/report.json`）。桌面模擬不是 iPhone 真機，`build/web/` 是舊版。
- 獨立 GPT-6 Sol／medium 唯讀審查完成，未發現可重現的本輪功能缺陷；報告 `production/qa/reviews/2026-10-29-sol-medium.md`。依審查修正「v5 讀取器拒絕 v6」的測試描述並單獨重跑 `test_wardrobe.gd` 通過；舊版整個遊戲的寫入端對端未驗。本輪 8795 本地伺服器已停止。
- 依使用者要求現在暫停；iPhone 17 Safari／背景恢復／20～30 分鐘發熱／真人試玩待驗，bot 不跑 25 分鐘。無新授權不 commit、push、上傳或同步其他原型 kit；詳細證據與指令在 `PROGRESS.md`。

## 2026-10-28｜出門交接：暫停

- 使用者要求補 M3 後依規劃繼續，選擇優先做單機後續內容，多人 M4 延後；現在出門並要求交接，已停止開發。`master` 最新提交與實作基準 `21604e31`；本輪變更未 commit／push，保留其他專案工作區修改。
- M3 增加 v5 存檔遷移及保護、單件裝備精煉與交易去重、設定、進化確認、背景輸入清除；另實作 S19 圖鑑／成就／聲望與 S33 釣魚薄切片。完成範圍與限制見 `PROGRESS.md`。
- 完整 10 組 suite 通過於最後存檔驗證及圖鑑未知資料保留修改**之前**（`/tmp/godot-tests.bqN5hB/`）；之後只重跑 `test_m3_hardening.gd` 和 `test_collection.gd` 且通過，釣魚測試通過早於最後存檔驗證修改。最終完整回歸尚未跑。
- Web 的畫布、設定持久化、v4→v5 遷移檢查通過，但整體因測試時 `/favicon.ico` 404 **FAIL**：`/tmp/seal-web-m3-final/report.json`。需排查後重跑；本輪伺服器 8795 已停止。
- `build/mobile-web/` 為手動匯出的手機候選，PCK 35.05 MB、WASM 約 39.5 MB；新建的 `tools/build_mobile_web.sh` 未完整執行，手機 ZIP 尚未建立；`build/web/` 是 2026-10-27 舊版。
- 下一步：釐清瀏覽器失敗、重跑完整測試／短 bot／網頁測試，驗證手機匯出腳本，補 M3 與 S19／S33 規格、經濟和 QA 文件，再安排 iPhone 17 Safari 觸控、背景／強制終止恢復、FPS、20～30 分鐘發熱與真人試玩。使用者不希望 bot 再跑 25 分鐘。
- 其他原型 kit 副本不自動同步；外部 itch 草稿上傳前先取得使用者同意。詳細證據、測試指令及未完成事項在 `PROGRESS.md`。

## 2026-10-27｜繼續進度與 review 回饋

- 分支 `master`，實作基準 `21604e31`；本輪 seal-meadow 相關程式、場景、測試與文件未 commit／push。未更動其他原型。
- 完成長按拾物／傳送、點擊優先序及範圍、閒置受擊反擊（保留手動移動與既有目標）、右上寵物按鈕、世界地圖、佔位怪物比例、bot 成功揮砍統計。詳細狀態見 `PROGRESS.md`、`REVIEW.md`。
- 7 組 suite 通過：`env XDG_DATA_HOME=/tmp/seal-meadow-verified XDG_CONFIG_HOME=/tmp/seal-meadow-verified-config TEST_TIMEOUT=90 bash prototypes/godot-kit/tools/run_tests.sh prototypes/seal-meadow m0 m1 m1_loot m2 m3 content review_interactions`（repo 根目錄執行；`/tmp/godot-tests.P3vyHO`，m1／m1_loot 各有 ObjectDB 清理警告）。清五怪 18.0／11.1 秒（普攻／揮砍）；1,000 筆訊息仍最多 60 段。未執行 25 分鐘 bot。
- 本機 Web 橫向 Chromium 觸控開關地圖 0 錯誤；最新 PCK 64.19 MB、WASM 39.5 MB、zip 約 16 MB。尚未上傳，也沒有 iPhone 17 Safari、發熱、長時間穩定與真人樂趣證據。
- 混元 3D 2.1 只做官方需求／授權調查，沒安裝或產生素材；見 `design/pipeline/3d-to-sprite.md`。真機集中測試、多人延後及其他原型 kit 副本不自動同步的使用者決定不變。`sync.sh --check seal-meadow` 本輪報 drift，未同步。
- 下一步：使用者試玩檢查比例與觸控；依已決定的安排一起做 iPhone 17 真機驗收。準備外部 HTTPS 發布時需按既有約定先取得使用者同意。

## 2026-10-26｜系統文件與 roadmap 規劃

- 使用者要求：以 Lead Game Designer、Godot Specialist、Lead Programmer、Lead Systems Designer 職責，根據手機製作基準詳細列出各系統文件與 roadmap。
- 已確認：手機執行、固定鏡頭方向／俯角、無旋轉操作、不做短連招；現行製作基準不安排其他鍵序／節奏連招。鏡頭可跟隨平移。
- 此次完成：40 系統 planning dossiers、系統索引、文件契約、Godot 架構草案、M0～M6 roadmap、16 項決策清單、驗證計畫、game brief 與 README 入口。
- 入口：`design/planning/README.md`；結構化登錄：`design/planning/system-register.json`；順序與出口：`production/roadmap.md`。
- 狀態：Planning Draft；不是 40 份詳細 GDD 定案，不是功能實作完成。現有 prototype 含部分行為，但新手機範圍未驗收。
- Studio：從遊戲 root 明確跑 resolve_config，得到 minimal／solo／collaborative；依使用者本次詳細文件要求增加深度，未改全域設定。授權內可逆文件編輯直接完成，未開代理。
- 文件驗證：40 unique systems、120 unique AC、前置圖無循環、反向依賴一致、首版階段先後一致、49 Markdown／615 本地連結／8 圖通過。證據：`production/planning-validation-2026-10-26.json`。
- 沒有修改遊戲腳本、scene、素材、匯出或部署；Godot／真機／多人壓測未執行。
- 下一步建議：依 M0 工作包補可實作的 GDD／契約／TDD，收斂 D01～D03（方向、平台、目標機），再做固定鏡頭／觸控／導航／最小物品與保存的手機薄切片。使用者尚未在本次要求實作。
- 更新規劃時同步維護 Markdown／JSON 與雙向依賴；本次 `/tmp/seal_planning_build.py` 僅製作工具，正常執行不可用它覆寫人工文件。

## 2026-10-29 審查改善續作

使用者授權依改善清單續作。新增材料出售確認與背包快照核對；補經濟循環實測計畫及 quick spec。手機候選尚未重建，真機確認視窗待驗。驗證結果見根目錄 Progress.md 最新改善段落。

2026-10-29 續作：出售確認改為 HUD 內可編輯 Control scene，含捲動清單與固定取消／確認鈕；M2 真實按鈕與兩尺寸版面檢查 PASS，證據 `/tmp/godot-tests.yEAs8b`。Web 尚未重建。

## 2026-10-30 手機候選更新

已重建 `build/mobile-web/` 與 `build/seal-meadow-mobile-web.zip`，包含出售確認 Control scene；IDBFS 修補完成，ZIP CRC 完整性與 PCK 場景／腳本存在檢查通過。ZIP SHA-256 `dbb467521f52a1e971cc367f2b464fad0f0cb59cd1552741c5e712805124246f`。詳見 `production/qa/mobile-candidate-2026-10-30.json`。

新增滿 12 格、大字模式、兩種橫向尺寸的捲動清單／固定按鈕／取消保留物品測試，L2 M2 PASS（`/tmp/godot-tests.8mkgik`）。未修改 runtime；未重跑 M3，沿用 2026-10-29 結果。匯出仍有沙箱 TCP 監聽錯誤，未見腳本解析錯誤。

沙箱在 socket 建立階段即 PermissionError，無法啟動本機伺服器／Chromium Web 驗證；此候選的觸控與 IndexedDB 尚未驗證。前次 Chromium 12 項 PASS 屬於舊候選，不能沿用到新包。未上傳，iPhone 真機與長時間驗收仍待完成。
