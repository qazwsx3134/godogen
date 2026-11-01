# 特效試映室

本機可攜式網站，分為 Sprite 圖集檢視器與真正的 Godot Web 展示。沒有上傳或公開部署。

- Sprite：41 組 Scenario 素材；搜尋、播放／暫停、重播、逐幀、時間軸、fps、1～8 倍、透明格線、原始錨點、下載 PNG／recipe。遵循 prefers-reduced-motion，切換素材會還原它的原始 fps。
- Godot：引擎按需載入，2D 41 組／3D 87 組可選並重播。3D 含 41 組 billboard 與全部 46 種 00GameDevs 原生效果，預設顯示原生效果。可篩選來源、Hit／Stop 與調速；慢速會延長自動重播間隔。武器與後製使用獨立 demo 場景。移植精度與 API 範圍見 [說明](../docs/vfx/THREE-PORTS.md)。
- 使用者提供的 `tools/vfx/pixle_vfx_forge.md` 包含額外 Static Impact recipe，目前未執行 renderer，也未將它冒充為已匯入素材。網站可下載各組原始 recipe，現階段不在瀏覽器執行或編輯 Scenario renderer。

## 建置、開啟

推薦從 repo 的[預覽工作台](../../../preview/README.md)同時開啟特效與故事編輯器：在 repo 根目錄執行 `python3 preview/start.py`，前往 `http://127.0.0.1:8000/preview/`。缺少展示包時會嘗試自動建置。

也可以獨立建置並開啟特效試映室（repo 根目錄）：

```bash
python3 prototypes/godot-kit/tools/vfx/build_showcase.py
python3 prototypes/godot-kit/build/showcase/serve.py
```

瀏覽器開 `http://127.0.0.1:8765/`。另一個連接埠可加 `--port 8766`。Sprite 頁也能直接開 `build/showcase/index.html`；Godot 的 WASM 與 PCK 須透過 HTTP。

`build/vfx-showcase.zip` 是可攜式網站包，解壓後執行其中 `serve.py`。建置需要 Godot 4.7 及對應版本的 `web_nothreads_release.zip`（已用本機既有範本建置）。不需要 npm 套件、網路 API 或雲端服務。原始碼在 `showcase/`，`data.js`／圖片／Godot 輸出由建置工具產生。

建置在暫存 Godot project 內進行；不改 kit `project.godot`。以 `--export-pack` 產生正式 PCK，搭配同版官方 release JS／WASM／audio worklet 與輕量 HTML shell。只產生 release 網站；不建立 debug template。`build/` 不納入版控，可重建。模板根目錄由 XDG_DATA_HOME 或標準使用者資料夾決定，執行檔可用 GODOT_BIN 指定。

## 驗證

```bash
# repo 根目錄；L2
XDG_DATA_HOME=/tmp/godot-vfx-user XDG_CONFIG_HOME=/tmp/godot-vfx-config \
  godot --headless --path prototypes/godot-kit --script res://tests/test_vfx.gd
XDG_DATA_HOME=/tmp/godot-vfx-user XDG_CONFIG_HOME=/tmp/godot-vfx-config \
  godot --headless --path prototypes/godot-kit --script res://tests/test_vfx_library.gd
XDG_DATA_HOME=/tmp/godot-vfx-user XDG_CONFIG_HOME=/tmp/godot-vfx-config \
  godot --headless --path prototypes/godot-kit --script res://tests/test_three_ports.gd
node --test --test-isolation=none prototypes/godot-kit/showcase/test_player.cjs
node --check prototypes/godot-kit/showcase/app.js
```

已有 Playwright 與 Chromium 的環境，先啟動上述 server，再跑：

```bash
node prototypes/godot-kit/showcase/test_browser.cjs http://127.0.0.1:8765/
```

可用 `PLAYWRIGHT_MODULE` 指向既有 Playwright module 絕對路徑、`CHROMIUM_BIN` 指向既有瀏覽器。此 script 會驗證搜尋、切換素材、逐幀／速度／倍率、手機寬度、實際 Godot Web 啟動，截圖存到 kit `build/`。

本次環境 Chromium 在啟動時被 socket sandbox 權限擋住，**瀏覽器測試未通過、沒有外觀驗收證據**。已完成的 headless、純 JS 測試與打包證據見 [驗證報告](../docs/vfx/VALIDATION.md)。Web boot、實際 GPU 外觀與手機觸控仍需在允許瀏覽器的環境重跑。
