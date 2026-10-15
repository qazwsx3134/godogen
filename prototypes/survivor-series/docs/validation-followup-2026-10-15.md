# 2026-10-15 第二輪收尾

接續 [第一輪 P1／P2 與 VFX 修正](vfx-polish-2026-10-15.md)，完成回歸、碰撞邊界與密集戰鬥的可讀性修正。

## 修正

| 項目 | 現況 |
|---|---|
| 路障圓角 | 以擴張矩形作粗查，再檢查側邊與四個圓角。擦過角落空白區可通過，真正的圓弧接觸與相切會命中。 |
| 清場索引 | `Street.clear()` 同時清空空間索引，不會讓下一次查詢取到已回收的敵人。 |
| 主角被特效遮住 | 附近至少 8 個敵人或 12 個投射物時顯示淡金輪廓及半透明本體。兩個 `Readability` Sprite2D 留在男女角色場景，各自跟隨原本的動作、翻面和可見性；不改主體的 y 排序。玩家血條／血量尾條位於 z=10。清場與重開會重設輪廓。`street.tscn` 的 `readability_*` 可調門檻與範圍。 |
| kit 測試 | 直接檢查 `effect()` 回傳值，移除「第一個子 node 必定是爆炸」的假設。補齊各類配額、命中保留名額、字幕節流、統計不可回寫與清場。 |
| 測試收尾警告 | fusion／heroes／view 在場景回收後等待原生音訊執行緒。先以 verbose 確認殘留為 AudioStreamWAV／AudioStreamPlaybackWAV，再重跑完整套件確認警告消失。 |
| 瀏覽器回歸 | `browser_check.mjs` 增加正式版短局忽略、QA 獎勵隔離與選卡後再次移動。新增 `browser_webkit_check.mjs`，保留 WebKit 的觸控開始、結算、清場、IDBFS 重載與商店檢查入口。 |

## 自動測試

Godot 4.7，macOS；原生結果在 [native/](review-2026-10-15/followup/native/)。

- 遊戲 7 組：growth、playable、scaffold、heroes、fusion、view、combat_regressions，全部通過。最後一輪沒有 SCRIPT ERROR、Parse Error 或 ObjectDB 殘留警告。
- 新增 `combat_regressions` **38 項**：圓角、接觸順序、到期引爆、拋物越障、煙霧配額／獨立時鐘／暫停／到期、清場、男女主角輪廓，以及高密度配額。修正前 5 項碰撞／清場斷言失敗，修正後全數通過。
- godot-kit `proto_kit` 通過。套件裡預期的錯誤輸入測試會輸出 ERROR（缺少 scene、錯誤副檔名、損壞資源等）；最終為 `PROTO KIT TESTS PASSED`，沒有 SCRIPT ERROR。
- 高密度測試連續推進 **5 秒遊戲時間**，峰值：140 敵人、200 投射物、500 粒子、80 形狀、12 裝飾 shader、10 個煙霧。每一格均檢查配額與傷害煙霧可見性；所有拒絕計數都有實際觸發。這是容量與生命週期測試，不是手機效能量測。

## 瀏覽器與畫面

- [Chromium 完整流程報告](review-2026-10-15/followup/chromium-report.json)：觸控移動、選卡後移動、暫停／繼續、25 秒 QA 局、重試、重新載入存檔、商店與桌面尺寸。QA 前後正式版金幣不變，正式版始終為 600 秒。無 browser／Godot／載入錯誤。
- [WebKit 報告](review-2026-10-15/followup/webkit-report.json)：6 項通過，無錯誤；觸控開始一秒 QA 局、結算回收、重新載入金幣保留、商店往返。
- [一般戰鬥](review-2026-10-15/followup/normal-combat.png) · [WebKit 結算](review-2026-10-15/followup/webkit-results.png)
- [Chromium 密集定格](review-2026-10-15/followup/density-chromium.png) · [WebKit 密集定格](review-2026-10-15/followup/density-webkit.png)

密集定格由測試副本人工填滿配額，兩種引擎都是 140 敵人、240 投射物、500 粒子、80 形狀、12 shader、10 煙霧，主角輪廓與血條仍可辨識。它是超出一般遊玩的遮擋檢查，不代表正常招式會長成圖中的藍色重疊圓環。兩者的容量快照分別在 [Chromium](review-2026-10-15/followup/density-chromium.json)／[WebKit](review-2026-10-15/followup/density-webkit.json)；預覽腳本保存在 [density.gd.txt](review-2026-10-15/followup/density.gd.txt)。

## 重新執行

Mac 的引擎位置為 `/Applications/Godot.app/Contents/MacOS/Godot`。下列指令由 repo 根目錄執行：

```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot bash prototypes/godot-kit/tools/run_tests.sh prototypes/survivor-series growth:600 playable:600 scaffold heroes:60 fusion:60 view:60 combat_regressions:60
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot bash prototypes/godot-kit/tools/run_tests.sh prototypes/godot-kit proto_kit:60
```

瀏覽器工具用法在檔頭。先匯出 `Web` 與 `Web QA`、套用 IDBFS 補丁，再用 localhost 提供 `build/`；Chromium 工具傳 `--url .../qa/index.html --production-url .../web/index.html`。WebKit 工具傳 `--url .../qa/index.html --webkit <已安裝的 pw_run.sh>`。兩者都接受 `--playwright <playwright-core 路徑>` 與 `--out <資料夾>`。

## 交付與仍需實機的部分

正式 `build/web`、QA `build/qa` 與 `build/survivor-series-web.zip` 已更新，兩份 JS 均套用 IDBFS 補丁，無對外發布。[建置指紋](review-2026-10-15/followup/build-manifest.json) 記錄交付檔案的 SHA-256。

WebKit 是本機桌面引擎搭配手機尺寸，Chromium 使用軟體 WebGL；都不能替代 iPhone／Android 的 GPU、瀏海安全區、瀏覽器工具列、切換 App 與實際喇叭／耳機驗收。本輪沒有完成手機真機驗收，也沒有據此宣稱手機達到 60 FPS。需要實機的項目仍留在 TODO T-001～T-004。
