# Boss 與裝甲負載測試

## 操作

在 Godot 4.7 開啟 `scenes/boss_battlefield.tscn`，按 F6 執行目前場景。F5 仍開原本的 `battlefield.tscn`。進場後左上角 HUD 顯示 FPS 和 draw call；Esc 可釋放滑鼠，點右上角的控制。鍵盤也可直接切換：

| 按鍵 | 功能 |
|---|---|
| 1／2／3 | Boss 待機／飛行／開火動畫；飛行在原地循環，開火結束後回到選定的待機或飛行 |
| 4／5／6 | 展示機總數切換為 10／40／80 |
| 7 | 切換展示機的投影，預設關閉 |

這裡的 10／40／80 **只計展示機**，不含 Boss、玩家與原戰場的 3 台可攻擊 scout。預設 10 台包括 4 台 melee、4 台 tank、2 台 Phido；前 8 台播放錯開的 idle，Phido 為靜態模型。額外的展示機在切換負載時產生，會沿地形排列。前 10 台是儲存在 `Armor` 底下的獨立 scene instance，可在編輯器移動；Boss 也是可調位置的獨立 instance。

新加入的 Boss 與展示機目前用來檢查外觀、動畫及**渲染負載**，沒有戰鬥 AI、碰撞、受傷或攻擊判定；Boss 的開火是動畫，不會發射子彈。原有的 3 台 scout、任務與重試仍可使用。這個場景不能代表 80 台有完整 AI 與碰撞的敵人負載。

## 素材與優化

- Boss 使用 `assets/boss/boss_animated.glb`，包含骨架及 `idle`／`fly`／`fire` 動畫。
- melee／tank 展示機分別使用 `assets/armor/melee.glb`、`tank.glb`：從 `docs/86/enemy/modular/` 的重組版本複製，分別為 1,294／1,160 三角面，各有一個 mesh；保留骨架和動畫。原始版本 1,458／1,324 三角面，僅供測試工具對照。
- Phido 使用 `docs/86/phido/lowpoly_v2/` 的低面數版本，2,940 三角面、一個 mesh。
- 裝甲展示機預設不投影，可用 7 即時開啟比較。Boss、玩家和原本的 scout 不受這個開關影響。關閉投影會改變展示機的視覺效果。

## 固定鏡頭量測

2026-11-15，以 1280×720、Godot 4.7 GL Compatibility、Mesa llvmpipe 軟體渲染，固定鏡頭對同一戰場量測。每個條件先暖機 20 幀，再取 30 幀平均；Boss 處於 idle。這些 draw call／primitive 數包含整個畫面與各渲染 pass，並非單一模型的三角面數。即時監視器可能因鏡頭方向及可見物件而不同。

| 場景條件 | draw call | 繪製 primitive |
|---|---:|---:|
| 原戰場，無 Boss／展示機 | 255 | 95,711 |
| 原戰場＋Boss | 257 | 144,663 |
| Boss＋10 台原始模型，投影開 | 281 | 187,340 |
| Boss＋10 台優化模型，投影開 | 281 | 184,389 |
| Boss＋10 台優化模型，投影關 | 267 | 160,359 |
| Boss＋40 台優化展示機，投影開 | 357 | 280,905 |
| Boss＋40 台優化展示機，投影關 | 297 | 198,625 |
| Boss＋80 台優化展示機，投影開 | 437 | 382,953 |
| Boss＋80 台優化展示機，投影關 | 337 | 249,647 |

10 台原始／優化比較都使用相同位置的 4 melee、4 tank、2 Phido，兩組 Phido 相同；其他條件由場景實際的負載控制產生。數字是這個固定鏡頭的樣本，不推論手機 FPS、硬體 GPU 瓶頸或長時間溫度表現。

在專案根目錄重跑（需 Godot 與 Xvfb；有桌面環境可省略 `xvfb-run -a`）：

```bash
xvfb-run -a godot --path . --resolution 1280x720 --disable-vsync --script res://tools/perf_boss_armors.gd
godot --headless --fixed-fps 60 --path . --script res://tests/test_boss_scene.gd
```

下一步請在目標裝置直接開啟場景，維持相同視角切換數量和陰影，記錄 FPS、draw call、Godot Profiler 的 CPU／GPU 時間與一段時間後的發熱。尚未進行手機、手把或完整遊戲 AI 負載實測。

畫面截圖：[出生點](boss_battlefield.png)。截圖上的 FPS 為軟體渲染結果。
