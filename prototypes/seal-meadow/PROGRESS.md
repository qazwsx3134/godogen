# seal-meadow 交接進度

最後更新：2026-10-29。每次 commit、使用者出門或下班時更新這份檔案。

## 2026-10-29 復工：M3 硬化與新 review

使用者已返家，之後指定「做到一個階段先停下來，開另一個 Sol medium review」。S35 衣櫥單機階段及獨立審查已完成，目前暫停；多人 M4 保持延後。分支 `master`，本輪基準／目前最新提交 `180149a9`；本輪程式、場景、測試與文件尚未 commit／push，其他工作區修改保留。

- `REVIEW.md` 8～10：精煉移到背包分頁，兩次確認與切換取消；範圍技能命中時，未有有效既有目標且未移動才鎖定最近的命中存活怪；點傳送門顯示金色外環，換互動、移動、攻擊、施法或傳送時清除。可編輯 `ui/refine_row.tscn` 和 `scenes/portal.tscn`。
- M3 補強：損壞或異常大於 12 格的背包不再被載入時截斷，會回復有效備份或停止覆寫；寵物飢餓的經驗損失訊息改為顯示實際減少值。
- 單機 S35 衣櫥：已領成就解鎖測試布衣及程序化裝飾光環；可預覽未解鎖項目、關閉還原，套用前檢查兩項資格，外觀不改裝備／數值。存檔升 v6，v5 舊檔預設原貌／無光環；v5 讀取器會拒絕 v6，舊版遊戲寫入保護的端對端仍未實測。可編輯 `ui/wardrobe_window.tscn` 與 `scenes/player.tscn` 的 `%Aura`。
- 已補 S17／S18／S19／S33 的 GDD、TDD 與 QA 文件，和 `production/qa/m3-economy.md`。精煉以商店價的理論期望 935.24 金／件；seed 73、10,000 次模擬 934.128 金。D09／D10 仍是暫定，真人平衡未驗。
- **L2 驗證**：衣櫥完成後 `wardrobe`、`m0`、`m3`、`m3_hardening`、`collection`、`content`、`review_interactions` 通過，匯入無錯（`/tmp/godot-tests.wtxsbV/`）；衣櫥前 `m1`、`m1_loot`、`fishing` 通過。復工起點 10 組完整 suite 通過但沙箱匯入有 socket 錯誤，之後隔離環境的 editor 匯入無錯。依分層規範，最新改動的完整 suite 等使用者手動驗收後才重跑。newer／corrupt 警告是保護案例的預期輸出。
- `test_m3` 直接測 844×390／1280×720 下精煉列、44 px 觸控區及編輯文字／間距保留；`test_wardrobe` 測資格、預覽取消、數值不變、升版與 scene 編輯，桌面截圖 `/tmp/seal-review-resumed-shots/`、`/tmp/seal-wardrobe-shots/`。隔離副本中 11 個變異均被測試捕捉。
- `tools/build_mobile_web.sh` 已重建並套 IDBFS 補丁，PCK 35.07 MB、WASM 約 39.5 MB；`build/seal-meadow-mobile-web.zip` SHA-256 `a8150f3138aa02062f7abbd855ea6d87a7de0fba8cb16a7d4bacefb73efb91c4`。本地 Chromium 12 項載入、設定、v4／v5→v6、精煉及衣櫥預覽／套用／重開通過，0 browser error／failed request（`/tmp/seal-web-wardrobe-20261029/report.json`）。先前 favicon 404 是測試 fixture 的請求，已換成同源 HTML fixture；沒有忽略遊戲錯誤。`build/web/` 仍是 2026-10-27 舊版。
- **未完成**：iPhone 17 Safari 真機操作、背景／強制終止恢復、FPS、20～30 分鐘發熱與真人平衡；依使用者要求不要讓 bot 跑 25 分鐘。未上傳 itch，外部上傳與同步其他原型 kit 仍按既有約定處理。
- **獨立審查**：另一個 GPT-6 Sol／medium 已完成唯讀審查，沒有可重現的本輪功能缺陷；完整報告 `production/qa/reviews/2026-10-29-sol-medium.md`。審查指出舊版拒絕覆寫的測試命名超出單一斷言範圍；已改為「v5 讀取器拒絕 v6」，並以 `env XDG_DATA_HOME=/tmp/seal-wardrobe-final XDG_CONFIG_HOME=/tmp/seal-wardrobe-final-config timeout 90 godot --headless --path prototypes/seal-meadow --script res://tests/test_wardrobe.gd` 單獨重跑通過；QA 另標舊版程式端對端未驗。本輪 8795 本地伺服器已停止，依使用者要求到此暫停。

