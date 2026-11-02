# seal-meadow 交接進度

最後更新：2026-10-31。每次 commit、使用者出門或下班時更新這份檔案。只保留最近 3 次 commit 期間的工作與尚未 commit 的工作（新的在上）；更早的紀錄移到 [MILESTONE.md](MILESTONE.md)。

## 2026-10-31｜續作：存檔寫入與恢復保護

使用者要求繼續 seal 單機。`master`，基準仍為 `fad04133`（最新以 git log 查核）；前輪生命週期回修和本輪存檔保護皆未 commit／push，保留其他工作區修改，未上傳。

- 新增本遊戲 `scripts/save_store.gd`，嚴格讀取版本外層後才逐版遷移與驗證 payload，再選有效備份。字串／bool／小數版本不會被強轉成可覆寫版本。kit 來源與副本保持原樣，schema 仍 v6。
- 每次保存先驗待寫入快照、較新備份及現有主檔；不讓背景／進度保存覆寫遊戲開啟後被替換的較新／損壞／異常檔。恢復備份前比對啟動選定的主檔／備份 bytes，防止後來的新檔被恢復流程蓋回。拒絕後保留兩檔、記錄 save_blocked_reason 並顯示訊息，重開前不自動解除。
- 先紅後綠：`save_protection` 修正前重現失敗（`/tmp/godot-tests.ELMiQg`）；最終 L2 `save_protection m3_hardening world_lifecycle` 三組 PASS（`/tmp/godot-tests.ClMJR5`），含既有遷移、有效備份恢復、交易／設定及跨區復活。沒有 scene 修改；未見 SCRIPT ERROR／Parse Error，匯入仍有沙箱 TCP 監聽錯誤。其餘 suite 本批未跑，保留前次證據；L3 仍等人工驗收。
- 最後補查 v1～v6 正向載入／保存、非法 header 的有效備份恢復、同版本備份被替換的恢復保護；save_protection 單獨重跑 PASS（`/tmp/seal-saveguard-final-positive.log`），只補測試，runtime／候選不變。其他兩組沿用本輪 ClMJR5 證據。
- 最新手機 ZIP 已重建：15,115,896 bytes，SHA-256 `1fc3a827659c957f6831ad04cf625d6d62b41f03af092fb61715ead958a41bab`。ZIP／PCK 靜態、IDBFS 與 save_store 入包 PASS；編譯 PCK 的較新檔案保護／v5 遷移保存冒煙 PASS（`/tmp/seal-saveguard-pack-20261031.log`）。報告 `production/qa/mobile-candidate-2026-10-31.json`，10-30 報告標為歷史，不能把新包當作已做瀏覽器驗證。
- 規則／限制／命令見 `docs/save-protection.md`；這不是完整經濟 schema、防作弊、檔案鎖或多分頁合併，不保證檢查後與另一程序同時寫入的窄競態。通用教訓同步至 `prototypes/LESSONS.md`。
- 未驗／延期：新包 Web／IndexedDB 因 socket 沙箱未驗；iPhone、長時間發熱與真人平衡待驗，戰鬥寵 AI／多人 M4 保持延期。下一步用最新候選驗收存檔保護提示及單機流程；沒有真人結果前不宣稱全面驗收或跑 L3，bot 不跑 25 分鐘。

## 2026-10-30｜續作：跨區復活與乘坐／釣魚交互

使用者要求繼續 seal 單機。分支 `master`，本輪實作基準 `fad04133`（`git log -1`）；本 session 未 commit／push／上傳。本輪腳本、測試、文件與候選修改未提交，保留其他工作區變更。

