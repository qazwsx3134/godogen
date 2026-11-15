# 網頁版瘦身流程

網頁版下載量決定玩家要等多久。`bash tools/build_web.sh` 每次匯出都會自動瘦身，原始檔（字型、圖、音樂、`.import`）都不動。

```
tools/build_web.sh
 ├─ 1. rsync 專案 → .cache/web-slim/（不含 build、art_src、.cache；.godot 只在第一次複製）
 ├─ 2. godot-kit/tools/web/slim_web.py .cache/web-slim   ← 只改副本
 │     ├─ 字型   超過 1 MB 的 .ttf/.otf/.ttc → 子集：專案用到的字＋Big5 常用字＋符號
 │     ├─ 圖     超過 64 KB、無損儲存的圖 → .import 改 Lossy WebP、品質 0.9
 │     ├─ 開機圖 boot_splash 寬度縮到 1280；icon 縮到 512
 │     └─ 音樂   超過 512 KB 的 .ogg → 重壓成 Vorbis 品質 0.3（約 110 kbps）
 ├─ 3. 在副本裡匯入（只重匯有變的檔）並匯出 → build/web/
 └─ 4. 補 index.js 的 IDBFS 問題
```

`SLIM=0 bash tools/build_web.sh` 不瘦身，直接匯出專案本身。需要 `uv`（會自動帶 fonttools、pillow、soundfile）與 `rsync`。

## 2026-11-14 第一次瘦身的結果

| 項目 | 瘦身前 | 瘦身後 |
|---|---|---|
| 字型（NotoSerifTC 可變字重＋story-cjk 第 0 個字面） | 23.0 MB | 4.9 MB |
| 圖（52 張大圖） | 35.2 MB | 9.6 MB |
| 音樂（13 首 ogg） | 21.3 MB | 14.1 MB |
| 開機圖 `index.png`／icon | 3.3／1.5 MB | 1.4／0.3 MB |
| **`index.pck`** | **90.4 MB** | **36.7 MB** |

引擎 `index.wasm` 39.5 MB 是固定的，由試玩站（game-portal）上傳時 gzip 成約 10 MB。玩家第一次載入從約 100 MB 降到約 49 MB。

驗證：同一個瀏覽器（headless Chromium，1280×720）開瘦身前後的匯出版，截圖標題畫面、開始故事、對話框（教學提示），並排比對肉眼看不出差別，兩邊都沒有 console 錯誤。**音樂重壓還沒用耳朵聽過**：在手機或喇叭上聽一首長曲（`gintama_13`）確認。

## 已知限制

- 字型子集在每次匯出時依當下的劇本重新產生，新增劇本不必手動處理。缺字仍會顯示成方框：來源字型本身就缺 `‹ › ⋮ ✓`（瘦身前就缺），匯出記錄會列出 `font lacks`。
- `story-cjk.ttc` 只保留第 0 個字面（WenQuanYi Zen Hei）。若哪個資源設定了 `face_index`，要改 `slim_web.py`。
- `icudt_godot.dat`（4.8 MB，CJK 斷行用的 ICU 資料）保留，沒有動。
- 想再縮：音樂可以改成單聲道或更低品質；圖可以降到 0.8。每次調整都要重做截圖比對，音樂要實際聽。
