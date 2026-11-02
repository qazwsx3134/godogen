# 全員推王：目前進度

回來時先讀這份，再看 [FUSION.md](FUSION.md)（融合的決定與系統）、[ROADMAP.md](ROADMAP.md)（里程碑）與 [../README.md](../README.md)（規格、可編輯的 scene、執行方式）。

只保留最近 3 次 commit 期間的工作與尚未 commit 的工作（新的在上）；更早的紀錄移到 [MILESTONE.md](MILESTONE.md)。

## 目前狀態（2026-10-30）

master，六頁原生手機方向。現行介面與玩法見 [README](../README.md)，種族為人類／獸人／精靈。離線開頭五分鐘戰鬥模擬與強敵權重已修正；march／progression／home／main L2 通過（`/tmp/godot-tests.GbS3oh`）。本段文件整理沒有重跑遊戲測試，沿用該次證據。

待完成：真人前三層驗收、手機恢復／發熱、長時間估算差距的接受標準、作者素材選擇。沒有 Web preset；尚未產生本輪新的原生手機安裝包。工作區未 commit／push，最新提交用 git log 查核。下面按日期保留歷史狀態。

## 生圖：種族英雄與行軍背景（2026-10-29）

作者要我照 `docs/race-art-prompts.md` 與 `docs/bg-layer-prompts.md` 生圖並去背，用 Codex。生圖用本機 Codex CLI（`--route codex-cli`），由 Claude 的 shell 直接跑 `.py`，沒有另開 Herdr pane。

| 項目 | 狀態 | 位置 |
|---|---|---|
| 精靈、獸人 × 6 職業，各 6 個姿勢（站姿＋跑 2＋攻擊＋倒地＋大招），共 72 張，已去背並對齊腳底 | 完成並接進遊戲：`heroes.png` 第 6～11 列獸人、12～17 列精靈（取代舊的怪獸／夢靈暫代），推王、行軍、名冊卡、英雄詳情大圖都依種族換圖 | `art_src/races/`、`tools/pack_stage_art.py heroes portraits`、`scripts/army.gd row_of`、`scripts/portraits.gd` |
| 行軍背景第一套（天空、遠山、中景、地面、7 個物件），共 11 張，已去背 | 完成並接進遊戲：共用 scene `scenes/components/march_backdrop.tscn`，六頁的 `MarchBackdrop` 取代從參考圖裁的 `DistantLandscape`／`LowerLandscape*`／`LowerPatch*`／`Ground`；霧沼與熔岩兩套還沒生 | `art_src/bg_layers/`、`tools/pack_backdrop.py`、`tools/build_backdrop.gd`、`scripts/march_arena.gd bind_scenery` |

作者決定：精靈耳朵在 40 px 看不出來（沒通過文件的驗收），**不重做**。

驗證：
- 圖：逐張看過 contact sheet；色相差遮罩掃描 72 張英雄圖與 10 張透明背景，殘點合計 3 px、沒有碰到畫布邊。
- 接進遊戲：`heroes.png` 人類第 0～5 列與原本逐位元相同；headless 匯入沒有錯誤；`test_main`、`test_home`、`test_march` PASSED（換背景後重跑一次，也 PASSED）；`capture_home.gd` 與 `capture_shots.gd` 截圖看過：名冊有狐狸、白狐等獸人卡，行軍條是新的分層背景、行軍中有位移。`test_stages`、`test_balance`、`test_progression`、`test_recruit`、`test_report`、`test_skills` 沒跑（數值與這些系統沒動）。
- 舊的 `tools/pack_form_art.py` 標成停用（再跑會蓋掉種族列）；`assets/heroes/portraits/monster_*`、`dream_*` 與參考圖裁的風景區域已不再使用，還沒刪。

## 怎麼接著做

```bash
GB=/Applications/Godot.app/Contents/MacOS/Godot
cd prototypes/hero-horde-idle
$GB --path . -- --save=trial                    # 試玩（不碰正式存檔）
for t in march progression home recruit report skills main balance stages; do   # 完整測試（依序，不要同時跑）
  timeout 900 $GB --headless --path . --script res://tests/test_$t.gd 2>&1 | grep -E 'PASSED|FAILED|SCRIPT ERROR'
done
$GB --path . --resolution 470x836 --script res://tools/capture_home.gd -- <輸出資料夾>   # 主畫面七頁截圖
$GB --path . --resolution 390x844 --script res://tools/capture_shots.gd -- <輸出資料夾>  # 推王截圖
```

- 分層驗收：改單一系統跑該系統的測試；動到行軍、養成、推王之間的交互，加跑 `test_home` 與 `test_main`；完整測試等作者手動驗收後再跑（`test_stages` 約 80 秒）。
- scene 以存檔為準：`tools/build_fusion_ui.gd` 已套用，頁面掛上腳本後重跑會跳過；要重做某頁，先看 diff 再刪檔重跑。
- 生圖一律先列出批次內容給作者選。

## 2026-10-29 離線收益審查改善

使用者授權繼續改善。完成 domain 在線／離線對照工具與前後 JSON 證據，見 FIRST-THREE-FLOORS-ACCEPTANCE.md。修正離線漏算強敵三倍獎勵：使用加權獎勵速率，擊殺數仍不加權。L2 march／progression PASS（`/tmp/godot-tests.VzEGYo`）。固定 seed 第一層四組金幣差距由 -14%～-24% 縮小至 -8%～+3%；不是全面平衡或真機證據。低等隊伍成長途中加速仍未納入離線固定速率。未改存檔格式、未重建 Web、未 commit／push。

