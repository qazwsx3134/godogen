這裡是原尺寸圖；場景實際用的是 `../pixel/` 的像素縮小版（`tools/pixelize.py` 產生，檔名後綴是像素高度，例如 `heroes/man_32.png`）。燈籠光暈、濕地反光與煙霧維持平滑。主角、流氓、胖子、機車與汽車的像素版是重畫的（`art_src/<角色>/pixel/`，選定的寫在 `SELECTED.txt`），不是從這裡縮的；`pixelize.py` 只產生還不存在的檔案，加 `--force` 才會覆蓋（會蓋掉重畫版）。原圖留在 ../source/。主角使用 Motion/Visual/Art，敵人使用 Visual/Art；同一 Visual 下的 Placeholder 可獨立關閉。

| 檔案 | 來源（`art_src/`） | 用在 |
|---|---|---|
| `map/pavement.png`（512，無縫） | `map/ground/r8/candidate-02.png`（第八輪長方形鋪磚，暫用） | `street.tscn` Map/Ground |
| `fx/soft_puff.tres`（徑向漸層，有深色邊） | 程式產生 | `smoke.tscn` 的地面霧與煙團 |
| `map/lantern_glow.png`、`map/wet_reflection.png` | 同上 overlay，裁掉透明邊 | `scenes/props/lantern_post.tscn` |
| `map/<道具>.png` ×8 | `map/godot/assets/props/` | `scenes/props/*.tscn` |
| `enemies/gangster.png`（92×160，顯示 0.5 倍） | `enemies/smoker-gangster/master/`（candidate-01） | `scenes/smoker.tscn` Visual/Art |
| `heroes/man.png`、`heroes/woman.png`（180 高，顯示 0.5 倍） | `heroes/<id>/master-green/` | `player.tscn` BodyMan/Art、BodyWoman/Art |
| `enemies/fatty.png` | `enemies/fatty/master/` | `fatty.tscn` Visual/Art |
| `vehicles/<motorcycle|car>-<s|se|e|ne|n>.png` | `vehicles/<v>/master`（se）、`dir-<d>/selected.png` | `bike.tscn`、`car.tscn` 的 `direction_textures` |
| `icons/*.png`（128²） | `icons/<名稱>/selected.png` | `pickup.tscn` Looks/*/Art；`data/items/` 六把武器的 `icon`；其餘 27 張卡片的圖示在 `art_src/icons/<id>/selected.png`（切自 `art_src/icons/sheets/`），遊戲用 `assets/pixel/icons/<id>_24.png` |

場景由 `tools/build_map_scenes.gd`（2026-10-12）與 `tools/build_art_scenes.gd`（2026-10-13）一次產生，之後以場景檔為準。
