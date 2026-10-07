# 男女主角原畫候選回報
狀態：男女各 3 張候選已生成；全部未核准，未執行 approve，未生成動畫或其他素材。
實際路徑：master_still.py generate（手動沿用 BRIEF 指定 text 區塊）→ route_media.py → local:codex-cli。
provider=openai；model/requestedModel=codex-image_gen；底層影像模型版本未回報，未自行推定。
每次生成均附 art-direction-night-market.png；原始圖與 job.json、prompt.txt、run.json 保留於各角色資料夾。
man 1：/mnt/d/repo/godot/godogen/prototypes/survivor-series/art_src/heroes/man/candidate-01.png
man 2：/mnt/d/repo/godot/godogen/prototypes/survivor-series/art_src/heroes/man/candidate-02.png
man 3：/mnt/d/repo/godot/godogen/prototypes/survivor-series/art_src/heroes/man/candidate-03.png
woman 1：/mnt/d/repo/godot/godogen/prototypes/survivor-series/art_src/heroes/woman/candidate-01.png
woman 2：/mnt/d/repo/godot/godogen/prototypes/survivor-series/art_src/heroes/woman/candidate-02.png
woman 3：/mnt/d/repo/godot/godogen/prototypes/survivor-series/art_src/heroes/woman/candidate-03.png
man 原始比較圖（master_still）：/mnt/d/repo/godot/godogen/prototypes/survivor-series/art_src/heroes/man/takes.png
man 交付比較圖（同 contact_sheet 函式）：/mnt/d/repo/godot/godogen/prototypes/survivor-series/art_src/heroes/man/candidates-contact.png
woman 原始比較圖（master_still）：/mnt/d/repo/godot/godogen/prototypes/survivor-series/art_src/heroes/woman/takes.png
woman 交付比較圖（同 contact_sheet 函式）：/mnt/d/repo/godot/godogen/prototypes/survivor-series/art_src/heroes/woman/candidates-contact.png
處理/QC：1254×1254 原生尺寸；forge_matte.key_still 去除品紅底為真 alpha；六張皆單一全身、留白、無地面陰影、未觸邊；詳 candidate-qc.json。
朝向修正：男 1、2 原始朝左下，交付 candidate 水平鏡像成右下；原始 generated.png 未改動。
視覺偏差：女三張仍有明顯虹膜，未完全符合窄角線條眼；姿勢偏戰鬥架勢，非完全直挺；鏡頭約 50 度僅視覺檢查，無法精確量測。
環境問題：系統 Python 缺 Pillow，已用暫存 venv 補齊；sandbox 初次阻擋 Codex 初始化，核准外部執行後六張成功。未用 codeart 替代。
