# 驗收紀錄

遊戲規則驗證日期：2026-09-21，最終畫面重驗：2026-09-22。iOS 建置流程整合日期：2026-09-22。以下為本機工作目錄的實際結果；尚未推送或觸發 GitHub Actions。

本頁記錄目前 Stage A 的實作證據。2026-09-23 確定的「自然時間成長、步數與 Apple 健康 workout 選配加速」目前只有[設計規格](IDLE-GROWTH.md)與 [iOS 技術架構](IOS-ARCHITECTURE.md)，下列舊孵化測試不可視為新規則已通過。

## 已實作

- 可操作的直式主場景、七項核心功能與散步入口；像素房間、五種成長外觀、狀態動畫、音效及設定。
- 500 模擬步孵化與 24 小時替代模式、15 秒訓練、三名 NPC、三種成熟分支、收藏及新蛋。
- UTC 時間結算、離線 12 小時保護、作息、排泄、疾病及療護倒數。
- 完整個體和戰鬥快照存檔、備份恢復、步數去重，以及正式模式停用模擬步數與快轉。
- iOS 匯出設定及 GitHub Actions 工作流；簽署和上傳的配置見 [IOS-CICD.md](IOS-CICD.md)。

## 已測試

引擎：`4.7.stable.official.5b4e0cb0f`。桌面圖形測試環境為 Apple M1 Pro、Compatibility renderer。

| 驗證 | 實際結果 | 主要涵蓋範圍 |
| --- | --- | --- |
| Headless editor import | exit 0，無腳本錯誤 | 新增場景、字型、圖示、腳本匯入 |
| `test_care.gd` | `CARE TESTS PASS` | 拒絕操作不變異、訓練上限、睡眠、時間倒退、事件分段、疾病、進化與收藏 |
| `test_steps_save.gd` | `test_steps_save: PASS` | 完整孵化、延遲／重複／跨日／重啟步數、來源覆蓋、損壞存檔備份恢復；未跳過 hatch |
| `test_battle.gd` | `Battle tests passed` | 能力快照、雙方出手、固定 seed、重開續接、一次結算、KO 受傷與健康分離 |
| 真實主場景 headless 操作 | 110 checks，0 failures | 孵化至收藏、新蛋、重新建立主場景後恢復戰鬥與收藏 |
| 正式模式模擬 | 14 checks，0 failures | 無假步數按鈕、資料未知狀態、時間孵化、拒絕快轉及步數注入 |
| 桌面視窗操作與擷取 | 118 checks，0 failures | 真實輸入事件與畫面；375×667、390×844、402×874、430×932 的捲動及操作入口 |
| 匯出後的正式版 PCK | 17 checks，0 failures | 真正匯出的資料檔、對手、字型授權及正式模式行為 |
| iOS pipeline 離線測試 | 16 tests PASS | 簽署輸入隔離、profile/keychain 回復、私鑰清理、版本號與模擬器重用 |
| 模板工具／啟動檢查工具 | 7／3 tests PASS | 架構、來源與快取驗證；程序與資源錯誤判定 |
| arm64 模擬器模板 | 編譯、封裝與快取命中通過 | 固定 Godot source commit，補入 arm64 engine／camera，保留官方 device 函式庫 |
| iPhone 17 Pro 模擬器 | Release BUILD SUCCEEDED；啟動檢查 PASS | iOS 26.5、arm64、安裝、程序存活、主畫面與 Dynamic Island 安全區 |
| iPhone 12 模擬器 | Release BUILD SUCCEEDED；啟動檢查 PASS | iOS 26.5、arm64、安裝、程序存活與主畫面 |
| 未簽署 iPhone App | Release BUILD SUCCEEDED | 官方 device template、arm64、iOS 16 minimum、Xcode 26.6／iPhoneOS 26.5 SDK |

重跑入口（repository root）：

```sh
bash prototypes/pixel-monster/tools/verify.sh

/Applications/Godot.app/Contents/MacOS/Godot \
  --path prototypes/pixel-monster --script res://tests/test_flow.gd \
  --log-file /tmp/pixel-monster-visual-final.log \
  -- --save-path=/tmp/pixel-monster-test-visual.json
```

測試只用 `/tmp/pixel-monster-test-*.json`。`verify.sh` 先匯入，再檢查測試 exit status 及腳本／資源錯誤。戰鬥可能走不同的勝敗支線，因此重跑的檢查總數可略有差異。

沙盒中的第一次 editor import 無法儲存使用者 Library 內的 Godot 編輯器設定，已取得既有授權後重跑成功。沙盒 headless 引擎會印出 macOS CA 憑證診斷；NaN 存檔損壞案例會印出預期的 JSON warning。headless flow 結束時另有 ObjectDB 清理 warning；實際圖形視窗的最終 verbose 執行無腳本錯誤或 ObjectDB warning。

iOS 建置第一次發現官方模板宣告 arm64 simulator、實際只有 x86_64 的問題，已以相同 Godot commit 補建。Apple M1 Pro 的首次編譯耗時 5 分 43 秒，後續快取重用通過。Xcode／CoreSimulator 的沙盒限制經正式權限流程處理後完成上述本機驗證。詳細命令與 CI 使用方式見 [IOS-CICD](IOS-CICD.md)，結果索引見 [test-results.json](evidence/test-results.json)。

## 畫面證據

以下 PNG 均由 Godot 實際場景擷取：

- [新蛋](evidence/01-egg.png)、[小房間](evidence/02-companion.png)、[體重與成長日記](evidence/03-diary.png)。
- [訓練](evidence/04-training.png)、[重開後的戰鬥](evidence/05-battle.png)、[成熟體](evidence/06-mature.png)。
- [下一顆蛋](evidence/07-next-egg.png)、[長螢幕配置](evidence/08-phone.png)。
- 原生 Release App：[iPhone 17 Pro 模擬器](evidence/09-ios-iphone17-pro.png)、[iPhone 12 模擬器](evidence/10-ios-iphone12.png)。

## 尚未驗證

- iPhone 17 Pro／iPhone 12 實機安裝、效能、安全區與觸控尺寸。桌面視窗比例驗證不能取代實機。
- iOS 16 的最低 OS runtime 未執行；目前原生啟動測試使用 iOS 26.5。deployment target 設定不能取代舊 OS 相容性測試。
- 放置成長重構、`ActivityService`、iOS `CMPedometer`／HealthKit `HKWorkout` 原生外掛、entitlement、隱私用途說明與本機資料備份排除尚未實作；目前 release 使用無來源狀態和舊的時間孵化，沒有假活動資料。
- Apple Distribution 簽署、TestFlight 上傳及 App Store 審核尚未執行；需要實際 Apple Developer／App Store Connect 設定。
- GitHub 雲端 runner 尚未執行；本機驗證不能代表遠端 Actions 已通過。
- Android 原生串接與好友對戰後端為後續階段。
