# 2026-10-15：P1／P2 與 VFX 調整

使用者授權處理進度 review 的 P1、P2，並參考 [PokéSurvivor](https://pokesurvivor.com/) 調整呈現。保留台灣夜市題材與現有武器／傷害數值；參考短打擊、像素粒子與地面／空中效果分層。

## 修改

| 問題 | 現在的行為 |
|---|---|
| 裝飾 shader 12 個滿額後，傷害煙霧失去主要視覺 | `smoke.tscn` 自帶獨立的 Cloud 材質、DangerArea 與 DangerBoundary。`Street` 推進煙霧時間，到期同時停止傷害與移除。煙霧另受 10 個 hazard 配額限制。 |
| 高速投射物跨過薄路障，先打到後方敵人 | `Map.sweep_block` 查整段移動跨過的格子，以投射物半徑擴張路障矩形。`Projectile.hit_fraction` 計算敵人的首次接觸，`Street` 依順序處理、在牆面停止或引爆。拋物／落物／軌道／伸展武器維持既有規則。 |
| 正式網頁接受任意短局並給完整獎勵 | 正式 `Web` 忽略短局網址；`Web QA` 帶 `survivor_qa` feature，使用 `survivor_meta_qa.json`。原生編輯器命令列 QA 參數也使用獨立存檔。QA 短局標題為「測試局完成」。 |
| 遙測和物件回收斷言讀舊 Effects holder | `snapshot().effects` 讀 `fx.count()`；`vfx` 包含粒子／形狀／shader 各自的計數、上限與略過數。瀏覽器預算檢查及 playable 的回收斷言一起更新。 |
| 揮擊與命中混在一起 | 揮擊 0.12 秒、重揮 0.18 秒；`slash()` 不附帶星芒。真實碰撞才出星芒，普通 0.09 秒、重擊 0.14 秒。一般拳頭移除重複的「砰」字幕。 |
| 爆竹與屁共用大火球 | 爆竹為 0.3 秒的短閃光、破碎放射冠與碎屑；臭氣為 0.55 秒的低矮半透明綠色團塊，沒有白色爆炸核心。 |
| 特效整片蓋住人物 | 地面圈 z=-1，傷害煙霧邊界 z=-2；角色 z=0；低矮煙絲 z=1；打擊 z=8，數字 z=9。煙霧採離散輪廓與半透明填色。字幕至少間隔 0.45 秒，形狀預算保留最多 8 格給命中。 |

共用 VFX 從 `prototypes/godot-kit/addons/proto_kit/` 修改，再同步到 survivor-series。更新 kit README、pixel-vfx skill 與圖集背景層。煙霧 scene 由 Godot 儲存，包含 5 個可編輯 node；存檔時確認 pack 前後數量一致。

## 畫面

圖集是獨立擺放效果的預覽；主角與敵人保留作為大小、遮擋參考。煙霧固定在壽命中段，其他特效依標示時間推進。

- [40 ms：短閃光與命中](review-2026-10-15/vfx-040ms.png)
- [100 ms：方向揮擊、爆竹、臭氣與薄霧](review-2026-10-15/vfx-100ms.png)
- [280 ms：碎屑與氣體收尾](review-2026-10-15/vfx-280ms.png)
- [390×844 實際戰鬥，10 個傷害煙霧](review-2026-10-15/combat-phone.png)
- [QA 短局結算](review-2026-10-15/qa-results.png)

## 本輪確認範圍

Godot 4.7、macOS；Web 使用 Compatibility、無 threads。Godot 匯入與正式／QA release 匯出均完成，這些最終匯出 log 無錯誤。兩份 Web 套用既有 IDBFS 補丁。

問題重現腳本的結果見 [reproduction.log](review-2026-10-15/reproduction.log)：

- 先填滿 12 個裝飾 shader，再建立傷害煙霧：hazard 1、Cloud 與 Footprint 仍可見，shader 統計為 12。
- 投射物從 `(600,840)` 以 1000 px/s 移動 0.1 秒，撞到 x=630 的 10 px 薄牆：半徑 5 的投射物停在 x=625，標記回收；後方敵人 HP 保持 26。
- 無碰撞呼叫 `slash`：只有 slash 形狀，沒有假命中星芒。
- 同幀到期引爆與撞牆：引爆位置仍為 x=625；單次穿透武器按接觸先後命中近敵，近敵 HP 26→25、遠敵維持 26。
- 兩個煙霧材質獨立，分別推進 1／2 秒時 progress 為 0.263／0.526。

Headless Chrome 以觸控開始遊戲，觀察正式版約 12 秒並選一張升級卡，紀錄見 [browser-observation.json](review-2026-10-15/browser-observation.json)：

- 相同 context 先玩 QA 一秒局，再開正式網址 `?duration=1`：QA 為 1 秒、150 QA 金幣；正式仍為 600 秒、0 金幣，存檔路徑分開。
- QA 結算字型正常；正式版可進入戰鬥與升級，煙霧達 10 個仍可讀。這次短觀察的裝飾峰值為粒子 14、形狀 3、shader 1（非壓力效能量測）。
- 無 browser page error、Godot script error 或缺字訊息。

本輪沒有執行完整自動測試套件，也沒有量測真機 GPU、長時間遊玩或真人手感。截圖來自桌面 Chrome 的手機尺寸模擬，不能當成 iPhone／Android 實機驗收。路障目前採擴張矩形的保守掃掠判定，矩形角落可能略提早接觸。
