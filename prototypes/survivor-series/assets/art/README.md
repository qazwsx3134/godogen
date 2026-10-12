遊戲用貼圖放在這裡，原圖留在 ../source/。主角使用 Motion/Visual/Art，敵人使用 Visual/Art；同一 Visual 下的 Placeholder 可獨立關閉。

| 檔案 | 來源（`art_src/`） | 用在 |
|---|---|---|
| `map/pavement.png`（512，無縫） | `map/godot/assets/tilesets/pavement.png`（第七輪） | `street.tscn` Map/Ground |
| `map/lantern_glow.png`、`map/wet_reflection.png` | 同上 overlay，裁掉透明邊 | `scenes/props/lantern_post.tscn` |
| `map/<道具>.png` ×8 | `map/godot/assets/props/` | `scenes/props/*.tscn` |
| `enemies/gangster.png`（92×160，顯示 0.5 倍） | `enemies/smoker-gangster/master/`（candidate-01） | `scenes/smoker.tscn` Visual/Art |
| `heroes/man.png`、`heroes/woman.png`（180 高，顯示 0.5 倍） | `heroes/<id>/master-green/` | `player.tscn` BodyMan/Art、BodyWoman/Art |
| `enemies/fatty.png` | `enemies/fatty/master/` | `fatty.tscn` Visual/Art |
| `vehicles/<motorcycle|car>-<s|se|e|ne|n>.png` | `vehicles/<v>/master`（se）、`dir-<d>/selected.png` | `bike.tscn`、`car.tscn` 的 `direction_textures` |
| `icons/*.png`（128²） | `icons/<名稱>/selected.png` | `pickup.tscn` Looks/*/Art；`data/items/` 六把武器的 `icon`（升級卡右上角） |

場景由 `tools/build_map_scenes.gd`（2026-10-12）與 `tools/build_art_scenes.gd`（2026-10-13）一次產生，之後以場景檔為準。
