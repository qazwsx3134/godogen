# 男主角動作影片：手動生成交接

沒有影片 API，`sprite_set.py run` 停在 `waiting-for-clips`。每個動作用外部圖生影片工具做一支，放進指定的 `media/` 資料夾，再跑一次 `run` 就會接手去背、QC、對位、像素化與打包。

根目錄：`prototypes/survivor-series/art_src/heroes/man/set/actions/`

| 動作 | 起始圖（上傳這張） | prompt（整段貼上） | 影片放這裡 | 比例 | 尾幀 |
|---|---|---|---|---|---|
| idle（循環） | `idle/job/input.png` | `idle/takes/t01/prompt.txt` | `idle/takes/t01/media/clip.mp4` | 1:1 | 有尾幀欄位就也放 input.png |
| walk（循環） | `walk/job/input.png` | `walk/takes/t01/prompt.txt` | `walk/takes/t01/media/clip.mp4` | 1:1 | 不用 |
| attack（單次） | `attack/job/input.png` | `attack/takes/t01/prompt.txt` | `attack/takes/t01/media/clip.mp4` | 16:9 | 有尾幀欄位就也放 input.png |

生成設定：5–6 秒、720p、鏡頭固定、不要開工具自帶的「增強／運鏡」。`.mp4`、`.webm`、`.mov` 都收，檔名不限。

拿到影片後先自己看一眼：
- 背景整段維持純綠，沒有地板、陰影或漸層
- 角色沒有轉成側面、沒有走出畫面、沒有縮放
- attack 只出一拳、最後回到起始姿勢

放好後執行：

```bash
cd prototypes/survivor-series/art_src/heroes/man
~/repo/agent-sprite-forge/.venv/bin/python ~/repo/agent-sprite-forge/skills/video2dsprite/scripts/sprite_set.py run --plan set/set_plan.json
```

QC 沒過的動作會開下一個 take（`t02/`，prompt 自動加修正句），一樣手動生成放進 `t02/media/`。

## 設定紀錄
- 核准原畫：`man/master-green/master.json`（來源 `man/edit-02.png`，綠幕 key，因紅領帶偏洋紅）。`man/master/` 是先做的洋紅版，沒用到，可刪。
- 計畫：idle / walk / attack，pixel finish，身高 90 px；三個動作的 motion 已依 ANIM.md 改寫（駝背厭世、拖步、右手大揮拳，維持斜俯視朝右下）。
- Python 環境：`~/repo/agent-sprite-forge/.venv`（系統 numpy 太舊）；ffmpeg 8.1.2，VP9 alpha 正常。