## 2026-10-28 出門交接（歷史紀錄，現已復工）

**使用者指示**：先補 M3 尚未完成的工作，接著依 `design/planning` 推進；M3 之後選擇**先做單機後續內容**，多人 M4 繼續延後。使用者現在出門並要求交接，停止開發；沒有授權 commit、push 或上傳 itch。分支 `master`，本輪基準 `21604e31`，本專案與根目錄 `Progress.md` 的修改都尚未提交，其他專案工作區修改需保留。

### 已實作／部分完成

- **M3 存檔與交易硬化**：存檔 v5，v1～v4 逐步遷移；同款裝備各有 uid／精煉等級，v4 原本共用的加成會保留到既有每件副本。精煉請求序號可重送同一結果，過舊序號拒絕；交任務的完成狀態在 XP 觸發存檔前更新。新版／損壞存檔停止覆寫；壞主檔可從有效備份恢復且不把壞檔覆蓋到備份。相關：`scripts/inventory.gd`、`player.gd`、`refine.gd`、`quests.gd`、`save_validation.gd`、`main.gd`。
- **M3 介面／生命週期**：新增音效、加大文字、減少戰鬥停頓設定並保存；背包可捲動，寵物進化有機率／失敗提示與二次確認。切背景清除按住移動、取消未完成施法／普攻；`ui/settings_window.tscn` 是可編輯 scene。
- **單機 S19**：`collection_book.gd` 與可編輯圖鑑視窗／成就列，紀錄三種怪物、四個可領取成就與聲望稱號，滿包獎勵不消耗／不領取、已領取不重發。舊存檔不推測歷史擊殺；既有任務完成數與寵物階段可用現況判定。未知圖鑑資料會保留。
- **單機 S33**：草原池塘的可編輯 `scenes/fishing_spot.tscn` 與釣魚視窗；村長賣釣餌，每次前景等待 5 秒，完成時才一起扣餌與發魚／凝膠。停止、移動、受擊、切背景或滿包不消耗；超出範圍不能開釣。小魚可賣或餵寵物。
- **網頁體積候選**：`export_presets.cfg` 新增 ETC2-only `Mobile Web`，保留原本通用 `Web`。本機 `build/mobile-web/` 已手動匯出並套 IDBFS 補丁；PCK **35.05 MB**、WASM 約 **39.5 MB**。原 `build/web/` 是 2026-10-27 舊版，不代表本輪內容。`tools/build_mobile_web.sh` 已寫但**尚未完整執行驗證，也尚未產生 ZIP**。

### 驗證證據與未完成

- 完整 10 組 suite 在較早版本通過，紀錄 `/tmp/godot-tests.bqN5hB/`；之後又加強存檔內容驗證與圖鑑未知資料保留，**最終版本未重跑完整 suite**。其後單獨重跑 `test_m3_hardening.gd`、`test_collection.gd` 通過；`test_fishing.gd` 的通過在最後存檔驗證修改之前。m1 離開時有 ObjectDB 清理警告；新版存檔保護測試預期印出 `save not loaded: newer` 警告。
- `tools/m3_economy.gd` 已以 seed 73、10,000 次模擬：現行 +0→+6 平均約 **934.13 金**；假設 +4 失敗退回 +3 的示例約 **1084.42 金**，示例沒有套用到遊戲。正式經濟／規格文件尚未補齊，短模擬不是真人平衡驗收。
- 手機比例桌面截圖：`/tmp/seal-m3-shots-final/`（設定、寵物、村長、背包、圖鑑、釣魚），非真機。`tools/web_m3_check.mjs` 的隔離 Chromium 測試證明畫布載入、設定存入 IndexedDB／重開、v4 裝備在 Web 升級及等級／金幣保留；**整體仍 FAIL**：測試切到 `index.icon.png` 後瀏覽器請求 `/favicon.ico` 得到 404，報告 `/tmp/seal-web-m3-final/report.json`。遊戲主要資源在伺服器紀錄中為 200；需釐清測試環境／favicon、修正並重跑，不能記為完整瀏覽器通過。本機測試伺服器 8795 已停止。
- **未完成**：iPhone 17 Safari 真機載入、觸控、背景／強制終止恢復、FPS 與 20～30 分鐘發熱；真人遊玩與平衡；M3 寵物／精煉 GDD、TDD、經濟與 QA 證據；S19／S33 規格與完整回歸；手機候選包 ZIP 與真機相容性。依使用者要求不要再讓機器人跑 25 分鐘，短測可用。其他原型 kit 副本不要自動同步。

