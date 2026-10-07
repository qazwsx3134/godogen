# 原畫修改候選回報
狀態：master_still.py edit 各執行一次、各兩張候選；全部未核准，未執行 approve，原 candidate-01 不變。
生成路徑：route_media.py → local:codex-cli；provider=openai；requestedModel=codex-image_gen（底層影像模型版本未回報）；每張以對應 candidate-01 為第一參考圖。
man edit-01：/mnt/d/repo/godot/godogen/prototypes/survivor-series/art_src/heroes/man/edit-01.png
man edit-02：/mnt/d/repo/godot/godogen/prototypes/survivor-series/art_src/heroes/man/edit-02.png
woman edit-01：/mnt/d/repo/godot/godogen/prototypes/survivor-series/art_src/heroes/woman/edit-01.png
woman edit-02：/mnt/d/repo/godot/godogen/prototypes/survivor-series/art_src/heroes/woman/edit-02.png
man 比較圖（原圖＋兩張 edit）：/mnt/d/repo/godot/godogen/prototypes/survivor-series/art_src/heroes/man/edits-contact.png
woman 比較圖（原圖＋兩張 edit）：/mnt/d/repo/godot/godogen/prototypes/survivor-series/art_src/heroes/woman/edits-contact.png
QC：四張均 1254×1254、真透明 alpha、手腳完整、無地面陰影、未觸邊、朝右下；沿用 forge_matte.key_still 去背，不縮放；提示詞/原始圖/job.json/run.json/QC 保留於各 edit-run/。
男偏差：兩張已改為露額、貼頭的黑色油頭；表情、西裝紅領帶與駝背姿勢目視維持，但有少量輪廓/衣褶重繪，無法保證非頭髮區逐像素相同。
女偏差：兩張站姿均已直立、腳靠近；edit-01 仍有明顯虹膜，不符線條眼；edit-02 已呈細長銳利線條眼、無大虹膜。髮型服裝目視保留，有少量衣褶/手部重繪；均待使用者確認。
