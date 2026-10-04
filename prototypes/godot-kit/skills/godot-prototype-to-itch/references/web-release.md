# 網頁匯出、瘦身、瀏覽器驗證、itch.io 頁面

以 Godot 4.7 stable、Compatibility 渲染器、單執行緒為準。以下數字都是 sugarcane-tanks 的實測（`index.pck`／`index.wasm`），別的專案會不同，但量法一樣。

## 1. 匯出設定（`export_presets.cfg`，已驗證能匯出可執行的網頁版）

```ini
[preset.0]
name="Web"
platform="Web"
runnable=true
export_filter="all_resources"
exclude_filter="tests/*, tools/*"
export_path="build/web/index.html"
script_export_mode=2

[preset.0.options]
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/export_icon=true
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
progressive_web_app/enabled=false
```

- **Thread Support 關掉**：itch.io 不用設 SharedArrayBuffer、不用 COOP／COEP 標頭。開了才需要。
- **貼圖不要勾 `for_mobile`**（ETC2／ASTC）：用的是無損或有損 WebP，勾了還要另外處理匯入。
- 專案 `config/name` 變成網頁的 `<title>`。
- **匯出模式維持 `all_resources`**：用名字在執行時找的檔案（`ResourceLoader.exists("res://assets/sfx/x.ogg")` 的「丟檔案就換聲音」、`title_bg.png`）沒有 scene 引用，改成只匯出 scene 與相依資源就會默默消失。代價是沒用到的資源也會進 pck，用 `exclude_filter` 清掉明確沒用的。
- **boot splash**：引擎啟動時讀**原檔**（一定要在 pck 裡），匯入後的貼圖版本是多餘的（0.66 MB）；把原檔路徑放進 `exclude_filter` 只會排除匯入版（實測 pck 8.31 → 7.65 MB，網頁殼的 `index.png` 仍會產生）。預設網頁殼本身就有 splash 圖（`index.png`，用 `image-rendering: pixelated`）、進度條（`<progress id="status-progress">`）與缺功能檢查（`Engine.getMissingFeatures`），不需要自訂 shell。
- 預設的 HTML 殼已經有 boot splash 圖＋進度條；只有想要中文提示或品牌時才自訂 shell。

匯出指令（約 3 秒）：

```bash
godot --headless --path . --editor --quit                       # 先匯入，否則匯出會缺資源
godot --headless --path . --export-release "Web" build/web/index.html
```

輸出：`index.html`、`index.js`（約 280 KB）、`index.pck`、`index.wasm`（約 39.5 MB）、音訊 worklet 兩個、圖示。

## 2. 匯出範本

- 範本放在 `~/.local/share/godot/export_templates/4.7.stable/`，需要 `web_nothreads_release.zip` 與 `version.txt`（內容 `4.7.stable`）。
- `.tpz` 官方檔 1.28 GB，GitHub 在這台 WSL 約 36 KB/s。它是 zip：用 HTTP Range 讀中央目錄，只抓 `web_nothreads_release.zip`（10.2 MB，總共抓 13.6 MB），zip 內建 CRC-32 會驗證每個檔。現成工具：`godot-kit/tools/web/fetch_web_templates.py`（`build_web.sh` 第一次會自動呼叫它）。我另用了 `downloads.godotengine.org` 的導向位址（`godot-releases.nbg1.your-objectstorage.com/4.7-stable/...tpz`，支援 Range）。
- **Windows 的 Godot 編輯器不看 WSL 的資料夾**，要在編輯器裡 Editor → Manage Export Templates 另外安裝。

## 3. 大小：哪裡佔空間、怎麼縮

| `index.pck` | 瘦身前 | 瘦身後 | 做法 |
|---|---|---|---|
| 字型 | 8.9 MB | 1.5 MB | `tools/subset_font.py`：可變字重 11.9 MB → 靜態 Bold 子集 2.06 MB（ASCII＋遊戲用到的字＋符號區塊＋Big5 第一級 5,401 字） |
| 貼圖 | 9.8 MB | 2.3 MB | 四張 1080×1920 背景的 `.import`：`compress/mode=1`、`compress/lossy_quality=0.9`（PSNR 39–42 dB，前後截圖肉眼分不出） |
| 音訊 | 2.7 MB | 2.7 MB | Boss 曲 WAV 10.5 MB → Ogg 1.05 MB（`soundfile` 分段寫，見 testing 文件的工具備註） |
| 合計 | **21.6 MB** | **6.8 MB** | |

- 量法：匯出後用 pck 解析腳本按副檔名加總（pck v4：檔頭後讀目錄表），看最大的幾個檔。
- `.wasm` 是引擎本體，固定。itch.io 有沒有再壓縮**沒驗證**（有資料說沒有；`itch-publish` skill 說 itch 在它那邊壓縮上傳內容，兩者指的可能不是同一件事）。
- 小聲音檔不值得動；先動字型與大圖。新加大圖也要選 Lossy。

## 4. 匯出版才會出問題的地方

