# 派工：主角原畫核准＋動作影片（第三輪）

使用者已設定 XAI_API_KEY，要試影片管線。先只做男主角，驗證管線與成本；女主角等使用者看過男的結果再做。

## 步驟
1. 先跑 `forge_doctor.py` 與 `route_media.py resolve --kind video`，確認影片路徑是 xAI API、`ffmpeg` 5.1+ 在 PATH 上。任一不成立就停下回報，不要改用其他路徑。
2. 核准原畫：男 `man/edit-02.png`、女 `woman/edit-02.png` 都用 `master_still.py approve`（角色類別 hero，朝右下）。master.json 放在各自資料夾。
3. 只對男主角跑 `$video2dsprite` 的 `sprite_set.py plan` → `run` → `review`，動作三個：
   - `idle`（循環）：駝背、垂肩、輕微呼吸搖晃，厭世無力
   - `walk`（循環）：拖步、駝背的慢走
   - `attack`（單次）：大幅度右手揮拳，誇張的拳頭外拋後收回
   - 後製用 **pixel finish**，角色身高約 90 px；鏡頭維持原畫的斜俯視、朝右下，不要轉成側面。
   - output-dir：`/mnt/d/repo/godot/godogen/prototypes/survivor-series/art_src/heroes/man/set/`
4. `review` 後**不要 accept**，停下等 Claude 看 review sheet。

## 回報
寫到 `/mnt/d/repo/godot/godogen/prototypes/survivor-series/art_src/heroes/ANIM-REPORT.md`，≤15 行：
doctor/route 結果、兩個 master.json 路徑、每個動作的 take 數與 QC 結果、review sheet 路徑、實際生成的影片支數與秒數（估費用用）、問題。
