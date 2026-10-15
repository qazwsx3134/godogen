# PokéSurvivor 素材／VFX 研究交接

狀態：**依使用者要求收尾，暫停研究**。本輪只新增獨立研究資料；沒有把上游素材或程式接進 survivor-series。

## 已完成

- 下載官方公開專案固定版本 `c31715d183c0fd0b357e5ebc10fd85606132865e`（上游日期 `2026-10-14T17:34:01Z`）。
- 完整快照：**13,619 個檔案、81,435,036 bytes**；壓縮包 **57,660,568 bytes**。核對 tar 內嵌 commit，建立逐檔 SHA-256 清單。
- 下載網站首頁、正式版 JS／CSS／manifest；確認網站 `app.min.js` 與固定版本快照完全一致，版本為 `bc2124ff1d`。
- 素材：**13,468 張角色 sprite sheet**（一般 6,762、shiny 6,706），包含 Idle、Walk、Attack、Shoot、Charge、Hurt、Faint。保留上游 LICENSE、CREDITS 與字型來源。
- 初步讀過 VFX 生成、FX 更新／繪製、sprite 動畫、投射物、戰鬥觸發、預警與地圖／圖示生成程式。
- 確認原版 VFX 形狀由程式生成並快取：**23 種形狀、19 套配色**。直接執行原版繪製函式，烘出 **722 張研究用 VFX PNG**，另存每套配色的圖集。
- 建立本機研究檢視頁 `viewer.html`：VFX 配色／倍率、特效時間軸、角色方向與逐幀動畫、原版地圖／道具／圖示。
- 已用無頭 Chromium 開啟研究頁並產生截圖；匯出觀察紀錄為 **0 個瀏覽器錯誤**。目前頁面可運作，但**還沒完成逐張人工視覺審閱**。

## 已確認的研究重點（初步，尚未整理成完整報告）

1. VFX 以小型像素形狀生成原始 canvas，依 `shape + palette + frame` 快取；不只是下載貼圖。
2. 角色 metadata 有每個動畫自己的 `w/h/n/r/d/ax/ay`：尺寸、影格數、方向列、逐格時間與腳底錨點。切換動畫時維持腳的位置。
3. VFX 有不同形狀、拖尾與招式映射；`vfx.js` 負責形狀，`fx.js` 負責生命週期與畫面上的實例。
4. FX 依低／中／高畫質調整粒子、特效 sprite、文字配額及發射密度；投射物拖尾以 0.04 秒間隔發射。
5. 需要修正先前過度概括的描述：VFX sprite 旋轉取 22.5°，光束取 11.25°，揮擊弧沒有同樣的角度量化；裝飾擴散圈 y 比例 0.9，危險預警為 0.75，陰影與繞身軌道又有自己的比例。
6. 真正的多幀角色動作、逐幀時間、腳底錨點及材質不同的招式形狀，是後續與 survivor-series 對照的重要方向。這一點尚未完成系統性比對。

## 尚未完成

- **人工審閱** `screenshots/` 全部圖像，以及檢視頁的不同配色、方向與動畫切換。
- 整理完整研究報告：各類招式的形狀／尺寸／影格／節奏、VFX 快取與畫質調節、前後圖層與危險預警。
- 輸出所有招式的 `move → shape/palette/trail/melee/beam` 對照表。
- 統計 sprite metadata：方向數、常見單幀尺寸、各動畫時間與代表角色的錨點比較。
- 系統性比較原版與 survivor-series，列出可實作的改進優先序；目前只列初步觀察。
- 校正既有 `pokesurvivor-reference.md` 與 pixel-vfx skill 中過度概括的說法，附固定版本來源位置。
- 規劃／實作台灣夜市題材自己的多幀角色動畫與招式形狀庫。**本輪未開始改遊戲。**
- 研究頁尚未做手機版／WebKit 檢視，也未開啟原版完整遊戲作新一輪動態觀察。

## 資料位置

| 路徑 | 內容 |
|---|---|
| `upstream/` | 完整原始碼與素材快照 |
| `upstream-c31715d183c0.tar.gz` | 固定版本完整壓縮包 |
| `manifest.json` | 檔案清單、SHA-256、版本與下載來源 |
| `asset-summary.json`、`png-inventory.json` | 素材數量、尺寸與 PNG 格式清單 |
| `raw/` | 網站實際部署版本的 HTML、JS、CSS |
| `generated/vfx/` | 原版程式烘出的 722 張研究 PNG |
| `generated/atlas-*.png` | 19 套配色圖集 |
| `generated/vfx-catalogue.json` | 23 種形狀的尺寸、影格數、方向／旋轉屬性 |
| `generated/sprite-metadata.json` | 966 個角色的原始動畫 metadata |
| `generated/capture-observation.json` | 匯出／頁面觀察紀錄 |
| `screenshots/` | VFX 形狀、光束、近戰、角色動畫與地圖／圖示截圖 |
| `viewer.html`、`viewer.js`、`viewer.css` | 可逐格查看的本機研究頁 |
| `download_snapshot.py` | 重建固定版本快照的工具 |
| `capture_reference.mjs` | 使用原版繪製函式匯出 PNG 與截圖的工具 |

版本控制保留交接文件、精簡統計 `asset-summary.json`、下載／匯出工具與研究檢視頁。完整快照、壓縮包、網站原始檔、逐檔清單、下載／API 回應、`generated/`、`screenshots/` 及本機 session 狀態由本資料夾 `.gitignore` 排除；檔案仍留在本機，可用工具重建。它們都放在 Godot 原型目錄外，沒有進入遊戲匯出。

## 下次接續

```text
看截圖／檢視頁 → 完整研究報告 → 和目前遊戲逐項比較 → 排改進順序
```

先讀這份交接，再讀 `upstream/js/entities/vfx.js`、`fx.js`、`core/sprites.js` 與 `systems/combat.js`。不要自動開始把上游內容搬入遊戲。

重新開啟本機研究頁（目前伺服器已關閉）：

```bash
python3 -m http.server 8798 --bind 127.0.0.1 --directory research/pokesurvivor/2026-10-15
# 瀏覽 http://127.0.0.1:8798/viewer.html
```

上游來源：<https://github.com/JPTER78/pokesurvivor/tree/c31715d183c0fd0b357e5ebc10fd85606132865e>。授權與作者標示以快照的 `LICENSE`、`LICENSE-NONCOMMERCIAL.md`、`CREDITS.md` 為準。