- 修正村莊存檔重開後死亡，角色回草原但 zone／bounds 仍在村莊、第一步被推回舊區域的缺陷。復活事件現在同步地圖、相機與原寵物，並保存復活位置；原有路牌、滿 HP、養成資源保留與 schema v6 政策不變。
- 修正傳送淡出中死亡並復活，舊 travel 等待仍搬動角色／寫入目的地的競態；以生命週期編號讓死亡前的等待失效，恢復畫面後退出傳送。死亡也清除待互動與按住輸入。
- 釣魚有效開始才下坐，缺餌等拒絕保留乘坐。先紅後綠：修正前 world_lifecycle 六項、fishing 一項 FAIL（`/tmp/godot-tests.fhnDuc`）；最終 L2 `world_lifecycle fishing companions review_interactions` 全 PASS（`/tmp/godot-tests.ajHIaM`），無 SCRIPT ERROR／Parse Error；匯入仍有沙箱 TCP 錯誤。本輪未改 scene，未重跑 M2／M3，前批證據仍各自保留；L3 等人工驗收。
- 手機候選已重建：`build/seal-meadow-mobile-web.zip`，15,113,782 bytes，SHA-256 `e3f3e418de02f17c719c95736a7f253d4023122434a02ca194ffd7a35b029ccd`。靜態 ZIP／PCK／IDBFS 及編譯 PCK 的復活／傳送取消／釣魚下坐冒煙 PASS（`/tmp/seal-lifecycle-pack.log`）。來源 hash 與前包紀錄在 `production/qa/mobile-candidate-2026-10-30.json`。
- 重要入口：`design/quick-specs/world-lifecycle-2026-10-30.md`、`production/qa/world-lifecycle-2026-10-30.md`、`tests/test_world_lifecycle.gd`；README／釣魚與乘坐 GDD／QA 已同步，通用 await 生命週期陷阱已記 `prototypes/LESSONS.md`。
- 未驗／延期：新包 Web／IndexedDB 因 socket 沙箱未驗；iPhone 觸控、淡入淡出、相機、背景恢復、FPS／長時間發熱與真人平衡仍待驗。戰鬥寵 AI、多人 M4 保持延期，不自動同步其他 kit 副本，bot 不跑 25 分鐘。
- 下一步：以最新候選試玩跨區復活、傳送中受致命傷、乘坐開始釣魚，再按真人回饋推進單機；本輪完整命令及限制見交互 QA。

## 2026-10-30｜復工：審查改善與 S34 單機乘坐

使用者最新授權「繼續直到做完」及「做完之後看 seal 也繼續進度」，已解除前次暫停。分支 `master`；本輪程式／場景／文件未 commit／push，保留其他原型修改。多人 M4 仍延後。

- 已完成本輪 S34 乘坐薄切片：寵物第 2 階解鎖、移速 ×1.25、重複切換不累加，攻防加成不重複。選怪／有效技能／受傷／死亡／切區／背景／讀檔會下坐，失敗技能保留狀態。乘坐取消釣魚而不扣餌；暫態不寫檔，schema 仍 v6。
- 沿用同一個 Pet 與史萊姆占位素材；Actor 高度／比例下坐還原。`ui/hud.tscn` 的 PetPanel 改固定 Head + Scroll/Box，乘坐／進化／餵食動作具手機觸控尺寸，場景仍可在編輯器維護。
- L2 `companions m3 review_interactions` 全 PASS（`/tmp/godot-tests.KN9GPi`），含實際按鈕、位移、戰鬥／生命週期、讀檔重開、兩尺寸大字／捲動／44px、編輯器文字／間距保留。匯入仍有沙箱 TCP 監聽錯誤，未見 SCRIPT ERROR／Parse Error。M2 未重跑，沿用 `/tmp/godot-tests.8mkgik`；L3 全套依規範等人工驗收。
- `tools/build_mobile_web.sh` 已再次重建手機候選：`build/seal-meadow-mobile-web.zip` SHA-256 `6c1cc1117d8bc50dea798f576057665fd1ab97d53557a896ca3c8c2dc42b7b8d`；15,112,870 bytes。ZIP／PCK 靜態、IDBFS 與編譯 PCK 的乘坐／背景／出售視窗冒煙 PASS（`/tmp/seal-s34-pack.log`）；來源 hash 與上包區別見 `production/qa/mobile-candidate-2026-10-30.json`。
- 文件入口：`design/gdd/battle-pets-guarders.md`、`docs/architecture/systems/battle-pets-guarders.md`、`production/qa/systems/battle-pets-guarders.md`；README、roadmap、planning dossier／index 同步。S34 只是乘坐分支，AC-S34-03 戰鬥 AI 仍未實作。
- 未完成／延期：iPhone 視覺、觸控、速度感、背景／強制關閉恢復、FPS／20～30 分鐘發熱及真人平衡。沙箱禁止 socket，這次新包 Web／IndexedDB 未驗；10-29 Chromium 證據屬於舊包。未上傳，不自動同步其他 kit 副本，bot 不跑 25 分鐘。
- 下一步：先用此手機候選驗收乘坐重疊、寵物面板與出售確認；依真人回饋調整單機內容／數值。多人與戰鬥寵 AI 不隨本切片自動展開。

