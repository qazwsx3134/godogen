# 森林營地實作完成報告

本報告記錄原始交接驗收，後續地圖和移動更新見 [PROGRESS.md](PROGRESS.md)。

- 像素原型已可玩。沿用正式美術，480×270、整數縮放，地圖為三個畫面寬。
- 六層 `Parallax2D` 水平倍率依序為 sky 0.03、far 0.10、mid 0.24、near 0.45、closest 0.70、fg_occluder 1.30。
- 森林日夜約 60 秒一輪。T 快轉，`CanvasModulate` 整體壓暗、近層加速變暗，夜空星圖淡入。
- 營火可加柴增亮、道具架可查看三件道具、煮飯架會冒煙並播放音效；場景內另有帳篷與兩盞路燈。
- 角色可左右走與跳躍，起跳與落地各播一次音效。腳下陰影貼在 `RayCast2D` 命中點，離地越高越小越淡。
- 營火與路燈以 `PointLight2D.range_item_cull_mask` 限制在營地平面。實走至兩端驗證前景樹幹不壓到三個互動物件。
- `godot --headless --import` 無錯誤，`godot --headless --quit-after 12` 正常啟動，場景引用檢查零錯誤。
- `godot --headless --fixed-fps 60 --script res://tests/test_camp.gd` 通過 74 項 L2 檢查。
- `xvfb-run -a godot --audio-driver Dummy --script res://tests/capture_camp.gd` 產出 [白天](captures/day.png) 與 [深夜](captures/night.png)。切換營火燈光時，地面取樣變動 1,632 像素，森林取樣 0 像素。
- 走路腿部交替較弱。合成音效已驗證播放事件，待真人確認音色與視差氛圍。未 commit、未 push。
