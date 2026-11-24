# parallax-camp 歷史紀錄

## 2026-11-24｜master｜垂直視差

- 天空、遠景、中景、近景、最近背景的垂直倍率為 0.15、0.30、0.45、0.65、0.85。兩端遮蔽樹以 1.0 跟地面同速，天空預留頂部貼圖高度。
- `godot --headless --import` 無錯誤，`godot --headless --fixed-fps 60 --script res://tests/test_camp.gd` 與 `--fixed-fps 144` 各通過 142 項。離屏檢查在鏡頭上限量得天空上緣 480／480 像素覆蓋，近景和最近背景在各取樣點皆完整平鋪。日夜、林道與 zone 疊圖已更新；手感待真人驗收。

## 2026-11-24｜master｜營地構圖與共用鏡頭指南

- 帳篷旁使用預設跟隨。垂直取景偏移由 -93 改為 -50，鏡頭下限 y=320；開場角色腳下多約 43 像素。沿用原地面貼圖延長高台與下坡的可見土層。
- `godot --headless --import` 無錯誤，`godot --headless --fixed-fps 60 --script res://tests/test_camp.gd` 與 `--fixed-fps 144` 各通過 135 項。離屏驗證通過並更新日夜、林道及 zone 疊圖。
- 新增 [Godot 2D Camera 共用指南](../godot-2d-camera/README.md)，整理調校、接線與 Lessons。用空白 Godot 4.7 專案複製指南列出的場景與腳本，確認能追蹤角色及進出取景區。未 commit、未 push。

## 2026-11-24｜master｜獨立鏡頭與開發區域疊圖

- 比對 Godot Kit 的 Phantom Camera v0.12。它提供 Framed Follow、阻尼、按速度比例前視和虛擬鏡頭優先權。營地使用獨立 `CameraRig` 接上指定的指數平滑、水平／垂直死區、落地回中、前視門檻、下墜往下看和逐項 zone 覆寫。 [Phantom Camera 跟隨文件](https://phantom-camera.dev/follow-modes/overview)
- 可編輯的 `camera_rig.tscn`、`camera_zone.tscn` 已接入。帳篷、東側林道、高台各有取景區，高台和林道重疊可驗證優先級。開發版左下角 `Camera zones` 按鈕顯示範圍、死區與生效狀態，截圖在 `captures/camera-zones.png`。
- 重落地的上下偏移與震動由實際接地速度驅動，效果走 `Camera2D.offset`。`play_recoil()` 可接方向性後座，營地目前只有落地事件接線。
- L2（Godot 4.7）`godot --headless --import` 無錯誤，`godot --headless --quit-after 12` 正常啟動。`godot --headless --fixed-fps 60 --script res://tests/test_camp.gd` 與 `--fixed-fps 144` 各通過 132 項，包含同一目標收斂比較、完整林道走跑、區域覆寫與落地效果。
- `xvfb-run -a godot --audio-driver Dummy --script res://tests/capture_camp.gd` 產出四張截圖，確認高台區生效、近景捲動覆蓋及營火燈光比對。跑跳與取景手感待真人試玩，素材與跳躍動畫依指示延後。工作區修改未 commit、未 push。

## 2026-11-24｜master｜東側林道與二段跳

- 林道擴到五個畫面寬（2,400 px）。沿用正式地面圖鋪出東側台階與高台，新增兩盞路燈，並延伸相機、碰撞與前景樹的右端邊界。
- 跑速從 118 調為 162 px/s。Space 或 W 可在空中追加一次跳躍，落地後恢復。上東側高台時要用二段跳，沿台階可折返。
- 將重複圖層的水平偏移移到 `Parallax2D.scroll_offset`，修復煮飯架附近跨接點時露出缺口。14 個鏡頭位置逐層離屏驗證，Near 51,351／51,351、Closest 32,202／32,202 來源不透明像素在最差取樣中仍完整覆蓋。
- L2（Godot 4.7，於專案目錄）`godot --headless --import` 無錯誤、`godot --headless --quit-after 12` 正常啟動。`godot --headless --fixed-fps 60 --script res://tests/test_camp.gd` 通過 107 項。`xvfb-run -a godot --audio-driver Dummy --script res://tests/capture_camp.gd` 通過近景與燈光比對，更新日夜截圖並產出 `captures/trail.png`。
- 主要變更為 `scenes/camp.tscn`、`scenes/player.tscn`、`scripts/player.gd` 與驗收腳本。素材及跳躍動畫依使用者指示延後，音效聽感和跑跳手感待真人試玩。工作區修改未 commit、未 push。

## 2026-11-24｜master｜森林營地原型

- 完成 480×270、三個畫面寬的可玩營地。六層視差、左右端前景樹、原生 Camera2D 跟隨、約 60 秒日夜循環、星空淡入、各層深度暗化與營地專用燈光遮罩已接入。
- 完成左右走、跳躍、起跳／落地音效、RayCast2D 腳下陰影，以及營火加柴、道具面板、煮飯冒煙三個互動。沿用既有正式美術與 Godot Kit 合成音效。
- 主要場景為 `scenes/camp.tscn`、`player.tscn`、`interaction_point.tscn`、`street_lamp.tscn`。已核對打包前後節點數與子場景實例。
- L2（Godot 4.7，於專案目錄）`godot --headless --import` 無錯誤，`godot --headless --quit-after 12` 正常啟動；`godot --headless --fixed-fps 60 --script res://tests/test_camp.gd` 74 項全通過。
- `xvfb-run -a godot --audio-driver Dummy --script res://tests/capture_camp.gd` 產出兩張 480×270 截圖。開關營火時地面取樣有 1,632 像素變化，森林取樣為 0。
- 已知限制為走路動畫的腿部交替較弱、音效為合成佔位。聲音驗證涵蓋播放事件，下一步由主 session 真人驗收視差與氛圍。
- 實作與驗收檔案在工作區。依交接保留原美術修改，未 commit、未 push。

## 2026-11-23｜master｜分類提交

- art(parallax-camp): add prototype artwork
- 本次整理未重跑遊戲測試；既有驗證與待辦以 README、先前進度及測試檔為準。未 push。
- 下一步：依原專案進度進行人工驗收與後續工作。
