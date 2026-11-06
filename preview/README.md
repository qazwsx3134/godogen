# 預覽工作台

故事編輯器和特效試映室的共同入口。原始故事、素材及工具仍放在各自專案，這裡只負責開啟預覽。

## 開啟

Windows 可雙擊這個資料夾的 `start.bat`。macOS／Linux／WSL 可在 repo 根目錄執行：

```bash
python3 preview/start.py
```

服務會嘗試開啟瀏覽器；也可自行前往 **http://127.0.0.1:8000/preview/**。保持終端機視窗開啟，用完按 `Ctrl+C` 結束。需要 Python 3.10 以上；不用 npm。

- **故事編輯器**：點「開啟故事編輯器」。選擇故事和場景，在右側展開「試玩這個場景」並按「從這裡試玩」。編輯後按「驗證並存檔」可寫回專案；未存檔的內容也可試玩。需要可執行的 Godot 4.7 與桌面圖形環境。
- **Sprite 檢視器**：點「開啟 Sprite 檢視器」，或直接到 http://127.0.0.1:8000/preview/sprites/。左邊選原型專案與圖片（自動列出 `prototypes/` 底下的 png／webp／jpg／gif，略過 node_modules、.godot、dist、build、addons）；中間放大檢視（滾輪以游標為中心縮放，1～32 倍）、像素格線、游標座標與顏色；右邊可播放 sprite sheet（設定欄、列、格數、FPS）或連號序列（檔名結尾是數字的同系列圖片），開洋蔥皮檢查每格對齊；「像素對齊」會自動偵測 AI 假像素圖的格距與偏移、可限制色數，並排比較後下載 PNG（像素對齊流程移植自 [spritefusion-pixel-snapper](https://github.com/Hugo-Dz/spritefusion-pixel-snapper)（MIT）：先量化成 16 色、梯度剖面找格距、逐格找切點、每格取眾數色；不需安裝的 JS 版本，`preview/sprites/snap.js`）。偵測不準時可開「顯示格線」對照，再手動改格距與偏移。「合併大小」可選 1×1 照原圖（預設，不合併、顏色完全不變）、2×2～8×8（每 N×N 個像素合成 1 格）、自訂或自動偵測，選好會即時顯示對齊後幾格；自動偵測遇到已經是真像素的圖（例如縮好的遊戲 sprite）會判成格距 1、不縮小；每格輸出的是原圖裡多數那一群顏色的平均，不會被壓成 16 色；輸出尺寸預設「原圖解析度」（每格填滿，圖的大小不變），也可選「縮成真像素」。「編輯像素」有畫筆、橡皮擦（變透明）、滴管、復原（Ctrl／⌘＋Z），編輯的是畫面顯示的那張；「存回原檔」只能寫回 `prototypes/` 裡已存在的 PNG，會比對開檔時的內容（別處改過就拒絕覆寫），並先把舊檔備份到 `preview/.sprite-backups/`（不進版控）。除了「存回原檔」，其他操作都不會改動專案檔案。
- **特效試映室**：點「開啟特效試映室」，切換 Sprite 圖集／Godot 特效。Godot 預覽第一次載入會需要一些時間。

如果特效展示包尚未建置，啟動時會嘗試用 Godot 4.7 與同版本的 Web 匯出範本建立；建置失敗時故事編輯器仍可使用。特效來源更新後，可手動重建並重新整理頁面：

```bash
python3 prototypes/godot-kit/tools/vfx/build_showcase.py
```

Godot 不在 PATH 時，在啟動時指定實際執行檔：

```bash
python3 preview/start.py --godot /你的路徑/godot
```

Windows 路徑可加引號，例如 `py -3 preview\start.py --godot "C:\Godot\Godot.exe"`；也可設定 `GODOT_BIN`。若 8000 已被其他程式使用，先關閉該程式，或改用 `python3 preview/start.py --port 8001`。更換連接埠會使用不同的瀏覽器本機草稿儲存空間。

## 詳細操作

- [故事編輯器說明](../prototypes/debt-commission/docs/STORY-EDITOR.md)：新故事、試玩、存檔、編劇參考與素材設定。
- [特效試映室說明](../prototypes/godot-kit/showcase/README.md)：圖集功能、匯出與測試。
- [Three.js 特效使用與限制](../prototypes/godot-kit/docs/vfx/THREE-PORTS.md)：原生場景、API 與目前驗證邊界。

預覽只綁定本機 `127.0.0.1`。故事編輯器延用原本的專案服務、驗證和存檔保護；原本的 `http://127.0.0.1:8000/tools/story_editor/` 入口也可直接使用。

驗證入口與服務整合可在 repo 根目錄執行 `python3 preview/test_preview.py -v`；像素對齊演算法可執行 `node preview/sprites/snap_test.mjs`；測試在記憶體處理 HTTP，並以暫存專案檢查存檔路由，不更動正式故事。
