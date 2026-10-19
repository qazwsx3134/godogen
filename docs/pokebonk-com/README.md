# pokebonk.com 研究（2.5D 像素倖存者）

**這是使用者想做的方向的主要參考**：用 2D 像素精靈圖立在 3D 像素地形上，不建模。
另一款 3D 模型版的 [pokebonk.solais.cloud](../pokebonk-3d-survivor/README.md) 只當機制參考。

| 文件 | 內容 | 作者 |
|---|---|---|
| [codex-bundle-analysis.md](codex-bundle-analysis.md) | 靜態程式拆解：精靈與 billboard、高度場地形、相機與後處理、VFX 批次、機制公式、手機處理、品質分級；每項附 Godot 對應 | Codex |
| [live-play-notes.md](live-play-notes.md) | 訪客身分實玩 2 局：流程、HUD、選卡、結算、美術觀察 | Claude |
| [data/](data/) | 精靈動作、招式 runtime、角色、敵人與生成、升級與道具、環境圖集、下載清單 | Codex |

**驗收**：verifier 對報告抽驗 14 項，13 項通過。不通過的一項是鏡頭震動頻率：實際三軸約 4.6／7.0／5.4 Hz，報告原本寫 26Hz，已更正。

## 已經用在 Godot 灰盒（`prototypes/horde-25d/`）的結論

```
像素密度一致：角色 0.074 m/px ＝ 地面 13.5 px/m
billboard：right＝鏡頭 right 的水平分量，up＝mix(世界 Y, 鏡頭 up, 0.35)；道具 lean 0
alpha < 0.5 discard、不透明、寫深度 → 不用排序
腳底橢圓影（z ×0.6、最大 alpha 0.38）、受擊 squash（寬 ×1.35、高 ×0.7）
相機 FOV 70、俯角 26°、距離 9；震動 trauma²×0.3、每秒衰減 2
擋在鏡頭與玩家之間的道具用 4×4 網點挖空
升級經驗 round(8 + 5.5L + L^1.8)
hit stop 只放慢模擬時間，不碰引擎時鐘
```

## 版權

PMD 精靈圖（CC BY-NC 4.0）和寶可夢 IP 只能當參考。第三方檔案只放在 gitignored 的 `.claude/tasks/pokebonk-com/`。