## 一句話現況

M0～M3 有桌面可玩的核心循環，單機圖鑑、釣魚與衣櫥薄切片可用；獨立審查已完成，iPhone 17 實機驗收和真人平衡尚未完成。

## 怎麼驗證

```bash
env XDG_DATA_HOME=/tmp/seal-tests XDG_CONFIG_HOME=/tmp/seal-tests-config bash prototypes/godot-kit/tools/run_tests.sh prototypes/seal-meadow
env XDG_DATA_HOME=/tmp/seal-bot godot --headless --path prototypes/seal-meadow --fixed-fps 60 -s res://tests/bot_m1.gd -- clear 5
env XDG_DATA_HOME=/tmp/seal-m3-hardening-test XDG_CONFIG_HOME=/tmp/seal-m3-hardening-config timeout 60 godot --headless --path prototypes/seal-meadow --script res://tests/test_m3_hardening.gd
env XDG_DATA_HOME=/tmp/seal-collection-tests XDG_CONFIG_HOME=/tmp/seal-collection-config timeout 50 godot --headless --path prototypes/seal-meadow --script res://tests/test_collection.gd
env XDG_DATA_HOME=/tmp/seal-fishing-tests XDG_CONFIG_HOME=/tmp/seal-fishing-config timeout 50 godot --headless --path prototypes/seal-meadow --script res://tests/test_fishing.gd
```

上一輪 7 組 suite 通過（2026-10-27，`/tmp/godot-tests.P3vyHO`）；m1 與 m1_loot 離開時各有 ObjectDB 清理警告。測試包含長按後走去撿物與傳送、重疊點選、反擊／移動、世界地圖、1,000 筆訊息上限及場景編輯後保留。五怪清群短測：普攻 18.0 秒、揮砍 11.1 秒，快 1.62 倍；20 秒 bot 的完成揮砍 2 次／嘗試 2 次。短測不是長時間穩定或平衡驗收。當時 Godot Web 橫向 Chromium 844×390 觸控開關地圖、0 console error／請求失敗；截圖 `/tmp/seal-web-map.png`、`/tmp/seal-web-closed.png`。當時匯出的 `build/web/` 與 `build/seal-meadow-web.zip` 沒有上傳；PCK 64.19 MB、WASM 39.5 MB、zip 約 16 MB，這是舊版。本機伺服器 `http://127.0.0.1:8794/` 是否仍存活需另外確認。

`godot-kit/sync.sh --check seal-meadow` 目前回報 drift；上游有較新的額外模組及 `scene_builder.gd`，本輪沒有同步或修改 kit 副本。第一次沙箱內網頁匯出及測試匯入曾有 Godot socket／editor settings 權限錯誤；之後用隔離設定目錄與授權的環境重新匯出及重跑測試，沒有上述錯誤。

## 還沒做

1. **真機（M0-05、M3-05）**：iPhone 17 Safari 的載入時間、FPS、10～30 分鐘發熱、切背景後回來。需要 HTTPS 網址：用 itch 草稿頁上傳前要先問使用者。模擬器的數字在 `production/qa/m0-baseline.md`。
2. **長時間穩定性**：修好訊息紀錄的洩漏之後，還沒重跑長時間測試。使用者要求不要再讓機器人跑 25 分鐘；如果要測，改用短的定點測試。
3. **平衡**：
   - 機器人從不撤退，6 分鐘死 4～5 次，Lv1 遇到 5 隻一群可能太危險，要靠真人試玩判斷。
   - 收入約 280～600 金／6 分鐘；全部買齊加精煉到 +6 約需 2400 金，大約 4～8 次 session。
   - 寵物進化大約要餵 25～40 次。
4. **M2-06 多人試驗**：依 D08 延後。多人相關系統保留為之後可加入的項目；S19、S33 已優先製作單機薄切片。
5. **紙娃娃量產**：每個裝備層在 256 px 下一張 2560×1280，約 4.2 MB（壓縮後）。如果要大量換裝，再考慮裁切每層的空白（D05）。
6. **其他原型的 godot-kit 副本是舊版**：這次只用 `sync.sh` 同步了 seal-meadow，其他原型要等使用者同意再同步。
7. 已修正 bot 的 `sweeps` 統計；若要重新做長期平衡比較，仍需固定 seed、場景與玩法政策，不能把本輪 20 秒短測當成完整證據。

