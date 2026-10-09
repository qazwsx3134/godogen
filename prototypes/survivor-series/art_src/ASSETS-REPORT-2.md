# 階段二候選報告（第二輪，2026-10-08）
實際生成 route=local:codex-cli、provider=openai、model=codex-image_gen，使用 Codex 登入額度；未呼叫 API。
以下路徑相對 art_src；每項列出兩張候選、並排圖與實際 key。

- slipper：icons/slipper/candidate-{01,02}.png；icons/slipper/candidates-contact.png；key=magenta。
- pearl：icons/pearl/candidate-{01,02}.png；icons/pearl/candidates-contact.png；key=magenta。
- firecracker：icons/firecracker/candidate-{01,02}.png；icons/firecracker/candidates-contact.png；key=green。
- incense：icons/incense/candidate-{01,02}.png；icons/incense/candidates-contact.png；key=green。
- lantern：icons/lantern/candidate-{01,02}.png；icons/lantern/candidates-contact.png；key=green。
- cane：icons/cane/candidate-{01,02}.png；icons/cane/candidates-contact.png；key=green。
- gem：icons/gem/candidate-{01,02}.png；icons/gem/candidates-contact.png；key=magenta。
- coin：icons/coin/candidate-{01,02}.png；icons/coin/candidates-contact.png；key=magenta。
- rice：icons/rice/candidate-{01,02}.png；icons/rice/candidates-contact.png；key=magenta。
- vacuum：icons/vacuum/candidate-{01,02}.png；icons/vacuum/candidates-contact.png；key=magenta。
- chest：icons/chest/candidate-{01,02}.png；icons/chest/candidates-contact.png；key=green。

全部總覽：icons/all-contact.png，含 22 張候選與 32 px 輪廓預覽。
原始 generated.png、prompt.txt、job.json、run.json、spec.json 與 pad.json 保留於各素材 r2/；另恢復暫停前 cane 原圖至 r2/prior-pause-take-01/，未改候選。
驗收：11 項各 2 張、22 張真透明 RGBA 1024×1024、11 張並排圖與總覽齊全；每張单物件、置中、完整、無文字／地面陰影；22 次 pad 均無警告。
問題／偏差：暫停中斷 cane/chest 後先查舊請求再補齊；cane 沙盒啟動失敗已外部執行成功；pearl 01 次級棕色反光仍為單珠；香／吸塵器細長，24px 細節較弱。僅候選，未 approve 或動畫。
