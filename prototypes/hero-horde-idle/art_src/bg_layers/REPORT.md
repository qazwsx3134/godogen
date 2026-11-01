# 行軍背景分層（第一套：田園）回報

依 `docs/bg-layer-prompts.md` 生成，2026-10-29。產生器 `run_generation.py`，疊圖預覽 `preview.py` → `preview.png`。

- 工具：本機 Codex CLI 登入額度（`--route codex-cli`，`codex exec` 內建 image_gen），沒有 API key、沒有費用。11 張都是第一次就成功，沒有重試。
- 寬圖（`sky`、`far`、`mid`、`ground`）用 `route_media.py image` 生成 1536×1024（Codex 只出幾種固定比例，所以不是 1882 寬）。`far`、`mid`、`ground` 用洋紅底，由 `master_still.key_subject` 去背；`sky` 不透明。
- 物件 7 張（`prop_*`）用 `master_still.py generate --class prop`，洋紅底去背，裁到物件邊界。灌木的花指定白色和黃色，避免被洋紅去背吃掉。
- 去背 QA：10 張透明圖的 `opaque_key_px` 都是 0，沒有殘留的洋紅（matte 紀錄在 `inputs/results.json`）；用色相差遮罩（`r−g>50 且 b−g>50`）重掃，連暗紫色的陰影也是 0。
- 接縫：`far`、`mid`、`ground` 左右並排兩張看過，幾乎看不出接縫；接進遊戲前還要做邊緣淡入淡出。`sky` 不捲動，不用接。
- 沒做：霧沼（`_fog`）與熔岩（`_lava`）兩套。文件寫明先確認第一套的風格。

| 檔案 | 原始尺寸 | 內容所在範圍 |
|---|---|---|
| sky.png | 1536×1024 | 整張 |
| far.png | 1536×1024 | y 367–648 |
| mid.png | 1536×1024 | y 397–714 |
| ground.png | 1536×1024 | y 505–1024（草緣在上） |
| prop_*.png | 已裁切 | — |

下一步（Claude）：縮到遊戲的像素密度，裁成文件寫的高度，做邊緣接縫，接進主畫面風景層與行軍視差。
