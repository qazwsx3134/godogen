# Godot 共用素材庫

[目前進度與驗證](PROGRESS.md)

各原型可從這裡挑選素材。各包保留上游資料夾、原始檔名和授權。Godot 介面接法見 [AGENTS.md](AGENTS.md)。

| 素材包 | 版本與授權 | 內容 |
|---|---|---|
| [MorbidEmber／Pixel RPG Starter Pack](morbidember/pixel-rpg-starter-pack/) | v1.1，MIT | 64 個獨立 64×64 道具圖示與 512×512 圖集。[Godot Asset Store](https://store.godotengine.org/asset/morbidember/pixel-rpg-starter-pack/) |
| [Kenney／Input Prompts](kenney/input-prompts/) | 1.5A，CC0 1.0 | 依裝置分類的鍵鼠、觸控、控制器圖示，含 PNG、SVG 和字型。[Kenney](https://kenney.nl/assets/input-prompts) |
| [Kenney／UI Pack – Pixel Adventure](kenney/ui-pack-pixel-adventure/) | 2.0，CC0 1.0 | 粗框與細框的像素 UI，含獨立 PNG、圖集及預覽。[Kenney](https://kenney.nl/assets/ui-pack-pixel-adventure) |
| [Kenney／Fantasy UI Borders](kenney/fantasy-ui-borders/) | 1.0，CC0 1.0 | 白色奇幻花邊框，可用 `self_modulate` 染色：`PNG/Default` 為 48×48、`PNG/Double` 為 96×96。分成 Panel（實心）、Border（外框）、Transparent border／center（半透明）各 32 款，加上 Divider／Divider Fade 分隔線各 6 款，另有 SVG。做面板時用 `StyleBoxTexture`／`NinePatchRect`，Texture Margins 從 16 px（Double 用 32 px）起測。[Kenney](https://kenney.nl/assets/fantasy-ui-borders) |
| [Kenney／Pattern Pack](kenney/pattern-pack/) | 1.1，CC0 1.0 | 84 款黑白無縫圖樣（條紋、格子、磚、波浪、圓點、石紋等），`PNG/Default` 每張 256×256，另有 2 倍圖、tilesheet 與 SVG。適合當背景底紋、shader 遮罩、轉場。[Kenney](https://kenney.nl/assets/pattern-pack) |
| [Kenney／Pattern Pack Pixel](kenney/pattern-pack-pixel/) | 1.1，CC0 1.0 | 64 款 16×16 像素無縫圖樣，彩色與灰階各一套，附 tilemap（格間隔 1 px，見 `Tilesheet.txt`）。適合像素遊戲的背景與面板底紋。[Kenney](https://kenney.nl/assets/pattern-pack-pixel) |
| [Kenney／Development Essentials](kenney/development-essentials/) | 1.1，CC0 1.0 | 開發用基本貼圖：1×1／4×4 純色像素、棋盤格、6 種漸層、Perlin 雜訊、預設法線圖、UV 測試貼圖。給 shader、粒子、佔位材質用，不必再自己產生。[Kenney](https://kenney.nl/assets/development-essentials) |

版本依下載包內的授權檔或店面版本標籤記錄。MorbidEmber 也在商店頁註明限制 NFT 與 AI 訓練用途。

## 3D 模型、天空盒與 3D 貼圖

放在 repo 外的 `D:\repo\godot\model-assets`（WSL：`/mnt/d/repo/godot/model-assets`），索引見該資料夾的 `README.md`。裡面有 Kenney 的 Survival／Prototype／Castle／City／Food 等 3D 套件、5 張全景天空盒，以及 Retro Textures Fantasy／Liminal 像素貼圖。3D 遊戲要用工具、岩石、建築、天空或牆地貼圖時，先查那份索引，再把用到的檔案複製進遊戲。

## 外部素材工具與來源

- **合成音效用 Bfxr**。保留可重調的 `.bfxr` 設定，匯出 WAV 放到遊戲的 `res://`。採礦用的預設、調整方向與試聽入口見 [One More Rock 音效配方](../one-more-rock/README.md#音效配方)。 [Bfxr](https://www.bfxr.net/)
- **低多邊形 3D 道具可從 Polyfork 取用 GLB**。免費 low-poly 網格可選 CC BY 4.0，隨原始碼分享時使用這個授權，保留作者、素材來源、授權及修改註記。Polyfork 自家授權允許免署名隨遊戲發行，限制再散布獨立素材檔。下載時按素材頁確認版本，HD 和 `.mjs` 來源檔適用 Polyfork 自家授權。 [素材目錄](https://polyfork.dev/assets) · [官方授權說明](https://polyfork.dev/licensing)