8. 舊版通用 `Web` 匯出的 PCK 同時包含 S3TC／ETC2 貼圖；新版 `Mobile Web` 候選僅用 ETC2，但載入與真機記憶體仍需實測，且尚未建立 ZIP。不得把舊版壓縮 zip 的 16 MB 誤認為實際 PCK 的下載大小。

## 注意事項

- **改 scene 的方式**：用 Godot 存檔（headless 腳本搭配 `PackedScene.pack`，或 kit 的 `SceneBuilder`）；只有單純的數值或節點列才直接改文字。
- **Blender 位置**：Windows 版 `"/mnt/c/Program Files/Blender Foundation/Blender 5.1/blender.exe"`，路徑要先用 `wslpath -w` 轉換。
- **測試依賴的固定前提**：村莊與草原在同一個 scene，相距 300 m（`TerrainHeight.TOWN_CENTER`），Town 底下的節點要用 `global_position`。
- **生圖要先問**：AI 生圖前要先問使用者，是直接生成還是只給 prompt；程序化的 Blender 建模不需要問。

## 2026-10-30 手機候選更新

已重建 `build/mobile-web/` 與 `build/seal-meadow-mobile-web.zip`，包含出售確認 Control scene；IDBFS 修補完成，ZIP CRC 完整性與 PCK 場景／腳本存在檢查通過。ZIP SHA-256 `dbb467521f52a1e971cc367f2b464fad0f0cb59cd1552741c5e712805124246f`。詳見 `production/qa/mobile-candidate-2026-10-30.json`。

新增滿 12 格、大字模式、兩種橫向尺寸的捲動清單／固定按鈕／取消保留物品測試，L2 M2 PASS（`/tmp/godot-tests.8mkgik`）。未修改 runtime；未重跑 M3，沿用 2026-10-29 結果。匯出仍有沙箱 TCP 監聽錯誤，未見腳本解析錯誤。

沙箱在 socket 建立階段即 PermissionError，無法啟動本機伺服器／Chromium Web 驗證；此候選的觸控與 IndexedDB 尚未驗證。前次 Chromium 12 項 PASS 屬於舊候選，不能沿用到新包。未上傳，iPhone 真機與長時間驗收仍待完成。

## 跨專案審查改善（2026-10-29～30）：根目錄紀錄補遺

根目錄 `Progress.md` 拆分時（2026-11-02）移入本檔原本沒有的段落；其餘 seal 段落（10-28～10-31）本檔已有對應紀錄。

| 專案 | 已完成的程式／文件工作 | 仍待外部驗收／延期 |
|---|---|---|
| seal-meadow | 出售確認／快照保護、經濟驗收計畫；本輪另完成 S34 單機乘坐薄切片 | iPhone／真人平衡、Web 新包 IndexedDB、長時間發熱；多人 M4 延後 |

- 已完成（seal 部分）：seal 材料出售規格及經濟實測計畫。重要入口 `design/quick-specs/material-sale-2026-10-29.md`。
- 程式：seal 一鍵出售先列品項、數量、總額，明示包含養成材料；確認時核對背包快照，變動即拒絕；取消／換窗不出售。可編輯視窗 `ui/sell_confirmation.tscn`。沿用售價與保存流程。
- L2 驗證：隔離 XDG 執行 `TEST_TIMEOUT=120 bash prototypes/godot-kit/tools/run_tests.sh prototypes/seal-meadow m2 m3`：M3 PASS（`/tmp/godot-tests.M1gwyv`）；M2 首次因出售按鈕未捲入可點範圍失敗，補測試捲動後單獨重跑 M2 PASS（`/tmp/godot-tests.Fciz7c`）。scene headless 匯入未見解析／資源錯誤，但有沙箱 TCP listen ERR_CANT_CREATE（`/tmp/seal-fix-import.log`），不宣稱無錯匯入。
- seal 確認改 HUD Control／捲動清單，M2 實際取消／確認與 844×390、1280×720 安全範圍及 44px 高度 PASS（`/tmp/godot-tests.yEAs8b`）；headless 匯入仍有沙箱 TCP listen 錯誤，未見解析／資源錯誤（`/tmp/seal-modal-import.log`）。本輪未重跑 M3，沿用上一批通過證據。
- seal Web 候選已於 2026-10-30 重建，匯出及靜態驗證完成，瀏覽器待驗。
- 下一步：真機確認出售清單可讀及按鈕觸控；按各驗收文件收集實測，再決定架構與數值調整。
