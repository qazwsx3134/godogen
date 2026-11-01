# 單機復活／傳送／釣魚交互 QA

2026-10-30，master，實作基準 `fad04133`；本輪回修尚未提交。[規格](../../design/quick-specs/world-lifecycle-2026-10-30.md)。

## 重現與驗證

修正前以相同主場景測試先重現：world_lifecycle 六項 FAIL，fishing 一項 FAIL，紀錄 `/tmp/godot-tests.fhnDuc`。包含村莊復活仍為 town、相機未即時對齊、舊位置未更新存檔、第一步被推回村莊、淡出中死亡後仍傳送，以及釣魚未下坐。

最終 L2 指令（repo 根目錄）：

```bash
env XDG_DATA_HOME=/tmp/seal-lifecycle-data XDG_CONFIG_HOME=/tmp/seal-lifecycle-config TEST_TIMEOUT=120 bash prototypes/godot-kit/tools/run_tests.sh prototypes/seal-meadow world_lifecycle fishing companions review_interactions
```

四組全 PASS，logs `/tmp/godot-tests.ajHIaM`；摘要 `/tmp/seal-lifecycle-final.log`。匯入仍有沙箱 TCP listen ERR_CANT_CREATE，未見 SCRIPT ERROR／Parse Error。沒有修改 scene，未執行 L3 完整 suite，依規範等人工驗收。

| 測試 | 本輪結果 |
|---|---|
| world_lifecycle | 村莊保存／重開；重複致命傷只死一次；路牌復活回滿血並恢復草原 zone／bounds；相機與同一寵物重定位；復活位置 checkpoint；第一步不跳回村莊；金幣／背包／寵物階級保留；淡出中死亡不被舊傳送搬走；再重開仍在復活點 |
| fishing | 新增有效開始會下坐／缺餌拒絕保留乘坐；既有餌與獎勵交易、取消、滿包／背景等回歸通過 |
| companions | 乘坐資格、倍率、戰鬥與生命週期、存讀、大字與兩尺寸 UI／scene 編輯保留回歸通過 |
| review_interactions | 既有拾物／傳送點擊、移動與戰鬥互動回歸通過 |

## 手機候選

`tools/build_mobile_web.sh` 重建完成（`/tmp/seal-lifecycle-build.log`），ZIP SHA-256 `e3f3e418de02f17c719c95736a7f253d4023122434a02ca194ffd7a35b029ccd`；15,113,782 bytes。ZIP CRC／PCK 一致、資源入包／排除測試工具、IDBFS 靜態檢查 PASS。另在隔離 user:// 以編譯 PCK 實例化主場景，村莊復活／取消舊傳送／釣魚下坐冒煙 PASS（`/tmp/seal-lifecycle-pack.log`）。[產物／來源 hash 與前包紀錄](mobile-candidate-2026-10-30.json)。

桌面 headless PCK 不是 Web/WASM；新包瀏覽器／IndexedDB 因沙箱禁止 socket 未驗，不能沿用舊包 Chromium 結果。iPhone 淡入淡出、相機、觸控、長時間發熱與真人平衡待驗。M2／M3 本批未重跑；各自先前證據見交接，不能稱作本批新結果。未 commit／push／上傳。
