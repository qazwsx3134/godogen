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

## 真機待做

1. 在 iPhone 17 Safari 開啟（itch.io 草稿頁或其他 HTTPS 位址；Godot Web 不接受區網 http）。
2. 記錄：首次載入秒數、走動與群戰時的 FPS、10 分鐘後 FPS 與機身溫度、切到背景再回來是否暫停並保留等級。
3. 直向持機時畫面會變成直長視野（D01 只支援橫向）；若要提示「請橫放手機」另開工作。