## 2026-10-30 收益矩陣

compare_march_rewards 新增 --matrix，48 組涵蓋三種子、前三層與第八層退關邊界、兩起始等級、兩時長。前三層金幣差距 -14.50%～+7.84%；第八層五分鐘高估 11.42%～35.07%，在線均退關五次。完整資料與模型限制見 FIRST-THREE-FLOORS-ACCEPTANCE.md／march-rewards-matrix-2026-10-30.json。

工具層驗證 PASS：矩陣完整／無重複、有限正獎勵、退關條件、log 無 ERROR／SCRIPT ERROR／Parse Error；預設四組主要資源結果與前次一致。logs `/tmp/hero-march-matrix-20261030.log`、`/tmp/hero-march-default-20261030.log`。本輪未改 runtime，未重跑遊戲 suite；沿用 2026-10-29 march／progression 通過證據。近似差距容許值與算法決策待定，真人／真機未驗。未 commit／push。

## 2026-10-30 離線開頭戰鬥修正

已實作前五分鐘實際戰鬥、升級、退關與恢復，長時間剩餘段採更新隊伍的加權估算；單怪獎勵常數與 schema 不變。第八層五分鐘矩陣由高估 11%～35% 變為 -7%～0%；長時間與種子差距仍有，完整數據見 FIRST-THREE-FLOORS-ACCEPTANCE.md。L2 march／progression／home／main 全 PASS（`/tmp/godot-tests.GbS3oh`），戰報收支、退關與 save roundtrip 新斷言通過。桌面單次8小時結算約21ms，非真機／統計效能證據。未重建 Web、未 commit／push。

## 2026-10-30 現況文件整理

README 現在只記目前的六頁、種族、操作、場景與驗證入口；整理前完整內容保存於 `docs/history/README-2026-10-30.md`，含來源 SHA-256 與換算後連結。FUSION 保留作者決策但標示歷史時間。36 個目前文件連結與六頁／18 天賦／種族／430×932 設定／無 Web preset 的靜態核對 PASS，見 readme-validation-2026-10-30.json。這次沒有改程式或 scene，未重跑遊戲測試；沿用最新 L2 證據。未 commit／push。

2026-10-30 存檔保護：較新／不支援版本、破損 JSON 與空檔會保留原檔並停止寫入，主畫面會提示目前遊玩不保存。保存前也重新檢查目標版本。L2 四組 PASS，詳見[規則與限制](SAVE-PROTECTION.md)；完整內部欄位 schema 驗證仍未涵蓋。本輪沒有改 schema、未產生手機安裝包、未 commit／push。

## 2026-10-30 存檔 schema 完成

載入與目標檔／輸出快照皆驗證英雄、隊伍、裝備、詞綴、UID、容量及可選欄位；不識別的欄位阻止覆寫。保留短天賦／遺物與 scalar potion 的舊 v2 相容，v1 裝備／件數背包可遷移，超容量保護而不截斷。L2 save_protection／progression／home／main／recruit 全 PASS（`/tmp/godot-tests.vW1ukD`）。初輪版本 float 比對失敗已修正並完整重跑，證據與限制見 SAVE-PROTECTION.md。未改 schema 版本、未 commit／push。

## 根目錄紀錄補遺（2026-11-02 移入）

根目錄 `Progress.md` 拆分時移入本檔原本沒有或較簡略的段落，保留原文。

### 跨專案審查改善（2026-10-29～30）

| 專案 | 已完成的程式／文件工作 | 仍待外部驗收／延期 |
|---|---|---|
| hero-horde-idle | 現況文件、48 組收益證據、強敵與前五分鐘離線算法、存檔完整 schema 與輸出保護 | 真人前三層、容許收益差距與手機恢復成本；Web 路線延後 |

- 已完成（hero 部分）：hero 目前循環與前三層／離線收益驗收。重要入口 `docs/FIRST-THREE-FLOORS-ACCEPTANCE.md`。
- 部分／未完成（hero 部分）：真人／真機驗收及 hero 在線離線差距與容許值待測。未改平衡數字。
hero 最新 L2 `save_protection progression home main recruit` 全 PASS，證據 `/tmp/godot-tests.vW1ukD`；本批未重跑，詳見下方 10-30 schema 紀錄。其他專案驗證沿用各自最後一輪，未將舊證據冒充本輪結果。涉及真人、作者內容、真機及服務部署的項目保持未完成，未宣稱原清單全面驗收。
- 2026-10-30 hero 存檔保護：先重現較新版本／破損 JSON／空檔被覆寫三項 FAIL（`/tmp/hero-save-before.log`）；載入與寫入前現在檢查 JSON 根型別與版本，不相容時阻止覆寫並顯示主畫面提示。L2 save_protection／progression／home／main 全 PASS（`/tmp/godot-tests.zMQXlQ`），提示字型檢查 PASS。範圍限制與重現見 `hero-horde-idle/docs/SAVE-PROTECTION.md`；尚未全面驗證內部欄位 schema，未改存檔版本或輸出安裝包。
