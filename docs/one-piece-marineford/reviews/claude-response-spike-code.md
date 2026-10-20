# Claude 對 Codex spike 程式審查的處理

2026-10-20。審查對象是 `prototypes/luffy-marineford` 第 0 步視覺 spike 的程式（路線、鏡頭、後處理、方向表整合、量測）。審查全文：[codex-review-spike-code.md](codex-review-spike-code.md)。

| 審查項 | 處理 | 位置 |
|---|---|---|
| P1-1 橋口大步長橫移上橋 | 採納。`Route.clamp_move(from, to, r)`：從寬地面進裂縫且不在橋寬內，就停在裂縫邊一個半徑外、沿邊滑；已在橋上才夾橋寬。`Decor.push_out` 多帶起點，玩家、大軍走路與飛行都用。生成／瞬移仍用 `clamp_point`，改成退到較近的裂縫邊＋半徑。測試：兩個橋口、3 m 衝刺步、橋上側移、對齊橋走上去 | `scripts/route.gd`、`decor.gd`、`horde.gd`、`main.gd`；`tests/test_route.gd` |
| P1-2 舊的放射狀回收繞過路線、把前方敵人丟到後方 | 採納。路線模式（`recycle_behind > 0`）不走舊分支；舊行為只留給無路線模式。測試：前方 190 m 的敵人仍在路線上 | `scripts/horde.gd` |
| P1-3 終點附近在鏡頭內、玩家身上生怪 | 採納。`_spawn_one` 在前方位置超過終點時不生成（回傳 false，補兵迴圈停止）；後方回收在前方空間不足 `recycle_ahead × 0.6` 時不移、讓它繼續追。測試兩者 | `scripts/main.gd`、`horde.gd` |
| P2-4 身分描邊沒接上 | 採納。玩家材質設 `outline_player`（白）；大軍開 MultiMesh colors（buffer 16 → 20 float，`use_colors` 在 `instance_count` 之前），精英寫入 ROLE_ELITE（金），一般兵不描。測試角色值 | `scripts/player.gd`、`horde.gd` |
| P2-5 density 只切角色 | 採納。選定密度後，把 `1 / meters_per_px` 套到路線上所有有 `px_per_m` 的材質。測試地形值 | `scripts/main.gd` |
| P2-6 描邊平方項係數沒隨解析度／鏡頭換算 | 採納 Codex 的推導：平地相鄰畫素深度差 ≈ d² cosθ × thickness／(h f)，f＝渲染高／(2 tan(FOV/2))。`camera_rig.gd` 在換鏡頭、縮放、改視窗時算出係數 × `outline_margin`（2）寫入材質；shader 值只是預設 | `scripts/camera_rig.gd`、`shaders/pixel_outline.gdshader` |
| P2-7 SHOT 的 px 混用直立高度與邏輯座標 | 採納。改沿鏡頭 up（billboard 方向）量，乘上實際渲染尺寸；檢查 `save_png` 回傳。另外發現 macOS HiDPI 下 `get_texture().get_size()` 回報 1707×960、實際緩衝 1280×720，描邊換算、SHOT、PERF 都改用視窗尺寸（`CameraRig.render_size`）。魯夫實測 73 px，與 Codex 的 73 相符 | `scripts/main.gd`、`camera_rig.gd` |
| P2-8 圖集格子大小當成影子／施法高度 | 採納。大軍的 mesh 與材質複製一份自用；影子寬深固定世界尺寸（0.95 × 0.55 m，除以格子尺寸）；施法、受傷數字、目標點用角色身高（`SpriteSet.HEIGHTS`），不用格子尺寸 | `scripts/horde.gd`、`sprite_set.gd` |
| P2-9 punch 播不到收手格 | 採納。整段 punch 動畫對應到招式的停留時間（依 `length_ticks`）。測試三格都出現 | `scripts/player.gd` |
| P2-10 路線產生器忽略已存 scene 的設定 | 採納。已有 `route.tscn` 時先讀它的 Route 設定再重建地形 mesh；Bridge 尺寸對不上就警告（scene 不覆蓋，橋在編輯器裡改） | `tools/build_route.gd` |
| 量測可信度補充（in_view 是結束當下的幾何估計） | 接受，README 的量測表註明條件；之後手機量測補機型、瀏覽器、DPR | `prototypes/luffy-marineford/README.md` |

route、sprites、core 三組測試全部通過；網頁版重新匯出並重量（README「量測」）。

## 第二輪（[codex-review-spike-code-r2.md](codex-review-spike-code-r2.md)）

Codex 驗證修正：6 項結案，4 項部分完成（P1×1、P2×3）。

| 審查項 | 處理 | 位置 |
|---|---|---|
| P1 橋口：部分半徑（0.4／0.65／0.7／0.95）停在邊界後被浮點誤差重新判成裂縫內而橫移；斜向跨角漏判 | 採納。`clamp_move` 改成線段掃掠：區域只由起點判一次（在橋上、廣場側、頂端側），在「裂縫邊＋半徑」那條線上算穿越點的 x，在橋寬內才上橋，否則停在邊上沿邊滑，不再拿夾過的座標重新比邊界。`clamp_point` 改成選最近的可走位置（橋側或較近的裂縫邊）。測試：五種半徑 × 兩個橋口、停住後繼續推、兩端斜向跨角 | `scripts/route.gd`；`tests/test_route.gd` |
| P2 玩家白描邊沒生效（讀未設定的 uniform 得到 null） | 採納。`Player.identity_outline`（預設白）直接寫入材質。測試玩家材質 outline 的 alpha | `scripts/player.gd` |
| P2 終點前 33～55 m 的回收仍在畫面內瞬移 | 採納。回收要有完整的 `recycle_ahead` 距離才做。另外，高鏡頭看得到前方整條路，前方 55 m 本來就在視野裡，所以生成與回收都加 0.45 秒的溶解淡入（`appear_time`），不再假設「夠遠就看不到」。測試 Z=-210 | `scripts/horde.gd` |
| P2 橋段平移但長度不變時沒有警告 | 採納。警告同時比對尺寸與位置，並印出應設的值；橋面由人在編輯器調整（README 註明） | `tools/build_route.gd`、原型 README |

route、sprites、core 三組測試通過。

## 第三輪（[codex-review-spike-code-r3.md](codex-review-spike-code-r3.md)，只看預熱、出現淡入、拳影、橫幅接線）

| 審查項 | 處理 | 位置 |
|---|---|---|
| P2 預熱的特效池樣本要等遊戲恢復後才第一次畫出，樣本也沒回收 | 採納。預熱期間每幀以 dt=0 提交特效池（畫出、不老化），完整 3 幀後先回收樣本（`Fx.clear()`）、還原節點、解除壓暗，再恢復遊戲；數字 label 屬隱藏節點，已在那一輪畫過，不另發。測試：預熱期間遊戲時鐘不動、特效池有提交、結束時樣本清空。網頁大招最慢一幀 13～31 → 12 ms | `scripts/main.gd`、`fx.gd`；`tests/test_route.gd` |
| P2 拳頭圓形與外框超出 quad、末端被切平 | 採納。拳頭位置依 quad 長寬比算，外框加一個 texel 邊距落在格內；半徑縮到寬度的 0.36（外框 0.46），上下也不再出格 | `shaders/fist_streak.gdshader` |

banner、route、sprites、core 四組測試通過。
