# 90 秒測試場驗證紀錄

日期：2026-10-07。環境：Godot 4.7 stable、WSL Linux、Chromium 1243 的 headless／SwiftShader。手機瀏覽器測試使用 390×844 觸控裝置模擬；桌面使用 540×960。

## 通過的驗證

- `tests/test_playable.gd`：47 項檢查，無腳本錯誤。包含普通命中、移動中攻擊、致命揍飛只計分一次、汽車重量、機車固定預警路線、煙霧傷害與回收、受擊節流、暫停、失焦、完整 90 秒、重試、場景資料保留、實際 UI 字型、細血條、關閉震屏立即歸位。
- `tests/test_scaffold.gd`：7 項原始骨架檢查通過。
- `godot-kit/sync.sh --check survivor-series`：副本與 kit 一致。
- `tools/build_playable.gd`：重跑後 scene／resource 雜湊一致，保留既有編輯；本次初建及後續場景存檔均經 SceneBuilder 的 owner、節點數與子 scene 引用驗證。
- Web 匯入、release export 與共用 IDBFS 補丁成功。最終 `index.pck` 為 165,056 bytes；可上傳 zip 約 9.9 MB，主要為 Godot Web 引擎。
- 完整瀏覽器流程：36 個通過紀錄（含重複物件上限檢查），零瀏覽器／Godot 腳本錯誤與失敗請求。使用真正的 touchStart／touchMove／touchEnd 事件，未靠自動播放權限解除音訊限制。
- 最後的畫面／觸控檢查：10 個通過紀錄，零錯誤，覆蓋中文字、手機入口與戰鬥、觸控移動／放手、手勢啟動音訊、自動攻擊／擊飛、暫停／繼續及桌面載入。

完整瀏覽器一局的樣本：遊戲時間 90 秒、揍飛 48、受擊 56、出拳 174；結束時敵人、煙霧與命中特效均為零，觸控重試後分數重置。這是一次隨機刷怪樣本，不是平衡目標。

完整 90 秒流程是在中文字修正後的版本執行；之後的修改為血條外觀、關閉震屏歸位與編輯器初始顯示。這些修改以針對性 headless 檢查及畫面／觸控檢查驗證；未宣稱每項微調後都重跑完整 90 秒。

## 本機證據

- 完整流程：`build/qa/report.json`、`phone-menu.png`、`phone-combat.png`、`phone-results.png`、`desktop-menu.png`。
- 最終畫面：`build/qa-final/report.json`、`phone-menu.png`、`phone-combat.png`、`desktop-menu.png`。
- 網頁交付：`build/web/` 與 `build/survivor-series-web.zip`。

build 是本機產物，已由專案 .gitignore 排除。完整重跑方法記在 README；來源包含測試與 Web preset，可重新建立產物。

## 真人驗收尚未覆蓋

Android／iPhone 真機效能、瀏海及瀏覽器工具列安全區、實際喇叭聽感、打擊爽感與 opt image 素材接入。手機模擬與 SwiftShader 的幀率不代表真機；本次沒有發布外部網站，也沒有生成 AI 美術。