### 接手順序

1. 先讀根目錄 `Progress.md`、本檔、`README.md`、`production/session-state/active.md`；以 `git status --short -- Progress.md prototypes/seal-meadow` 確認工作區，保留全部既有未提交修改。
2. 修正／釐清 `/favicon.ico` 的瀏覽器測試失敗後，以隔離 `XDG_DATA_HOME`／`XDG_CONFIG_HOME` 重跑完整 `bash prototypes/godot-kit/tools/run_tests.sh prototypes/seal-meadow`、短清群 bot、字型／scene 與 `tools/web_m3_check.mjs`。先確認最新 code 皆已包含於候選匯出。
3. 驗證 `tools/build_mobile_web.sh`，產生 ZIP 並記錄 hash；通用 Web 也需重匯出。補 M3 與 S19／S33 文件、經濟結果及可重現 QA／真機計畫。只有本機／模擬證據時，M3 出口仍標真機未驗證。
4. 準備可審查的 HTTPS 真機測試方案；上傳 itch 草稿前依既有指示**先取得使用者同意**。真機測完再評估 M3 出口及下一個單機分支；多人保持延後。

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

## 本輪 review 實作

- 長按物品／傳送門不會被連續走路事件清掉目標；物品點選半徑 84 px、撿取距離 1.8 m，傳送圈及其名稱皆可點；重疊時依畫面距離選目標。
- 受到怪物攻擊時，閒置角色會自動反擊；既有有效目標、點地行走與鍵盤移動優先，手動移動也會取消未命中的普攻與互動目標。
- 右上有較大的寵物／背包按鈕；小地圖與「世界地圖」可開啟可編輯場景 `ui/world_map.tscn`，顯示草原、村莊與目前區域，不直接傳送。
- 依透明像素的實際身高縮小三種佔位怪物並調整名牌高度；真人手機試玩再定最終比例。`bot_m1.gd` 現在只將 `swept` 事件算作成功施放。
- 混元 3D 2.1 官方模型可作後續候選，但 VRAM 與地域／輸出授權需要先確認，詳見 `design/pipeline/3d-to-sprite.md`；沒有下載、安裝或生圖。

## 已完成

| 階段 | 內容 | 主要檔案 |
|---|---|---|
| 規劃 | 40 系統文件審閱與修正；D01 橫向、D02 手機 Web、D03 iPhone 17、D07 近戰＋範圍揮砍；D09／D10 暫定（見決策清單） | `design/planning/`、`design/core-loop.md` |
| M0 | Web 匯出、觸控點擊、固定鏡頭、背景暫停、版本化存檔 | kit `game_clock`／`tap_picker_3d`／`save_slots`、`export_presets.cfg` |
| M1 | 單一結算入口（固定 seed 可重播）、範圍揮砍（AP、冷卻、前搖可取消）、掉落與背包（全有或全無）、社群仇恨、怪物分群、經驗曲線 `100×L^1.8`、音效與打擊回饋 | `scripts/combat.gd`、`inventory.gd`、`items.gd`、`sfx.gd`、`tests/bot_m1.gd` |
| M2 | 村長 NPC、商店、3 段任務、兩個裝備欄與紙娃娃外觀（Blender 程序化渲染鐵劍與布衣）、村莊與傳送、小地圖、5 步新手教學、內容檢查 | `scenes/town.tscn`、`npc.tscn`、`portal.tscn`、`scripts/quests.gd`、`shop.gd`、`tutorial.gd`、`tests/test_content.gd` |
| M3 | 寵物（餵食、想吃的食物、飢餓、進化、跟隨）、精煉 +0～+6、兩段式確認、經濟重調（鐵劍 300、布衣 200、水晶 40、紅寶石 160） | `scripts/pet_rules.gd`、`refine.gd`、`pet_follower.gd`、`tests/test_m3.gd` |
| 記憶體 | 貼圖 180 → 59 MB：sprite 改成 VRAM 壓縮、紙娃娃格子 384 → 256 px；陰影 2048 | `assets/sprites/**.import`、`art_src/blender/test_chibi.render.json` |
| 修 bug | HP 回復時列表每幀重建，按鈕被刪掉；訊息紀錄沒有上限，造成記憶體洩漏（25 分鐘從 63 漲到 448 MB），已限制最多 60 行；字型缺「獠」字；Town 子節點用到區域座標 | `scripts/hud.gd`、`scripts/main.gd` |

存檔目前是 v6，v1～v5 的舊存檔都有轉換步驟；最新完整回歸依規範等手動驗收後執行，真機驗證尚未完成。

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
