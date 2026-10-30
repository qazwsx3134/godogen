# S34 單機乘坐 QA

2026-10-30；單機薄切片 L2 自動驗證通過，真人／真機未驗。

L2 對應：companions（新功能）、m3（寵物養成與精煉）、review_interactions（移動／選怪／傳送）。修改 scene 後另以 headless editor 匯入；完整 suite 等人工驗收。

- 第 1 階拒絕，第 2 階可乘坐；死亡／戰鬥／施法時拒絕。
- 重複切換有效速度固定、move_speed／攻防／裝備不變，玩家高度恢復 scene 基準。
- 點怪／受傷／有效技能／切區／死亡／讀檔／背景清理；被拒絕的技能保留乘坐。
- 跨區與重生只保留原本 Pet entity，乘坐取消後回跟隨。
- 存檔排除暫態乘坐，重開步行；Pet stage 與原進度不變。
- 大字、844×390／1280×720：按鈕觸控區、標題關閉可見、內容可捲動、可編輯 scene 的間距執行時保留。

真機未驗：史萊姆與騎乘人物的視覺重疊、固定鏡頭可讀性、觸控與移速節奏、Safari 效能。沒有戰鬥寵 AI，不以此宣稱 AC-S34-03 通過。

## 本輪執行證據

- 指令（repo 根目錄）：`env XDG_DATA_HOME=/tmp/seal-s34-data XDG_CONFIG_HOME=/tmp/seal-s34-config TEST_TIMEOUT=120 bash prototypes/godot-kit/tools/run_tests.sh prototypes/seal-meadow companions m3 review_interactions`。
- 最終三組全部 PASS：`/tmp/godot-tests.KN9GPi`（摘要 `/tmp/seal-s34-final.log`）。未見 SCRIPT ERROR／Parse Error；editor 匯入仍有沙箱 TCP listen ERR_CANT_CREATE，不能宣稱零錯誤匯入。
- companions 實例化主場景，真實按鈕乘坐／下坐、實際位移倍率、不累加攻防、失敗／成功技能、選怪、受傷、死亡、跨區同一 entity、背景、讀檔／重開、釣魚取消不扣餌均通過。大字模式 844×390／1280×720 的捲動／固定關閉／44px 動作區，以及另存 scene 的靜態關閉文字與間距保留通過。
- 最初測試有 HUD.bind 多傳參數與使用回草原傳送門的 fixture 錯誤，已修正；失敗紀錄 `/tmp/godot-tests.miZDGR`、`/tmp/godot-tests.IbBy7M` 不作通過證據。真正跨區使用 arrival.x > 100 的村莊門。
- 場景以 Godot PackedScene 儲存，node 數 157→161、子 scene 引用一致；製作過程有 reparent owner 暫態警告，存回後再載入／執行成功。正常匯入與執行不跑產生器。
- 手機 ZIP 已重建；靜態 ZIP／PCK、IDBFS、資源入包與編譯 PCK 實例化冒煙通過。報告 [mobile-candidate-2026-10-30.json](../mobile-candidate-2026-10-30.json)。桌面 headless PCK 不等於 WASM／Safari 驗證。
- 本輪未重跑 M2，沿用 `/tmp/godot-tests.8mkgik` 的出售滿包證據；完整 suite 依 L3 規則等人工驗收後執行。
