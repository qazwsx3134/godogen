# 驗證狀態（2026-11-06）

使用者於本輪後段指示「主要先著重於重構，測試可以先緩」。因此停止新增與擴大測試；**weighted_choice 抽取及 rarity/chest_shop/run_timeline/refine_ladder 接入後尚未重跑測試**。以下通過證據僅屬此前階段，不是最終工作樹的完整驗收。

## 此前已完成的 L2 證據

命令在 repo 根目錄執行；本機 Godot 為 `/Applications/Godot.app/Contents/MacOS/Godot`，版本 `4.7.stable.official.5b4e0cb0f`。

| 命令 | 當時結果 | 範圍 |
|---|---|---|
| `python3 prototypes/godot-kit/tools/test_capabilities.py` | 5 tests OK | 多行 API 擷取、未知 ID、契約欄位、覆蓋全部腳本、依賴閉包；當時 69 腳本 |
| `python3 prototypes/godot-kit/tools/capabilities.py check` | 69 capability contracts match source | 當時生成檔與原碼一致；後來 metadata 與 weighted_choice 已變動，未重跑 |
| `Godot --headless --path prototypes/godot-kit --editor --quit` | exit 0，無 SCRIPT／Parse／引擎 ERROR | 新傷害數字 scene 匯入；`/tmp/kit-cap-import.log` |
| `Godot --headless --path prototypes/godot-kit --script res://tests/test_capability_composition.gd` | 37 checks PASS | fixed_step、數字池、選卡→稀有度→施法→JSON 存讀；`/tmp/kit-cap-tests-final.log` |
| `Godot --headless --path prototypes/godot-kit --script res://tests/test_survivor_modules.gd` | 109 checks PASS | 原有 survivor 模組；`/tmp/kit-cap-regression.log` |
| 隔離副本將 fixed_step 的 advance 回傳改為 0，再跑同一 composition suite | exit 1，4 FAIL | 證明步數／追趕／邊界斷言會抓到錯誤；`/tmp/kit-cap-mutation.log`；正式來源未改 |

37 checks 包含：容量不成長、重用最早槽、門檻／NaN 拒絕、變換父節點下世界座標、浮動方向、critical alpha 不依賴縮放判斷、獨立 RNG、clear、進樹後保留編輯文字大小、runtime 不回寫場景，以及 retain/drop/reset/非法設定／小數邊界。

製作場景使用 `tools/build_damage_numbers.gd` → `SceneBuilder.save_scene`（PackedScene.pack + ResourceSaver.save），保存並回讀 1-node 字樣與 2-node 數字池，保留 Preview 子 scene 引用。初版製作工具錯把 save_scene 已釋放的 root 再 free，Godot exit 134；修正後重跑 exit 0。初次沙箱執行另有 macOS CA certificate 錯誤，最終匯入及測試在已授權環境完成。

## 重構後目前狀態

- `weighted_choice` 與四個消費模組：已人工審查 diff、亂數次數、順序、嚴格比較邊界與錯誤返回；未做新的執行驗證。
- 目錄已用 `capabilities.py build` 重新產生，這是生成工作，不當成測試通過。
- GPU 外觀、手機／Web、效能量測、既有遊戲副本遷移及完整 L3 都未做。
- 原有遊戲副本未同步；新模組不能因文件完整就標為多遊戲實際驗收。

後續恢復驗證時，先針對 weighted_choice 有效分佈與固定 seed 的舊新序列、非法權重的明確行為做最小 L1，再跑其四個消費模組的少量 L2。沒有作者手動驗收前不跑完整 L3。

## 2026-11-06 P0 生命週期重構（執行驗證延期）

本批 camera_shake／scene_loader／music 只審查來源差異與契約，再生能力目錄。沒有 Godot 執行、音訊實播或遊戲冒煙結果；先前 PASS 不涵蓋本批。未新增測試，依使用者優先重構指示延期。

恢復測試時採 L2，限下列受影響路徑：
- camera：非零 offset/rotation 的自然結束、立即停用、reset、換鏡頭、鏡頭已 free；明確遵守單一寫入者。
- loader：載入中與滿格停留期間的重複 request 保留狀態；場景只交付一次；失敗可重試；非法 delta 無更新；cancel 收取而非中止。
- music：同一資源另供音效使用時循環設定不變；Ogg/MP3/WAV 私有副本；同一原始資源不重播；快速換軌仍可淡出入。

## 2026-11-06 SaveSlots 重構（執行驗證延期）

本次僅 `capabilities.py build` 與 `check`（PASS 70）、`git diff --check`；未執行 Godot，無新的存檔測試證據。未使用作者真實 user:// 存檔。

恢復時採 L2：隔離路徑檢查主檔／備份任一 future 阻擋讀寫、缺失／小數／字串版本、validator 拒絕且檔案不變、JSON 數字 round-trip、無效主檔不污染好備份、migration 缺失／非 Dictionary 返回可回退、validator 收到副本、backup IO 失敗不得提交主檔，以及舊三參數呼叫。另確認單寫入者與兩檔非交易限制，不用並發測試假裝提供鎖。
