# M0 基準量測

2026-10-27。代表機：iPhone 17（D03）。**真機尚未量測**；下列是 WSL 上 headless Chromium（SwiftShader 軟體 WebGL）的數字，只能看功能與大小，不能代表手機幀率。

| 項目 | 數值 | 來源 |
|---|---|---|
| 下載 | `index.wasm` 39.5 MB（引擎，改不了）＋ `index.pck` 7.6 MB（場景 3.6／貼圖 2.3／字型 1.5 MB）；zip 15 MB | `build_web.sh` |
| 載入到可玩 | 桌面 23 s、直向手機 31 s、橫向觸控 11 s（軟體 WebGL，真機應更快） | `web_probe.mjs`、橫向觸控腳本 |
| console 錯誤／請求失敗 | 0／0 | 同上 |
| 觸控點地移動 | 通過（橫向 844×390、hasTouch） | 截圖前後比對 |
| 平均／1% low FPS、10 分鐘後 FPS | **未量** | 需 iPhone 17 Safari |

字型 1.5 MB 可用 `godot-kit/tools/subset_font.py` 子集化縮小。

## 2026-10-27 M3／review 後重新匯出

上述 7.6 MB 是 M0 的歷史數字。加入紙娃娃與後續素材後，本次 `index.pck` 64.19 MB（貼圖 58.77 MB；同時含桌面 S3TC 與手機 ETC2）、`index.wasm` 約 39.5 MB，zip 約 16 MB。本機 844×390 橫向 Chromium／SwiftShader 觸控測試可開關世界地圖，沒有瀏覽器 console error 或請求失敗，約 11.6 秒完成該測試流程；這不是 iPhone 的下載、效能或發熱數據。畫面：`/tmp/seal-web-map.png`、`/tmp/seal-web-closed.png`。

## 真機待做

1. 在 iPhone 17 Safari 開啟（itch.io 草稿頁或其他 HTTPS 位址；Godot Web 不接受區網 http）。
2. 記錄：首次載入秒數、走動與群戰時的 FPS、10 分鐘後 FPS 與機身溫度、切到背景再回來是否暫停並保留等級。
3. 直向持機時畫面會變成直長視野（D01 只支援橫向）；若要提示「請橫放手機」另開工作。
