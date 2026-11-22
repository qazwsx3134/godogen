# 派工：風格 A（A-erwin）整套正式素材

使用者選定 style-options/A-erwin。以它的 preview.png / preview_night.png 為風格基準，照 erwin-run 的生成路線產出整套「分層」素材。
舊的 art/*.png（被否決的 Q 版那批）移到 art/_rejected/，不要刪。

## 輸出：art/final/
- 遊戲畫面 480x270（或沿用 erwin-run 的像素密度，若改 640x360 請在報告說明並全套一致）。
- 背景層，各自獨立 PNG、左右無縫、除 sky 外透明：
  sky.png（白天/黃昏）、sky_night.png（星空）、far.png、mid.png、near.png、closest.png
  （可直接用 reused/ 的 erwin-run sky/far/mid/ground，缺的 near、closest 補生成；畫風、描邊、色調要與 erwin-run 一致）
- fg_occluder.png：前景遮蔽（樹幹＋草叢），只集中在左右兩側，中間留空給互動。
- ground.png：可拼接地面。
- props/：campfire_sheet.png（6 幀橫排）、tent.png、item_rack.png（看道具）、cook_rack.png（煮飯架＋鍋）、street_lamp.png —— 照 A 預覽的造型。
- hero/：idle、walk、jump 橫排 sheet＋frames.json，與 A 預覽中的旅人同一角色、約 32x48、朝右。
- preview.png：用上面分層素材重新合成一張，證明拼起來跟 A 預覽一致。

## 驗收
alpha 只有 0/255、背景左右接縫一致、sheet 每幀對齊（用 agent-sprite-forge 的 qc 工具）。做不到直說。

## 回報
寫 art/final/REPORT.md：每個檔案一行（路徑、尺寸、檢查結果），≤30 行。