- 匯出後原檔不在 pck 裡：`FileAccess.file_exists("res://assets/x.ogg")` 是 false。用 `ResourceLoader.exists(path)` + `load()`（`game/sfx.gd` 是範例）。
- 存檔走 `user://`（瀏覽器的 IndexedDB）。用「寫 `.tmp` 再改名」的存檔（`AtomicFile`）時，Emscripten 的 IDBFS 同步可能在改名前列出 `.tmp`，之後複製 ENOENT，console 出現 `Failed to save IDB file system`。`godot-kit/tools/web/patch_idbfs.py` 有補丁（`index.js` 裡把 errno 44 當作略過；找不到比對字串就失敗），`build_web.sh` 匯出後自動套用。sugarcane 的網頁版從 2026-10-04 起有套，只驗證過匯出與載入沒有 console 錯誤，真機上的設定存檔行為沒驗證。
- 視窗比 9:16 寬（桌面全螢幕）時 `expand` 會把 HUD 拉到螢幕兩端：`main.gd` 的 `_fit_window()` 在更寬時改成 `CONTENT_SCALE_ASPECT_KEEP`（兩側留黑），更高（手機）維持 `EXPAND`。
- `--write-movie` 與 headless 都量不到真實 FPS；網頁版軟體 WebGL 的幀率不代表手機。能比的是 draw call、物件數、節點數。

## 5. 手機震動（網頁）

- 呼叫 `Input.vibrate_handheld(ms)`；網頁版轉成 `navigator.vibrate(ms)`，**強度參數被忽略**。不支援時 Godot 每次都 `console.warn`，所以要先偵測、不支援就別呼叫。
- 偵測不能只看 `typeof navigator.vibrate === 'function'`：**桌面 Chromium 也是 function**（實測，`maxTouchPoints` 0）。要加 `navigator.maxTouchPoints > 0` 或 `matchMedia('(pointer: coarse)').matches`。實測手機模擬 `maxTouchPoints` 1、`coarse` true。
- iPhone Safari 沒有這個 API。Android Chrome、Firefox 有。
- itch.io 把遊戲放在跨網域 iframe：Chrome 對 iframe 內的震動有權限政策（`vibrate`，預設只給同源）與「要先被點過」兩個限制。**itch 的 iframe 有沒有開 `allow="vibrate"` 沒驗證**；沒震時看 console 的 `Permissions policy violation: vibrate`，這不是程式 bug。

## 6. 用真的瀏覽器驗證匯出版

**手機上測試不能用區網的 http 網址**：引擎檢查 `isSecureContext`，不是 HTTPS／localhost 時遊戲不啟動，只顯示缺少 `Secure Context`（pachinko 的 `serve.sh` 先踩過）。可行：上傳 itch.io 的 Draft／受限頁面用手機開（最省事，也驗證 iframe 的震動權限）；`adb reverse tcp:8000 tcp:8000` 後在手機開 `http://localhost:8000`；或在區網開 HTTPS（Caddy 內部 CA）。下面的桌面自動驗證用 `127.0.0.1`，算安全環境，所以沒有這個問題。


這台機器已有 Playwright 的 Chromium（`~/.cache/ms-playwright/chromium-*/chrome-linux64/chrome`）；`playwright-core` 用 `npm i playwright-core` 裝在暫存資料夾即可，用 `executablePath` 指定瀏覽器。

```js
const browser = await chromium.launch({ executablePath, headless: true,
  args: ['--enable-webgl', '--ignore-gpu-blocklist', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
// 兩種裝置：桌面 {viewport:{width:540,height:960}}、手機 {hasTouch:true,isMobile:true,viewport:{width:390,height:844},deviceScaleFactor:2}
```

- 用 `python3 -m http.server <port> --bind 127.0.0.1`（背景執行，記下 `$!` 再 `kill`；**不要用 `pkill -f`，會連自己的 shell 一起殺**）。不能用 `file://`。
- 看：`page.on('console')`、`pageerror`、`requestfailed`、`canvas` 尺寸、`navigator` 能力、截圖。軟體 WebGL 下約 15 秒載入完。
- `godot-kit/tools/web/web_probe.mjs` 就是這個（載入、console 錯誤、截圖、能力檢查；`--project` 指到專案，讓它讀專案自己的震動探測字串）。

## 7. itch.io 頁面與上傳

- 建頁面、`butler login` 只有使用者能做（瀏覽器授權）。頁面 **Kind of project = HTML**，頻道標成「playable in browser」（`itch-publish` 的坑）。
- 嵌入設定：直式 9:16，viewport 540×960；開 Fullscreen button；勾 Mobile friendly；方向 Portrait。桌面全螢幕靠上面的 `_fit_window()` 置中。
- 指令：`butler push build/web <user>/<game>:html --userversion <版本>`（推**資料夾**，不要推 zip 的 zip）。不用 butler 時：把 `build/web` 裡的檔案壓成 zip，**`index.html` 要在 zip 最上層**，頁面勾 "played in the browser"。
- 專案頁要寫的：音樂與音效作者與授權（CC0 也建議標）、字型授權（OFL）、素材是 AI 生成的要如實揭露（itch.io 專案頁有相關欄位，請在編輯畫面確認）、真人與真實地點的內容說明。
