# horde-25d：手機 2.5D 像素倖存者灰盒

狀態：**進行中**（灰盒技術驗證；題材未定）。參考 [pokebonk.com 研究](../../docs/pokebonk-com/README.md)。

## 要驗證的假設

1. **不建模**也能有 3D 空間感：2D 像素精靈圖立在 3D 場景裡，搭配像素風的地面、透視鏡頭、腳底影子和距離霧。
2. 同一套做法在 **網頁版（Compatibility）** 和 **原生 App（Mobile 渲染器）** 都能跑，畫面一致。
3. 用 GDScript、不建節點，手機也能撐住數百隻敵人：
   - 敵人資料存在陣列裡，用一個 MultiMesh 畫完（2 次 draw call）。
   - 用空間雜湊處理互推和命中。

## 怎麼跑

Godot 4.7 開啟 `prototypes/horde-25d/project.godot`，按 F5。

- 桌面：WASD、方向鍵或滑鼠拖曳。
- 手機：按住螢幕任一處，出現浮動搖桿。
- 武器自動攻擊；撿經驗寶石升級，三選一。

```bash
# 測試（遊戲時間 60 fps）
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot bash prototypes/godot-kit/tools/run_tests.sh prototypes/horde-25d core:60
# 網頁版
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot bash prototypes/godot-kit/tools/web/build_web.sh prototypes/horde-25d
python3 -m http.server 8794 --bind 127.0.0.1 --directory prototypes/horde-25d/build/web
# 開 http://localhost:8794/index.html?stress=400&autoplay&seed=3
```

QA 參數：
- 命令列寫在 `--` 之後，例如 `--autoplay`、`--stress=400`、`--seed=3`、`--duration=60`、`--no-hud-perf`。
- 網頁版寫在網址參數，例如 `?stress=400&autoplay`。

畫面左下角的效能列依序顯示：fps、模擬耗時、draw call、敵人數、特效數、實際使用的渲染器。

## 結構

```
main.tscn（main.gd：遊戲時鐘、生怪、經驗、勝負；依固定順序推進各系統）
 ├ Ground      PlaneMesh＋ground.gdshader：世界座標的像素草地，每公尺 13.5 px
 ├ Decor       MultiMesh：樹、石、花，按格子雜湊擺放，靠近玩家才畫
 ├ Player      player.tscn：Body（billboard）、Shadow、Xray（被擋住時的剪影）
 ├ Horde       MultiMesh：敵人陣列＋空間雜湊；mesh 的兩個 surface 分別是影子和精靈
 ├ Gems        MultiMesh：經驗寶石
 ├ Glow        MultiMesh：彈體、光球、火花、死亡圈（加法混合，1 次 draw call）
 ├ Fx / Numbers  特效壽命、傷害數字池（damage_number.tscn）
 ├ Arsenal     武器與被動（BOLT／AURA／ORBIT／NOVA），Aura、Nova 是地面環
 ├ Previews    只在編輯器看得到的敵人樣本（執行時隱藏）
 ├ CameraRig/Camera   FOV 70、俯角 26°、距離 9；震動用 h/v_offset
 └ Hud         hud.tscn：搖桿、經驗／血條、選卡（upgrade_card.tscn）、結算、效能列
```

可在編輯器調整的地方：

- **資料**：`data/enemies/*.tres`、`data/weapons/*.tres`、`data/passives/*.tres`。
- **材質參數**：`materials/*.tres`，例如 `lean`、`bob`、`hit_squash`、`outline`、`see_through`、地面配色。
- **各節點的 export**：
  - `main.gd`：生怪曲線、精英與包圍時間點、經驗曲線、hit stop。
  - `horde.gd`：上限、互推、回收距離。
  - `decor.gd`：密度、大小、權重。
  - `camera_rig.gd`：追蹤、震動。

`tools/build_scenes.gd` 是一次性的產生器，已經套用過了。檔案已存在時會跳過，不會蓋掉手動修改。
`tools/make_placeholder_art.py` 會產生佔位圖集 `assets/sprites/atlas.png`：4×2 格、每格 32 px、自己畫的。換成正式美術時保持相同格子配置即可。

## 目前的發現（2026-10-19）

1. **兩種渲染器的畫面一致**：同一幀用 Compatibility 和 Mobile 渲染，只有天空底色略有差異。下列效果兩邊都正常：
   - 剪影（`depth_test_inverted`）
   - 網點挖空
   - glow
   - 距離霧
2. **效能（桌面，不代表手機）**：
   - 原生視窗：300～500 隻敵人時模擬 0.8～1.2 ms，draw call 約 20。
   - 網頁版（無頭 Chromium，Apple GPU）：397 隻 60 fps、模擬 1.1 ms。
   - **還沒在真的手機上量**，這是下一步最重要的證據。
3. **像素密度一致**最影響觀感：角色每像素 0.074 m 對應地面每公尺 13.5 px，角色和地面看起來就像同一張像素畫。
4. **鏡頭低又廣角（26°、FOV 70）帶來的問題**：前景的物件和敵人會擋住玩家，需要兩個對策：
   - 道具用網點挖空。
   - 玩家用 x-ray 剪影。
5. **角色 shader 已移到 godot-kit 的 `sprite3d`**（2026-10-19）：本專案的外觀差異寫在 `tools/build_scenes.gd` 的 `LOOK`／`ACTOR` 與各材質；舊版 x-ray 會畫在主角自己身上，換成 kit 版後修正。
6. **Godot headless 存材質的陷阱**：沒設定的 shader 參數會被存成 `= null`，產生器存檔後要把這些行刪掉。

## 下一步

- [ ] 手機實測：網頁版在 iOS Safari 和 Android Chrome 上，200／400／600 隻敵人的 fps。
- [ ] 原生 Android 匯出設定與實機測試（Mobile 渲染器）。
- [ ] 選定題材後，生成正式精靈圖（AI 生圖前先確認批次）。
- [ ] 高度場台地地形（懸崖會擋路），參考研究文件第 2 節。
- [ ] 品質分級：最大敵數 500／900／1400；FPS 太低時自動降上限。
- [ ] 手機操作：左側 42% 才是搖桿、可選數位全速；直向時的處理方式要定。
